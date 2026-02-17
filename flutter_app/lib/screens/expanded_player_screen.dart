// lib/screens/expanded_player_screen.dart
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import '../widgets/media_player_widget.dart';
import '../providers/player_state_provider.dart';

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
  final VoidCallback? onClose;
  final String? moderationStatus;

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
    this.onClose,
    this.moderationStatus,
  });

  @override
  State<ExpandedPlayerScreen> createState() => _ExpandedPlayerScreenState();
}

class _ExpandedPlayerScreenState extends State<ExpandedPlayerScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String _selectedFilter = 'All';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
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
                  ),
                  const Text(
                    'Now playing',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.more_vert, color: Colors.white),
                    onPressed: () {
                      // TODO: Show more options menu
                    },
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
                                child: widget.coverPhotoUrl != null &&
                                        widget.coverPhotoUrl!.isNotEmpty
                                    ? Image.network(
                                        widget.coverPhotoUrl!,
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
                          if (widget.title != null)
                            Text(
                              widget.title!,
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
                          if (widget.artist != null)
                            Text(
                              widget.artist!.toUpperCase(),
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
                                Tab(text: 'UP NEXT'),
                                Tab(text: 'LYRICS'),
                                Tab(text: 'RELATED'),
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
    // Filter buttons
    final filters = ['All', 'Discover', 'Popular', 'Deep cuts', 'Chill'];
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
              const SizedBox(height: 12),
              // Filter buttons
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: filters.map((filter) {
                    final isSelected = _selectedFilter == filter;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8.0),
                      child: FilterChip(
                        label: Text(filter),
                        selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedFilter = filter;
                          });
                        },
                        selectedColor: accent.withOpacity(0.3),
                        labelStyle: TextStyle(
                          color: isSelected ? accent : Colors.grey.shade400,
                          fontSize: 12,
                        ),
                        backgroundColor: Colors.grey.shade800,
                        side: BorderSide(
                          color: isSelected ? accent : Colors.grey.shade700,
                          width: 1,
                        ),
                      ),
                    );
                  }).toList(),
                ),
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
                    final isPlaying = song['r2_key'] == widget.r2Key;
                    final songIndex = widget.playlist.indexWhere(
                      (s) => s['r2_key'] == song['r2_key'],
                    );

                    return InkWell(
                      onTap: () {
                        // TODO: Play selected song
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
        ],
      ),
    );
  }

  Widget _buildRelatedTab(Color accent) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.recommend,
            size: 64,
            color: Colors.grey.shade600,
          ),
          const SizedBox(height: 16),
          Text(
            'Related songs coming soon',
            style: TextStyle(
              color: Colors.grey.shade400,
              fontSize: 16,
            ),
          ),
        ],
      ),
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
      r2Key: widget.r2Key,
      title: widget.title,
      artist: widget.artist,
      coverPhotoUrl: widget.coverPhotoUrl,
      contentType: widget.contentType,
      playlist: widget.playlist,
      currentIndex: widget.currentIndex,
      showExpandButton: false,
      isMini: false, // Full player controls in expanded screen
      onNext: widget.onNext,
      onPrevious: widget.onPrevious,
      onClose: widget.onClose,
      moderationStatus: widget.moderationStatus,
    );
  }
}
