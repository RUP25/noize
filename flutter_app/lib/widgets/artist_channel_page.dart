import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/media_service.dart';
import '../utils/toast_util.dart';
import '../widgets/media_player_widget.dart';
import '../providers/player_state_provider.dart';
import '../config/api_config.dart';

class ArtistChannelPage extends StatefulWidget {
  final String channelName;

  const ArtistChannelPage({
    super.key,
    required this.channelName,
  });

  @override
  State<ArtistChannelPage> createState() => _ArtistChannelPageState();
}

class _ArtistChannelPageState extends State<ArtistChannelPage> {
  final MediaService _media = MediaService();
  List<dynamic> _songs = [];
  bool _loading = false;
  Map<String, dynamic>? _currentlyPlayingSong;
  String? _currentlyPlayingKey;
  List<Map<String, dynamic>> _currentPlaylist = [];
  int _currentPlaylistIndex = -1;

  @override
  void initState() {
    super.initState();
    _loadSongs();
  }

  Future<void> _loadSongs() async {
    setState(() => _loading = true);
    try {
      final songs = await _media.getArtistSongs(widget.channelName);
      if (mounted) {
        setState(() {
          _songs = songs;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showToast('Failed to load songs: $e');
      }
    }
  }

  void _playSong(Map<String, dynamic> song) {
    // Check if song is suspended
    // Check for suspended/flagged status (handle null/empty cases)
    final moderationStatus = song['moderation_status']?.toString().toLowerCase();
    if (moderationStatus == 'flagged') {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey.shade900,
          title: Row(
            children: [
              const Text('🎧', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'This Song Is Taking a Break',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            'Looks like this track has been temporarily suspended.\n\nHang tight — we\'re sorting things out behind the scenes.',
            style: TextStyle(color: Colors.grey.shade300),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK', style: TextStyle(color: const Color(0xFF78E08F))),
            ),
          ],
        ),
      );
      return;
    }
    
    final playList = _songs.map((s) => s as Map<String, dynamic>).toList();
    final index = playList.indexWhere((s) => s['r2_key'] == song['r2_key']);

    setState(() {
      _currentPlaylist = playList;
      _currentPlaylistIndex = index >= 0 ? index : 0;
      _currentlyPlayingSong = song;
      _currentlyPlayingKey = song['r2_key'];
    });
  }

  void _playNext() {
    if (_currentPlaylist.isEmpty || _currentPlaylistIndex < 0) return;

    int nextIndex = _currentPlaylistIndex + 1;
    if (nextIndex >= _currentPlaylist.length) {
      nextIndex = 0;
    }

    if (nextIndex < _currentPlaylist.length) {
      _playSong(_currentPlaylist[nextIndex]);
    }
  }

  void _playPrevious() {
    if (_currentPlaylist.isEmpty || _currentPlaylistIndex < 0) return;

    int prevIndex = _currentPlaylistIndex - 1;
    if (prevIndex < 0) {
      prevIndex = _currentPlaylist.length - 1;
    }

    if (prevIndex >= 0) {
      _playSong(_currentPlaylist[prevIndex]);
    }
  }

  void _closePlayer() {
    setState(() {
      _currentlyPlayingSong = null;
      _currentlyPlayingKey = null;
    });
  }

  bool _isVideo(String? contentType) {
    if (contentType == null) return false;
    return contentType.startsWith('video/');
  }

  String? _getCoverPhotoUrl(Map<String, dynamic> song) {
    final coverUrl = song['cover_photo_url'];
    if (coverUrl == null || coverUrl.toString().isEmpty) {
      return null;
    }
    final urlStr = coverUrl.toString();

    if (urlStr.contains('/media/public/')) {
      return urlStr;
    }

    if (urlStr.contains('.r2.cloudflarestorage.com') || urlStr.contains('r2.cloudflarestorage.com')) {
      return urlStr;
    }

    if (urlStr.contains('/media/download/')) {
      final uri = Uri.parse(urlStr);
      final pathParts = uri.path.split('/media/download/');
      if (pathParts.length == 2) {
        final encodedKey = pathParts[1];
        final decodedKey = Uri.decodeComponent(encodedKey);
        final base = Uri.parse(apiBaseUrl);
        final publicUrl = base.replace(path: '${base.path}/media/public/${Uri.encodeComponent(decodedKey)}').toString();
        return publicUrl;
      }
    }

    return urlStr;
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF78E08F);

    return Scaffold(
      backgroundColor: const Color(0xFF111414),
      appBar: AppBar(
        title: Text(widget.channelName),
        backgroundColor: Colors.grey.shade900,
      ),
      body: Stack(
        children: [
          if (_loading)
            const Center(child: CircularProgressIndicator())
          else if (_songs.isEmpty)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.music_off, size: 64, color: Colors.grey.shade600),
                  const SizedBox(height: 16),
                  Text(
                    'No songs available',
                    style: TextStyle(color: Colors.grey.shade400),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'This channel hasn\'t uploaded any music yet',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            )
          else
            ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _songs.length,
              itemBuilder: (context, index) {
                final song = _songs[index] as Map<String, dynamic>;
                final title = song['title'] ?? 'Untitled';
                final album = song['album'];
                final r2Key = song['r2_key'] ?? '';
                final contentType = song['content_type'] ?? '';
                final isVideo = _isVideo(contentType);
                final isPlaying = _currentlyPlayingKey == r2Key;
                final coverPhotoUrl = _getCoverPhotoUrl(song);

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade900,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isPlaying ? accent : Colors.grey.shade800,
                      width: isPlaying ? 2 : 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    leading: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: isVideo ? Colors.red.shade900 : accent.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: coverPhotoUrl != null
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                coverPhotoUrl,
                                fit: BoxFit.cover,
                                loadingBuilder: (context, child, loadingProgress) {
                                  if (loadingProgress == null) return child;
                                  return Center(
                                    child: CircularProgressIndicator(
                                      value: loadingProgress.expectedTotalBytes != null
                                          ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                          : null,
                                      strokeWidth: 2,
                                    ),
                                  );
                                },
                                errorBuilder: (context, error, stackTrace) {
                                  return Icon(
                                    isVideo ? Icons.videocam : Icons.music_note,
                                    color: isVideo ? Colors.red.shade300 : accent,
                                    size: 28,
                                  );
                                },
                              ),
                            )
                          : Icon(
                              isVideo ? Icons.videocam : Icons.music_note,
                              color: isVideo ? Colors.red.shade300 : accent,
                              size: 28,
                            ),
                    ),
                    title: Text(
                      title,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                        fontSize: 16,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (album != null && album.toString().isNotEmpty)
                          Text(
                            'Album: $album',
                            style: TextStyle(
                              color: Colors.grey.shade400,
                              fontSize: 12,
                            ),
                          ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(
                              isVideo ? Icons.video_library : Icons.audiotrack,
                              size: 14,
                              color: Colors.grey.shade500,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              isVideo ? 'Video' : 'Audio',
                              style: TextStyle(
                                color: Colors.grey.shade500,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (!isVideo)
                          IconButton(
                            icon: Icon(
                              isPlaying ? Icons.pause_circle : Icons.play_circle,
                              color: accent,
                              size: 32,
                            ),
                            onPressed: () {
                              _playSong(song);
                            },
                            tooltip: 'Play',
                          ),
                        if (isVideo)
                          IconButton(
                            icon: const Icon(
                              Icons.play_circle_outline,
                              color: Colors.white70,
                              size: 28,
                            ),
                            onPressed: () {
                              showToast('Video playback coming soon');
                            },
                            tooltip: 'View Video',
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          // Media Player at bottom (mini state)
          if (_currentlyPlayingSong != null)
            Consumer<PlayerStateProvider>(
              builder: (context, playerState, child) {
                if (playerState.isFull) {
                  return const SizedBox.shrink();
                }
                return Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: MediaPlayerWidget(
                    r2Key: _currentlyPlayingSong!['r2_key'],
                    title: _currentlyPlayingSong!['title'],
                    artist: _currentlyPlayingSong!['artist']?['channel_name'] ?? widget.channelName,
                    coverPhotoUrl: _getCoverPhotoUrl(_currentlyPlayingSong!),
                    contentType: _currentlyPlayingSong!['content_type'],
                    isVideo: _isVideo(_currentlyPlayingSong!['content_type']),
                    playlist: _currentPlaylist,
                    currentIndex: _currentPlaylistIndex,
                    isMini: true,
                    moderationStatus: _currentlyPlayingSong!['moderation_status']?.toString(),
                    onClose: () {
                      playerState.hide();
                      _closePlayer();
                    },
                    onNext: _playNext,
                    onPrevious: _playPrevious,
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}
