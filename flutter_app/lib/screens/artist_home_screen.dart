// lib/screens/artist_home_screen.dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../services/media_service.dart';
import '../services/upload_service.dart';
import '../utils/toast_util.dart';
import '../widgets/artist_channel_page.dart';
import '../widgets/media_player_widget.dart';
import '../providers/player_state_provider.dart';
import 'welcome_screen.dart';
import 'profile_screen.dart';
import 'dart:io';
import 'package:file_selector/file_selector.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:just_audio/just_audio.dart';
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
    'tips': 0,
    'donations': 0,
    'subs': 0,
    'total_earnings': 0,
  };

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
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
        });
        // Load songs after channel name is available
        if (_channelName != null) {
          _fetchMySongs();
        }
      }
    } catch (e) {
      if (mounted) {
        showToast('Failed to load user data: $e');
      }
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
  }

  void _playNext() {
    if (_currentPlaylist.isEmpty || _currentPlaylistIndex < 0) return;
    
    int nextIndex = _currentPlaylistIndex + 1;
    if (nextIndex >= _currentPlaylist.length) {
      // If repeat all is enabled, loop back to start
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
      // If repeat all is enabled, loop to end
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

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF78E08F);

    return Scaffold(
      backgroundColor: const Color(0xFF111414),
      appBar: AppBar(
        title: Text(_channelName ?? 'NOIZE Artist'),
        actions: [
          if (_channelName != null)
            IconButton(
              icon: const Icon(Icons.account_circle),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => const ProfileScreen(),
                  ),
                );
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
                  Tab(text: 'Upload'),
                  Tab(text: 'Albums'),
                  Tab(text: 'Analytics'),
                  Tab(text: 'Merch & Store'),
                  Tab(text: 'Messages'),
                ],
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildDashboardTab(accent),
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
                  ),
                );
              },
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
                  icon: Icons.upload,
                  title: 'Upload Music',
                  subtitle: 'Add new songs to your channel',
                  color: accent,
                  onTap: () => _tabController.animateTo(1),
                ),
                const SizedBox(height: 8),
                _buildActionTile(
                  icon: Icons.album,
                  title: 'Create Album',
                  subtitle: 'Organize your music into albums',
                  color: Colors.purple,
                  onTap: () => _tabController.animateTo(2),
                ),
                const SizedBox(height: 8),
                _buildActionTile(
                  icon: Icons.store,
                  title: 'Manage Store',
                  subtitle: 'Set up merch and tickets',
                  color: Colors.orange,
                  onTap: () => _tabController.animateTo(4),
                ),
              ],
            ),
          ),

          // My Uploads Section
          Padding(
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
                        fontSize: 18,
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
                const SizedBox(height: 12),
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
                      ],
                    ),
                  )
                else
                  ..._mySongs.map((song) => _buildUploadItem(song, accent)).toList(),
              ],
            ),
          ),
        ],
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
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Merchandise & Ticketing',
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
                    'Coming soon: Set up your merch store\nand sell tickets to your events',
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
  bool _uploading = false;
  String _selectedType = 'music';
  XFile? _coverPhotoFile;
  Uint8List? _coverPhotoBytes;
  String? _coverPhotoUrl;

  @override
  void dispose() {
    _titleController.dispose();
    _albumController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
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
              labelText: 'Title',
              labelStyle: const TextStyle(color: Colors.grey),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade700),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade700),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: widget.accent, width: 2),
              ),
            ),
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
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade700),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: Colors.grey.shade700),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide(color: widget.accent, width: 2),
              ),
            ),
          ),
          const SizedBox(height: 24),
          
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _uploading ? null : () async {
                if (_titleController.text.trim().isEmpty) {
                  showToast('Please enter a title');
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
                    );
                  } else {
                    await _uploadVideo(
                      title: _titleController.text.trim(),
                      album: _albumController.text.trim().isEmpty 
                          ? null 
                          : _albumController.text.trim(),
                    );
                  }
                  showToast('Upload successful!');
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
                  showToast('Upload failed: $e');
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
