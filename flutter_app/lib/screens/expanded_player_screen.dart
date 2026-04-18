// lib/screens/expanded_player_screen.dart
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import '../widgets/media_player_widget.dart';
import '../providers/player_state_provider.dart';
import '../widgets/player_more_options_sheet.dart';
import '../utils/toast_util.dart';

class ExpandedPlayerScreen extends StatefulWidget {
  final String? r2Key;
  final String? title;
  final String? artist;
  final String? coverPhotoUrl;
  final String? contentType;
  final List<Map<String, dynamic>> playlist;
  final int currentIndex;
  final VoidCallback? onNext;
  final VoidCallback? onPrevious;
  final ValueChanged<int>? onSelectTrackIndex;
  final VoidCallback? onClose;
  final String? moderationStatus;
  final bool isNoizeGuest;
  final VoidCallback? onGuestSkipLimitReached;

  const ExpandedPlayerScreen({
    super.key,
    required this.r2Key,
    this.title,
    this.artist,
    this.coverPhotoUrl,
    this.contentType,
    required this.playlist,
    required this.currentIndex,
    this.onNext,
    this.onPrevious,
    this.onSelectTrackIndex,
    this.onClose,
    this.moderationStatus,
    this.isNoizeGuest = false,
    this.onGuestSkipLimitReached,
  });

  @override
  State<ExpandedPlayerScreen> createState() => _ExpandedPlayerScreenState();
}

