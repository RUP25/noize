# backend/app/cdn_config.py
"""
Cloudflare CDN configuration and URL generation for R2 assets.
"""
import os
from typing import Optional
from urllib.parse import quote

# CDN Configuration
CDN_DOMAIN = os.getenv('CDN_DOMAIN', '')  # e.g., 'cdn.yourdomain.com' or 'your-bucket.r2.dev'
CDN_ENABLED = os.getenv('CDN_ENABLED', 'false').lower() == 'true'
R2_PUBLIC_DOMAIN = os.getenv('R2_PUBLIC_DOMAIN', '')  # Fallback R2 public domain

# CDN Settings
CDN_CACHE_TTL = int(os.getenv('CDN_CACHE_TTL', '31536000'))  # 1 year default
CDN_USE_HTTPS = os.getenv('CDN_USE_HTTPS', 'true').lower() == 'true'

# Image optimization (Cloudflare Image Resizing)
CDN_IMAGE_OPTIMIZATION = os.getenv('CDN_IMAGE_OPTIMIZATION', 'true').lower() == 'true'
CDN_IMAGE_QUALITY = os.getenv('CDN_IMAGE_QUALITY', '85')  # 0-100


def get_cdn_base_url() -> str:
    """
    Get the base CDN URL.
    
    Returns:
        Base CDN URL (e.g., 'https://cdn.yourdomain.com')
    """
    if not CDN_ENABLED or not CDN_DOMAIN:
        # Fallback to R2 public domain or direct R2 endpoint
        if R2_PUBLIC_DOMAIN:
            protocol = 'https' if CDN_USE_HTTPS else 'http'
            return f"{protocol}://{R2_PUBLIC_DOMAIN}"
        return ''
    
    protocol = 'https' if CDN_USE_HTTPS else 'http'
    return f"{protocol}://{CDN_DOMAIN}"


def get_cdn_url(key: str, content_type: Optional[str] = None, width: Optional[int] = None, 
                height: Optional[int] = None, quality: Optional[int] = None) -> str:
    """
    Generate CDN URL for an R2 object.
    
    Args:
        key: R2 object key (e.g., 'uploads/user123/song.mp3')
        content_type: MIME type (for image optimization)
        width: Optional image width for resizing
        height: Optional image height for resizing
        quality: Optional image quality (0-100)
    
    Returns:
        Full CDN URL
    """
    base_url = get_cdn_base_url()
    if not base_url:
        # No CDN configured, return empty or fallback
        return ''
    
    # URL encode the key
    encoded_key = quote(key, safe='/')
    
    # For images, add Cloudflare Image Resizing parameters
    if CDN_IMAGE_OPTIMIZATION and content_type and content_type.startswith('image/'):
        params = []
        
        if width:
            params.append(f'w={width}')
        if height:
            params.append(f'h={height}')
        
        quality_value = quality or int(CDN_IMAGE_QUALITY)
        params.append(f'q={quality_value}')
        
        if params:
            return f"{base_url}/{encoded_key}?{'&'.join(params)}"
    
    return f"{base_url}/{encoded_key}"


def get_image_cdn_url(key: str, width: Optional[int] = None, height: Optional[int] = None, 
                      quality: Optional[int] = None) -> str:
    """
    Generate optimized CDN URL for images.
    
    Args:
        key: R2 object key
        width: Desired width in pixels
        height: Desired height in pixels
        quality: Image quality (0-100, default from config)
    
    Returns:
        Optimized CDN URL
    """
    return get_cdn_url(key, content_type='image/jpeg', width=width, height=height, quality=quality)


def get_audio_cdn_url(key: str) -> str:
    """
    Generate CDN URL for audio files.
    
    Args:
        key: R2 object key
    
    Returns:
        CDN URL for audio
    """
    return get_cdn_url(key, content_type='audio/mpeg')


def get_video_cdn_url(key: str) -> str:
    """
    Generate CDN URL for video files.
    
    Args:
        key: R2 object key
    
    Returns:
        CDN URL for video
    """
    return get_cdn_url(key, content_type='video/mp4')


def get_cdn_headers(content_type: str, cache_control: Optional[str] = None) -> dict:
    """
    Get recommended CDN headers for responses.
    
    Args:
        content_type: MIME type
        cache_control: Custom cache control (default: public, max-age based on type)
    
    Returns:
        Dictionary of headers
    """
    headers = {
        'Content-Type': content_type,
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
        'Access-Control-Max-Age': '86400',
    }
    
    if cache_control:
        headers['Cache-Control'] = cache_control
    else:
        # Default cache control based on content type
        if content_type.startswith('image/'):
            headers['Cache-Control'] = f'public, max-age={CDN_CACHE_TTL}, immutable'
        elif content_type.startswith('audio/') or content_type.startswith('video/'):
            headers['Cache-Control'] = 'public, max-age=3600'  # 1 hour for media
        else:
            headers['Cache-Control'] = 'public, max-age=86400'  # 1 day for other files
    
    # Cloudflare specific headers
    if CDN_ENABLED:
        headers['CF-Cache-Status'] = 'HIT'  # Will be set by Cloudflare
        headers['X-Content-Type-Options'] = 'nosniff'
    
    return headers


def is_cdn_enabled() -> bool:
    """Check if CDN is enabled."""
    return CDN_ENABLED and bool(CDN_DOMAIN)


def convert_to_cdn_url(url: Optional[str], width: Optional[int] = None, 
                       height: Optional[int] = None) -> Optional[str]:
    """
    Convert a stored URL (R2 key or public URL) to CDN URL if CDN is enabled.
    
    Args:
        url: Original URL (can be R2 key like 'uploads/user/image.jpg' or full URL)
        width: Optional image width
        height: Optional image height
    
    Returns:
        CDN URL if CDN enabled and URL is valid, otherwise original URL
    """
    if not url or not is_cdn_enabled():
        return url
    
    # Extract R2 key from URL if it's a full URL
    key = url
    if url.startswith('http'):
        # Extract key from URL (e.g., from /media/public/uploads/...)
        if '/media/public/' in url:
            key = url.split('/media/public/')[-1]
        elif '/uploads/' in url:
            key = url.split('/uploads/')[-1]
            key = f'uploads/{key}'
        else:
            return url  # Not a recognized format
    
    # Check if it's an image
    is_image = key.lower().endswith(('.jpg', '.jpeg', '.png', '.webp', '.gif'))
    
    if is_image:
        return get_image_cdn_url(key, width=width, height=height)
    else:
        return get_cdn_url(key)
