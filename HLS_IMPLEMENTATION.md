# HLS Player Implementation

## Overview

The NOIZE.music app now supports HLS (HTTP Live Streaming) for audio playback, providing better performance, adaptive streaming, and improved user experience.

## What Was Implemented

### Backend Changes

1. **HLS Generation** (`backend/app/media.py`):
   - Added `_generate_hls_from_audio()` function that uses FFmpeg to convert audio files to HLS format
   - Generates `.m3u8` playlist file and `.ts` segment files
   - Stores HLS files in R2 storage with organized structure
   - Caches generated HLS files to avoid regeneration

2. **Updated Download Endpoint**:
   - Added `format` query parameter to `/media/download/{key}` endpoint
   - When `format=hls`, generates HLS if needed and returns `.m3u8` URL
   - Falls back to direct file streaming if HLS generation fails

3. **Dependencies**:
   - Added `ffmpeg-python==0.2.0` to `requirements.txt`
   - Requires FFmpeg to be installed on the server

### Frontend Changes

1. **Updated MediaPlayerWidget** (`flutter_app/lib/widgets/media_player_widget.dart`):
   - Modified to request HLS format by default
   - Adds `format=hls` query parameter to download requests
   - `just_audio` package automatically handles HLS streams

## How It Works

1. **First Request**:
   - Client requests audio with `format=hls`
   - Backend checks if HLS already exists in R2
   - If not, downloads original file, generates HLS using FFmpeg, uploads to R2
   - Returns `.m3u8` playlist URL

2. **Subsequent Requests**:
   - Backend finds existing HLS files
   - Returns cached `.m3u8` URL immediately

3. **Playback**:
   - `just_audio` downloads `.m3u8` playlist
   - Reads segment list and downloads segments sequentially
   - Starts playing after first few segments (much faster than full file download)

## File Structure in R2

```
uploads/user@email.com/abc123_song.mp3          (original file)
uploads/user@email.com/abc123_song.m3u8          (HLS playlist)
uploads/user@email.com/abc123_song_hls/         (HLS segments directory)
  ├── segment_000.ts
  ├── segment_001.ts
  ├── segment_002.ts
  └── ...
```

## Benefits

1. **Faster Playback**: Starts playing after downloading ~10-20 seconds of content
2. **Better Buffering**: Downloads small chunks instead of entire file
3. **Adaptive Streaming**: Can support multiple bitrates (future enhancement)
4. **Efficient Bandwidth**: Only downloads what's needed
5. **Better Seeking**: Can seek to any point by downloading specific segments

## Requirements

### Server Requirements
- FFmpeg must be installed on the backend server
- Sufficient disk space for temporary file processing
- R2 storage for HLS files

### Installation

```bash
# Install FFmpeg (Ubuntu/Debian)
sudo apt-get update
sudo apt-get install ffmpeg

# Install FFmpeg (macOS)
brew install ffmpeg

# Install FFmpeg (Windows)
# Download from https://ffmpeg.org/download.html

# Install Python dependencies
pip install -r requirements.txt
```

## Usage

### Backend API

```bash
# Request HLS format
GET /media/download/{key}?format=hls

# Response
{
  "url": "https://...presigned-url.../song.m3u8",
  "type": "presigned",
  "format": "hls"
}
```

### Flutter App

The app automatically requests HLS format. No code changes needed in screens - the `MediaPlayerWidget` handles it automatically.

## Future Enhancements

1. **Multiple Bitrates**: Generate HLS with different quality levels
2. **Background Processing**: Generate HLS during upload instead of on-demand
3. **CDN Integration**: Serve HLS files via CDN for better performance
4. **Playlist Rewriting**: Automatically rewrite playlist with full URLs for segments
5. **Live Streaming**: Support for live HLS streams

## Troubleshooting

### HLS Not Working

1. **Check FFmpeg Installation**:
   ```bash
   ffmpeg -version
   ```

2. **Check Backend Logs**:
   - Look for FFmpeg errors in server logs
   - Check if HLS generation is failing

3. **Fallback Behavior**:
   - If HLS generation fails, the app falls back to direct file streaming
   - Check if original file is accessible

4. **Storage Issues**:
   - Ensure R2 credentials are configured
   - Check if R2 bucket has write permissions

## Notes

- HLS generation is CPU-intensive and may take time for large files
- First playback may be slower while HLS is being generated
- Subsequent playbacks will be faster as HLS is cached
- For production, consider pre-generating HLS during upload
