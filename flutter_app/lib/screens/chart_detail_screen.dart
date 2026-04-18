import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/chart.dart';
import '../services/media_service.dart';
import '../widgets/media_player_widget.dart';
import '../providers/player_state_provider.dart';

class ChartDetailScreen extends StatefulWidget {
  final ChartItem chart;
  /// Backend `style`: trending_only | balanced | new_music_heavy
  final String chartStyle;

  const ChartDetailScreen({
    super.key,
    required this.chart,
    this.chartStyle = 'balanced',
  });

  @override
  State<ChartDetailScreen> createState() => _ChartDetailScreenState();
}

class _ChartDetailScreenState extends State<ChartDetailScreen> {
  final MediaService _media = MediaService();
  List<dynamic> _songs = [];
  bool _loading = true;
  String? _error;
  Map<String, dynamic>? _currentlyPlayingSong;
  List<Map<String, dynamic>> _currentPlaylist = [];
  int _currentPlaylistIndex = -1;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _media.getChartTopSongs(
        chartId: widget.chart.id,
        limit: 50,
        style: widget.chartStyle,
      );
      if (!mounted) return;
      setState(() {
        _songs = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  String _artistLabel(Map<String, dynamic> song) {
    final a = song['artist'];
    if (a is Map) {
      return a['channel_name']?.toString() ?? 'Unknown';
    }
    return a?.toString() ?? 'Unknown';
  }

  bool _isVideo(String? contentType) {
    if (contentType == null) return false;
    return contentType.startsWith('video/');
  }

  void _playSong(Map<String, dynamic> song) {
    final moderationStatus = song['moderation_status']?.toString().toLowerCase();
    if (moderationStatus == 'flagged') return;
    final playList = _songs.map((s) => s as Map<String, dynamic>).toList();
    final idx = playList.indexWhere((s) => s['r2_key'] == song['r2_key']);
    final playerState = Provider.of<PlayerStateProvider>(context, listen: false);
    playerState.showMini();
    setState(() {
      _currentlyPlayingSong = song;
      _currentPlaylist = playList;
      _currentPlaylistIndex = idx >= 0 ? idx : 0;
    });
    playerState.initializeShuffle(playList, _currentPlaylistIndex);
  }

  void _playNext() {
    if (_currentPlaylist.isEmpty) return;
    var i = _currentPlaylistIndex + 1;
    if (i >= _currentPlaylist.length) i = 0;
    setState(() {
      _currentPlaylistIndex = i;
      _currentlyPlayingSong = _currentPlaylist[i];
    });
  }

  void _playPrevious() {
    if (_currentPlaylist.isEmpty) return;
    var i = _currentPlaylistIndex - 1;
    if (i < 0) i = _currentPlaylist.length - 1;
    setState(() {
      _currentPlaylistIndex = i;
      _currentlyPlayingSong = _currentPlaylist[i];
    });
  }

  void _playAtIndex(int index) {
    if (index < 0 || index >= _currentPlaylist.length) return;
    setState(() {
      _currentPlaylistIndex = index;
      _currentlyPlayingSong = _currentPlaylist[index];
    });
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF78E08F);
    return Scaffold(
      backgroundColor: const Color(0xFF111414),
      appBar: AppBar(
        backgroundColor: Colors.grey.shade900,
        title: Text(
          widget.chart.title,
          style: const TextStyle(color: Colors.white),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: accent))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(_error!, textAlign: TextAlign.center, style: TextStyle(color: Colors.grey.shade400)),
                        const SizedBox(height: 16),
                        TextButton(
                          onPressed: _load,
                          child: const Text('Retry', style: TextStyle(color: accent)),
                        ),
                      ],
                    ),
                  ),
                )
              : Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                          child: Text(
                            widget.chart.subtitle.replaceAll('\\n', ' '),
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 13, height: 1.3),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            'Top ${_songs.length > 50 ? 50 : _songs.length}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: _songs.isEmpty
                              ? Center(
                                  child: Text(
                                    'No chart data yet. Play some tracks to build rankings.',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(color: Colors.grey.shade500),
                                  ),
                                )
                              : RefreshIndicator(
                                  color: accent,
                                  onRefresh: _load,
                                  child: ListView.builder(
                                    padding: const EdgeInsets.only(bottom: 100),
                                    itemCount: _songs.length,
                                    itemBuilder: (context, index) {
                                      final song = _songs[index] as Map<String, dynamic>;
                                      final mod = song['moderation_status']?.toString().toLowerCase();
                                      return ListTile(
                                        leading: SizedBox(
                                          width: 40,
                                          child: Text(
                                            '${index + 1}',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Colors.grey.shade500,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ),
                                        title: Text(
                                          song['title']?.toString() ?? 'Unknown',
                                          style: const TextStyle(color: Colors.white),
                                        ),
                                        subtitle: Text(
                                          _artistLabel(song),
                                          style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                                        ),
                                        trailing: Icon(Icons.play_arrow, color: accent),
                                        onTap: mod == 'flagged' ? null : () => _playSong(song),
                                      );
                                    },
                                  ),
                                ),
                        ),
                      ],
                    ),
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
                              artist: _artistLabel(_currentlyPlayingSong!),
                              coverPhotoUrl: _currentlyPlayingSong!['cover_photo_url'],
                              contentType: _currentlyPlayingSong!['content_type'],
                              isVideo: _isVideo(_currentlyPlayingSong!['content_type']?.toString()),
                              playlist: _currentPlaylist,
                              currentIndex: _currentPlaylistIndex,
                              isMini: true,
                              moderationStatus: _currentlyPlayingSong!['moderation_status']?.toString(),
                              onClose: () {
                                playerState.hide();
                                setState(() {
                                  _currentlyPlayingSong = null;
                                  _currentPlaylist = [];
                                  _currentPlaylistIndex = -1;
                                });
                              },
                              onNext: _playNext,
                              onPrevious: _playPrevious,
                              onSelectTrackIndex: _playAtIndex,
                            ),
                          );
                        },
                      ),
                  ],
                ),
    );
  }
}
