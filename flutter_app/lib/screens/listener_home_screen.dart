import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../widgets/listener_search_tab.dart';
import '../widgets/media_player_widget.dart';
import '../services/media_service.dart';
import '../services/auth_service.dart';
import '../utils/toast_util.dart';
import '../providers/language_provider.dart';
import '../providers/player_state_provider.dart';
import '../l10n/app_localizations.dart';
import 'upgrade_screen.dart';
import 'listener_profile_screen.dart';
import 'welcome_screen.dart';

class ListenerHomeScreen extends StatefulWidget {
  const ListenerHomeScreen({super.key});

  @override
  State<ListenerHomeScreen> createState() => _ListenerHomeScreenState();
}

class _ListenerHomeScreenState extends State<ListenerHomeScreen> with SingleTickerProviderStateMixin {
  final MediaService _media = MediaService();
  final AuthService _auth = AuthService();
  late final TabController _tabController;
  List<dynamic> _topSongs = [];
  List<dynamic> _likedSongs = [];
  List<dynamic> _playlists = [];
  bool _loading = false;
  bool _isUpgraded = false;
  String _userRole = 'guest';
  Map<String, dynamic>? _currentlyPlayingSong;
  List<Map<String, dynamic>> _currentPlaylist = [];
  int _currentPlaylistIndex = -1;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(_onTabChanged);
    _loadData();
    _checkUpgradeStatus();
  }

  Future<void> _checkUpgradeStatus() async {
    final user = await _auth.getMe();
    setState(() {
      _isUpgraded = user?['is_upgraded'] ?? false;
      _userRole = user?['user_role'] ?? 'guest';
    });
  }

  void _onTabChanged() {
    // Refresh data when switching to Liked tab
    if (_tabController.index == 2 && !_tabController.indexIsChanging) {
      _loadData();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _loading = true);
    try {
      // Load top charts
      _topSongs = await _media.getArtistSongs('popular');
    } catch (e) {
      _topSongs = [];
    }
    try {
      // Load playlists
      _playlists = await _media.getPlaylists();
    } catch (e) {
      _playlists = [];
    }
    try {
      // Load liked songs
      _likedSongs = await _media.getLikedSongsDetails();
    } catch (e) {
      _likedSongs = [];
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF78E08F);

    return Scaffold(
      backgroundColor: const Color(0xFF111414),
      appBar: AppBar(
        title: Consumer<LanguageProvider>(
          builder: (context, languageProvider, child) {
            return Text(AppLocalizations.of(context)?.appTitle ?? 'NOIZE.music');
          },
        ),
        actions: [
          if (!_isUpgraded)
            Consumer<LanguageProvider>(
              builder: (context, languageProvider, child) {
                return TextButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const UpgradeScreen(planType: 'listen')),
                    ).then((_) => _checkUpgradeStatus());
                  },
                  icon: const Icon(Icons.workspace_premium, size: 18),
                  label: Text(
                    AppLocalizations.of(context)?.upgrade ?? 'Upgrade',
                    style: const TextStyle(color: Color(0xFF78E08F)),
                  ),
                );
              },
            ),
          IconButton(
            icon: const Icon(Icons.account_circle),
            tooltip: AppLocalizations.of(context)?.profile ?? 'Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ListenerProfileScreen()),
              ).then((_) => _checkUpgradeStatus());
            },
          ),
          ValueListenableBuilder<String?>(
            valueListenable: _auth.authToken,
            builder: (context, token, _) {
              if (token != null) {
                return IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () async {
                    await _auth.logout();
                    if (!context.mounted) return;
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                      (Route<dynamic> route) => false,
                    );
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
              Consumer<LanguageProvider>(
                builder: (context, languageProvider, child) {
                  return TabBar(
                    controller: _tabController,
                    tabs: [
                      Tab(text: AppLocalizations.of(context)?.home ?? 'Home'),
                      Tab(text: AppLocalizations.of(context)?.search ?? 'Search'),
                      Tab(text: AppLocalizations.of(context)?.liked ?? 'Liked'),
                      Tab(text: AppLocalizations.of(context)?.playlists ?? 'Playlists'),
                    ],
                  );
                },
              ),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildHomeTab(accent),
                    const ListenerSearchTab(),
                    _buildLikedTab(accent),
                    _buildPlaylistsTab(accent),
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
                  // Full player is shown via ExpandedPlayerScreen
                  return const SizedBox.shrink();
                }
                return Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: MediaPlayerWidget(
                    r2Key: _currentlyPlayingSong!['r2_key'],
                    title: _currentlyPlayingSong!['title'],
                    artist: _currentlyPlayingSong!['artist']?.toString() ?? _currentlyPlayingSong!['artist']?['channel_name'],
                    coverPhotoUrl: _currentlyPlayingSong!['cover_photo_url'],
                    contentType: _currentlyPlayingSong!['content_type'],
                    isVideo: _currentlyPlayingSong!['content_type']?.toString().startsWith('video/') ?? false,
                    playlist: _currentPlaylist,
                    currentIndex: _currentPlaylistIndex,
                    isMini: true, // Show mini player
                    moderationStatus: _currentlyPlayingSong!['moderation_status']?.toString(),
                    onClose: () {
                      playerState.hide();
                      setState(() {
                        _currentlyPlayingSong = null;
                        _currentPlaylist = [];
                        _currentPlaylistIndex = -1;
                      });
                    },
                  ),
                );
              },
            ),
        ],
      ),
    );
  }

  bool _isVideo(String? contentType) {
    if (contentType == null) return false;
    return contentType.startsWith('video/');
  }

  Widget _buildHomeTab(Color accent) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          // Upgrade Banner (show based on current role)
          if (_userRole == 'guest')
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
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
                  Icon(Icons.workspace_premium, color: accent, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    AppLocalizations.of(context)?.listenerOnlySubscriptionPitchHeader ??
                        'Love listening? Listen more with NOIZE Listen.',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)?.listenerOnlySubscriptionPitchBody ??
                        'Ad-free. Unlimited playlists. Offline downloads.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const UpgradeScreen(planType: 'listen')),
                      ).then((_) => _checkUpgradeStatus());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    ),
                    child: Text(
                      AppLocalizations.of(context)?.listenerOnlySubscriptionPitchCta ?? 'GO PREMIUM',
                    ),
                  ),
                ],
              ),
            )
          else if (_userRole == 'listen')
            Container(
              width: double.infinity,
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange.withOpacity(0.2), Colors.orange.withOpacity(0.1)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Icon(Icons.monetization_on, color: Colors.orange.shade300, size: 40),
                  const SizedBox(height: 12),
                  Text(
                    AppLocalizations.of(context)?.freeUserUpgradeReminderBannerHeader ??
                        'Want to earn while you listen?',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    AppLocalizations.of(context)?.freeUserUpgradeReminderBannerBody ??
                        'Upgrade to NOIZE REP and start earning by supporting music you love.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.grey,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const UpgradeScreen(planType: 'rep')),
                      ).then((_) => _checkUpgradeStatus());
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange.shade300,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    ),
                    child: Text(
                      AppLocalizations.of(context)?.freeUserUpgradeReminderBannerCta ?? 'UPGRADE NOW',
                    ),
                  ),
                ],
              ),
            ),
          // Top Charts Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)?.top50Charts ?? 'Top 50 Charts',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                if (_loading)
                  const Center(child: Padding(
                    padding: EdgeInsets.all(20.0),
                    child: CircularProgressIndicator(),
                  ))
                else if (_topSongs.isEmpty)
                  Container(
                    padding: const EdgeInsets.all(40),
                    child: Center(
                      child: Column(
                        children: [
                          Icon(Icons.music_note, size: 64, color: Colors.grey.shade600),
                          const SizedBox(height: 16),
                          Text(
                            AppLocalizations.of(context)?.noSongsAvailable ?? 'No songs available',
                            style: TextStyle(color: Colors.grey.shade400),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _topSongs.length > 50 ? 50 : _topSongs.length,
                    itemBuilder: (context, index) {
                      final song = _topSongs[index];
                      return ListTile(
                        leading: song['cover_photo_url'] != null && song['cover_photo_url'].toString().isNotEmpty
                            ? Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  color: Colors.grey.shade800,
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    song['cover_photo_url'],
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Center(
                                        child: Text(
                                          '${index + 1}',
                                          style: TextStyle(
                                            color: Colors.grey.shade500,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              )
                            : Container(
                                width: 40,
                                alignment: Alignment.center,
                                child: Text(
                                  '${index + 1}',
                                  style: TextStyle(
                                    color: Colors.grey.shade500,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ),
                        title: Text(
                          song['title'] ?? (AppLocalizations.of(context)?.unknown ?? 'Unknown'),
                          style: const TextStyle(color: Colors.white),
                        ),
                        subtitle: Text(
                          song['album'] ?? '',
                          style: const TextStyle(color: Colors.grey),
                        ),
                        trailing: Icon(Icons.play_arrow, color: accent),
                        onTap: () {
                          // Check if song is suspended
                          // Debug: print moderation status
                          if (kDebugMode) {
                            print('🔍 Song moderation_status: ${song['moderation_status']}');
                            print('🔍 Song keys: ${song.keys.toList()}');
                            print('🔍 Full song data: $song');
                          }
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
                                    child: Text('OK', style: TextStyle(color: accent)),
                                  ),
                                ],
                              ),
                            );
                            return;
                          }
                          final playList = _topSongs.map((s) => s as Map<String, dynamic>).toList();
                          final index = playList.indexWhere((s) => s['r2_key'] == song['r2_key']);
                          final playerState = Provider.of<PlayerStateProvider>(context, listen: false);
                          playerState.showMini();
                          // Only set playing song if not suspended
                          if (moderationStatus != 'flagged') {
                            setState(() {
                              _currentlyPlayingSong = song;
                              _currentPlaylist = playList;
                              _currentPlaylistIndex = index >= 0 ? index : 0;
                            });
                          }
                        },
                      );
                    },
                  ),
              ],
            ),
          ),
        ],
      ),
    );
      },
    );
  }

  Widget _buildLikedTab(Color accent) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return RefreshIndicator(
          onRefresh: _loadData,
          child: _likedSongs.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.favorite_border, size: 64, color: Colors.grey.shade600),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context)?.noLikedSongsYet ?? 'No liked songs yet',
                        style: TextStyle(color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                )
          : ListView.builder(
            itemCount: _likedSongs.length,
            itemBuilder: (context, index) {
              final song = _likedSongs[index];
              return Card(
                color: Colors.grey.shade900,
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  leading: song['cover_photo_url'] != null && song['cover_photo_url'].toString().isNotEmpty
                      ? Container(
                          width: 56,
                          height: 56,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            color: Colors.grey.shade800,
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              song['cover_photo_url'],
                              fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) {
                                return CircleAvatar(
                                  backgroundColor: accent.withOpacity(0.2),
                                  child: Icon(Icons.music_note, color: accent),
                                );
                              },
                            ),
                          ),
                        )
                      : CircleAvatar(
                          backgroundColor: accent.withOpacity(0.2),
                          child: Icon(Icons.music_note, color: accent),
                        ),
                  title: Text(
                    song['title'] ?? (AppLocalizations.of(context)?.unknown ?? 'Unknown'),
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (song['artist'] != null)
                        Text(
                          '${AppLocalizations.of(context)?.by ?? 'By'} ${song['artist']}',
                          style: TextStyle(color: accent, fontSize: 12),
                        ),
                      Text(
                        song['album'] ?? '',
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                      ),
                    ],
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.favorite, color: Colors.red),
                        onPressed: () async {
                          try {
                            await _media.likeSong(song['id'] as int);
                            setState(() {
                              _likedSongs.removeAt(index);
                            });
                            showToast(AppLocalizations.of(context)?.removedFromLiked ?? 'Removed from liked');
                          } catch (e) {
                            showToast('${AppLocalizations.of(context)?.saveFailed ?? 'Failed'}: $e');
                          }
                        },
                      ),
                    ],
                  ),
                  onTap: () {
                    // Check if song is suspended
                    // Debug: print moderation status
                    if (kDebugMode) {
                      print('🔍 Liked song moderation_status: ${song['moderation_status']}');
                      print('🔍 Liked song keys: ${song.keys.toList()}');
                    }
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
                              child: Text('OK', style: TextStyle(color: accent)),
                            ),
                          ],
                        ),
                      );
                      return;
                    }
                    final playList = _likedSongs.map((s) => s as Map<String, dynamic>).toList();
                    final index = playList.indexWhere((s) => s['r2_key'] == song['r2_key']);
                    final playerState = Provider.of<PlayerStateProvider>(context, listen: false);
                    playerState.showMini();
                    // Only set playing song if not suspended
                    if (moderationStatus != 'flagged') {
                      setState(() {
                        _currentlyPlayingSong = song;
                        _currentPlaylist = playList;
                        _currentPlaylistIndex = index >= 0 ? index : 0;
                      });
                    }
                  },
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPlaylistsTab(Color accent) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Column(
          children: [
            if (_playlists.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.playlist_add, size: 64, color: Colors.grey.shade600),
                      const SizedBox(height: 16),
                      Text(
                        AppLocalizations.of(context)?.noPlaylistsYet ?? 'No playlists yet',
                        style: TextStyle(color: Colors.grey.shade400),
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () => _createPlaylist(context, accent),
                        icon: const Icon(Icons.add),
                        label: Text(AppLocalizations.of(context)?.createPlaylist ?? 'Create Playlist'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
              )
        else
          Expanded(
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '${_playlists.length} ${_playlists.length == 1 ? (AppLocalizations.of(context)?.playlist ?? 'Playlist') : (AppLocalizations.of(context)?.playlists ?? 'Playlists')}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _createPlaylist(context, accent),
                        icon: const Icon(Icons.add, size: 18),
                        label: Text(AppLocalizations.of(context)?.newLabel ?? 'New'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: accent,
                          foregroundColor: Colors.black,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: _playlists.length,
                    itemBuilder: (context, index) {
                      final playlist = _playlists[index];
                      return Card(
                        color: Colors.grey.shade900,
                        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: ListTile(
                          leading: CircleAvatar(
                            backgroundColor: accent.withOpacity(0.2),
                            child: Icon(Icons.playlist_play, color: accent),
                          ),
                          title: Text(
                            playlist['name'] ?? (AppLocalizations.of(context)?.playlist ?? 'Playlist'),
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                          subtitle: Text(
                            '${playlist['song_count'] ?? 0} ${AppLocalizations.of(context)?.songs ?? 'songs'}',
                            style: TextStyle(color: Colors.grey.shade400),
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                icon: const Icon(Icons.play_arrow, color: Color(0xFF78E08F)),
                                onPressed: () {
                                  _playPlaylist(playlist);
                                },
                              ),
                              PopupMenuButton<String>(
                                icon: const Icon(Icons.more_vert, color: Colors.grey),
                                color: Colors.grey.shade900,
                                onSelected: (value) {
                                  if (value == 'edit') {
                                    _editPlaylist(context, playlist, accent);
                                  } else if (value == 'delete') {
                                    _deletePlaylist(context, playlist);
                                  }
                                },
                                itemBuilder: (context) => [
                                  PopupMenuItem(
                                    value: 'edit',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.edit, color: Colors.white, size: 20),
                                        const SizedBox(width: 8),
                                        Text(AppLocalizations.of(context)?.edit ?? 'Edit'),
                                      ],
                                    ),
                                  ),
                                  PopupMenuItem(
                                    value: 'delete',
                                    child: Row(
                                      children: [
                                        const Icon(Icons.delete, color: Colors.red, size: 20),
                                        const SizedBox(width: 8),
                                        Text(AppLocalizations.of(context)?.delete ?? 'Delete'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          onTap: () {
                            _playPlaylist(playlist);
                          },
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          ],
        );
      },
    );
  }

  Future<void> _playPlaylist(Map<String, dynamic> playlist) async {
    try {
      final playlistData = await _media.getPlaylist(playlist['id']);
      if (playlistData['songs'] != null && (playlistData['songs'] as List).isNotEmpty) {
        final songs = (playlistData['songs'] as List).map((s) => s as Map<String, dynamic>).toList();
        final playerState = Provider.of<PlayerStateProvider>(context, listen: false);
        playerState.showMini();
        setState(() {
          _currentlyPlayingSong = songs[0];
          _currentPlaylist = songs;
          _currentPlaylistIndex = 0;
        });
      } else {
        showToast('Playlist is empty');
      }
    } catch (e) {
      showToast('Failed to load playlist: $e');
    }
  }

  Future<void> _editPlaylist(BuildContext context, Map<String, dynamic> playlist, Color accent) async {
    final nameController = TextEditingController(text: playlist['name']);
    bool isPublic = playlist['is_public'] ?? false;
    
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.grey.shade900,
          title: Text(AppLocalizations.of(context)?.editPlaylist ?? 'Edit Playlist', style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)?.playlistName ?? 'Playlist Name',
                  labelStyle: const TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent)),
                ),
              ),
              if (_isUpgraded) ...[
                const SizedBox(height: 16),
                CheckboxListTile(
                  value: isPublic,
                  onChanged: (val) => setState(() => isPublic = val ?? false),
                  title: Text(AppLocalizations.of(context)?.makePublic ?? 'Make Public', style: const TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: Text(AppLocalizations.of(context)?.shareWithOtherUsers ?? 'Share with other users', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  activeColor: accent,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppLocalizations.of(context)?.cancel ?? 'Cancel', style: const TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.black),
              child: Text(AppLocalizations.of(context)?.save ?? 'Save'),
            ),
          ],
        ),
      ),
    );
    
    if (ok != true || nameController.text.trim().isEmpty) return;

    try {
      await _media.updatePlaylist(
        playlist['id'],
        name: nameController.text.trim(),
        isPublic: isPublic,
      );
      showToast(AppLocalizations.of(context)?.playlistUpdated ?? 'Playlist updated!');
      _loadData(); // Reload playlists
    } catch (e) {
      showToast('${AppLocalizations.of(context)?.saveFailed ?? 'Failed'}: $e');
    }
  }

  Future<void> _deletePlaylist(BuildContext context, Map<String, dynamic> playlist) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: Text(AppLocalizations.of(context)?.deletePlaylist ?? 'Delete Playlist', style: const TextStyle(color: Colors.white)),
        content: Text(
          '${AppLocalizations.of(context)?.deletePlaylistConfirm ?? 'Are you sure you want to delete'} "${playlist['name']}"?',
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(AppLocalizations.of(context)?.cancel ?? 'Cancel', style: const TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
            child: Text(AppLocalizations.of(context)?.delete ?? 'Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      await _media.deletePlaylist(playlist['id']);
      showToast(AppLocalizations.of(context)?.playlistDeleted ?? 'Playlist deleted!');
      _loadData(); // Reload playlists
    } catch (e) {
      showToast('${AppLocalizations.of(context)?.deleteFailed ?? 'Failed to delete'}: $e');
    }
  }

  Future<void> _createPlaylist(BuildContext context, Color accent) async {
    final controller = TextEditingController();
    bool isPublic = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.grey.shade900,
          title: Text(AppLocalizations.of(context)?.createPlaylist ?? 'Create Playlist', style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: AppLocalizations.of(context)?.playlistName ?? 'Playlist Name',
                  labelStyle: const TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent)),
                ),
              ),
              if (_isUpgraded) ...[
                const SizedBox(height: 16),
                CheckboxListTile(
                  value: isPublic,
                  onChanged: (val) => setState(() => isPublic = val ?? false),
                  title: Text(AppLocalizations.of(context)?.makePublic ?? 'Make Public', style: const TextStyle(color: Colors.white, fontSize: 14)),
                  subtitle: Text(AppLocalizations.of(context)?.shareWithOtherUsers ?? 'Share with other users', style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  activeColor: accent,
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(AppLocalizations.of(context)?.cancel ?? 'Cancel', style: const TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.black),
              child: Text(AppLocalizations.of(context)?.create ?? 'Create'),
            ),
          ],
        ),
      ),
    );
    if (ok != true || controller.text.trim().isEmpty) return;

    try {
      await _media.createPlaylist(controller.text.trim(), isPublic: isPublic);
      showToast(AppLocalizations.of(context)?.playlistCreated ?? 'Playlist created!');
      _loadData(); // Reload playlists
    } catch (e) {
      showToast('${AppLocalizations.of(context)?.saveFailed ?? 'Failed'}: $e');
    }
  }
}
