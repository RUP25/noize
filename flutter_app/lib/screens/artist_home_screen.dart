// lib/screens/artist_home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/media_service.dart';
import '../services/upload_service.dart';
import '../utils/toast_util.dart';
import '../widgets/artist_channel_page.dart';
import '../widgets/media_player_widget.dart';
import '../providers/player_state_provider.dart';
import 'welcome_screen.dart';
import 'artist_plus_upgrade_screen.dart';
import 'profile_screen.dart';
import 'dart:io' if (dart.library.html) 'dart:html' as html;
import 'package:file_selector/file_selector.dart';
import 'dart:convert';
import 'dart:typed_data';
import '../utils/file_helper.dart' show createPlatformFile, PlatformFile, buildImageFromPath;
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/api_config.dart';

class ArtistHomeScreen extends StatefulWidget {
  const ArtistHomeScreen({super.key});

  @override
  State<ArtistHomeScreen> createState() => _ArtistHomeScreenState();
}

class _ArtistHomeScreenState extends State<ArtistHomeScreen> with SingleTickerProviderStateMixin {
  final AuthService _auth = AuthService();
  final MediaService _media = MediaService();
  final UploadService _upload = UploadService();
  late final TabController _tabController;
  
  String? _channelName;
  Map<String, dynamic>? _userData;
  String? _profilePhotoUrl;
  List<dynamic> _mySongs = [];
  bool _loadingSongs = false;
  List<Map<String, dynamic>> _albums = [];
  final AudioPlayer _audioPlayer = AudioPlayer();
  String? _currentlyPlayingKey;
  Map<String, dynamic>? _currentlyPlayingSong;
  List<Map<String, dynamic>> _currentPlaylist = []; // Current playlist/queue
  int _currentPlaylistIndex = -1; // Current song index in playlist
  Map<String, dynamic> _analytics = {
    'streams': 0,
    'likes': 0,
    'dislikes': 0,
    'tips': 0,
    'donations': 0,
    'subs': 0,
    'total_earnings': 0,
  };
  List<dynamic> _merchandise = [];
  List<dynamic> _events = [];
  bool _loadingMerchandise = false;
  bool _loadingEvents = false;
  bool _artistPlus = false;
  int? _artistPlusMonthlyPaise;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 7, vsync: this);
    _loadUserData();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    try {
      final user = await _auth.getMe();
      if (mounted) {
        setState(() {
          _userData = user;
          _channelName = user?['channel_name'];
          _profilePhotoUrl = user?['photo_url']?.toString();
          _artistPlus = user?['artist_plus'] == true;
          final ap = user?['artist_plus_monthly_paise'];
          _artistPlusMonthlyPaise = ap is int
              ? ap
              : (ap != null ? int.tryParse(ap.toString()) : null);
        });
        // Load songs after channel name is available
        if (_channelName != null) {
          _fetchMySongs();
          _loadMerchandise();
          _loadEvents();
        }
        if (user?['is_artist'] == true) {
          _loadEngagementStats();
        }
      }
    } catch (e) {
      if (mounted) {
        showToast('Failed to load user data: $e');
      }
    }
  }

  Future<void> _loadEngagementStats() async {
    if (!_auth.isLoggedIn) return;
    try {
      final s = await _media.getArtistEngagementStats();
      if (!mounted) return;
      setState(() {
        _analytics['streams'] = s['streams'] ?? 0;
        _analytics['likes'] = s['likes'] ?? 0;
        _analytics['dislikes'] = s['dislikes'] ?? 0;
        _analytics['subs'] = s['subs'] ?? 0;
      });
    } catch (_) {
      // Non-fatal: dashboard still works with zeros
    }
  }

  Future<void> _fetchMySongs() async {
    if (_channelName == null || _channelName!.isEmpty) {
      if (mounted) {
        setState(() => _loadingSongs = false);
        showToast('No channel name available. Please create a channel first.');
      }
      return;
    }
    setState(() => _loadingSongs = true);
    try {
      print('🎵 Loading songs for channel: $_channelName');
      final songs = await _media.getArtistSongs(_channelName!);
      if (mounted) {
        setState(() {
          _mySongs = songs;
          _loadingSongs = false;
        });
        _extractAlbumsFromSongs();
        _loadEngagementStats();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingSongs = false);
        print('❌ Error loading songs: $e');
        showToast('Failed to load songs: $e');
      }
    }
  }

  void _extractAlbumsFromSongs() {
    // Extract unique albums from songs
    final Map<String, Map<String, dynamic>> albumMap = {};
    
    for (var song in _mySongs) {
      final albumName = song['album'] as String?;
      if (albumName != null && albumName.isNotEmpty) {
        if (!albumMap.containsKey(albumName)) {
          albumMap[albumName] = {
            'name': albumName,
            'cover_photo_url': song['cover_photo_url'],
            'song_count': 0,
            'songs': <Map<String, dynamic>>[],
          };
        }
        albumMap[albumName]!['song_count'] = (albumMap[albumName]!['song_count'] as int) + 1;
        albumMap[albumName]!['songs'].add(song);
        // Use the first song's cover photo if album doesn't have one
        if (albumMap[albumName]!['cover_photo_url'] == null && song['cover_photo_url'] != null) {
          albumMap[albumName]!['cover_photo_url'] = song['cover_photo_url'];
        }
      }
    }
    
    setState(() {
      _albums = albumMap.values.toList();
    });
  }

  void _playSong(Map<String, dynamic> song, {List<Map<String, dynamic>>? playlist}) {
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
    
    // If playlist is provided, use it; otherwise use all songs
    final playList = playlist ?? _mySongs.map((s) => s as Map<String, dynamic>).toList();
    
    // Find the index of the current song in the playlist
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
    _playSong(_currentPlaylist[index], playlist: _currentPlaylist);
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


  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF78E08F);

    return Scaffold(
      backgroundColor: const Color(0xFF111414),
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _channelName ?? 'NOIZE Artist',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            Text(
              _artistPlus
                  ? 'Artist+ · ₹${((_artistPlusMonthlyPaise ?? 0) / 100).toStringAsFixed(0)}/mo'
                  : 'NOIZE Artist · Free tier',
              style: TextStyle(fontSize: 11, color: Colors.grey.shade400),
            ),
          ],
        ),
        actions: [
          if (_channelName != null)
            IconButton(
              icon: CircleAvatar(
                radius: 18, // slightly larger than default
                backgroundColor: Colors.grey.shade800,
                backgroundImage: (_profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty)
                    ? NetworkImage(_profilePhotoUrl!)
                    : null,
                child: (_profilePhotoUrl == null || _profilePhotoUrl!.isEmpty)
                    ? const Icon(Icons.account_circle, color: Colors.white)
                    : null,
              ),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ProfileScreen(),
                  ),
                ).then((_) => _loadUserData());
              },
              tooltip: 'View Profile',
            ),
          ValueListenableBuilder<String?>(
            valueListenable: _auth.authToken,
            builder: (context, token, _) {
              if (token != null) {
                return IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () async {
                    await _auth.logout();
                    if (mounted) {
                      Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                        (Route<dynamic> route) => false,
                      );
                    }
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Column(
            children: [
              TabBar(
                controller: _tabController,
                isScrollable: true,
                tabs: const [
                  Tab(text: 'Dashboard'),
                  Tab(text: 'My Uploads'),
                  Tab(text: 'Upload'),
                  Tab(text: 'Albums'),
                  Tab(text: 'Analytics'),
                  Tab(text: 'Merch & Events'),
                  Tab(text: 'Messages'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDashboardTab(accent),
                    _buildMyUploadsTab(accent),
                    _buildUploadTab(accent),
                    _buildAlbumsTab(accent),
                    _buildAnalyticsTab(accent),
                    _buildMerchTab(accent),
                    _buildMessagesTab(accent),
                  ],
                ),
              ),
            ],
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
                    artist: _currentlyPlayingSong!['artist']?['channel_name'],
                    coverPhotoUrl: _currentlyPlayingSong!['cover_photo_url'],
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

  Future<void> _openArtistPlusUpgrade() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const ArtistPlusUpgradeScreen()),
    );
    if (ok == true && mounted) await _loadUserData();
  }

  Widget _artistPlusLockBanner(Color accent) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.orange.shade900.withOpacity(0.25),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade700.withOpacity(0.6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Artist+ required',
            style: TextStyle(
              color: Colors.orange.shade200,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Merch, events, tipping & campaigns are part of NOIZE Artist+ (₹299–₹599/mo).',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 13, height: 1.35),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: _openArtistPlusUpgrade,
            child: Text('View Artist+ plans', style: TextStyle(color: accent, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardTab(Color accent) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome Card
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [accent.withOpacity(0.2), accent.withOpacity(0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accent.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Icon(Icons.music_note, color: accent, size: 48),
                const SizedBox(height: 12),
                Text(
                  'Welcome, ${_channelName ?? "Artist"}!',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Manage your music, connect with fans, and grow your career',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade300,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade800),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'NOIZE Artist — free tier',
                  style: TextStyle(color: accent, fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  '• Upload music\n• Channel profile\n• Basic stats',
                  style: TextStyle(color: Colors.grey.shade400, height: 1.45),
                ),
                if (!_artistPlus) ...[
                  const SizedBox(height: 12),
                  Text(
                    'Artist+ (₹299–₹599/mo): fan tipping, merchandise, campaigns. Events: info, external ticket link, listing on profile.',
                    style: TextStyle(color: Colors.grey.shade500, fontSize: 13, height: 1.35),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _openArtistPlusUpgrade,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      child: const Text('Upgrade to Artist+'),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Quick Stats
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quick Stats',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Streams',
                        '${_analytics['streams']}',
                        Icons.play_circle_outline,
                        accent,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        'Subscribers',
                        '${_analytics['subs']}',
                        Icons.people,
                        Colors.blue,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Likes',
                        '${_analytics['likes']}',
                        Icons.thumb_up_outlined,
                        Colors.green.shade400,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        'Dislikes',
                        '${_analytics['dislikes']}',
                        Icons.thumb_down_outlined,
                        Colors.deepOrange.shade300,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildStatCard(
                        'Tips',
                        '₹${_analytics['tips']}',
                        Icons.volunteer_activism,
                        Colors.purple,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        'Earnings',
                        '₹${_analytics['total_earnings']}',
                        Icons.monetization_on,
                        Colors.orange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Quick Actions
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                _buildActionTile(
                  icon: Icons.library_music,
                  title: 'My Uploads',
                  subtitle: 'View and manage your songs',
                  color: accent,
                  onTap: () => _tabController.animateTo(1),
                ),
                const SizedBox(height: 8),
                _buildActionTile(
                  icon: Icons.upload,
                  title: 'Upload Music',
                  subtitle: 'Add new songs to your channel',
                  color: accent,
                  onTap: () => _tabController.animateTo(2),
                ),
                const SizedBox(height: 8),
                _buildActionTile(
                  icon: Icons.album,
                  title: 'Create Album',
                  subtitle: 'Organize your music into albums',
                  color: Colors.purple,
                  onTap: () => _tabController.animateTo(3),
                ),
                const SizedBox(height: 8),
                _buildActionTile(
                  icon: Icons.store,
                  title: 'Manage Store',
                  subtitle: 'Set up merch and tickets',
                  color: Colors.orange,
                  onTap: () => _tabController.animateTo(5),
                ),
              ],
            ),
          ),

        ],
      ),
    );
  }

  Widget _buildMyUploadsTab(Color accent) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'My Uploads',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                if (_channelName != null)
                  TextButton.icon(
                    onPressed: _fetchMySongs,
                    icon: _loadingSongs
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 18),
                    label: const Text('Refresh'),
                    style: TextButton.styleFrom(
                      foregroundColor: accent,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_loadingSongs && _mySongs.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24.0),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (_mySongs.isEmpty)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  children: [
                    Icon(Icons.music_off, size: 48, color: Colors.grey.shade600),
                    const SizedBox(height: 12),
                    Text(
                      'No uploads yet',
                      style: TextStyle(
                        color: Colors.grey.shade400,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Upload your first song or video to get started',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.grey.shade500,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: () => _tabController.animateTo(2), // Navigate to Upload tab
                      icon: const Icon(Icons.upload),
                      label: const Text('Upload Now'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ],
                ),
              )
            else
              ..._mySongs.map((song) => _buildUploadItem(song, accent)).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadTab(Color accent) {
    return _UploadTabContent(
      accent: accent,
      upload: _upload,
      auth: _auth,
      onUploadSuccess: _fetchMySongs,
    );
  }

  Widget _buildAlbumsTab(Color accent) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'My Albums',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              ElevatedButton.icon(
                onPressed: () => _showCreateAlbumDialog(accent),
                icon: const Icon(Icons.add),
                label: const Text('Create Album'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.black,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _albums.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.album, size: 64, color: Colors.grey.shade600),
                        const SizedBox(height: 16),
                        Text(
                          'No albums yet',
                          style: TextStyle(color: Colors.grey.shade400),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create your first album to organize your music',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : GridView.builder(
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16,
                      mainAxisSpacing: 16,
                      childAspectRatio: 0.75,
                    ),
                    itemCount: _albums.length,
                    itemBuilder: (context, index) {
                      final album = _albums[index];
                      return _buildAlbumCard(album, accent);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlbumCard(Map<String, dynamic> album, Color accent) {
    final albumName = album['name'] as String;
    final coverUrl = album['cover_photo_url'] as String?;
    final songCount = album['song_count'] as int;
    final songs = album['songs'] as List<Map<String, dynamic>>;
    
    return GestureDetector(
      onTap: () {
        _showAlbumDetail(album, accent);
      },
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade800),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Album cover
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                  color: Colors.grey.shade800,
                ),
                child: coverUrl != null && coverUrl.isNotEmpty
                    ? ClipRRect(
                        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                        child: Image.network(
                          coverUrl,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return Icon(Icons.album, color: accent, size: 60);
                          },
                        ),
                      )
                    : Icon(Icons.album, color: accent, size: 60),
              ),
            ),
            // Album info
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    albumName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$songCount ${songCount == 1 ? 'song' : 'songs'}',
                    style: TextStyle(
                      color: Colors.grey.shade400,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCreateAlbumDialog(Color accent) async {
    final _nameController = TextEditingController();
    XFile? _coverFile;
    Uint8List? _coverBytes;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.grey.shade900,
          title: const Text('Create Album', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _nameController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    labelText: 'Album Name',
                    labelStyle: const TextStyle(color: Colors.grey),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: accent),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: accent),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Album Cover',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: () async {
                    final file = await openFile(
                      acceptedTypeGroups: [
                        const XTypeGroup(label: 'images', extensions: ['jpg', 'jpeg', 'png'])
                      ],
                    );
                    if (file != null) {
                      final bytes = await file.readAsBytes();
                      setState(() {
                        _coverFile = file;
                        _coverBytes = bytes;
                      });
                    }
                  },
                  child: Container(
                    height: 150,
                    width: 150,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _coverFile != null ? accent : Colors.grey.shade700,
                      ),
                    ),
                    child: _coverFile != null && _coverBytes != null && _coverBytes!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(
                              _coverBytes!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.error, color: Colors.red);
                              },
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.image, color: Colors.grey.shade600),
                              const SizedBox(height: 8),
                              Text(
                                'Tap to add cover',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                if (_nameController.text.trim().isNotEmpty) {
                  Navigator.pop(context, true);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.black,
              ),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );

    if (result == true && _nameController.text.trim().isNotEmpty) {
      try {
        // Upload cover if selected
        String? coverUrl;
        if (_coverFile != null) {
          final filename = _coverFile!.name;
          final bytes = await _coverFile!.readAsBytes();
          
          // Use proxy upload for web to avoid CORS issues
          final base = Uri.parse(apiBaseUrl);
          final uploadUri = base.replace(path: '${base.path}/media/upload-proxy');
          
          final request = http.MultipartRequest('POST', uploadUri);
          request.headers.addAll(_auth.authHeader);
          request.files.add(
            http.MultipartFile.fromBytes(
              'file',
              bytes,
              filename: filename,
            ),
          );
          
          final streamedResponse = await request.send();
          final response = await http.Response.fromStream(streamedResponse);
          
          if (response.statusCode != 200) {
            throw Exception('Upload failed: ${response.statusCode}');
          }
          
          final data = jsonDecode(response.body);
          final key = data['key'] as String;
          
          coverUrl = base.replace(path: '${base.path}/media/download/${Uri.encodeComponent(key)}').toString();
        }
        
        // Store album locally (albums are extracted from songs)
        // When you upload songs with this album name, they will appear in the Albums tab
        showToast('Album "${_nameController.text.trim()}" ready! Upload songs with this album name to see them here.');
        // Refresh albums list
        _extractAlbumsFromSongs();
      } catch (e) {
        showToast('Failed to create album: $e');
      }
    }
  }

  void _showAlbumDetail(Map<String, dynamic> album, Color accent) {
    final albumName = album['name'] as String;
    final songs = album['songs'] as List<Map<String, dynamic>>;
    final coverUrl = album['cover_photo_url'] as String?;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.8,
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: Colors.grey.shade800)),
              ),
              child: Row(
                children: [
                  // Album cover
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      color: Colors.grey.shade800,
                    ),
                    child: coverUrl != null && coverUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              _getCoverPhotoUrl({'cover_photo_url': coverUrl}) ?? coverUrl,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return Icon(Icons.album, color: accent, size: 40);
                              },
                            ),
                          )
                        : Icon(Icons.album, color: accent, size: 40),
                  ),
                  const SizedBox(width: 16),
                  // Album info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          albumName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 20,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${songs.length} ${songs.length == 1 ? 'song' : 'songs'}',
                          style: TextStyle(
                            color: Colors.grey.shade400,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            // Songs list
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: songs.length,
                itemBuilder: (context, index) {
                  final song = songs[index];
                  final title = song['title'] ?? 'Untitled';
                  final r2Key = song['r2_key'] ?? '';
                  final isPlaying = _currentlyPlayingKey == r2Key;
                  
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: isPlaying ? accent.withOpacity(0.2) : Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isPlaying ? accent : Colors.transparent,
                        width: isPlaying ? 2 : 0,
                      ),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: Container(
                        width: 50,
                        height: 50,
                        decoration: BoxDecoration(
                          color: accent.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: song['cover_photo_url'] != null && song['cover_photo_url'].toString().isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  _getCoverPhotoUrl(song) ?? '',
                                  fit: BoxFit.cover,
                                  errorBuilder: (context, error, stackTrace) {
                                    return Icon(Icons.music_note, color: accent, size: 24);
                                  },
                                ),
                              )
                            : Icon(Icons.music_note, color: accent, size: 24),
                      ),
                      title: Text(
                        title,
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: isPlaying ? FontWeight.bold : FontWeight.normal,
                        ),
                      ),
                      trailing: IconButton(
                        icon: Icon(
                          isPlaying ? Icons.pause_circle : Icons.play_circle,
                          color: accent,
                          size: 32,
                        ),
                        onPressed: () {
                          _playSong(song, playlist: songs);
                          Navigator.pop(context); // Close the album detail sheet
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAnalyticsTab(Color accent) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Analytics',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          _buildAnalyticsCard(
            'Total Streams',
            '${_analytics['streams']}',
            Icons.play_circle_outline,
            accent,
          ),
          const SizedBox(height: 16),
          _buildAnalyticsCard(
            'Likes',
            '${_analytics['likes']}',
            Icons.thumb_up_outlined,
            Colors.green.shade400,
          ),
          const SizedBox(height: 16),
          _buildAnalyticsCard(
            'Dislikes',
            '${_analytics['dislikes']}',
            Icons.thumb_down_outlined,
            Colors.deepOrange.shade300,
          ),
          const SizedBox(height: 16),
          _buildAnalyticsCard(
            'Subscribers',
            '${_analytics['subs']}',
            Icons.people,
            Colors.blue,
          ),
          const SizedBox(height: 16),
          _buildAnalyticsCard(
            'Tips Received',
            '₹${_analytics['tips']}',
            Icons.volunteer_activism,
            Colors.purple,
          ),
          const SizedBox(height: 16),
          _buildAnalyticsCard(
            'Donations',
            '₹${_analytics['donations']}',
            Icons.favorite,
            Colors.red,
          ),
          const SizedBox(height: 16),
          _buildAnalyticsCard(
            'Total Earnings',
            '₹${_analytics['total_earnings']}',
            Icons.monetization_on,
            Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _buildMerchTab(Color accent) {
    return DefaultTabController(
      length: 2,
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Merchandise & Events',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (!_artistPlus) _artistPlusLockBanner(accent),
            TabBar(
              indicatorColor: accent,
              labelColor: accent,
              unselectedLabelColor: Colors.grey.shade400,
              tabs: const [
                Tab(text: 'Merchandise'),
                Tab(text: 'Events'),
              ],
            ),
            const SizedBox(height: 16),
            Expanded(
              child: TabBarView(
                children: [
                  _buildMerchandiseTab(accent),
                  _buildEventsTab(accent),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _loadMerchandise() async {
    if (_channelName == null) return;
    setState(() => _loadingMerchandise = true);
    try {
      final merch = await _media.getArtistMerchandise(_channelName!);
      if (mounted) {
        setState(() {
          _merchandise = merch;
          _loadingMerchandise = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingMerchandise = false);
        showToast('Failed to load merchandise: $e');
      }
    }
  }

  Future<void> _loadEvents() async {
    if (_channelName == null) return;
    setState(() => _loadingEvents = true);
    try {
      final events = await _media.getArtistEvents(_channelName!);
      if (mounted) {
        setState(() {
          _events = events;
          _loadingEvents = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loadingEvents = false);
        showToast('Failed to load events: $e');
      }
    }
  }

  Future<String> _uploadImageFile(PlatformFile file) async {
    if (kIsWeb) {
      if (file.bytes == null) {
        throw Exception('No image bytes available');
      }
      final filename = file.name ?? 'image.jpg';
      final contentType = _lookupImageContentType(filename);
      final base = Uri.parse(apiBaseUrl);
      final uploadUri = base.replace(path: '${base.path}/media/upload-proxy');
      
      final request = http.MultipartRequest('POST', uploadUri);
      request.headers.addAll(_auth.authHeader);
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          file.bytes!,
          filename: filename,
        ),
      );
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode != 200) {
        throw Exception('Image upload failed: ${response.statusCode}');
      }
      
      final data = jsonDecode(response.body);
      final key = data['key'] as String;
      final downloadUri = base.replace(path: '${base.path}/media/public/${Uri.encodeComponent(key)}');
      return downloadUri.toString();
    } else {
      if (file.path == null) {
        throw Exception('No image path available');
      }
      final filename = file.name ?? 'image.jpg';
      final contentType = _lookupImageContentType(filename);
      final base = Uri.parse(apiBaseUrl);
      final uploadUri = base.replace(path: '${base.path}/media/upload-proxy');
      
      final request = http.MultipartRequest('POST', uploadUri);
      request.headers.addAll(_auth.authHeader);
      request.files.add(
        await http.MultipartFile.fromPath('file', file.path!, filename: filename),
      );
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode != 200) {
        throw Exception('Image upload failed: ${response.statusCode}');
      }
      
      final data = jsonDecode(response.body);
      final key = data['key'] as String;
      final downloadUri = base.replace(path: '${base.path}/media/public/${Uri.encodeComponent(key)}');
      return downloadUri.toString();
    }
  }

  String _lookupImageContentType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _deleteMerchandise(Color accent, int merchId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text(
          'Delete Merchandise',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to delete this merchandise item? This action cannot be undone.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade400)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _media.deleteMerchandise(merchId);
      if (mounted) {
        showToast('Merchandise deleted successfully');
        _loadMerchandise();
      }
    } catch (e) {
      if (mounted) {
        showToast('Failed to delete merchandise: $e');
      }
    }
  }

  Future<void> _deleteEvent(Color accent, int eventId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text(
          'Delete Event',
          style: TextStyle(color: Colors.white),
        ),
        content: const Text(
          'Are you sure you want to delete this event? This action cannot be undone.',
          style: TextStyle(color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade400)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await _media.deleteEvent(eventId);
      if (mounted) {
        showToast('Event deleted successfully');
        _loadEvents();
      }
    } catch (e) {
      if (mounted) {
        showToast('Failed to delete event: $e');
      }
    }
  }

  void _showEditMerchItemDialog(Color accent, Map<String, dynamic> item) async {
    final titleController = TextEditingController(text: item['title']?.toString() ?? '');
    final priceController = TextEditingController(text: item['price']?.toString() ?? '');
    final descriptionController = TextEditingController(text: item['description']?.toString() ?? '');
    final purchaseLinkController = TextEditingController(text: item['purchase_link']?.toString() ?? '');
    final stockController = TextEditingController(text: item['stock']?.toString() ?? '');
    final categoryController = TextEditingController(text: item['category']?.toString() ?? '');
    PlatformFile? selectedImageFile;
    String? imagePath;
    Uint8List? imageBytes;
    String? currentImageUrl = item['image_url']?.toString();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.grey.shade900,
          title: const Text(
            'Edit Merchandise Item',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Image Preview/Upload
                GestureDetector(
                  onTap: () async {
                    final XFile? file = await openFile(
                      acceptedTypeGroups: [
                        const XTypeGroup(
                          label: 'images',
                          extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp'],
                        ),
                      ],
                    );
                    if (file != null) {
                      selectedImageFile = await createPlatformFile(file);
                      if (kIsWeb) {
                        imageBytes = selectedImageFile?.bytes;
                        imagePath = selectedImageFile?.name;
                      } else {
                        imagePath = selectedImageFile?.path;
                      }
                      currentImageUrl = null;
                      setDialogState(() {});
                    }
                  },
                  child: Container(
                    height: 200,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey.shade700),
                    ),
                    child: currentImageUrl != null && currentImageUrl!.isNotEmpty && selectedImageFile == null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(currentImageUrl!, fit: BoxFit.cover),
                          )
                        : selectedImageFile != null
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: kIsWeb && imageBytes != null
                                    ? Image.memory(imageBytes!, fit: BoxFit.cover)
                                    : (!kIsWeb && imagePath != null
                                        ? buildImageFromPath(imagePath!)
                                        : const SizedBox()),
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey.shade600),
                                  const SizedBox(height: 8),
                                  Text('Tap to change image', style: TextStyle(color: Colors.grey.shade500)),
                                ],
                              ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Item Title *',
                    labelStyle: TextStyle(color: Colors.grey),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.green)),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: priceController,
                        decoration: const InputDecoration(
                          labelText: 'Price (\$) *',
                          labelStyle: TextStyle(color: Colors.grey),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.green)),
                        ),
                        style: const TextStyle(color: Colors.white),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextField(
                        controller: categoryController,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          labelStyle: TextStyle(color: Colors.grey),
                          enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                          focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.green)),
                        ),
                        style: const TextStyle(color: Colors.white),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: purchaseLinkController,
                  decoration: const InputDecoration(
                    labelText: 'Purchase Link',
                    labelStyle: TextStyle(color: Colors.grey),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.green)),
                  ),
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    labelStyle: TextStyle(color: Colors.grey),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.green)),
                  ),
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: stockController,
                  decoration: const InputDecoration(
                    labelText: 'Stock Quantity',
                    labelStyle: TextStyle(color: Colors.grey),
                    enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                    focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.green)),
                  ),
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel', style: TextStyle(color: Colors.grey.shade400)),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty || priceController.text.isEmpty) {
                  showToast('Please fill in all required fields');
                  return;
                }

                try {
                  final title = titleController.text.trim();
                  final priceText = priceController.text.trim();
                  final description = descriptionController.text.trim();
                  final category = categoryController.text.trim();
                  final stockText = stockController.text.trim();
                  final purchaseLinkText = purchaseLinkController.text.trim();

                  // Basic client-side validation for purchase link to avoid 422 from backend
                  String? purchaseLink;
                  if (purchaseLinkText.isNotEmpty) {
                    if (!purchaseLinkText.startsWith('http://') &&
                        !purchaseLinkText.startsWith('https://')) {
                      showToast('Purchase link must start with http:// or https://');
                      return;
                    }
                    purchaseLink = purchaseLinkText;
                  }

                  final updateData = <String, dynamic>{
                    'title': title,
                    'price': double.tryParse(priceText) ?? 0.0,
                    'description': description.isEmpty ? null : description,
                    'purchase_link': purchaseLink,
                    'category': category.isEmpty ? null : category,
                    'stock': stockText.isEmpty ? null : int.tryParse(stockText),
                  };

                  // Upload new image if selected
                  if (selectedImageFile != null) {
                    final imageUrl = await _uploadImageFile(selectedImageFile!);
                    updateData['image_url'] = imageUrl;
                  }

                  await _media.updateMerchandise(item['id'], updateData);
                  if (mounted) {
                    showToast('Merchandise updated successfully');
                    Navigator.of(context).pop();
                    _loadMerchandise();
                  }
                } catch (e) {
                  if (mounted) {
                    showToast('Failed to update merchandise: $e');
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.black),
              child: const Text('Update'),
            ),
          ],
        ),
      ),
    );
  }

  void _showEditEventDialog(Color accent, Map<String, dynamic> event) {
    final titleController = TextEditingController(text: event['title']?.toString() ?? '');
    final dateController = TextEditingController(text: event['date']?.toString() ?? '');
    // Backend may return HH:MM:SS; editor expects HH:MM
    final initialTime = event['time']?.toString() ?? '';
    final normalizedTime = (initialTime.contains(':') && initialTime.length >= 5)
        ? initialTime.substring(0, 5)
        : initialTime;
    final timeController = TextEditingController(text: normalizedTime);
    final locationController = TextEditingController(text: event['location']?.toString() ?? '');
    final descriptionController = TextEditingController(text: event['description']?.toString() ?? '');
    final ticketPriceController = TextEditingController(text: event['ticket_price']?.toString() ?? '');
    final ticketLinkController = TextEditingController(text: event['ticket_link']?.toString() ?? '');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text(
          'Edit Event',
          style: TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Event Title *',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.green)),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: dateController,
                      decoration: const InputDecoration(
                        labelText: 'Date *',
                        labelStyle: TextStyle(color: Colors.grey),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.green)),
                      ),
                      style: const TextStyle(color: Colors.white),
                      readOnly: true,
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: dateController.text.isNotEmpty
                              ? DateTime.parse(dateController.text)
                              : DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          dateController.text = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: timeController,
                      decoration: const InputDecoration(
                        labelText: 'Time *',
                        labelStyle: TextStyle(color: Colors.grey),
                        enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                        focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.green)),
                      ),
                      style: const TextStyle(color: Colors.white),
                      readOnly: true,
                      onTap: () async {
                        final currentTime = timeController.text.isNotEmpty
                            ? TimeOfDay(
                                hour: int.parse(timeController.text.split(':')[0]),
                                minute: int.parse(timeController.text.split(':')[1]),
                              )
                            : TimeOfDay.now();
                        final time = await showTimePicker(
                          context: context,
                          initialTime: currentTime,
                        );
                        if (time != null) {
                          timeController.text = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(
                  labelText: 'Location *',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.green)),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.green)),
                ),
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ticketPriceController,
                decoration: const InputDecoration(
                  labelText: 'Ticket Price (\$)',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.green)),
                ),
                style: const TextStyle(color: Colors.white),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ticketLinkController,
                decoration: const InputDecoration(
                  labelText: 'Ticket Link (optional)',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.green)),
                ),
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('Cancel', style: TextStyle(color: Colors.grey.shade400)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.isEmpty ||
                  dateController.text.isEmpty ||
                  timeController.text.isEmpty ||
                  locationController.text.isEmpty) {
                showToast('Please fill in all required fields');
                return;
              }

              try {
                final updateData = <String, dynamic>{
                  'title': titleController.text,
                  'date': dateController.text,
                  'time': timeController.text,
                  'location': locationController.text,
                  'description': descriptionController.text.isEmpty ? null : descriptionController.text,
                  'ticket_price': ticketPriceController.text.isEmpty
                      ? null
                      : double.tryParse(ticketPriceController.text),
                  'ticket_link': ticketLinkController.text.trim().isEmpty ? null : ticketLinkController.text.trim(),
                };

                await _media.updateEvent(event['id'], updateData);
                if (mounted) {
                  showToast('Event updated successfully');
                  Navigator.of(context).pop();
                  _loadEvents();
                }
              } catch (e) {
                if (mounted) {
                  showToast('Failed to update event: $e');
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.black),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  Widget _buildMerchandiseTab(Color accent) {
    if (_loadingMerchandise) {
      return const Center(child: CircularProgressIndicator());
    }
    
    final merchItems = _merchandise.map((item) => item as Map<String, dynamic>).toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Merchandise & Ticketing',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _artistPlus
                    ? () {
                        _showCreateMerchItemDialog(accent);
                      }
                    : _openArtistPlusUpgrade,
                icon: Icon(_artistPlus ? Icons.add : Icons.lock_outline, size: 18),
                label: Text(_artistPlus ? 'Add Item' : 'Artist+'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: merchItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.store, size: 64, color: Colors.grey.shade600),
                        const SizedBox(height: 16),
                        Text(
                          'Merchandise Store',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Add your first merchandise item\nto start selling to your fans',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${_channelName ?? "Your"} Merch',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey.shade300,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: merchItems.length,
                          itemBuilder: (context, index) {
                            final item = merchItems[index];
                            return Container(
                              width: 280,
                              margin: EdgeInsets.only(
                                right: index < merchItems.length - 1 ? 20 : 0,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade900,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.grey.shade800,
                                  width: 1,
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
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
                                    child: item['image_url'] != null
                                        ? ClipRRect(
                                            borderRadius: const BorderRadius.only(
                                              topLeft: Radius.circular(12),
                                              topRight: Radius.circular(12),
                                            ),
                                            child: Image.network(
                                              item['image_url'],
                                              fit: BoxFit.cover,
                                              errorBuilder: (context, error, stackTrace) {
                                                return _buildPlaceholderImage(accent, item['category']);
                                              },
                                            ),
                                          )
                                        : _buildPlaceholderImage(accent, item['category']),
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
                                              item['title'],
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.white,
                                              ),
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          // Description (always shown above, if present)
                                          if (item['description'] != null) ...[
                                            const SizedBox(height: 6),
                                            Flexible(
                                              child: Text(
                                                item['description'],
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey.shade400,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                          const Spacer(),
                                          Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Row(
                                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                                crossAxisAlignment: CrossAxisAlignment.center,
                                                children: [
                                                  Flexible(
                                                    child: Text(
                                                      '\$${item['price'].toStringAsFixed(2)}',
                                                      style: TextStyle(
                                                        fontSize: 18,
                                                        fontWeight: FontWeight.bold,
                                                        color: accent,
                                                      ),
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                  ),
                                                  Row(
                                                    mainAxisSize: MainAxisSize.min,
                                                    children: [
                                                      IconButton(
                                                        icon: Icon(Icons.edit, size: 16, color: accent),
                                                        onPressed: _artistPlus
                                                            ? () => _showEditMerchItemDialog(accent, item)
                                                            : _openArtistPlusUpgrade,
                                                        tooltip: 'Edit',
                                                        padding: EdgeInsets.zero,
                                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                      ),
                                                      IconButton(
                                                        icon: Icon(Icons.delete, size: 16, color: Colors.red.shade300),
                                                        onPressed: _artistPlus
                                                            ? () => _deleteMerchandise(accent, item['id'])
                                                            : _openArtistPlusUpgrade,
                                                        tooltip: 'Delete',
                                                        padding: EdgeInsets.zero,
                                                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                                      ),
                                                    ],
                                                  ),
                                                ],
                                              ),
                                              if (item['stock'] != null) ...[
                                                const SizedBox(height: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 3,
                                                  ),
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
                                              if (item['purchase_link'] != null &&
                                                  item['purchase_link'].toString().isNotEmpty) ...[
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
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildEventsTab(Color accent) {
    if (_loadingEvents) {
      return const Center(child: CircularProgressIndicator());
    }
    
    final events = _events.map((event) => event as Map<String, dynamic>).toList();

    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Live Show Events',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              ElevatedButton.icon(
                onPressed: _artistPlus
                    ? () {
                        _showCreateEventDialog(accent);
                      }
                    : _openArtistPlusUpgrade,
                icon: Icon(_artistPlus ? Icons.add : Icons.lock_outline, size: 18),
                label: Text(_artistPlus ? 'Create Event' : 'Artist+'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: events.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.event, size: 64, color: Colors.grey.shade600),
                        const SizedBox(height: 16),
                        Text(
                          'No Events Yet',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade400,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Create your first live show event\nto connect with your fans',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade500),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    itemCount: events.length,
                    itemBuilder: (context, index) {
                      final event = events[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade900,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.grey.shade800,
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Expanded(
                                  child: Text(
                                    event['title'] ?? 'Untitled Event',
                                    style: const TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.edit, size: 18, color: accent),
                                      onPressed: _artistPlus
                                          ? () => _showEditEventDialog(accent, event)
                                          : _openArtistPlusUpgrade,
                                      tooltip: 'Edit',
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete, size: 18, color: Colors.red.shade300),
                                      onPressed: _artistPlus
                                          ? () => _deleteEvent(accent, event['id'])
                                          : _openArtistPlusUpgrade,
                                      tooltip: 'Delete',
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (event['description'] != null) ...[
                              const SizedBox(height: 8),
                              Text(
                                event['description'],
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade400,
                                ),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Icon(Icons.calendar_today, size: 16, color: accent),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _formatEventDate(event['date']?.toString() ?? ''),
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.access_time, size: 16, color: accent),
                                const SizedBox(width: 8),
                                Text(
                                  event['time']?.toString() ?? '',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Icon(Icons.location_on, size: 16, color: accent),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    event['location']?.toString() ?? '',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade300,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (event['ticket_price'] != null) ...[
                              const SizedBox(height: 16),
                              Divider(color: Colors.grey.shade800),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Ticket Price',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.grey.shade400,
                                    ),
                                  ),
                                  Text(
                                    '\$${(event['ticket_price'] ?? 0).toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: accent,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _formatEventDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return '${_getWeekday(date.weekday)}, ${_getMonth(date.month)} ${date.day}, ${date.year}';
    } catch (e) {
      return dateStr;
    }
  }

  String _getWeekday(int weekday) {
    const weekdays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
    return weekdays[weekday - 1];
  }

  String _getMonth(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December'
    ];
    return months[month - 1];
  }

  void _showCreateEventDialog(Color accent) {
    final titleController = TextEditingController();
    final dateController = TextEditingController();
    final timeController = TextEditingController();
    final locationController = TextEditingController();
    final descriptionController = TextEditingController();
    final ticketPriceController = TextEditingController();
    final ticketLinkController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text(
          'Create Live Show Event',
          style: TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'Event Title *',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.green),
                  ),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: dateController,
                      decoration: const InputDecoration(
                        labelText: 'Date *',
                        labelStyle: TextStyle(color: Colors.grey),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.green),
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                      readOnly: true,
                      onTap: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          dateController.text = '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextField(
                      controller: timeController,
                      decoration: const InputDecoration(
                        labelText: 'Time *',
                        labelStyle: TextStyle(color: Colors.grey),
                        enabledBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.grey),
                        ),
                        focusedBorder: UnderlineInputBorder(
                          borderSide: BorderSide(color: Colors.green),
                        ),
                      ),
                      style: const TextStyle(color: Colors.white),
                      readOnly: true,
                      onTap: () async {
                        final time = await showTimePicker(
                          context: context,
                          initialTime: TimeOfDay.now(),
                        );
                        if (time != null) {
                          timeController.text = '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: locationController,
                decoration: const InputDecoration(
                  labelText: 'Location *',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.green),
                  ),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: descriptionController,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.green),
                  ),
                ),
                style: const TextStyle(color: Colors.white),
                maxLines: 3,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ticketPriceController,
                decoration: const InputDecoration(
                  labelText: 'Ticket Price (\$)',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.green),
                  ),
                ),
                style: const TextStyle(color: Colors.white),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: ticketLinkController,
                decoration: const InputDecoration(
                  labelText: 'Ticket Link (optional)',
                  labelStyle: TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.green),
                  ),
                ),
                style: const TextStyle(color: Colors.white),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade400),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              if (titleController.text.isEmpty ||
                  dateController.text.isEmpty ||
                  timeController.text.isEmpty ||
                  locationController.text.isEmpty) {
                showToast('Please fill in all required fields');
                return;
              }
              
              try {
                final eventData = <String, dynamic>{
                  'title': titleController.text.trim(),
                  'date': dateController.text.trim(),
                  'time': timeController.text.trim(),
                  'location': locationController.text.trim(),
                  'description': descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim(),
                  'ticket_price': ticketPriceController.text.trim().isEmpty 
                      ? null 
                      : double.tryParse(ticketPriceController.text.trim()),
                  'ticket_link': ticketLinkController.text.trim().isEmpty ? null : ticketLinkController.text.trim(),
                };
                
                await _media.createEvent(eventData);
                
                if (mounted) {
                  showToast('Event created successfully!');
                  Navigator.of(context).pop();
                  _loadEvents();
                }
              } catch (e) {
                if (mounted) {
                  showToast('Failed to create event: $e');
                }
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.black,
            ),
            child: const Text('Create Event'),
          ),
        ],
      ),
    );
  }

  void _showCreateMerchItemDialog(Color accent) async {
    final titleController = TextEditingController();
    final priceController = TextEditingController();
    final descriptionController = TextEditingController();
    final purchaseLinkController = TextEditingController();
    final stockController = TextEditingController();
    final categoryController = TextEditingController();
    PlatformFile? selectedImageFile;
    String? imagePath;
    Uint8List? imageBytes; // For web platform

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: Colors.grey.shade900,
          title: const Text(
            'Add Merchandise Item',
            style: TextStyle(color: Colors.white),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Image Picker
                GestureDetector(
                  onTap: () async {
                    final XFile? file = await openFile(
                      acceptedTypeGroups: [
                        const XTypeGroup(
                          label: 'images',
                          extensions: ['jpg', 'jpeg', 'png', 'gif', 'webp'],
                        ),
                      ],
                    );
                    if (file != null) {
                      selectedImageFile = await createPlatformFile(file);
                      if (kIsWeb) {
                        // For web, read bytes and store them
                        imageBytes = selectedImageFile?.bytes;
                        imagePath = selectedImageFile?.name; // Store filename for reference
                      } else {
                        // For mobile/desktop, use path
                        imagePath = selectedImageFile?.path;
                      }
                      setDialogState(() {});
                    }
                  },
                  child: Container(
                    width: double.infinity,
                    height: 200,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade800,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: imagePath != null ? accent : Colors.grey.shade700,
                        width: 2,
                      ),
                    ),
                    child: imagePath != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: kIsWeb && imageBytes != null
                                ? Image.memory(
                                    imageBytes!,
                                    fit: BoxFit.cover,
                                  )
                                : (!kIsWeb && selectedImageFile?.path != null
                                    ? buildImageFromPath(selectedImageFile!.path!)
                                    : const SizedBox()), // Fallback
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.add_photo_alternate, size: 48, color: Colors.grey.shade500),
                              const SizedBox(height: 8),
                              Text(
                                'Tap to add photo',
                                style: TextStyle(color: Colors.grey.shade400),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  decoration: const InputDecoration(
                    labelText: 'Item Title *',
                    labelStyle: TextStyle(color: Colors.grey),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.green),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: priceController,
                        decoration: const InputDecoration(
                          labelText: 'Price (\$) *',
                          labelStyle: TextStyle(color: Colors.grey),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.green),
                          ),
                        ),
                        style: const TextStyle(color: Colors.white),
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: categoryController.text.isEmpty ? null : categoryController.text,
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          labelStyle: TextStyle(color: Colors.grey),
                          enabledBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.grey),
                          ),
                          focusedBorder: UnderlineInputBorder(
                            borderSide: BorderSide(color: Colors.green),
                          ),
                        ),
                        dropdownColor: Colors.grey.shade900,
                        style: const TextStyle(color: Colors.white),
                        items: const [
                          DropdownMenuItem(value: 'Apparel', child: Text('Apparel')),
                          DropdownMenuItem(value: 'Accessories', child: Text('Accessories')),
                          DropdownMenuItem(value: 'Music', child: Text('Music')),
                          DropdownMenuItem(value: 'Other', child: Text('Other')),
                        ],
                        onChanged: (value) {
                          categoryController.text = value ?? '';
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: purchaseLinkController,
                  decoration: const InputDecoration(
                    labelText: 'Purchase Link (Amazon, etc.) *',
                    labelStyle: TextStyle(color: Colors.grey),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.green),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.url,
                ),
                const SizedBox(height: 8),
                Text(
                  'Link where fans can purchase this item',
                  style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: descriptionController,
                  decoration: const InputDecoration(
                    labelText: 'Description',
                    labelStyle: TextStyle(color: Colors.grey),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.green),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: stockController,
                  decoration: const InputDecoration(
                    labelText: 'Stock Quantity',
                    labelStyle: TextStyle(color: Colors.grey),
                    enabledBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.grey),
                    ),
                    focusedBorder: UnderlineInputBorder(
                      borderSide: BorderSide(color: Colors.green),
                    ),
                  ),
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.number,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(
                'Cancel',
                style: TextStyle(color: Colors.grey.shade400),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                if (titleController.text.isEmpty || priceController.text.isEmpty) {
                  showToast('Please fill in title and price');
                  return;
                }
                
                try {
                  // Upload image first if selected
                  String? imageUrl;
                  if (selectedImageFile != null) {
                    imageUrl = await _uploadImageFile(selectedImageFile!);
                  }
                  
                  // Create merchandise data
                  final merchData = <String, dynamic>{
                    'title': titleController.text.trim(),
                    'price': double.tryParse(priceController.text) ?? 0.0,
                    'description': descriptionController.text.trim().isEmpty ? null : descriptionController.text.trim(),
                    'purchase_link': purchaseLinkController.text.trim().isEmpty ? null : purchaseLinkController.text.trim(),
                    'category': categoryController.text.trim().isEmpty ? null : categoryController.text.trim(),
                    'stock': stockController.text.trim().isEmpty ? null : int.tryParse(stockController.text.trim()),
                    if (imageUrl != null) 'image_url': imageUrl,
                  };
                  
                  await _media.createMerchandise(merchData);
                  
                  if (mounted) {
                    showToast('Merchandise item created successfully!');
                    Navigator.of(context).pop();
                    _loadMerchandise();
                  }
                } catch (e) {
                  if (mounted) {
                    showToast('Failed to create merchandise: $e');
                  }
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: accent,
                foregroundColor: Colors.black,
              ),
              child: const Text('Add Item'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholderImage(Color accent, String? category) {
    IconData iconData;
    switch (category?.toLowerCase()) {
      case 'apparel':
        iconData = Icons.checkroom;
        break;
      case 'accessories':
        iconData = Icons.watch;
        break;
      case 'music':
        iconData = Icons.album;
        break;
      default:
        iconData = Icons.shopping_bag;
    }

    return Container(
      decoration: BoxDecoration(
        color: Colors.grey.shade800,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(12),
          topRight: Radius.circular(12),
        ),
      ),
      child: Center(
        child: Icon(
          iconData,
          size: 64,
          color: accent.withOpacity(0.5),
        ),
      ),
    );
  }

  Widget _buildMessagesTab(Color accent) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Fan Messages & Notifications',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.message, size: 64, color: Colors.grey.shade600),
                  const SizedBox(height: 16),
                  Text(
                    'No messages yet',
                    style: TextStyle(color: Colors.grey.shade400),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Connect with your fans and send notifications',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade500),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 32),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade800),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }

  String? _getCoverPhotoUrl(Map<String, dynamic> song) {
    final coverUrl = song['cover_photo_url'];
    if (coverUrl == null || coverUrl.toString().isEmpty) {
      return null;
    }
    final urlStr = coverUrl.toString();
    
    // If it's already a public URL, use it as-is
    if (urlStr.contains('/media/public/')) {
      return urlStr;
    }
    
    // If it's a presigned R2 URL, use it as-is
    if (urlStr.contains('.r2.cloudflarestorage.com') || urlStr.contains('r2.cloudflarestorage.com')) {
      return urlStr;
    }
    
    // Convert old /media/download/ URLs to /media/public/ URLs for cover photos
    if (urlStr.contains('/media/download/')) {
      // Extract the key from the old URL and construct new public URL
      final uri = Uri.parse(urlStr);
      final pathParts = uri.path.split('/media/download/');
      if (pathParts.length == 2) {
        // Decode the URL-encoded key (e.g., uploads%2F123%2F... -> uploads/123/...)
        final encodedKey = pathParts[1];
        final decodedKey = Uri.decodeComponent(encodedKey);
        final base = Uri.parse(apiBaseUrl);
        // Re-encode for the new URL - use encodeComponent to properly encode slashes
        final publicUrl = base.replace(path: '${base.path}/media/public/${Uri.encodeComponent(decodedKey)}').toString();
        print('Converted cover photo URL: $urlStr -> $publicUrl');
        return publicUrl;
      }
    }
    
    // If it's already a public URL or presigned URL, use it as-is
    print('Using cover photo URL as-is: $urlStr');
    return urlStr;
  }

  Widget _buildUploadItem(Map<String, dynamic> song, Color accent) {
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
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
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
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(Icons.thumb_up_outlined, size: 14, color: Colors.green.shade400),
                const SizedBox(width: 4),
                Text(
                  '${song['like_count'] ?? 0}',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
                const SizedBox(width: 14),
                Icon(Icons.thumb_down_outlined, size: 14, color: Colors.deepOrange.shade300),
                const SizedBox(width: 4),
                Text(
                  '${song['dislike_count'] ?? 0}',
                  style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Edit button
            IconButton(
              icon: const Icon(
                Icons.edit,
                color: Colors.white70,
                size: 20,
              ),
              onPressed: () {
                _showEditSongDialog(song, accent);
              },
              tooltip: 'Edit',
            ),
            // Delete button
            IconButton(
              icon: const Icon(
                Icons.delete,
                color: Colors.red,
                size: 20,
              ),
              onPressed: () {
                _showDeleteSongDialog(song, accent);
              },
              tooltip: 'Delete',
            ),
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
  }

  Future<void> _showEditSongDialog(Map<String, dynamic> song, Color accent) async {
    final songId = song['id']; // Don't cast yet, handle type conversion in update
    final titleController = TextEditingController(text: song['title'] ?? '');
    final albumController = TextEditingController(text: song['album']?.toString() ?? '');
    final coverPhotoController = TextEditingController(text: song['cover_photo_url']?.toString() ?? '');
    final lyricsController = TextEditingController(text: song['lyrics']?.toString() ?? '');

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text(
          'Edit Song',
          style: TextStyle(color: Colors.white),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: titleController,
                decoration: InputDecoration(
                  labelText: 'Title',
                  labelStyle: TextStyle(color: Colors.grey.shade400),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade700),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: accent),
                  ),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: albumController,
                decoration: InputDecoration(
                  labelText: 'Album (optional)',
                  labelStyle: TextStyle(color: Colors.grey.shade400),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade700),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: accent),
                  ),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: coverPhotoController,
                decoration: InputDecoration(
                  labelText: 'Cover Photo URL (optional)',
                  labelStyle: TextStyle(color: Colors.grey.shade400),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade700),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: accent),
                  ),
                ),
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: lyricsController,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: 'Lyrics (optional)',
                  labelStyle: TextStyle(color: Colors.grey.shade400),
                  hintText: 'Enter song lyrics...\n\nFor synchronized lyrics:\n[00:15] First line\n[00:20] Second line',
                  hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                  helperText: 'Format: [mm:ss] followed by lyrics',
                  helperStyle: TextStyle(color: Colors.grey.shade500, fontSize: 11),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Colors.grey.shade700),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: accent),
                  ),
                ),
                style: const TextStyle(color: Colors.white),
                maxLength: 10000,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade400),
            ),
          ),
          TextButton(
            onPressed: () {
              // Validate title is not empty
              if (titleController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: const Text('Title cannot be empty'),
                    backgroundColor: Colors.red,
                  ),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            style: TextButton.styleFrom(foregroundColor: accent),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        // Show loading indicator
        showDialog(
          context: context,
          barrierDismissible: false,
          builder: (context) => Center(
            child: CircularProgressIndicator(color: accent),
          ),
        );
        
        // Ensure songId is an int (handle both int and String cases)
        int finalSongId;
        if (songId is int) {
          finalSongId = songId;
        } else if (songId is String) {
          finalSongId = int.tryParse(songId) ?? 0;
          if (finalSongId == 0) {
            throw Exception('Invalid song ID format');
          }
        } else {
          finalSongId = int.tryParse(songId.toString()) ?? 0;
          if (finalSongId == 0) {
            throw Exception('Invalid song ID format');
          }
        }
        
        await _media.updateSong(
          finalSongId,
          title: titleController.text.trim().isNotEmpty ? titleController.text.trim() : null,
          album: albumController.text.trim().isNotEmpty ? albumController.text.trim() : null,
          coverPhotoUrl: coverPhotoController.text.trim().isNotEmpty ? coverPhotoController.text.trim() : null,
          // Send empty string to clear lyrics, or the lyrics text if provided
          lyrics: lyricsController.text.trim(),
        );
        
        // Close loading dialog
        if (mounted) Navigator.pop(context);
        
        if (mounted) {
          showToast('Song updated successfully');
          _fetchMySongs(); // Refresh the list
        }
      } catch (e) {
        // Close loading dialog if still open
        if (mounted && Navigator.canPop(context)) {
          Navigator.pop(context);
        }
        if (mounted) {
          showToast('Failed to update song: $e');
          print('Error updating song: $e'); // Debug print
        }
      }
    }
    // Dispose controllers
    titleController.dispose();
    albumController.dispose();
    coverPhotoController.dispose();
    lyricsController.dispose();
  }

  Future<void> _showDeleteSongDialog(Map<String, dynamic> song, Color accent) async {
    final songId = song['id'] as int;
    final title = song['title'] ?? 'Untitled';

    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text(
          'Delete Song',
          style: TextStyle(color: Colors.white),
        ),
        content: Text(
          'Are you sure you want to delete "$title"? This action cannot be undone.',
          style: TextStyle(color: Colors.grey.shade300),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(
              'Cancel',
              style: TextStyle(color: Colors.grey.shade400),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (result == true) {
      try {
        await _media.deleteSong(songId);
        showToast('Song deleted successfully');
        _fetchMySongs(); // Refresh the list
      } catch (e) {
        showToast('Failed to delete song: $e');
      }
    }
  }

  Widget _buildAnalyticsCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade400,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _UploadTabContent extends StatefulWidget {
  final Color accent;
  final UploadService upload;
  final AuthService auth;
  final VoidCallback? onUploadSuccess;

  const _UploadTabContent({
    required this.accent,
    required this.upload,
    required this.auth,
    this.onUploadSuccess,
  });

  @override
  State<_UploadTabContent> createState() => _UploadTabContentState();
}

class _UploadTabContentState extends State<_UploadTabContent> {
  final _titleController = TextEditingController();
  final _albumController = TextEditingController();
  final _lyricsController = TextEditingController();
  bool _uploading = false;
  String _selectedType = 'music';
  XFile? _coverPhotoFile;
  Uint8List? _coverPhotoBytes;
  String? _coverPhotoUrl;
  
  // Validation state
  String? _titleError;
  String? _albumError;
  String? _lyricsError;

  @override
  void dispose() {
    _titleController.dispose();
    _albumController.dispose();
    _lyricsController.dispose();
    super.dispose();
  }

  // Validation functions
  String? _validateTitle(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Title is required';
    }
    final trimmed = value.trim();
    if (trimmed.length < 1) {
      return 'Title must be at least 1 character';
    }
    if (trimmed.length > 200) {
      return 'Title must be at most 200 characters';
    }
    return null;
  }

  String? _validateAlbum(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Album is optional
    }
    final trimmed = value.trim();
    if (trimmed.length > 200) {
      return 'Album name must be at most 200 characters';
    }
    return null;
  }

  String? _validateLyrics(String? value) {
    if (value == null || value.trim().isEmpty) {
      return null; // Lyrics is optional
    }
    final trimmed = value.trim();
    if (trimmed.length > 10000) {
      return 'Lyrics must be at most 10000 characters';
    }
    return null;
  }

  bool _validateForm() {
    final titleError = _validateTitle(_titleController.text);
    final albumError = _validateAlbum(_albumController.text);
    final lyricsError = _validateLyrics(_lyricsController.text);
    
    setState(() {
      _titleError = titleError;
      _albumError = albumError;
      _lyricsError = lyricsError;
    });
    
    return titleError == null && albumError == null && lyricsError == null;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          const Text(
            'Upload Content',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 24),
          
          // Content Type Selector
          Row(
            children: [
              Expanded(
                child: ChoiceChip(
                  label: const Text('Music'),
                  selected: _selectedType == 'music',
                  onSelected: (selected) {
                    setState(() => _selectedType = 'music');
                  },
                  selectedColor: widget.accent,
                  labelStyle: TextStyle(
                    color: _selectedType == 'music' ? Colors.black : Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ChoiceChip(
                  label: const Text('Video'),
                  selected: _selectedType == 'video',
                  onSelected: (selected) {
                    setState(() => _selectedType = 'video');
                  },
                  selectedColor: widget.accent,
                  labelStyle: TextStyle(
                    color: _selectedType == 'video' ? Colors.black : Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          TextField(
            controller: _titleController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Title *',
              labelStyle: const TextStyle(color: Colors.grey),
              hintText: 'Enter song title (1-200 characters)',
              hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              errorText: _titleError,
              errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _titleError != null ? Colors.red : Colors.grey.shade700,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _titleError != null ? Colors.red : Colors.grey.shade700,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _titleError != null ? Colors.red : widget.accent,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
            ),
            onChanged: (value) {
              // Clear error when user starts typing
              if (_titleError != null) {
                setState(() {
                  _titleError = _validateTitle(value);
                });
              }
            },
            maxLength: 200,
            buildCounter: (context, {required currentLength, required isFocused, maxLength}) {
              return Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  '$currentLength/$maxLength',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          
          // Cover Photo Upload
          if (_selectedType == 'music')
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Cover Photo (optional)',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                GestureDetector(
                  onTap: _pickCoverPhoto,
                  child: Container(
                    height: 150,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _coverPhotoBytes != null ? widget.accent : Colors.grey.shade700,
                        width: 2,
                      ),
                    ),
                    child: _coverPhotoBytes != null && _coverPhotoBytes!.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.memory(
                              _coverPhotoBytes!,
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return const Icon(Icons.error, color: Colors.red);
                              },
                            ),
                          )
                        : Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.image, size: 48, color: Colors.grey.shade600),
                              const SizedBox(height: 8),
                              Text(
                                'Tap to upload cover photo',
                                style: TextStyle(color: Colors.grey.shade400),
                              ),
                            ],
                          ),
                  ),
                ),
                if (_coverPhotoBytes != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: TextButton.icon(
                      onPressed: () {
                        setState(() {
                          _coverPhotoFile = null;
                          _coverPhotoBytes = null;
                          _coverPhotoUrl = null;
                        });
                      },
                      icon: const Icon(Icons.delete, size: 18),
                      label: const Text('Remove'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
              ],
            ),
          
          TextField(
            controller: _albumController,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'Album (optional)',
              labelStyle: const TextStyle(color: Colors.grey),
              hintText: 'Enter album name (max 200 characters)',
              hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              errorText: _albumError,
              errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _albumError != null ? Colors.red : Colors.grey.shade700,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _albumError != null ? Colors.red : Colors.grey.shade700,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _albumError != null ? Colors.red : widget.accent,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
            ),
            onChanged: (value) {
              // Clear error when user starts typing
              if (_albumError != null) {
                setState(() {
                  _albumError = _validateAlbum(value);
                });
              }
            },
            maxLength: 200,
            buildCounter: (context, {required currentLength, required isFocused, maxLength}) {
              return Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  '$currentLength/$maxLength',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          
          // Lyrics Text Field
          TextField(
            controller: _lyricsController,
            style: const TextStyle(color: Colors.white),
            maxLines: 8,
            decoration: InputDecoration(
              labelText: 'Lyrics (optional)',
              labelStyle: const TextStyle(color: Colors.grey),
              hintText: 'Enter song lyrics...\n\nFor synchronized lyrics, add timestamps:\n[00:15] First line\n[00:20] Second line',
              hintStyle: TextStyle(color: Colors.grey.shade600, fontSize: 12),
              helperText: 'Format: [mm:ss] followed by lyrics. Lines without timestamps use the previous timestamp.',
              helperStyle: TextStyle(color: Colors.grey.shade500, fontSize: 11),
              errorText: _lyricsError,
              errorStyle: const TextStyle(color: Colors.red, fontSize: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _lyricsError != null ? Colors.red : Colors.grey.shade700,
                ),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _lyricsError != null ? Colors.red : Colors.grey.shade700,
                ),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(
                  color: _lyricsError != null ? Colors.red : widget.accent,
                  width: 2,
                ),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
            ),
            onChanged: (value) {
              // Clear error when user starts typing
              if (_lyricsError != null) {
                setState(() {
                  _lyricsError = _validateLyrics(value);
                });
              }
            },
            maxLength: 10000,
            buildCounter: (context, {required currentLength, required isFocused, maxLength}) {
              return Padding(
                padding: const EdgeInsets.only(top: 4.0),
                child: Text(
                  '$currentLength/$maxLength',
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 24),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _uploading ? null : () async {
                // Validate form before proceeding
                if (!_validateForm()) {
                  showToast('Please fix the errors before uploading');
                  return;
                }
                setState(() => _uploading = true);
                try {
                  // Upload cover photo first if selected
                  String? coverPhotoUrl;
                  if (_coverPhotoFile != null && _coverPhotoBytes != null) {
                    coverPhotoUrl = await _uploadCoverPhoto();
                  }
                  
                  if (_selectedType == 'music') {
                    await widget.upload.pickAndUpload(
                      title: _titleController.text.trim(),
                      album: _albumController.text.trim().isEmpty 
                          ? null 
                          : _albumController.text.trim(),
                      coverPhotoUrl: coverPhotoUrl,
                      lyrics: _lyricsController.text.trim().isEmpty 
                          ? null 
                          : _lyricsController.text.trim(),
                    );
                    showToast('Song uploaded successfully!');
                  } else {
                    await _uploadVideo(
                      title: _titleController.text.trim(),
                      album: _albumController.text.trim().isEmpty 
                          ? null 
                          : _albumController.text.trim(),
                    );
                    showToast('Video uploaded successfully!');
                  }
                  _titleController.clear();
                  _albumController.clear();
                  setState(() {
                    _coverPhotoFile = null;
                    _coverPhotoBytes = null;
                    _coverPhotoUrl = null;
                  });
                  // Refresh the uploads list in dashboard
                  if (widget.onUploadSuccess != null) {
                    widget.onUploadSuccess!();
                  }
                } catch (e) {
                  String errorMessage = 'Upload failed';
                  final errorString = e.toString().toLowerCase();
                  
                  if (errorString.contains('no file selected') || errorString.contains('no cover photo selected')) {
                    errorMessage = 'No file selected. Please choose a file to upload.';
                  } else if (errorString.contains('cover photo upload failed')) {
                    errorMessage = 'Cover photo upload failed. Please try again or continue without a cover photo.';
                  } else if (errorString.contains('cannot connect to server') || 
                             errorString.contains('failed to fetch') ||
                             errorString.contains('clientexception')) {
                    errorMessage = 'Cannot connect to server. Please check your internet connection and try again.';
                  } else if (errorString.contains('upload failed')) {
                    if (errorString.contains('statuscode')) {
                      final match = RegExp(r'(\d{3})').firstMatch(errorString);
                      if (match != null) {
                        final statusCode = match.group(1);
                        if (statusCode == '413') {
                          errorMessage = 'File too large. Please choose a smaller file.';
                        } else if (statusCode == '400') {
                          errorMessage = 'Invalid file format. Please check your file and try again.';
                        } else if (statusCode == '401' || statusCode == '403') {
                          errorMessage = 'Authentication failed. Please log in again.';
                        } else {
                          errorMessage = 'Upload failed with error code $statusCode. Please try again.';
                        }
                      } else {
                        errorMessage = 'Upload failed. Please try again.';
                      }
                    } else {
                      errorMessage = 'Upload failed. Please check your connection and try again.';
                    }
                  } else if (errorString.contains('metadata failed')) {
                    errorMessage = 'File uploaded but failed to save metadata. Please try uploading again.';
                  } else if (errorString.contains('timeout')) {
                    errorMessage = 'Upload timed out. Please check your connection and try again.';
                  } else {
                    // For other errors, show a generic message but log the actual error
                    errorMessage = 'Upload failed. Please try again.';
                    print('Upload error: $e'); // Debug print
                  }
                  
                  showToast(errorMessage);
                } finally {
                  if (mounted) {
                    setState(() => _uploading = false);
                  }
                }
              },
              icon: _uploading 
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.upload),
              label: Text(_uploading ? 'Uploading...' : 'Select & Upload'),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.accent,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickCoverPhoto() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(label: 'images', extensions: ['jpg', 'jpeg', 'png', 'webp'])
        ],
      );
      if (file != null) {
        try {
          final bytes = await file.readAsBytes();
          if (bytes.isNotEmpty && bytes.length > 10 && mounted) {
            // Validate it's a valid image by checking magic bytes
            final isValidImage = bytes.length >= 4 && (
              (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) || // JPEG
              (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) || // PNG
              (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46) // WEBP/RIFF
            );
            if (isValidImage && mounted) {
              setState(() {
                _coverPhotoFile = file;
                _coverPhotoBytes = bytes;
              });
            } else if (mounted) {
              showToast('Invalid image file');
            }
          }
        } catch (e) {
          if (mounted) {
            showToast('Failed to load image: $e');
          }
        }
      }
    } catch (e) {
      showToast('Failed to pick cover photo: $e');
    }
  }

  Future<String> _uploadCoverPhoto() async {
    if (_coverPhotoFile == null || _coverPhotoBytes == null) {
      throw Exception('No cover photo selected');
    }

    try {
      final filename = _coverPhotoFile!.name;
      final contentType = _lookupImageContentType(filename);

      // Use proxy upload for web to avoid CORS issues
      final base = Uri.parse(apiBaseUrl);
      final uploadUri = base.replace(path: '${base.path}/media/upload-proxy');
      
      final request = http.MultipartRequest('POST', uploadUri);
      request.headers.addAll(widget.auth.authHeader);
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          _coverPhotoBytes!,
          filename: filename,
        ),
      );
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode != 200) {
        throw Exception('Cover photo upload failed: ${response.statusCode}');
      }
      
      final data = jsonDecode(response.body);
      final key = data['key'] as String;
      
      // Get the download URL
      // Use public endpoint for cover photos so they can be loaded without auth
      final downloadUri = base.replace(path: '${base.path}/media/public/${Uri.encodeComponent(key)}');
      return downloadUri.toString();
    } catch (e) {
      throw Exception('Failed to upload cover photo: $e');
    }
  }

  String _lookupImageContentType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _uploadVideo({required String title, String? album}) async {
    final file = await openFile(
      acceptedTypeGroups: [
        const XTypeGroup(label: 'video', extensions: ['mp4', 'mov', 'avi', 'mkv'])
      ],
    );
    if (file == null) throw Exception('No file selected');

    final filename = file.name;
    final bytes = await file.readAsBytes();
    final contentType = _lookupVideoContentType(filename);

    final presign = await widget.upload.requestPresign(filename, contentType);
    final uploadUrl = presign['upload_url'];
    final key = presign['key'];

    final putResp = await http.put(
      Uri.parse(uploadUrl),
      headers: {'Content-Type': contentType},
      body: bytes,
    );

    if (putResp.statusCode != 200 && putResp.statusCode != 201) {
      throw Exception('Upload failed: ${putResp.statusCode}');
    }

    // Register metadata (similar to music)
    final base = Uri.parse(apiBaseUrl);
    final metaUri = base.replace(path: '${base.path}/artist/metadata');
    final metaResp = await http.post(
      metaUri,
      headers: <String, String>{...widget.auth.authHeader, 'Content-Type': 'application/json'},
      body: jsonEncode({
        'title': title,
        if (album != null) 'album': album,
        'r2_key': key,
        'content_type': contentType,
      }),
    );

    if (metaResp.statusCode != 200) {
      throw Exception('Metadata failed: ${metaResp.statusCode}');
    }
  }

  String _lookupVideoContentType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.avi')) return 'video/x-msvideo';
    if (lower.endsWith('.mkv')) return 'video/x-matroska';
    return 'video/mp4';
  }
}
