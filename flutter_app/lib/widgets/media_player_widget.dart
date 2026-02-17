// lib/widgets/media_player_widget.dart
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../services/auth_service.dart';
import '../config/api_config.dart';
import '../screens/expanded_player_screen.dart';
import '../providers/player_state_provider.dart';

class MediaPlayerWidget extends StatefulWidget {
  final String? r2Key;
  final String? title;
  final String? artist;
  final String? coverPhotoUrl;
  final String? contentType;
  final bool isVideo;
  final VoidCallback? onClose;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final List<Map<String, dynamic>>? playlist;
  final int? currentIndex;
  final bool showExpandButton;
  final bool isMini; // Whether to show mini or full player
  final String? moderationStatus; // Add moderation status to prevent playing suspended songs

  const MediaPlayerWidget({
    super.key,
    required this.r2Key,
    this.title,
    this.artist,
    this.coverPhotoUrl,
    this.contentType,
    this.isVideo = false,
    this.onClose,
    this.onNext,
    this.onPrevious,
    this.playlist,
    this.currentIndex,
    this.showExpandButton = true,
    this.isMini = true, // Default to mini player
    this.moderationStatus,
  });

  @override
  State<MediaPlayerWidget> createState() => _MediaPlayerWidgetState();
}

class _MediaPlayerWidgetState extends State<MediaPlayerWidget> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AuthService _auth = AuthService();
  
  bool _isLoading = false;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String? _error;
  double _volume = 1.0;
  bool _isMuted = false;
  LoopMode _loopMode = LoopMode.off;

  @override
  void initState() {
    super.initState();
    // Initialize volume and loop mode
    _audioPlayer.setVolume(_volume);
    _audioPlayer.setLoopMode(_loopMode);
    
    // Set up stream listeners
    _audioPlayer.durationStream.listen((duration) {
      if (mounted) {
        setState(() => _duration = duration ?? Duration.zero);
      }
    });
    _audioPlayer.positionStream.listen((position) {
      if (mounted) {
        setState(() => _position = position);
      }
    });
    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          // Reset loading state based on processing state
          if (state.processingState == ProcessingState.ready) {
            _isLoading = false;
          } else if (state.processingState == ProcessingState.loading) {
            _isLoading = true;
          }
        });
      }
    });
    _audioPlayer.volumeStream.listen((volume) {
      if (mounted) {
        setState(() => _volume = volume);
      }
    });
    _audioPlayer.loopModeStream.listen((loopMode) {
      if (mounted) {
        setState(() => _loopMode = loopMode);
      }
    });
    
    // Don't auto-play if song is suspended/flagged
    if (!widget.isVideo && widget.r2Key != null && widget.moderationStatus != 'flagged') {
      _loadAndPlay();
    } else if (widget.moderationStatus == 'flagged') {
      // Show error if trying to play suspended song
      if (mounted) {
        setState(() {
          _error = 'This song has been temporarily suspended';
        });
      }
    }
  }

  @override
  void didUpdateWidget(MediaPlayerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the r2Key changed, load and play the new song (but not if suspended)
    if (oldWidget.r2Key != widget.r2Key && widget.r2Key != null && !widget.isVideo && widget.moderationStatus != 'flagged') {
      _loadAndPlay();
    } else if (widget.moderationStatus == 'flagged') {
      // Stop playing if song becomes suspended
      _audioPlayer.stop();
      if (mounted) {
        setState(() {
          _error = 'This song has been temporarily suspended';
          _isLoading = false;
          _isPlaying = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadAndPlay() async {
    if (widget.r2Key == null) return;
    
    // Check if song is suspended before playing
    if (widget.moderationStatus == 'flagged') {
      if (mounted) {
        setState(() {
          _error = 'This song has been temporarily suspended';
          _isLoading = false;
        });
      }
      return;
    }
    
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
        _isPlaying = false;
        _position = Duration.zero;
        _duration = Duration.zero;
      });
    }

    try {
      // Stop any currently playing audio first
      try {
        await _audioPlayer.stop();
        await Future.delayed(const Duration(milliseconds: 100));
      } catch (e) {
        // Ignore if nothing is playing
      }

      if (!mounted) return;

      final base = Uri.parse(apiBaseUrl);
      final streamUrl = base.replace(
        path: '${base.path}/media/download/${Uri.encodeComponent(widget.r2Key!)}',
        queryParameters: {'format': 'hls'},  // Request HLS format
      );
      final resp = await http.get(streamUrl, headers: _auth.authHeader);

      if (!mounted) return;

      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body);
        final presignedUrl = data['url'];
        
        await _audioPlayer.setUrl(presignedUrl);
        
        if (!mounted) return;
        
        await _audioPlayer.play();
        
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isPlaying = true;
          });
        }
      } else {
        throw Exception('Failed to get audio URL: ${resp.statusCode}');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _isPlaying = false;
          _error = e.toString();
        });
      }
    }
  }

  Future<void> _togglePlayPause() async {
    if (_isLoading) return; // Don't allow play/pause while loading
    
    try {
      if (_isPlaying) {
        await _audioPlayer.pause();
      } else {
        // If we have a URL but it's not playing, try to play it
        if (widget.r2Key != null && _duration == Duration.zero) {
          // Song might not be loaded yet, load it first
          await _loadAndPlay();
        } else {
          await _audioPlayer.play();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Playback error: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _seek(Duration position) async {
    await _audioPlayer.seek(position);
  }

  Future<void> _toggleMute() async {
    if (_isMuted) {
      await _audioPlayer.setVolume(_volume > 0 ? _volume : 1.0);
      setState(() => _isMuted = false);
    } else {
      await _audioPlayer.setVolume(0.0);
      setState(() => _isMuted = true);
    }
  }

  Future<void> _setVolume(double volume) async {
    await _audioPlayer.setVolume(volume);
    setState(() {
      _volume = volume;
      _isMuted = volume == 0.0;
    });
  }

  Future<void> _toggleRepeat() async {
    LoopMode newMode;
    switch (_loopMode) {
      case LoopMode.off:
        newMode = LoopMode.one;
        break;
      case LoopMode.one:
        newMode = LoopMode.all;
        break;
      case LoopMode.all:
        newMode = LoopMode.off;
        break;
    }
    await _audioPlayer.setLoopMode(newMode);
    setState(() => _loopMode = newMode);
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF78E08F);

    if (widget.isVideo) {
      // Video player placeholder
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (widget.title != null)
                        Text(
                          widget.title!,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      if (widget.artist != null)
                        Text(
                          widget.artist!,
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 14,
                          ),
                        ),
                    ],
                  ),
                ),
                if (widget.onClose != null)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: widget.onClose,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              height: 200,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.videocam, size: 48, color: Colors.grey.shade600),
                    const SizedBox(height: 8),
                    Text(
                      'Video playback coming soon',
                      style: TextStyle(color: Colors.grey.shade400),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Mini player - compact version
    if (widget.isMini)
      return GestureDetector(
        onTap: () {
          // Tap to expand
          final playerState = Provider.of<PlayerStateProvider>(context, listen: false);
          playerState.showFull();
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => ExpandedPlayerScreen(
                r2Key: widget.r2Key,
                title: widget.title,
                artist: widget.artist,
                coverPhotoUrl: widget.coverPhotoUrl,
                contentType: widget.contentType,
                playlist: widget.playlist ?? [],
                currentIndex: widget.currentIndex ?? 0,
                onNext: widget.onNext,
                onPrevious: widget.onPrevious,
                onClose: () {
                  playerState.showMini();
                  Navigator.pop(context);
                },
                moderationStatus: widget.moderationStatus,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(top: BorderSide(color: accent.withOpacity(0.3), width: 2)),
          ),
          child: Row(
            children: [
              // Cover photo thumbnail
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: Colors.grey.shade800,
                ),
                child: widget.coverPhotoUrl != null && widget.coverPhotoUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: Image.network(
                          widget.coverPhotoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(Icons.music_note, color: accent, size: 24);
                          },
                        ),
                      )
                    : Icon(Icons.music_note, color: accent, size: 24),
              ),
              const SizedBox(width: 12),
              // Song info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.title != null)
                      Text(
                        widget.title!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (widget.artist != null)
                      Text(
                        widget.artist!,
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              // Play/Pause button
              IconButton(
                icon: Icon(
                  _isLoading
                      ? Icons.hourglass_empty
                      : _isPlaying
                          ? Icons.pause
                          : Icons.play_arrow,
                  color: Colors.white,
                  size: 28,
                ),
                onPressed: _isLoading ? null : _togglePlayPause,
                tooltip: _isPlaying ? 'Pause' : 'Play',
              ),
              // Expand button
              if (widget.showExpandButton)
                IconButton(
                  icon: const Icon(Icons.keyboard_arrow_up, color: Colors.white, size: 20),
                  onPressed: () {
                    final playerState = Provider.of<PlayerStateProvider>(context, listen: false);
                    playerState.showFull();
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ExpandedPlayerScreen(
                          r2Key: widget.r2Key,
                          title: widget.title,
                          artist: widget.artist,
                          coverPhotoUrl: widget.coverPhotoUrl,
                          contentType: widget.contentType,
                          playlist: widget.playlist ?? [],
                          currentIndex: widget.currentIndex ?? 0,
                          onNext: widget.onNext,
                          onPrevious: widget.onPrevious,
                          onClose: () {
                            playerState.showMini();
                            Navigator.pop(context);
                          },
                        ),
                      ),
                    );
                  },
                  tooltip: 'Expand',
                ),
            ],
          ),
        ),
      );

    // Full player - detailed version (used in expanded screen)
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: accent.withOpacity(0.3), width: 2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Progress bar at top
          if (_error == null && _duration.inMilliseconds > 0)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 2.0,
                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 0),
                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 0),
                ),
                child: Slider(
                  value: _position.inMilliseconds.toDouble(),
                  max: _duration.inMilliseconds.toDouble(),
                  activeColor: Colors.grey.shade400,
                  inactiveColor: Colors.grey.shade700,
                  onChanged: (value) {
                    _seek(Duration(milliseconds: value.toInt()));
                  },
                ),
              ),
            ),
          
          const SizedBox(height: 8),
          
          // Main controls row
          Row(
            children: [
              // Cover photo and song info
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade800,
                ),
                child: widget.coverPhotoUrl != null && widget.coverPhotoUrl!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          widget.coverPhotoUrl!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(Icons.music_note, color: accent, size: 30);
                          },
                        ),
                      )
                    : Icon(Icons.music_note, color: accent, size: 30),
              ),
              const SizedBox(width: 12),
              
              // Song title and artist
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.title != null)
                      Text(
                        widget.title!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                          fontSize: 14,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    if (widget.artist != null)
                      Text(
                        widget.artist!,
                        style: TextStyle(
                          color: Colors.grey.shade400,
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              ),
              
              // Playback controls
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Previous button
                  IconButton(
                    icon: const Icon(Icons.skip_previous, color: Colors.white, size: 28),
                    onPressed: widget.onPrevious,
                    tooltip: 'Previous',
                  ),
                  
                  // Play/Pause button
                  IconButton(
                    icon: Icon(
                      _isLoading
                          ? Icons.hourglass_empty
                          : _isPlaying
                              ? Icons.pause
                              : Icons.play_arrow,
                      color: Colors.white,
                      size: 32,
                    ),
                    onPressed: _isLoading ? null : _togglePlayPause,
                    tooltip: _isPlaying ? 'Pause' : 'Play',
                  ),
                  
                  // Next button
                  IconButton(
                    icon: const Icon(Icons.skip_next, color: Colors.white, size: 28),
                    onPressed: widget.onNext,
                    tooltip: 'Next',
                  ),
                  
                  // Time display
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      '${_formatDuration(_position)} / ${_formatDuration(_duration)}',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 12),
          
          // Secondary controls row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Left side - thumbs and more options
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.thumb_down_outlined, color: Colors.grey.shade400, size: 20),
                    onPressed: () {
                      // TODO: Implement thumbs down
                    },
                    tooltip: 'Thumbs down',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: Icon(Icons.thumb_up_outlined, color: Colors.grey.shade400, size: 20),
                    onPressed: () {
                      // TODO: Implement thumbs up
                    },
                    tooltip: 'Thumbs up',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: Icon(Icons.more_vert, color: Colors.grey.shade400, size: 20),
                    onPressed: () {
                      // TODO: Implement more options menu
                    },
                    tooltip: 'More options',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              
              // Right side - volume and playback modes
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Volume control
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          _isMuted || _volume == 0.0
                              ? Icons.volume_off
                              : _volume < 0.5
                                  ? Icons.volume_down
                                  : Icons.volume_up,
                          color: Colors.grey.shade400,
                          size: 20,
                        ),
                        onPressed: _toggleMute,
                        tooltip: _isMuted ? 'Unmute' : 'Mute',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 80,
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2.0,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
                          ),
                          child: Slider(
                            value: _isMuted ? 0.0 : _volume,
                            max: 1.0,
                            activeColor: Colors.grey.shade400,
                            inactiveColor: Colors.grey.shade700,
                            onChanged: _setVolume,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(width: 16),
                  
                  // Repeat button
                  IconButton(
                    icon: Icon(
                      _loopMode == LoopMode.off
                          ? Icons.repeat
                          : _loopMode == LoopMode.one
                              ? Icons.repeat_one
                              : Icons.repeat,
                      color: _loopMode == LoopMode.off
                          ? Colors.grey.shade400
                          : accent,
                      size: 20,
                    ),
                    onPressed: _toggleRepeat,
                    tooltip: _loopMode == LoopMode.off
                        ? 'Repeat off'
                        : _loopMode == LoopMode.one
                            ? 'Repeat one'
                            : 'Repeat all',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Shuffle button (placeholder)
                  IconButton(
                    icon: Icon(
                      Icons.shuffle,
                      color: Colors.grey.shade400,
                      size: 20,
                    ),
                    onPressed: () {
                      // TODO: Implement shuffle
                    },
                    tooltip: 'Shuffle',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Expand button
                  if (widget.showExpandButton && widget.isMini)
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_up, color: Colors.white, size: 20),
                      onPressed: () {
                        final playerState = Provider.of<PlayerStateProvider>(context, listen: false);
                        playerState.showFull();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ExpandedPlayerScreen(
                              r2Key: widget.r2Key,
                              title: widget.title,
                              artist: widget.artist,
                              coverPhotoUrl: widget.coverPhotoUrl,
                              contentType: widget.contentType,
                              playlist: widget.playlist ?? [],
                              currentIndex: widget.currentIndex ?? 0,
                              onNext: widget.onNext,
                              onPrevious: widget.onPrevious,
                              onClose: () {
                                playerState.showMini();
                                if (widget.onClose != null) {
                                  widget.onClose!();
                                } else {
                                  Navigator.pop(context);
                                }
                              },
                            ),
                          ),
                        );
                      },
                      tooltip: 'Expand',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                    ),
                ],
              ),
            ],
          ),
          
          // Error message if any
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Error: $_error',
                style: const TextStyle(color: Colors.red, fontSize: 12),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
    );
  }
}
