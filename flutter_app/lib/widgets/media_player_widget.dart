// lib/widgets/media_player_widget.dart
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';
import '../services/auth_service.dart';
import '../services/media_service.dart';
import '../config/api_config.dart';
import '../screens/expanded_player_screen.dart';
import '../providers/player_state_provider.dart' as player_provider;
import '../widgets/player_more_options_sheet.dart';
import '../utils/toast_util.dart';
import '../services/guest_playback_policy.dart';

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
  final ValueChanged<int>? onSelectTrackIndex;
  final List<Map<String, dynamic>>? playlist;
  final int? currentIndex;
  final bool showExpandButton;
  final bool isMini; // Whether to show mini or full player
  final String? moderationStatus; // Add moderation status to prevent playing suspended songs
  /// NOIZE Guest entry funnel: ads + limited skips; conversion layer → NOIZE Listen.
  final bool isNoizeGuest;
  /// Called after a track ends to advance the queue without consuming a guest skip.
  final VoidCallback? onQueueAdvanceWithoutSkip;
  final VoidCallback? onGuestSkipLimitReached;

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
    this.onSelectTrackIndex,
    this.playlist,
    this.currentIndex,
    this.showExpandButton = true,
    this.isMini = true, // Default to mini player
    this.moderationStatus,
    this.isNoizeGuest = false,
    this.onQueueAdvanceWithoutSkip,
    this.onGuestSkipLimitReached,
  });

  @override
  State<MediaPlayerWidget> createState() => _MediaPlayerWidgetState();
}

class _MediaPlayerWidgetState extends State<MediaPlayerWidget> {
  final AudioPlayer _audioPlayer = AudioPlayer();
  final AuthService _auth = AuthService();
  final MediaService _media = MediaService();
  
  bool _isLoading = false;
  bool _isPlaying = false;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  String? _error;
  double _volume = 1.0;
  bool _isMuted = false;
  LoopMode _loopMode = LoopMode.off;
  bool _isToggling = false; // Track if we're in the middle of a toggle
  bool _handlingCompletion = false;
  bool _listenReported = false;
  /// After a successful like API call for the current track; reset when the track changes.
  bool? _likedForCurrentTrack;
  bool? _dislikedForCurrentTrack;

