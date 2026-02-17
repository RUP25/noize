from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, Query
from fastapi.responses import RedirectResponse
from pydantic import BaseModel
import os, uuid
import boto3
from botocore.exceptions import ClientError
from typing import Optional
import tempfile
import subprocess
import shutil
from pathlib import Path
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy import select
from .auth_integration import get_current_user
from .models import User, Song
from .db import get_db
from .cdn_config import (
    get_cdn_url, get_image_cdn_url, get_audio_cdn_url, get_video_cdn_url,
    get_cdn_headers, is_cdn_enabled, get_cdn_base_url
)

router = APIRouter(prefix="/media", tags=["media"])

R2_ENDPOINT = os.getenv('R2_ENDPOINT')
R2_ACCESS_KEY = os.getenv('R2_ACCESS_KEY')
R2_SECRET_KEY = os.getenv('R2_SECRET_KEY')
R2_BUCKET = os.getenv('R2_BUCKET', 'noize-dev')

if not (R2_ENDPOINT and R2_ACCESS_KEY and R2_SECRET_KEY):
    print("Warning: R2 credentials not set. /media/upload-presign and /media/download will fail if invoked.")

session = boto3.session.Session()
s3 = session.client(
    's3',
    endpoint_url=R2_ENDPOINT,
    aws_access_key_id=R2_ACCESS_KEY,
    aws_secret_access_key=R2_SECRET_KEY,
    region_name='auto'
)

class PresignReq(BaseModel):
    filename: str
    content_type: str
    purpose: str = "track"

@router.post('/upload-presign')
async def presign(req: PresignReq, user=Depends(get_current_user)):
    key = f"uploads/{user.contact}/{uuid.uuid4().hex}_{req.filename}"
    try:
        url = s3.generate_presigned_url('put_object', Params={'Bucket': R2_BUCKET, 'Key': key, 'ContentType': req.content_type}, ExpiresIn=300)
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
    return {"upload_url": url, "key": key}

@router.post('/upload-proxy')
async def upload_proxy(
    file: UploadFile = File(...),
    current_user: User = Depends(get_current_user)
):
    """Proxy upload endpoint to avoid CORS issues with direct R2 uploads from web browsers"""
    try:
        # Generate key
        key = f"uploads/{current_user.contact}/{uuid.uuid4().hex}_{file.filename}"
        
        # Read file content
        contents = await file.read()
        
        # Upload to R2
        s3.put_object(
            Bucket=R2_BUCKET,
            Key=key,
            Body=contents,
            ContentType=file.content_type or 'application/octet-stream'
        )
        
        # Generate CDN URL if enabled, otherwise use public endpoint
        cdn_url = None
        if is_cdn_enabled():
            cdn_url = get_cdn_url(key, content_type=file.content_type)
        
        return {
            "key": key,
            "filename": file.filename,
            "content_type": file.content_type,
            "cdn_url": cdn_url,  # CDN URL if enabled
            "public_url": f"/media/public/{key}"  # Fallback public URL
        }
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

def _generate_hls_key(original_key: str) -> str:
    """Generate HLS playlist key from original key"""
    # Replace file extension with .m3u8
    base_key = original_key.rsplit('.', 1)[0] if '.' in original_key else original_key
    return f"{base_key}.m3u8"

def _hls_segments_key(original_key: str) -> str:
    """Generate HLS segments directory key from original key"""
    base_key = original_key.rsplit('.', 1)[0] if '.' in original_key else original_key
    return f"{base_key}_hls/"