class _ExpandedPlayerScreenState extends State<ExpandedPlayerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'All';
  final ScrollController _lyricsScrollController = ScrollController();
  int _lastLyricsLineIndex = -1;
  late int _activeIndex;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _activeIndex = widget.currentIndex;
  }

  @override
  void didUpdateWidget(covariant ExpandedPlayerScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.currentIndex != oldWidget.currentIndex) {
      _activeIndex = widget.currentIndex;
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _lyricsScrollController.dispose();
    super.dispose();
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '0:00';
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF78E08F);
    const bgColor = Color(0xFF111414);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Top bar with close button
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
                        onPressed: () {
                          final playerState = Provider.of<PlayerStateProvider>(context, listen: false);
                          playerState.showMini();
                          if (widget.onClose != null) {
                            widget.onClose!();
                          } else {
                            Navigator.pop(context);
                          }
                        },
                        tooltip: 'Minimize',
                      ),
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () {
                          final playerState = Provider.of<PlayerStateProvider>(context, listen: false);
                          playerState.hide();
                          if (widget.onClose != null) {
                            widget.onClose!();
                          } else {
                            Navigator.pop(context);
                          }
                        },
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                  const Text(
                    'Now playing',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.notifications_none, color: Colors.white),
                        tooltip: 'Notifications',
                        onPressed: () {
                          showToast('Notifications coming soon');
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.chat_bubble_outline, color: Colors.white),
                        tooltip: 'Messages',
                        onPressed: () {
                          showToast('Messages coming soon');
                        },
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        onPressed: () {
                          showPlayerMoreOptionsSheet(
                            context: context,
                            song: _currentSong,
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Main content area
            Expanded(
              child: Row(
                children: [
                  // Left side - Album art and info
                  Expanded(
                    flex: 3,
                    child: Container(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Album art
                          Expanded(
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.5),
                                    blurRadius: 20,
                                    spreadRadius: 5,
                                  ),
                                ],
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: _currentSong?['cover_photo_url'] != null &&
                                        _currentSong!['cover_photo_url'].toString().isNotEmpty
                                    ? Image.network(
                                        _currentSong!['cover_photo_url'].toString(),
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Container(
                                            color: Colors.grey.shade900,
                                            child: Center(
                                              child: Icon(
                                                Icons.music_note,
                                                size: 120,
                                                color: accent,
                                              ),
                                            ),
                                          );
                                        },
                                      )
                                    : Container(
                                        color: Colors.grey.shade900,
                                        child: Center(
                                          child: Icon(
                                            Icons.music_note,
                                            size: 120,
                                            color: accent,
                                          ),
                                        ),
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          // Song title
                          if (_currentSong?['title'] != null)
                            Text(
                              _currentSong?['title']?.toString() ?? '',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          const SizedBox(height: 8),
                          // Artist name
                          if (_currentArtistText.isNotEmpty)
                            Text(
                              _currentArtistText.toUpperCase(),
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                letterSpacing: 1.2,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  // Right side - Playlist/Queue
                  Expanded(
                    flex: 2,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey.shade900.withOpacity(0.5),
                        border: Border(
                          left: BorderSide(
                            color: Colors.grey.shade800.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                      ),
                      child: Column(
                        children: [
                          // Tabs
                          Container(
                            decoration: BoxDecoration(
                              border: Border(
                                bottom: BorderSide(
                                  color: Colors.grey.shade800,
                                  width: 1,
                                ),
                              ),
                            ),
                            child: TabBar(
                              controller: _tabController,
                              indicatorColor: accent,
                              labelColor: accent,
                              unselectedLabelColor: Colors.grey.shade400,
                              tabs: const [
                                Tab(text: 'NEXT UP'),
                                Tab(text: 'LYRICS'),
                                Tab(icon: Icon(Icons.radio)),
                              ],
                            ),
                          ),
                          // Tab content
                          Expanded(
                            child: TabBarView(
                              controller: _tabController,
                              children: [
                                _buildUpNextTab(accent),
                                _buildLyricsTab(),
                                _buildRelatedTab(accent),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            // Bottom player controls
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                border: Border(
                  top: BorderSide(
                    color: Colors.grey.shade800,
                    width: 1,
                  ),
                ),
              ),
              child: _buildBottomControls(accent),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUpNextTab(Color accent) {
    final filteredPlaylist = _getFilteredPlaylist();

    return Column(
      children: [
        // Playlist info and save button
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Playing from ${widget.title ?? "Mix"}',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () {
                      // TODO: Save playlist
                    },
                    icon: const Icon(Icons.playlist_add, size: 18),
                    label: const Text('Save'),
                    style: TextButton.styleFrom(
                      foregroundColor: accent,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        // Song list
        Expanded(
          child: filteredPlaylist.isEmpty
              ? Center(
                  child: Text(
                    'No songs available',
                    style: TextStyle(color: Colors.grey.shade400),
                  ),
                )
              : ListView.builder(
                  itemCount: filteredPlaylist.length,
                  itemBuilder: (context, index) {
                    final song = filteredPlaylist[index];
                    final isPlaying = song['r2_key'] == _currentSong?['r2_key'];
                    final songIndex = widget.playlist.indexWhere(
                      (s) => s['r2_key'] == song['r2_key'],
                    );

                    return InkWell(
                      onTap: () {
                        if (songIndex >= 0) {
                          widget.onSelectTrackIndex?.call(songIndex);
                          setState(() {
                            _activeIndex = songIndex;
                          });
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: isPlaying
                              ? accent.withOpacity(0.1)
                              : Colors.transparent,
                          border: Border(
                            left: BorderSide(
                              color: isPlaying ? accent : Colors.transparent,
                              width: 3,
                            ),
                          ),
                        ),
                        child: Row(
                          children: [
                            // Album art thumbnail
                            Container(
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(6),
                                color: Colors.grey.shade800,
                              ),
                              child: song['cover_photo_url'] != null &&
                                      song['cover_photo_url'].toString().isNotEmpty
                                  ? ClipRRect(
                                      borderRadius: BorderRadius.circular(6),
                                      child: Image.network(
                                        song['cover_photo_url'],
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Icon(
                                            Icons.music_note,
                                            color: accent,
                                            size: 24,
                                          );
                                        },
                                      ),
                                    )
                                  : Icon(
                                      Icons.music_note,
                                      color: accent,
                                      size: 24,
                                    ),
                            ),
                            const SizedBox(width: 12),
                            // Song info
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    song['title'] ?? 'Unknown',
                                    style: TextStyle(
                                      color: isPlaying
                                          ? accent
                                          : Colors.white,
                                      fontWeight: isPlaying
                                          ? FontWeight.bold
                                          : FontWeight.normal,
                                      fontSize: 14,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    song['artist']?['channel_name'] ??
                                        song['artist']?.toString() ??
                                        'Unknown Artist',
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
                            // Duration
                            Text(
                              _formatDuration(
                                song['duration'] != null
                                    ? Duration(seconds: song['duration'] as int)
                                    : null,
                              ),
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildLyricsTab() {
    return Consumer<PlayerStateProvider>(
      builder: (context, playerState, _) {
        // Find the current song in the playlist
        Map<String, dynamic>? currentSong;
        if (widget.playlist.isNotEmpty) {
          if (_activeIndex >= 0 && _activeIndex < widget.playlist.length) {
            currentSong = widget.playlist[_activeIndex];
          } else {
            // Fallback: find by r2Key
            try {
              currentSong = widget.playlist.firstWhere(
                (song) => song['r2_key'] == _currentSong?['r2_key'],
                orElse: () => widget.playlist.isNotEmpty ? widget.playlist[0] : {},
              );
            } catch (e) {
              currentSong = widget.playlist.isNotEmpty ? widget.playlist[0] : null;
            }
          }
        }

        // Get lyrics from the current song
        final lyricsText = currentSong?['lyrics']?.toString().trim();
        
        if (lyricsText == null || lyricsText.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.music_note,
                  size: 64,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(height: 16),
                Text(
                  'Lyrics not available',
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32.0),
                  child: Text(
                    'To add synchronized lyrics, format them with timestamps:\n[00:15] First line of lyrics\n[00:20] Second line of lyrics',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.grey.shade500,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Parse synchronized lyrics
        final lyricsLines = _parseSynchronizedLyrics(lyricsText);
        final currentPosition = playerState.position;
        
        // Debug output (remove in production)
        if (lyricsLines.isNotEmpty) {
          final activeIndex = _getCurrentLineIndex(lyricsLines, currentPosition);
          if (activeIndex >= 0 && activeIndex < lyricsLines.length) {
            final activeLine = lyricsLines[activeIndex];
            print('Position: ${currentPosition.inSeconds}s, Active line: ${activeLine.timestamp.inSeconds}s - "${activeLine.text.substring(0, activeLine.text.length > 40 ? 40 : activeLine.text.length)}"');
          }
        }
        
        final currentLineIndex = _getCurrentLineIndex(lyricsLines, currentPosition);
        
        // Build synchronized lyrics display
        return _buildSynchronizedLyrics(lyricsLines, currentLineIndex);
      },
    );
  }

  /// Parse lyrics with timestamps in multiple formats:
  /// - [mm:ss] or [m:ss] format: [00:15] First line
  /// - Time range format: 0:00 - 0:13 | Intro text
  /// - Multiple lines separated by / on same timestamp
  List<LyricsLine> _parseSynchronizedLyrics(String lyrics) {
    final lines = <LyricsLine>[];
    
    // Regex for [mm:ss] or [m:ss] format
    final bracketRegex = RegExp(r'\[(\d+):(\d+)\]\s*(.*)');
    // Regex for time range format: 0:00 - 0:13 | text or 0:00 - 0:13 | Section: text
    // Captures start time (before the dash) and text after the pipe
    final rangeRegex = RegExp(r'(\d+):(\d+)\s*-\s*\d+:\d+\s*\|\s*(.*)');
    
    // Split by lines
    final rawLines = lyrics.split('\n');
    
    for (var line in rawLines) {
      line = line.trim();
      if (line.isEmpty) {
        // Empty line - add with no timestamp (will show immediately after previous)
        if (lines.isNotEmpty) {
          final lastTimestamp = lines.last.timestamp;
          lines.add(LyricsLine(timestamp: lastTimestamp, text: ''));
        } else {
          lines.add(LyricsLine(timestamp: Duration.zero, text: ''));
        }
        continue;
      }
      
      // Try bracket format first: [mm:ss] text
      var match = bracketRegex.firstMatch(line);
      if (match != null) {
        final minutes = int.tryParse(match.group(1) ?? '0') ?? 0;
        final seconds = int.tryParse(match.group(2) ?? '0') ?? 0;
        final text = match.group(3) ?? '';
        final timestamp = Duration(minutes: minutes, seconds: seconds);
        
        // Split text by / to create multiple lines with same timestamp
        final textLines = text.split('/').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
        if (textLines.isEmpty) {
          lines.add(LyricsLine(timestamp: timestamp, text: text));
        } else {
          for (var textLine in textLines) {
            lines.add(LyricsLine(timestamp: timestamp, text: textLine));
          }
        }
        continue;
      }
      
      // Try time range format: 0:00 - 0:13 | text
      match = rangeRegex.firstMatch(line);
      if (match != null) {
        final minutes = int.tryParse(match.group(1) ?? '0') ?? 0;
        final seconds = int.tryParse(match.group(2) ?? '0') ?? 0;
        final text = match.group(3) ?? '';
        final timestamp = Duration(minutes: minutes, seconds: seconds);
        
        // Split text by / to create multiple lines with same timestamp
        final textLines = text.split('/').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
        if (textLines.isEmpty) {
          lines.add(LyricsLine(timestamp: timestamp, text: text));
        } else {
          for (var textLine in textLines) {
            lines.add(LyricsLine(timestamp: timestamp, text: textLine));
          }
        }
        continue;
      }
      
      // Line without timestamp - use previous timestamp or zero
      if (lines.isNotEmpty) {
        final lastTimestamp = lines.last.timestamp;
        // Also check if line contains / for splitting
        final textLines = line.split('/').map((t) => t.trim()).where((t) => t.isNotEmpty).toList();
        if (textLines.isEmpty) {
          lines.add(LyricsLine(timestamp: lastTimestamp, text: line));
        } else {
          for (var textLine in textLines) {
            lines.add(LyricsLine(timestamp: lastTimestamp, text: textLine));
          }
        }
      } else {
        lines.add(LyricsLine(timestamp: Duration.zero, text: line));
      }
    }
    
    return lines;
  }

  /// Get the index of the current line based on playback position
  /// A line is active if: position >= line.timestamp AND position < nextLine.timestamp
  /// For lines with the same timestamp (split by /), returns the last one with that timestamp
  int _getCurrentLineIndex(List<LyricsLine> lines, Duration position) {
    if (lines.isEmpty) return -1;
    
    // If position is before first line, return -1 (no line active yet)
    if (position < lines[0].timestamp) {
      return -1;
    }
    
    // Find the line that should be active based on position
    // A line is active if position >= its timestamp and < next line's timestamp
    // For multiple lines with same timestamp, we want the last one
    int lastMatchingIndex = -1;
    
    for (int i = 0; i < lines.length; i++) {
      final lineTimestamp = lines[i].timestamp;
      
      // Check if position has reached this line
      if (position >= lineTimestamp) {
        // Check if there's a next line with a different timestamp
        if (i < lines.length - 1) {
          final nextLineTimestamp = lines[i + 1].timestamp;
          // If next line has different timestamp and position is before it, this is active
          if (nextLineTimestamp != lineTimestamp && position < nextLineTimestamp) {
            // Return the last line with this timestamp (for lines split by /)
            return lastMatchingIndex >= 0 ? lastMatchingIndex : i;
          }
          // If next line has same timestamp, continue to find the last one
          if (nextLineTimestamp == lineTimestamp) {
            lastMatchingIndex = i;
            continue;
          }
        } else {
          // This is the last line, and position has reached it
          return i;
        }
        
        // Track this as a potential match
        lastMatchingIndex = i;
      } else {
        // Position hasn't reached this line yet
        // If we found a matching line before, return it
        if (lastMatchingIndex >= 0) {
          return lastMatchingIndex;
        }
        // This shouldn't happen due to check above, but return -1 to be safe
        return -1;
      }
    }
    
    // If we get here, return the last matching index or last line
    return lastMatchingIndex >= 0 ? lastMatchingIndex : lines.length - 1;
  }

  /// Build the synchronized lyrics display with highlighting and auto-scroll
  Widget _buildSynchronizedLyrics(List<LyricsLine> lines, int currentLineIndex) {
    const accent = Color(0xFF78E08F);
    
    // Auto-scroll to current line when it changes
    if (currentLineIndex != _lastLyricsLineIndex && currentLineIndex >= 0) {
      _lastLyricsLineIndex = currentLineIndex;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_lyricsScrollController.hasClients && 
            currentLineIndex >= 0 && 
            currentLineIndex < lines.length) {
          // Calculate scroll position to center the current line
          final itemHeight = 56.0; // Approximate height per line
          final screenHeight = MediaQuery.of(context).size.height;
          final targetOffset = (currentLineIndex * itemHeight) - (screenHeight / 3);
          
          if (targetOffset >= 0 && targetOffset <= _lyricsScrollController.position.maxScrollExtent) {
            _lyricsScrollController.animateTo(
              targetOffset,
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOut,
            );
          }
        }
      });
    }
    
    if (lines.isEmpty) {
      return const Center(
        child: Text(
          'No lyrics available',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }
    
    return ListView.builder(
      controller: _lyricsScrollController,
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 32.0),
      itemCount: lines.length,
      itemBuilder: (context, index) {
        final line = lines[index];
        final isCurrentLine = index == currentLineIndex;
        final isPastLine = currentLineIndex >= 0 && index < currentLineIndex;
        
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 200),
            style: TextStyle(
              color: isCurrentLine
                  ? accent
                  : isPastLine
                      ? Colors.grey.shade400
                      : Colors.grey.shade600,
              fontSize: isCurrentLine ? 18 : 16,
              fontWeight: isCurrentLine ? FontWeight.w600 : FontWeight.normal,
              height: 1.6,
            ),
            child: Text(
              line.text.isEmpty ? ' ' : line.text,
              textAlign: TextAlign.center,
            ),
          ),
        );
      },
    );
  }

  Widget _buildRelatedTab(Color accent) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Radio',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Related songs',
                style: TextStyle(
                  color: Colors.grey.shade400,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.radio,
                  size: 64,
                  color: Colors.grey.shade600,
                ),
                const SizedBox(height: 16),
                Text(
                  'Related songs will appear here based on your taste.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.grey.shade400,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  List<Map<String, dynamic>> _getFilteredPlaylist() {
    if (_selectedFilter == 'All') {
      return widget.playlist;
    }
    // TODO: Implement actual filtering logic based on filter type
    return widget.playlist;
  }

  Widget _buildBottomControls(Color accent) {
    return MediaPlayerWidget(
      r2Key: _currentSong?['r2_key']?.toString(),
      title: _currentSong?['title']?.toString(),
      artist: _currentArtistText,
      coverPhotoUrl: _currentSong?['cover_photo_url']?.toString(),
      contentType: widget.contentType,
      playlist: widget.playlist,
      currentIndex: _activeIndex,
      showExpandButton: false,
      isMini: false, // Full player controls in expanded screen
      onNext: _advanceToNext,
      onPrevious: _advanceToPrevious,
      onQueueAdvanceWithoutSkip: _advanceToNext,
      onSelectTrackIndex: widget.onSelectTrackIndex,
      onClose: widget.onClose,
      moderationStatus: widget.moderationStatus,
      isNoizeGuest: widget.isNoizeGuest,
      onGuestSkipLimitReached: widget.onGuestSkipLimitReached,
    );
  }

  Map<String, dynamic>? get _currentSong {
    if (widget.playlist.isEmpty) return null;
    if (_activeIndex >= 0 && _activeIndex < widget.playlist.length) {
      return widget.playlist[_activeIndex];
    }
    return null;
  }

  String get _currentArtistText {
    final song = _currentSong;
    if (song == null) return '';
    final a = song['artist'];
    if (a is Map && a['channel_name'] != null) return a['channel_name'].toString();
    if (a != null) return a.toString();
    return '';
  }

  void _advanceToNext() {
    if (widget.playlist.isEmpty || _activeIndex < 0) return;
    final playerState = Provider.of<PlayerStateProvider>(context, listen: false);
    final nextIndex = playerState.getNextIndex(_activeIndex, widget.playlist.length);
    if (nextIndex == null) return;
    widget.onSelectTrackIndex?.call(nextIndex);
    setState(() => _activeIndex = nextIndex);
    playerState.initializeShuffle(widget.playlist, nextIndex);
  }

  void _advanceToPrevious() {
    if (widget.playlist.isEmpty || _activeIndex < 0) return;
    final playerState = Provider.of<PlayerStateProvider>(context, listen: false);
    final prevIndex = playerState.getPreviousIndex(_activeIndex, widget.playlist.length);
    if (prevIndex == null) return;
    widget.onSelectTrackIndex?.call(prevIndex);
    setState(() => _activeIndex = prevIndex);
    playerState.initializeShuffle(widget.playlist, prevIndex);
  }
}

/// Helper class to represent a lyrics line with timestamp
class LyricsLine {
  final Duration timestamp;
  final String text;
  
  LyricsLine({required this.timestamp, required this.text});
}