  @override
  void initState() {
    super.initState();
    // Initialize volume and loop mode
    _audioPlayer.setVolume(_volume);
    _audioPlayer.setLoopMode(_loopMode);

    // Initialize shuffle if playlist is available
    if (widget.playlist != null && widget.currentIndex != null) {
      final playerState = Provider.of<player_provider.PlayerStateProvider>(context, listen: false);
      playerState.initializeShuffle(widget.playlist!, widget.currentIndex!);
    }
    // Reset per-track repeat-once state
    Provider.of<player_provider.PlayerStateProvider>(context, listen: false).onTrackChanged();
    
    // Set up stream listeners
    _audioPlayer.durationStream.listen((duration) {
      if (mounted) {
        final newDuration = duration ?? Duration.zero;
        setState(() => _duration = newDuration);
        // Notify provider of position updates
        final playerState = Provider.of<player_provider.PlayerStateProvider>(context, listen: false);
        playerState.updatePosition(_position, newDuration);
      }
    });
    _audioPlayer.positionStream.listen((position) {
      if (mounted) {
        setState(() => _position = position);
        // Notify provider of position updates
        final playerState = Provider.of<player_provider.PlayerStateProvider>(context, listen: false);
        playerState.updatePosition(position, _duration);
        _maybeTelemetryListen(position);
      }
    });
    _audioPlayer.playerStateStream.listen((state) {
      if (mounted) {
        setState(() {
          // Always update playing state from the actual player state
          // The stream gives us the most accurate state
          _isPlaying = state.playing;
          // Reset loading state based on processing state
          if (state.processingState == ProcessingState.ready) {
            _isLoading = false;
            _isToggling = false; // Reset toggle flag when ready
          } else if (state.processingState == ProcessingState.loading) {
            _isLoading = true;
          }
        });
      }
      // Handle end-of-track behavior (repeat-once and/or advance)
      if (state.processingState == ProcessingState.completed) {
        _handleTrackCompleted();
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
    final moderationStatusLower = widget.moderationStatus?.toString().toLowerCase();
    if (!widget.isVideo && widget.r2Key != null && moderationStatusLower != 'flagged') {
      _loadAndPlay();
    } else if (moderationStatusLower == 'flagged') {
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
    
    // Initialize shuffle if playlist or currentIndex changed
    if (widget.playlist != null && widget.currentIndex != null) {
      if (oldWidget.playlist != widget.playlist || oldWidget.currentIndex != widget.currentIndex) {
        final playerState = Provider.of<player_provider.PlayerStateProvider>(context, listen: false);
        playerState.initializeShuffle(widget.playlist!, widget.currentIndex!);
      }
    }
    
    // If the r2Key changed, load and play the new song (but not if suspended)
    final moderationStatusLower = widget.moderationStatus?.toString().toLowerCase();
    if (oldWidget.r2Key != widget.r2Key || oldWidget.currentIndex != widget.currentIndex) {
      _listenReported = false;
      _likedForCurrentTrack = null;
      _dislikedForCurrentTrack = null;
    }
    if (oldWidget.r2Key != widget.r2Key && widget.r2Key != null && !widget.isVideo && moderationStatusLower != 'flagged') {
      Provider.of<player_provider.PlayerStateProvider>(context, listen: false).onTrackChanged();
      _loadAndPlay();
    } else if (moderationStatusLower == 'flagged') {
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

  void _invokeUserNext() {
    if (widget.isNoizeGuest) {
      if (!GuestPlaybackPolicy.tryConsumeSkip()) {
        widget.onGuestSkipLimitReached?.call();
        return;
      }
    }
    widget.onNext?.call();
  }

  void _invokeUserPrevious() {
    if (widget.isNoizeGuest) {
      if (!GuestPlaybackPolicy.tryConsumeSkip()) {
        widget.onGuestSkipLimitReached?.call();
        return;
      }
    }
    widget.onPrevious?.call();
  }

  Widget _buildGuestAdRow() {
    const accent = Color(0xFF78E08F);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 10),
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: accent.withOpacity(0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.campaign_outlined, size: 16, color: accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Ad · NOIZE Guest · ${GuestPlaybackPolicy.skipsRemaining} skips left · Full library on NOIZE Listen',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 10, height: 1.25),
            ),
          ),
        ],
      ),
    );
  }

  void _maybeTelemetryListen(Duration position) {
    if (_listenReported || !_auth.isLoggedIn) return;
    if (position.inSeconds < 30) return;
    final pl = widget.playlist;
    final idx = widget.currentIndex;
    if (pl == null || idx == null || idx < 0 || idx >= pl.length) return;
    final row = pl[idx];
    if (row is! Map) return;
    final raw = row['id'];
    final songId = raw is int ? raw : int.tryParse(raw.toString());
    if (songId == null) return;
    _listenReported = true;
    _media.recordListen(songId, listenMs: position.inMilliseconds);
  }

  Future<void> _loadAndPlay() async {
    if (widget.r2Key == null) return;
    
    // Check if song is suspended before playing (case-insensitive)
    final moderationStatusLower = widget.moderationStatus?.toString().toLowerCase();
    if (moderationStatusLower == 'flagged') {
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
        
        // State will be updated by playerStateStream listener
        // Don't manually set _isPlaying here to avoid race conditions
        if (mounted) {
          setState(() {
            _isLoading = false;
            // _isPlaying will be updated by the stream listener
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
      // Get the actual player state to ensure accuracy
      final playerState = _audioPlayer.playerState;
      final isActuallyPlaying = playerState.playing;
      
      if (isActuallyPlaying) {
        // Currently playing, so pause
        await _audioPlayer.pause();
      } else {
        // Not playing, so play
        // If we have a URL but it's not loaded yet, load it first
        if (widget.r2Key != null && _duration == Duration.zero) {
          // Song might not be loaded yet, load it first
          if (mounted) {
            setState(() {
              _isLoading = true;
            });
          }
          await _loadAndPlay();
        } else {
          await _audioPlayer.play();
        }
      }
    } catch (e) {
      // Handle error
      if (mounted) {
        setState(() {
          _error = 'Playback error: $e';
          _isLoading = false;
        });
      }
      print('Playback error: $e'); // Debug print
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
    final playerState = Provider.of<player_provider.PlayerStateProvider>(context, listen: false);
    playerState.toggleRepeat();
    
    // Also update audio player loop mode for single song repeat
    if (playerState.repeatMode == player_provider.RepeatMode.one) {
      await _audioPlayer.setLoopMode(LoopMode.one);
      setState(() => _loopMode = LoopMode.one);
    } else {
      await _audioPlayer.setLoopMode(LoopMode.off);
      setState(() => _loopMode = LoopMode.off);
    }
  }

  Future<void> _handleTrackCompleted() async {
    if (_handlingCompletion) return;
    if (!mounted) return;
    _handlingCompletion = true;
    try {
      final ps = Provider.of<player_provider.PlayerStateProvider>(context, listen: false);

      // Repeat-once: replay one additional time, then turn off.
      if (ps.repeatOnceEnabled && !ps.hasRepeatedOnceForCurrentTrack) {
        ps.consumeRepeatOnceForCurrentTrack();
        await _audioPlayer.seek(Duration.zero);
        await _audioPlayer.play();
        ps.disableRepeatOnce();
        return;
      }

      // Continuous repeat-one is handled by just_audio LoopMode.one.
      if (ps.repeatMode == player_provider.RepeatMode.one) {
        return;
      }

      // Auto-advance: do not consume NOIZE Guest skip quota (user-initiated skips only).
      final advance = widget.onQueueAdvanceWithoutSkip ?? widget.onNext;
      if (advance != null && widget.playlist != null && widget.currentIndex != null) {
        advance();
      }
    } catch (_) {
      // Ignore completion handling errors; playback state will stabilize via streams.
    } finally {
      _handlingCompletion = false;
    }
  }

  void _openPlaylistSheet() {
    final list = widget.playlist ?? const <Map<String, dynamic>>[];
    if (list.isEmpty || widget.onSelectTrackIndex == null) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        const accent = Color(0xFF78E08F);
        final current = widget.currentIndex ?? -1;
        return Container(
          height: MediaQuery.of(context).size.height * 0.6,
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            border: Border(top: BorderSide(color: accent.withOpacity(0.25), width: 2)),
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Playlist',
                        style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) {
                    final song = list[index];
                    final isPlaying = index == current;
                    final title = song['title']?.toString() ?? 'Unknown';
                    final artist = song['artist']?['channel_name']?.toString() ??
                        song['artist']?.toString() ??
                        'Unknown Artist';
                    return ListTile(
                      leading: Icon(isPlaying ? Icons.equalizer : Icons.music_note, color: isPlaying ? accent : Colors.grey.shade500),
                      title: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: isPlaying ? accent : Colors.white),
                      ),
                      subtitle: Text(
                        artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                      ),
                      onTap: () {
                        widget.onSelectTrackIndex?.call(index);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Map<String, dynamic>? _currentSongFromWidget() {
    final list = widget.playlist;
    if (list == null || list.isEmpty) return null;
    final idx = widget.currentIndex;
    if (idx != null && idx >= 0 && idx < list.length) return list[idx];
    final key = widget.r2Key;
    if (key != null) {
      try {
        return list.firstWhere((s) => s['r2_key']?.toString() == key.toString());
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  int? _currentSongId() {
    final song = _currentSongFromWidget();
    final songIdRaw = song?['id'];
    if (songIdRaw is int) return songIdRaw;
    if (songIdRaw is num) return songIdRaw.toInt();
    return int.tryParse(songIdRaw?.toString() ?? '');
  }

  Future<void> _onLikePressed() async {
    final songId = _currentSongId();
    if (songId == null) {
      showToast('Cannot like this track (missing id)');
      return;
    }
    if (!_auth.isLoggedIn) {
      showToast('Log in to like songs');
      return;
    }
    try {
      final r = await _media.likeSong(songId);
      if (!mounted) return;
      final liked = r['liked'] == true;
      setState(() {
        _likedForCurrentTrack = liked;
        if (liked) _dislikedForCurrentTrack = false;
      });
      showToast(liked ? 'Saved to Liked Songs' : 'Removed from Liked Songs');
    } catch (e) {
      showToast('Could not update like: $e');
    }
  }

  Future<void> _onDislikePressed() async {
    final songId = _currentSongId();
    if (songId == null) {
      showToast('Cannot dislike this track (missing id)');
      return;
    }
    if (!_auth.isLoggedIn) {
      showToast('Log in to provide feedback');
      return;
    }
    try {
      final r = await _media.dislikeSong(songId);
      if (!mounted) return;
      final disliked = r['disliked'] == true;
      setState(() {
        _dislikedForCurrentTrack = disliked;
        if (disliked) _likedForCurrentTrack = false;
      });
      showToast(disliked ? 'We\'ll show fewer tracks like this' : 'Dislike removed');
    } catch (e) {
      showToast('Could not update dislike: $e');
    }
  }

  Future<void> _openMoreOptions() async {
    await showPlayerMoreOptionsSheet(
      context: context,
      song: _currentSongFromWidget(),
    );
  }

  Future<void> _openAddToPlaylistSheet() async {
    final song = _currentSongFromWidget();
    final songIdRaw = song?['id'];
    final songId = (songIdRaw is int) ? songIdRaw : int.tryParse(songIdRaw?.toString() ?? '');
    if (songId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cannot add to playlist: missing song id')),
      );
      return;
    }

    // Must be logged in
    if (!_auth.isLoggedIn) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Login required to manage playlists')),
      );
      return;
    }

    List<dynamic> playlists = [];
    try {
      playlists = await _media.getPlaylists();
    } catch (_) {
      playlists = [];
    }

    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) {
        const accent = Color(0xFF78E08F);
        return SafeArea(
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.55,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Add to playlist',
                            style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            final controller = TextEditingController();
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (_) => AlertDialog(
                                backgroundColor: Colors.grey.shade900,
                                title: const Text('Create playlist', style: TextStyle(color: Colors.white)),
                                content: TextField(
                                  controller: controller,
                                  style: const TextStyle(color: Colors.white),
                                  decoration: const InputDecoration(
                                    hintText: 'Playlist name',
                                    hintStyle: TextStyle(color: Colors.grey),
                                  ),
                                ),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                                  ),
                                  ElevatedButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.black),
                                    child: const Text('Create'),
                                  ),
                                ],
                              ),
                            );
                            final name = controller.text.trim();
                            if (ok == true && name.isNotEmpty) {
                              try {
                                final res = await _media.createPlaylist(name);
                                final newId = res['playlist_id']?.toString();
                                if (newId != null && newId.isNotEmpty) {
                                  await _media.addToPlaylist(newId, songId);
                                  if (context.mounted) {
                                    Navigator.pop(context); // close bottom sheet
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Added to "$name"')),
                                    );
                                  }
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(content: Text('Failed: $e')),
                                  );
                                }
                              }
                            }
                          },
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('New'),
                          style: TextButton.styleFrom(foregroundColor: accent),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: playlists.isEmpty
                        ? Center(
                            child: Text(
                              'No playlists yet',
                              style: TextStyle(color: Colors.grey.shade400),
                            ),
                          )
                        : ListView.builder(
                            itemCount: playlists.length,
                            itemBuilder: (context, index) {
                              final p = playlists[index] as Map<String, dynamic>;
                              final pid = p['id']?.toString() ?? '';
                              final name = p['name']?.toString() ?? 'Playlist';
                              final count = p['song_count'] ?? 0;
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: accent.withOpacity(0.2),
                                  child: Icon(Icons.playlist_play, color: accent),
                                ),
                                title: Text(name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
                                subtitle: Text('$count songs', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                                onTap: () async {
                                  if (pid.isEmpty) return;
                                  try {
                                    await _media.addToPlaylist(pid, songId);
                                    if (context.mounted) {
                                      Navigator.pop(context);
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Added to "$name"')),
                                      );
                                    }
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text('Failed: $e')),
                                      );
                                    }
                                  }
                                },
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
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
          final playerState = Provider.of<player_provider.PlayerStateProvider>(context, listen: false);
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
                onSelectTrackIndex: widget.onSelectTrackIndex,
                onClose: () {
                  playerState.showMini();
                  Navigator.pop(context);
                },
                moderationStatus: widget.moderationStatus,
                isNoizeGuest: widget.isNoizeGuest,
                onGuestSkipLimitReached: widget.onGuestSkipLimitReached,
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            border: Border(top: BorderSide(color: accent.withOpacity(0.3), width: 2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.isNoizeGuest) ...[
                _buildGuestAdRow(),
                const SizedBox(height: 4),
              ],
              // Progress bar (thin) + time
              if (_error == null && _duration.inMilliseconds > 0)
                Row(
                  children: [
                    Expanded(
                      child: SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          trackHeight: 2.0,
                          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 0),
                          overlayShape: const RoundSliderOverlayShape(overlayRadius: 0),
                        ),
                        child: Slider(
                          value: _position.inMilliseconds
                              .clamp(0, _duration.inMilliseconds)
                              .toDouble(),
                          max: _duration.inMilliseconds.toDouble(),
                          activeColor: Colors.grey.shade400,
                          inactiveColor: Colors.grey.shade700,
                          onChanged: (value) {
                            _seek(Duration(milliseconds: value.toInt()));
                          },
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatDuration(_position),
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 10),
                    ),
                  ],
                ),
              if (_error == null && _duration.inMilliseconds > 0)
                const SizedBox(height: 2),
              // Main row with artwork, info, controls
              Row(
                children: [
                  // Left: artwork + text
                  Expanded(
                    flex: 2,
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
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
                        const SizedBox(width: 10),
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
                                    fontSize: 13,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              if (widget.artist != null)
                                Text(
                                  widget.artist!,
                                  style: TextStyle(
                                    color: Colors.grey.shade400,
                                    fontSize: 11,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Center: playback controls (playlist + repeat + prev/play/next) – truly centered
                  Expanded(
                    flex: 1,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        Consumer<player_provider.PlayerStateProvider>(
                          builder: (context, playerState, child) {
                            return IconButton(
                              icon: Icon(
                                playerState.repeatMode == player_provider.RepeatMode.off
                                    ? Icons.repeat
                                    : playerState.repeatMode == player_provider.RepeatMode.one
                                        ? Icons.repeat_one
                                        : Icons.repeat,
                                color: playerState.repeatMode == player_provider.RepeatMode.off
                                    ? Colors.white
                                    : accent,
                                size: 18,
                              ),
                              onPressed: _toggleRepeat,
                              tooltip: playerState.repeatMode == player_provider.RepeatMode.off
                                  ? 'Repeat off'
                                  : playerState.repeatMode == player_provider.RepeatMode.one
                                      ? 'Repeat one'
                                      : 'Repeat all',
                            );
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_previous, color: Colors.white, size: 22),
                          onPressed: widget.onPrevious != null ? _invokeUserPrevious : null,
                          tooltip: 'Previous',
                        ),
                        IconButton(
                          icon: Icon(
                            _isLoading
                                ? Icons.hourglass_empty
                                : _isPlaying
                                    ? Icons.pause
                                    : Icons.play_arrow,
                            color: Colors.white,
                            size: 26,
                          ),
                          onPressed: _isLoading ? null : _togglePlayPause,
                          tooltip: _isPlaying ? 'Pause' : 'Play',
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_next, color: Colors.white, size: 22),
                          onPressed: widget.onNext != null ? _invokeUserNext : null,
                          tooltip: 'Next',
                        ),
                        IconButton(
                          icon: const Icon(Icons.playlist_add, color: Colors.white, size: 18),
                          onPressed: _openAddToPlaylistSheet,
                          tooltip: 'Add to playlist',
                        ),
                      ],
                    ),
                  ),
                  // Right: like/dislike/comment/more + close/expand
                  Expanded(
                    flex: 2,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        IconButton(
                          icon: Icon(
                            _dislikedForCurrentTrack == true
                                ? Icons.thumb_down_alt
                                : Icons.thumb_down_alt_outlined,
                            color: Colors.white,
                            size: 18,
                          ),
                          onPressed: _onDislikePressed,
                          tooltip: 'Dislike',
                        ),
                        IconButton(
                          icon: Icon(
                            _likedForCurrentTrack == true
                                ? Icons.thumb_up
                                : Icons.thumb_up_alt_outlined,
                            color: Colors.white,
                            size: 18,
                          ),
                          onPressed: _onLikePressed,
                          tooltip: 'Like',
                        ),
                        IconButton(
                          icon: const Icon(Icons.chat_bubble_outline, color: Colors.white, size: 18),
                          onPressed: () {
                            // TODO: open comments
                          },
                          tooltip: 'Comments',
                        ),
                        IconButton(
                          icon: const Icon(Icons.more_vert, color: Colors.white, size: 18),
                          onPressed: _openMoreOptions,
                          tooltip: 'More options',
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white, size: 18),
                          onPressed: () async {
                            try {
                              await _audioPlayer.stop();
                            } catch (_) {}
                            if (widget.onClose != null) {
                              widget.onClose!();
                            } else {
                              final playerState = Provider.of<player_provider.PlayerStateProvider>(context, listen: false);
                              playerState.hide();
                            }
                          },
                          tooltip: 'Close',
                        ),
                        if (widget.showExpandButton)
                          IconButton(
                            icon: const Icon(Icons.keyboard_arrow_up, color: Colors.white, size: 18),
                            onPressed: () {
                              final playerState = Provider.of<player_provider.PlayerStateProvider>(context, listen: false);
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
                                    onSelectTrackIndex: widget.onSelectTrackIndex,
                                    onClose: () {
                                      playerState.showMini();
                                      Navigator.pop(context);
                                    },
                                    moderationStatus: widget.moderationStatus,
                                    isNoizeGuest: widget.isNoizeGuest,
                                    onGuestSkipLimitReached: widget.onGuestSkipLimitReached,
                                  ),
                                ),
                              );
                            },
                            tooltip: 'Expand',
                          ),
                      ],
                    ),
                  ),
                ],
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
          if (widget.isNoizeGuest) ...[
            _buildGuestAdRow(),
            const SizedBox(height: 8),
          ],
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
                    onPressed: widget.onPrevious != null ? _invokeUserPrevious : null,
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
                    onPressed: widget.onNext != null ? _invokeUserNext : null,
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
                    icon: Icon(
                      _dislikedForCurrentTrack == true ? Icons.thumb_down : Icons.thumb_down_outlined,
                      color: _dislikedForCurrentTrack == true ? Colors.orange.shade300 : Colors.grey.shade400,
                      size: 20,
                    ),
                    onPressed: _onDislikePressed,
                    tooltip: 'Thumbs down',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: Icon(
                      _likedForCurrentTrack == true ? Icons.thumb_up : Icons.thumb_up_outlined,
                      color: _likedForCurrentTrack == true ? accent : Colors.grey.shade400,
                      size: 20,
                    ),
                    onPressed: _onLikePressed,
                    tooltip: 'Thumbs up',
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                  const SizedBox(width: 16),
                  IconButton(
                    icon: Icon(Icons.more_vert, color: Colors.grey.shade400, size: 20),
                    onPressed: () {
                      _openMoreOptions();
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
                  Consumer<player_provider.PlayerStateProvider>(
                    builder: (context, playerState, child) {
                      return IconButton(
                        icon: Icon(
                          playerState.repeatMode == player_provider.RepeatMode.off
                              ? Icons.repeat
                              : playerState.repeatMode == player_provider.RepeatMode.one
                                  ? Icons.repeat_one
                                  : Icons.repeat,
                          color: playerState.repeatMode == player_provider.RepeatMode.off
                              ? Colors.grey.shade400
                              : accent,
                          size: 20,
                        ),
                        onPressed: _toggleRepeat,
                        tooltip: playerState.repeatMode == player_provider.RepeatMode.off
                            ? 'Repeat off'
                            : playerState.repeatMode == player_provider.RepeatMode.one
                                ? 'Repeat one'
                                : 'Repeat all',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      );
                    },
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Shuffle button
                  Consumer<player_provider.PlayerStateProvider>(
                    builder: (context, playerState, child) {
                      return IconButton(
                        icon: Icon(
                          Icons.shuffle,
                          color: playerState.isShuffleEnabled
                              ? accent
                              : Colors.grey.shade400,
                          size: 20,
                        ),
                        onPressed: () {
                          playerState.toggleShuffle();
                          // Reinitialize shuffle with current playlist
                          if (widget.playlist != null && widget.currentIndex != null) {
                            playerState.initializeShuffle(widget.playlist!, widget.currentIndex!);
                          }
                        },
                        tooltip: playerState.isShuffleEnabled ? 'Shuffle on' : 'Shuffle off',
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      );
                    },
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Expand button
                  if (widget.showExpandButton && widget.isMini)
                    IconButton(
                      icon: const Icon(Icons.keyboard_arrow_up, color: Colors.white, size: 20),
                      onPressed: () {
                        final playerState = Provider.of<player_provider.PlayerStateProvider>(context, listen: false);
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
                              onSelectTrackIndex: widget.onSelectTrackIndex,
                              onClose: () {
                                playerState.showMini();
                                if (widget.onClose != null) {
                                  widget.onClose!();
                                } else {
                                  Navigator.pop(context);
                                }
                              },
                              moderationStatus: widget.moderationStatus,
                              isNoizeGuest: widget.isNoizeGuest,
                              onGuestSkipLimitReached: widget.onGuestSkipLimitReached,
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