async def _generate_hls_from_audio(key: str) -> Optional[str]:
    """
    Generate HLS playlist and segments from audio file.
    Returns the HLS playlist key if successful, None otherwise.
    """
    try:
        # Check if HLS already exists
        hls_key = _generate_hls_key(key)
        try:
            s3.head_object(Bucket=R2_BUCKET, Key=hls_key)
            # HLS already exists
            return hls_key
        except ClientError:
            # HLS doesn't exist, need to generate it
            pass
        
        # Check if ffmpeg is available
        try:
            subprocess.run(['ffmpeg', '-version'], capture_output=True, check=True)
        except (subprocess.CalledProcessError, FileNotFoundError):
            # ffmpeg not available, return None
            return None
        
        # Download original file to temp location
        with tempfile.TemporaryDirectory() as tmpdir:
            tmpdir_path = Path(tmpdir)
            input_file = tmpdir_path / "input.mp3"
            output_dir = tmpdir_path / "hls_output"
            output_dir.mkdir()
            
            # Download from R2
            try:
                s3.download_file(R2_BUCKET, key, str(input_file))
            except ClientError as e:
                if e.response['Error']['Code'] == '404':
                    return None
                raise
            
            # Generate HLS using ffmpeg
            playlist_file = output_dir / "playlist.m3u8"
            segment_pattern = output_dir / "segment_%03d.ts"
            
            cmd = [
                'ffmpeg', '-i', str(input_file),
                '-c:a', 'aac',  # Audio codec
                '-b:a', '128k',  # Bitrate
                '-hls_time', '10',  # 10 second segments
                '-hls_playlist_type', 'vod',  # Video on demand
                '-hls_segment_filename', str(segment_pattern),
                '-f', 'hls',
                str(playlist_file)
            ]
            
            result = subprocess.run(cmd, capture_output=True, text=True)
            if result.returncode != 0:
                print(f"FFmpeg error: {result.stderr}")
                return None
            
            # Upload all segment files first
            segments_key_prefix = _hls_segments_key(key)
            segment_files = sorted(output_dir.glob("segment_*.ts"))
            for segment_file in segment_files:
                segment_name = segment_file.name
                segment_key = f"{segments_key_prefix}{segment_name}"
                with open(segment_file, 'rb') as f:
                    s3.put_object(
                        Bucket=R2_BUCKET,
                        Key=segment_key,
                        Body=f,
                        ContentType='video/mp2t'
                    )
            
            # Read and rewrite playlist to use absolute URLs for segments
            # This allows the player to fetch segments directly
            with open(playlist_file, 'r') as f:
                playlist_content = f.read()
            
            # For now, use relative paths - the player will need to construct full URLs
            # In production, you'd want to rewrite with full CDN/presigned URLs
            segments_key_prefix_relative = segments_key_prefix.rstrip('/')
            updated_playlist = playlist_content
            for segment_file in segment_files:
                segment_name = segment_file.name
                # Use relative path - segments will be accessed via /media/download/{segment_key}
                updated_playlist = updated_playlist.replace(
                    segment_name,
                    f"{segments_key_prefix_relative}/{segment_name}"
                )
            
            # Upload rewritten playlist file
            s3.put_object(
                Bucket=R2_BUCKET,
                Key=hls_key,
                Body=updated_playlist.encode('utf-8'),
                ContentType='application/vnd.apple.mpegurl'
            )
            
            return hls_key
    except Exception as e:
        print(f"Error generating HLS: {str(e)}")
        return None

