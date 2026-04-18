import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
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

class _ArtistChannelPageState extends State<ArtistChannelPage> with SingleTickerProviderStateMixin {
  final MediaService _media = MediaService();
  List<dynamic> _songs = [];
  List<Map<String, dynamic>> _albums = [];
  List<dynamic> _merchandise = [];
  List<dynamic> _events = [];
  bool _loading = false;
  bool _loadingMerch = false;
  bool _loadingEvents = false;
  String? _artistPhotoUrl;
  Map<String, dynamic>? _currentlyPlayingSong;
  String? _currentlyPlayingKey;
  List<Map<String, dynamic>> _currentPlaylist = [];
  int _currentPlaylistIndex = -1;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadSongs();
    _loadMerchandise();
    _loadEvents();
    
    // Poll for updates every 10 seconds when on merchandise or events tabs
    _startPolling();
  }
  
  @override
  void dispose() {
    _tabController.removeListener(_onTabChanged);
    _tabController.dispose();
    super.dispose();
  }
  
  void _onTabChanged() {
    // Reload data when switching to merchandise or events tabs
    if (_tabController.index == 1) {
      _loadMerchandise();
    } else if (_tabController.index == 2) {
      _loadEvents();
    }
  }
  
  void _startPolling() {
    // Poll every 10 seconds for new merchandise and events
    Future.delayed(const Duration(seconds: 10), () {
      if (mounted) {
        // Only poll if on merchandise or events tab
        if (_tabController.index == 1 || _tabController.index == 2) {
          if (_tabController.index == 1) {
            _loadMerchandise();
          }
          if (_tabController.index == 2) {
            _loadEvents();
          }
        }
        _startPolling(); // Continue polling
      }
    });
  }


  Future<void> _loadSongs() async {
    setState(() => _loading = true);
    try {
      final songs = await _media.getArtistSongs(widget.channelName);
      if (mounted) {
        setState(() {
          _songs = songs;
          // Try to derive artist photo from returned song payloads.
          // Most API responses include `song['artist']` with `photo_url`.
          if (songs.isNotEmpty && songs.first is Map) {
            final first = songs.first as Map;
            final artist = first['artist'];
            if (artist is Map && artist['photo_url'] != null) {
              _artistPhotoUrl = artist['photo_url']?.toString();
            }
          }
          _loading = false;
        });
        _extractAlbumsFromSongs();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showToast('Failed to load songs: $e');
      }
    }
  }

  void _extractAlbumsFromSongs() {
    final Map<String, Map<String, dynamic>> albumMap = {};

    for (final raw in _songs) {
      if (raw is! Map) continue;
      final song = raw as Map<String, dynamic>;

      final rawAlbum = song['album']?.toString();
      final albumName = (rawAlbum == null || rawAlbum.trim().isEmpty)
          ? (widget.channelName) // fallback bucket for "no album"
          : rawAlbum.trim();

      if (!albumMap.containsKey(albumName)) {
        albumMap[albumName] = {
          'name': albumName,
          'cover_photo_url': song['cover_photo_url'],
          'song_count': 0,
          'songs': <Map<String, dynamic>>[],
          'is_fallback_album': (rawAlbum == null || rawAlbum.trim().isEmpty),
        };
      }

      albumMap[albumName]!['songs'].add(song);
      albumMap[albumName]!['song_count'] = (albumMap[albumName]!['song_count'] as int) + 1;
      // If cover missing, use first available song cover
      if ((albumMap[albumName]!['cover_photo_url'] == null ||
              albumMap[albumName]!['cover_photo_url'].toString().isEmpty) &&
          (song['cover_photo_url'] != null && song['cover_photo_url'].toString().isNotEmpty)) {
        albumMap[albumName]!['cover_photo_url'] = song['cover_photo_url'];
      }
    }

    final albums = albumMap.values.toList();
    // Sort: real albums first (A-Z), then fallback bucket last.
    albums.sort((a, b) {
      final af = a['is_fallback_album'] == true;
      final bf = b['is_fallback_album'] == true;
      if (af != bf) return af ? 1 : -1;
      return (a['name'] as String).toLowerCase().compareTo((b['name'] as String).toLowerCase());
    });

    if (mounted) setState(() => _albums = albums);
  }

  Future<void> _loadMerchandise() async {
    setState(() => _loadingMerch = true);
    try {
      final merch = await _media.getArtistMerchandise(widget.channelName);
      if (mounted) {
        setState(() {
          _merchandise = merch;
          _loadingMerch = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingMerch = false);
      }
    }
  }

  Future<void> _loadEvents() async {
    setState(() => _loadingEvents = true);
    try {
      final events = await _media.getArtistEvents(widget.channelName);
      if (mounted) {
        setState(() {
          _events = events;
          _loadingEvents = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingEvents = false);
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
    
    // Initialize shuffle if enabled
    final playerState = Provider.of<PlayerStateProvider>(context, listen: false);
    playerState.initializeShuffle(playList, _currentPlaylistIndex);
  }

  void _playNext() {
    if (_currentPlaylist.isEmpty || _currentPlaylistIndex < 0) return;

    final playerState = Provider.of<PlayerStateProvider>(context, listen: false);
    final nextIndex = playerState.getNextIndex(_currentPlaylistIndex, _currentPlaylist.length);

    if (nextIndex != null && nextIndex < _currentPlaylist.length) {
      _playSong(_currentPlaylist[nextIndex]);
    }
  }

  void _playPrevious() {
    if (_currentPlaylist.isEmpty || _currentPlaylistIndex < 0) return;

    final playerState = Provider.of<PlayerStateProvider>(context, listen: false);
    final prevIndex = playerState.getPreviousIndex(_currentPlaylistIndex, _currentPlaylist.length);

    if (prevIndex != null && prevIndex >= 0 && prevIndex < _currentPlaylist.length) {
      _playSong(_currentPlaylist[prevIndex]);
    }
  }

  void _playAtIndex(int index) {
    if (_currentPlaylist.isEmpty) return;
    if (index < 0 || index >= _currentPlaylist.length) return;
    _playSong(_currentPlaylist[index]);
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
        toolbarHeight: 140,
        centerTitle: true,
        title: SizedBox(
          height: 140,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Center logo (enlarged x5)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Image.asset(
                  'assets/logo.png',
                  height: 120,
                ),
              ),
              // Artist/channel name aligned left
              Align(
                alignment: Alignment.centerLeft,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 220),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.channelName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white),
                      ),
                      const SizedBox(height: 10),
                      CircleAvatar(
                        radius: 38, // bigger profile pic below the name
                        backgroundColor: Colors.grey.shade800,
                        backgroundImage: (_artistPhotoUrl != null && _artistPhotoUrl!.isNotEmpty)
                            ? NetworkImage(_artistPhotoUrl!)
                            : null,
                        child: (_artistPhotoUrl == null || _artistPhotoUrl!.isEmpty)
                            ? const Icon(Icons.account_circle, color: Colors.white, size: 42)
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Colors.grey.shade900,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: accent,
          labelColor: accent,
          unselectedLabelColor: Colors.grey.shade400,
          tabs: const [
            Tab(
              icon: Icon(Icons.music_note),
              text: 'Songs',
            ),
            Tab(
              icon: Icon(Icons.shopping_bag_outlined),
              text: 'Merchandise',
            ),
            Tab(
              icon: Icon(Icons.event),
              text: 'Events',
            ),
          ],
        ),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildSongsTab(accent),
                _buildMerchandiseTab(accent),
                _buildEventsTab(accent),
              ],
            ),
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
                      onSelectTrackIndex: _playAtIndex,
                    ),
                  );
                },
              ),
        ],
      ),
    );
  }

  Widget _buildSongsTab(Color accent) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_songs.isEmpty) {
      return Center(
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
      );
    }
    if (_albums.isEmpty) {
      return Center(child: Text('No albums yet', style: TextStyle(color: Colors.grey.shade400)));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 5,
        crossAxisSpacing: 18,
        mainAxisSpacing: 18,
        childAspectRatio: 0.75,
      ),
      itemCount: _albums.length,
      itemBuilder: (context, index) {
        final album = _albums[index];
        final albumName = album['name'] as String;
        final songs = album['songs'] as List<Map<String, dynamic>>;
        final coverUrl = _getCoverPhotoUrl({'cover_photo_url': album['cover_photo_url']}) ??
            (album['cover_photo_url']?.toString());
        final songCount = album['song_count'] as int? ?? songs.length;
        final isFallback = album['is_fallback_album'] == true;

        return InkWell(
          onTap: () => _showAlbumSongsSheet(albumName: albumName, songs: songs, accent: accent),
          borderRadius: BorderRadius.circular(999),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                width: double.infinity,
                alignment: Alignment.center,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.grey.shade800, width: 1),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.35),
                        blurRadius: 18,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: (coverUrl != null && coverUrl.isNotEmpty)
                        ? Image.network(
                            coverUrl,
                            fit: BoxFit.cover,
                            errorBuilder: (_, __, ___) => Container(
                              color: Colors.grey.shade800,
                              child: Center(child: Icon(Icons.album, color: accent, size: 44)),
                            ),
                          )
                        : Container(
                            color: Colors.grey.shade800,
                            child: Center(child: Icon(Icons.album, color: accent, size: 44)),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                albumName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                isFallback ? '${widget.channelName} • $songCount songs' : '$songCount songs',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showAlbumSongsSheet({
    required String albumName,
    required List<Map<String, dynamic>> songs,
    required Color accent,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.grey.shade900,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.7,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        albumName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w700),
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
                  itemCount: songs.length,
                  itemBuilder: (context, index) {
                    final song = songs[index];
                    final title = song['title']?.toString() ?? 'Untitled';
                    final contentType = song['content_type']?.toString();
                    final isVideo = _isVideo(contentType);
                    final r2Key = song['r2_key']?.toString() ?? '';
                    final isPlaying = _currentlyPlayingKey == r2Key;
                    final cover = _getCoverPhotoUrl(song);

                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: isPlaying ? accent : Colors.grey.shade800),
                      ),
                      child: ListTile(
                        leading: Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey.shade800,
                          ),
                          child: cover != null && cover.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    cover,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) =>
                                        Icon(isVideo ? Icons.videocam : Icons.music_note, color: accent),
                                  ),
                                )
                              : Icon(isVideo ? Icons.videocam : Icons.music_note, color: accent),
                        ),
                        title: Text(title, style: const TextStyle(color: Colors.white)),
                        subtitle: Text(isVideo ? 'Video' : 'Audio', style: TextStyle(color: Colors.grey.shade400)),
                        trailing: Icon(Icons.play_circle_fill, color: accent, size: 34),
                        onTap: () {
                          final moderationStatus = song['moderation_status']?.toString().toLowerCase();
                          if (moderationStatus == 'flagged') return;
                          Navigator.pop(context);
                          _playSong(song);
                        },
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMerchandiseTab(Color accent) {
    if (_loadingMerch) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_merchandise.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.shopping_bag_outlined, size: 64, color: Colors.grey.shade600),
            const SizedBox(height: 16),
            Text(
              'No merchandise available',
              style: TextStyle(color: Colors.grey.shade400),
            ),
            const SizedBox(height: 8),
            Text(
              'This artist hasn\'t added any merchandise yet',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      scrollDirection: Axis.horizontal,
      itemCount: _merchandise.length,
      itemBuilder: (context, index) {
        final item = _merchandise[index] as Map<String, dynamic>;
        return Container(
          width: 280,
          margin: EdgeInsets.only(right: index < _merchandise.length - 1 ? 16 : 0),
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade800, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Product Image
              Container(
                width: double.infinity,
                height: 200,
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: item['image_url'] != null && item['image_url'].toString().isNotEmpty
                    ? ClipRRect(
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(12),
                          topRight: Radius.circular(12),
                        ),
                        child: Image.network(
                          item['image_url'].toString(),
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(Icons.shopping_bag, size: 64, color: accent.withOpacity(0.5));
                          },
                        ),
                      )
                    : Icon(Icons.shopping_bag, size: 64, color: accent.withOpacity(0.5)),
              ),
              // Product Info
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          item['title'] ?? 'Untitled Item',
                          style: const TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (item['description'] != null && item['description'].toString().isNotEmpty) ...[
                        const SizedBox(height: 6),
                        Flexible(
                          child: Text(
                            item['description'].toString(),
                            style: TextStyle(
                              fontSize: 11,
                              color: Colors.grey.shade400,
                            ),
                            maxLines: 6,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '\$${(item['price'] ?? 0).toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: accent,
                                ),
                              ),
                              if (item['stock'] != null)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: (item['stock'] as int) > 10
                                        ? accent.withOpacity(0.2)
                                        : Colors.red.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Text(
                                    (item['stock'] as int) > 10
                                        ? 'In Stock'
                                        : 'Only ${item['stock']} left',
                                    style: TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: (item['stock'] as int) > 10
                                          ? accent
                                          : Colors.red.shade300,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          if (item['purchase_link'] != null && item['purchase_link'].toString().isNotEmpty) ...[
                            const SizedBox(height: 6),
                            SizedBox(
                              width: double.infinity,
                              child: TextButton(
                                style: TextButton.styleFrom(
                                  padding: const EdgeInsets.symmetric(vertical: 6),
                                  backgroundColor: accent,
                                  foregroundColor: Colors.black,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                ),
                                onPressed: () async {
                                  final url = item['purchase_link']?.toString();
                                  if (url != null && url.isNotEmpty) {
                                    final uri = Uri.parse(url);
                                    if (await canLaunchUrl(uri)) {
                                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                                    } else {
                                      showToast('Could not open purchase link');
                                    }
                                  }
                                },
                                child: const Text(
                                  'Buy',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEventsTab(Color accent) {
    if (_loadingEvents) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_events.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_outlined, size: 64, color: Colors.grey.shade600),
            const SizedBox(height: 16),
            Text(
              'No events scheduled',
              style: TextStyle(color: Colors.grey.shade400),
            ),
            const SizedBox(height: 8),
            Text(
              'This artist hasn\'t scheduled any events yet',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }
    // Display events as cards in a grid layout
    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        childAspectRatio: 0.75,
      ),
      itemCount: _events.length,
      itemBuilder: (context, index) {
        final event = _events[index] as Map<String, dynamic>;
        return Container(
          decoration: BoxDecoration(
            color: Colors.grey.shade900,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey.shade800, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Event header with icon
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: accent.withOpacity(0.1),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(Icons.event, size: 24, color: accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        event['title'] ?? 'Untitled Event',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              // Event details
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (event['description'] != null && event['description'].toString().isNotEmpty) ...[
                        Text(
                          event['description'].toString(),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade400,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 8),
                      ],
                      // Date
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 14, color: accent),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              _formatEventDate(event['date']?.toString() ?? ''),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade300,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Time
                      Row(
                        children: [
                          Icon(Icons.access_time, size: 14, color: accent),
                          const SizedBox(width: 6),
                          Text(
                            event['time']?.toString() ?? '',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade300,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Location
                      Row(
                        children: [
                          Icon(Icons.location_on, size: 14, color: accent),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              event['location']?.toString() ?? '',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade300,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      // Ticket price
                      if (event['ticket_price'] != null) ...[
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Ticket',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                              Text(
                                '\$${(event['ticket_price'] ?? 0).toStringAsFixed(2)}',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: accent,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (event['ticket_link'] != null &&
                            event['ticket_link'].toString().isNotEmpty) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              style: ElevatedButton.styleFrom(
                                backgroundColor: accent,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              onPressed: () async {
                                final url = event['ticket_link']?.toString();
                                if (url == null || url.isEmpty) return;
                                final uri = Uri.parse(url);
                                if (await canLaunchUrl(uri)) {
                                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                                } else {
                                  showToast('Could not open ticket link');
                                }
                              },
                              child: const Text(
                                'Get Ticket',
                                style: TextStyle(fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _formatEventDate(String dateStr) {
    if (dateStr.isEmpty) return '';
    try {
      final date = DateTime.parse(dateStr);
      final weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      final months = [
        'January', 'February', 'March', 'April', 'May', 'June',
        'July', 'August', 'September', 'October', 'November', 'December'
      ];
      return '${weekdays[date.weekday - 1]}, ${months[date.month - 1]} ${date.day}, ${date.year}';
    } catch (e) {
      return dateStr;
    }
  }
}