@router.get('/download/{key:path}')
async def download(
    key: str, 
    format: Optional[str] = Query(None, description="Format: 'hls' for HLS streaming, default is direct file"),
    current_user: User = Depends(get_current_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Get download URL for media file.
    Returns CDN URL if enabled, otherwise presigned R2 URL.
    
    If format='hls', generates and returns HLS playlist URL (.m3u8).
    For HLS playlists, segments are accessible via the same base URL pattern.
    """
    try:
        # Store original key for moderation check (before HLS key transformation)
        original_key = key
        
        # Handle HLS format request
        if format == 'hls':
            # Check if it's an audio file
            if not key.lower().endswith(('.mp3', '.m4a', '.wav', '.flac', '.ogg')):
                raise HTTPException(status_code=400, detail="HLS format only supported for audio files")
            
            # Generate HLS if it doesn't exist
            hls_key = await _generate_hls_from_audio(key)
            if not hls_key:
                # Fallback to direct file if HLS generation fails
                format = None
            else:
                key = hls_key
        
        # Check if song is suspended/flagged (check original key, not HLS key)
        result = await db.execute(select(Song).where(Song.r2_key == original_key))
        song = result.scalars().first()
        if song and song.moderation_status == 'flagged':
            raise HTTPException(
                status_code=403, 
                detail="This song has been temporarily suspended"
            )
        
        # Check if CDN is enabled and use it
        if is_cdn_enabled():
            cdn_url = get_cdn_url(key)
            if cdn_url:
                return {"url": cdn_url, "type": "cdn", "format": format or "direct"}
        
        # Fallback to presigned URL
        url = s3.generate_presigned_url('get_object', Params={'Bucket': R2_BUCKET, 'Key': key}, ExpiresIn=3600)
        return {"url": url, "type": "presigned", "format": format or "direct"}
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))

@router.get('/public/{key:path}')
async def public_download(
    key: str,
    redirect: bool = Query(False, description="Redirect to CDN if enabled"),
    width: Optional[int] = Query(None, description="Image width for optimization"),
    height: Optional[int] = Query(None, description="Image height for optimization"),
    quality: Optional[int] = Query(None, description="Image quality (0-100)")
):
    """
    Public endpoint for cover photos and other public media - no auth required.
    
    If CDN is enabled and redirect=true, redirects to CDN URL.
    Otherwise, streams the file directly from R2.
    """
    try:
        # Only allow access to cover photos and public assets
        if not key.startswith('uploads/'):
            raise HTTPException(status_code=403, detail="Access denied")
        
        # If CDN is enabled and redirect requested, redirect to CDN
        if redirect and is_cdn_enabled():
            cdn_url = get_image_cdn_url(key, width=width, height=height, quality=quality)
            if cdn_url:
                return RedirectResponse(url=cdn_url, status_code=302)
        
        # Get the object from R2
        try:
            response = s3.get_object(Bucket=R2_BUCKET, Key=key)
            content_type = response.get('ContentType', 'image/jpeg')
            # Read the streaming body into bytes
            body_bytes = response['Body'].read()
        except ClientError as e:
            error_code = e.response.get('Error', {}).get('Code', '')
            if error_code == 'NoSuchKey':
                raise HTTPException(status_code=404, detail="File not found")
            raise HTTPException(status_code=500, detail=f"Error fetching file: {str(e)}")
        except Exception as e:
            raise HTTPException(status_code=500, detail=f"Error fetching file: {str(e)}")
        
        from fastapi.responses import Response
        headers = get_cdn_headers(content_type)
        return Response(
            content=body_bytes,
            media_type=content_type,
            headers=headers
        )
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))


@router.get('/cdn/{key:path}')
async def cdn_url(
    key: str,
    width: Optional[int] = Query(None),
    height: Optional[int] = Query(None),
    quality: Optional[int] = Query(None)
):
    """
    Get CDN URL for a media file.
    Returns the CDN URL if enabled, otherwise returns error.
    """
    if not is_cdn_enabled():
        raise HTTPException(status_code=503, detail="CDN is not enabled")
    
    # Determine content type from key extension
    content_type = 'application/octet-stream'
    if key.endswith(('.jpg', '.jpeg')):
        content_type = 'image/jpeg'
    elif key.endswith('.png'):
        content_type = 'image/png'
    elif key.endswith('.webp'):
        content_type = 'image/webp'
    elif key.endswith(('.mp3', '.m4a')):
        content_type = 'audio/mpeg'
    elif key.endswith('.mp4'):
        content_type = 'video/mp4'
    
    cdn_url = get_cdn_url(key, content_type=content_type, width=width, height=height, quality=quality)
    
    if not cdn_url:
        raise HTTPException(status_code=500, detail="Failed to generate CDN URL")
    
    return {
        "cdn_url": cdn_url,
        "key": key,
        "optimized": bool(width or height or quality)
    }
