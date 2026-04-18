import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:provider/provider.dart';
import '../widgets/listener_search_tab.dart';
import '../widgets/media_player_widget.dart';
import '../widgets/artist_channel_page.dart';
import '../services/media_service.dart';
import '../services/auth_service.dart';
import '../utils/toast_util.dart';
import '../providers/language_provider.dart';
import '../providers/player_state_provider.dart';
import '../l10n/app_localizations.dart';
import 'upgrade_screen.dart';
import 'listener_profile_screen.dart';
import 'welcome_screen.dart';
import 'playlist_detail_screen.dart';
import 'charts_screen.dart';
import 'chart_detail_screen.dart';
import 'experience_screen.dart';
import '../data/charts.dart';
import 'popular_artists_screen.dart';
import 'noize_donation_screen.dart';

class ListenerHomeScreen extends StatefulWidget {
  const ListenerHomeScreen({super.key});

  @override
  State<ListenerHomeScreen> createState() => _ListenerHomeScreenState();
}

class _ListenerHomeScreenState extends State<ListenerHomeScreen> with SingleTickerProviderStateMixin {
  static const accent = Color(0xFF78E08F);
  final MediaService _media = MediaService();
  final AuthService _auth = AuthService();
  late final TabController _tabController;
  List<dynamic> _topSongs = [];
  List<dynamic> _likedSongs = [];
  List<dynamic> _playlists = [];
  List<dynamic> _followingArtists = [];
  List<dynamic> _popularArtists = [];
  List<dynamic> _forYouSongs = [];
  List<dynamic> _trendingSongs = [];
  bool _loading = false;
  bool _isUpgraded = false;
  String _userRole = 'guest';
  Map<String, dynamic>? _currentUser;
  Map<String, dynamic>? _uiConfig;
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
    _loadUiConfig();
  }

  Future<void> _loadUiConfig() async {
    try {
      final cfg = await _auth.getUiConfig();
      if (mounted) {
        setState(() => _uiConfig = cfg);
      }
    } catch (_) {
      // ignore
    }
  }

  Future<void> _checkUpgradeStatus() async {
    final user = await _auth.getMe();
    setState(() {
      _currentUser = user;
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
    try {
      _followingArtists = await _media.getFollowingArtists();
    } catch (e) {
      _followingArtists = [];
    }
    try {
      _popularArtists = await _media.getPopularArtists(limit: 12);
    } catch (e) {
      _popularArtists = [];
    }
    try {
      if (_auth.isLoggedIn) {
        _forYouSongs = await _media.getForYouRecommendations(limit: 30);
      } else {
        _forYouSongs = [];
      }
    } catch (e) {
      _forYouSongs = [];
    }
    try {
      _trendingSongs = await _media.getTrendingRecommendations(limit: 30);
    } catch (e) {
      _trendingSongs = [];
    }
    setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111414),
      appBar: AppBar(
        toolbarHeight: 120,
        centerTitle: true,
        title: Padding(
          padding: const EdgeInsets.only(top: 4.0),
          child: Image.asset(
            'assets/logo.png',
            height: 104,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none),
            tooltip: 'Notifications',
            onPressed: () {
              // TODO: Implement notifications screen
            },
          ),
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
            tooltip: AppLocalizations.of(context)?.profile ?? 'Profile',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const ListenerProfileScreen()),
              ).then((_) => _checkUpgradeStatus());
            },
            icon: CircleAvatar(
              radius: 14,
              backgroundColor: Colors.grey.shade800,
              backgroundImage: (_currentUser?['photo_url'] != null &&
                      _currentUser!['photo_url'].toString().isNotEmpty)
                  ? NetworkImage(_currentUser!['photo_url'].toString())
                  : null,
              child: (_currentUser?['photo_url'] == null ||
                      _currentUser!['photo_url'].toString().isEmpty)
                  ? const Icon(Icons.account_circle, color: Colors.white)
                  : null,
            ),
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
                      Tab(
                        icon: const Icon(Icons.home_outlined),
                        text: AppLocalizations.of(context)?.home ?? 'Home',
                      ),
                      Tab(
                        icon: const Icon(Icons.search),
                        text: AppLocalizations.of(context)?.search ?? 'Search',
                      ),
                      Tab(
                        icon: const Icon(Icons.explore_outlined),
                        text: 'Experience',
                      ),
                      Tab(
                        icon: const Icon(Icons.playlist_play),
                        text: AppLocalizations.of(context)?.playlists ?? 'Playlists',
                      ),
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
                    _buildExperienceTab(accent),
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
                    onNext: _advancePlaylistNext,
                    onPrevious: _advancePlaylistPrevious,
                    onQueueAdvanceWithoutSkip: _advancePlaylistNext,
                    onSelectTrackIndex: _playAtIndex,
                    isNoizeGuest: _userRole == 'guest',
                    onGuestSkipLimitReached: _onGuestSkipLimitReached,
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
        final hour = DateTime.now().hour;
        final timeKey = (hour >= 5 && hour < 12)
            ? 'morning'
            : (hour >= 12 && hour < 17)
                ? 'afternoon'
                : (hour >= 17 && hour < 22)
                    ? 'evening'
                    : 'night';

        final greetings = (_uiConfig?['greetings'] is Map) ? (_uiConfig!['greetings'] as Map) : null;
        final greetingText = greetings != null && greetings[timeKey] != null
            ? greetings[timeKey].toString()
            : (timeKey == 'morning'
                ? 'Good morning'
                : timeKey == 'afternoon'
                    ? 'Good afternoon'
                    : timeKey == 'evening'
                        ? 'Good evening'
                        : 'Good night');

        final name = (_currentUser?['full_name']?.toString().trim().isNotEmpty ?? false)
            ? _currentUser!['full_name'].toString().trim()
            : (_currentUser?['channel_name']?.toString().trim().isNotEmpty ?? false)
                ? _currentUser!['channel_name'].toString().trim()
                : (_currentUser?['email']?.toString().split('@').first ?? 'there');

        final storyTitle = (_uiConfig?['story_title']?.toString().trim().isNotEmpty ?? false)
            ? _uiConfig!['story_title'].toString().trim()
            : 'Your Story';

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
          // NOIZE Donation — social impact; official NGO sites only (no revenue)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const NoizeDonationScreen()),
                  );
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        const Color(0xFF7C9EFF).withOpacity(0.2),
                        const Color(0xFF5C6BC0).withOpacity(0.09),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFF7C9EFF).withOpacity(0.35)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const Icon(Icons.volunteer_activism, color: Color(0xFF9FA8DA), size: 36),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              AppLocalizations.of(context)?.noizeDonationCardTitle ?? 'NOIZE Donation',
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              AppLocalizations.of(context)?.noizeDonationCardSubtitle ??
                                  'Social impact · Discover NGOs — official sites only. No payments through NOIZE.',
                              style: TextStyle(
                                color: Colors.grey.shade400,
                                fontSize: 12,
                                height: 1.35,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Text(
                              AppLocalizations.of(context)?.noizeDonationCta ?? 'Explore NGOs',
                              style: const TextStyle(
                                color: Color(0xFF9FA8DA),
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(Icons.chevron_right, color: Colors.grey.shade500),
                    ],
                  ),
                ),
              ),
            ),
          ),
          // Top Charts Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // User greeting + large avatar (highlighted area)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor: Colors.grey.shade800,
                      backgroundImage: (_currentUser?['photo_url'] != null &&
                              _currentUser!['photo_url'].toString().isNotEmpty)
                          ? NetworkImage(_currentUser!['photo_url'].toString())
                          : null,
                      child: (_currentUser?['photo_url'] == null ||
                              _currentUser!['photo_url'].toString().isEmpty)
                          ? const Icon(Icons.account_circle, color: Colors.white, size: 40)
                          : null,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$greetingText, $name',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Let’s pick up where you left off.',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Charts section (horizontal) + Show all
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Charts',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ChartsScreen()),
                        );
                      },
                      child: Text(
                        'Show all',
                        style: TextStyle(color: Colors.grey.shade300),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 210,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: chartsCatalog.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 14),
                    itemBuilder: (context, index) {
                      final c = chartsCatalog[index];
                      return _HomeChartCard(
                        title: c.title,
                        subtitle: c.subtitle,
                        imageUrl: c.imageUrl,
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChartDetailScreen(chart: c),
                            ),
                          );
                        },
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),

                if (_forYouSongs.isNotEmpty) ...[
                  const _HomeSectionHeader(title: 'Made for you'),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 190,
                    child: _HorizontalMediaRow(
                      items: (_forYouSongs.take(15)).toList(),
                      emptyText: '',
                      onTapSong: (song) {
                        final moderationStatus = song['moderation_status']?.toString().toLowerCase();
                        if (moderationStatus == 'flagged') return;
                        final playList = _forYouSongs.map((s) => s as Map<String, dynamic>).toList();
                        final idx = playList.indexWhere((s) => s['r2_key'] == song['r2_key']);
                        final playerState = Provider.of<PlayerStateProvider>(context, listen: false);
                        playerState.showMini();
                        setState(() {
                          _currentlyPlayingSong = song;
                          _currentPlaylist = playList;
                          _currentPlaylistIndex = idx >= 0 ? idx : 0;
                        });
                        playerState.initializeShuffle(playList, _currentPlaylistIndex);
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                if (_trendingSongs.isNotEmpty) ...[
                  const _HomeSectionHeader(title: 'Trending on NOIZE'),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 190,
                    child: _HorizontalMediaRow(
                      items: (_trendingSongs.take(15)).toList(),
                      emptyText: '',
                      onTapSong: (song) {
                        final moderationStatus = song['moderation_status']?.toString().toLowerCase();
                        if (moderationStatus == 'flagged') return;
                        final playList = _trendingSongs.map((s) => s as Map<String, dynamic>).toList();
                        final idx = playList.indexWhere((s) => s['r2_key'] == song['r2_key']);
                        final playerState = Provider.of<PlayerStateProvider>(context, listen: false);
                        playerState.showMini();
                        setState(() {
                          _currentlyPlayingSong = song;
                          _currentPlaylist = playList;
                          _currentPlaylistIndex = idx >= 0 ? idx : 0;
                        });
                        playerState.initializeShuffle(playList, _currentPlaylistIndex);
                      },
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Listen again
                _HomeSectionHeader(
                  title: 'Listen again',
                  trailing: _HomePillButton(
                    label: 'More',
                    onTap: () => showToast('Listen again: coming soon'),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 190,
                  child: _HorizontalMediaRow(
                    items: (_likedSongs.take(10)).toList(),
                    emptyText: 'Nothing to replay yet',
                    onTapSong: (song) {
                      final moderationStatus = song['moderation_status']?.toString().toLowerCase();
                      if (moderationStatus == 'flagged') return;
                      final playList = _likedSongs.map((s) => s as Map<String, dynamic>).toList();
                      final idx = playList.indexWhere((s) => s['r2_key'] == song['r2_key']);
                      final playerState = Provider.of<PlayerStateProvider>(context, listen: false);
                      playerState.showMini();
                      setState(() {
                        _currentlyPlayingSong = song;
                        _currentPlaylist = playList;
                        _currentPlaylistIndex = idx >= 0 ? idx : 0;
                      });
                      playerState.initializeShuffle(playList, _currentPlaylistIndex);
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Your favourites
                const _HomeSectionHeader(title: 'Your favourites'),
                const SizedBox(height: 12),
                SizedBox(
                  height: 190,
                  child: _HorizontalMediaRow(
                    items: (_likedSongs.take(10)).toList(),
                    emptyText: 'No favourites yet',
                    onTapSong: (song) {
                      final moderationStatus = song['moderation_status']?.toString().toLowerCase();
                      if (moderationStatus == 'flagged') return;
                      final playList = _likedSongs.map((s) => s as Map<String, dynamic>).toList();
                      final idx = playList.indexWhere((s) => s['r2_key'] == song['r2_key']);
                      final playerState = Provider.of<PlayerStateProvider>(context, listen: false);
                      playerState.showMini();
                      setState(() {
                        _currentlyPlayingSong = song;
                        _currentPlaylist = playList;
                        _currentPlaylistIndex = idx >= 0 ? idx : 0;
                      });
                      playerState.initializeShuffle(playList, _currentPlaylistIndex);
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Recently followed
                const _HomeSectionHeader(title: 'Recently followed'),
                const SizedBox(height: 12),
                SizedBox(
                  height: 140,
                  child: _HorizontalArtistRow(
                    items: (_followingArtists.take(12)).toList(),
                    emptyText: 'Follow artists to see them here',
                    onTapArtist: (artist) {
                      final name = artist['channel_name']?.toString();
                      if (name == null || name.isEmpty) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ArtistChannelPage(channelName: name)),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),

                // Popular artists
                _HomeSectionHeader(
                  title: 'Popular artists',
                  trailing: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PopularArtistsScreen()),
                      );
                    },
                    child: Text('Show all', style: TextStyle(color: Colors.grey.shade300)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 170,
                  child: _HorizontalPopularArtistRow(
                    items: (_popularArtists.take(12)).toList(),
                    emptyText: 'No artists yet',
                    onTapArtist: (artist) {
                      final name = artist['channel_name']?.toString();
                      if (name == null || name.isEmpty) return;
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => ArtistChannelPage(channelName: name)),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 24),

                Text(
                  storyTitle,
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
                else if (_topSongs.isEmpty && _trendingSongs.isEmpty)
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
                  Builder(
                    builder: (context) {
                      final storySongList = _topSongs.isNotEmpty ? _topSongs : _trendingSongs;
                      return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: storySongList.length > 50 ? 50 : storySongList.length,
                    itemBuilder: (context, index) {
                      final song = storySongList[index];
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
                          final playList = storySongList.map((s) => s as Map<String, dynamic>).toList();
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
                            // Initialize shuffle if enabled
                            playerState.initializeShuffle(playList, _currentPlaylistIndex);
                          }
                        },
                      );
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

  Widget _buildExperienceTab(Color accent) {
    return ExperienceScreen(accent: accent, isNoizeGuestTier: _userRole == 'guest');
  }

  Widget _buildPlaylistsTab(Color accent) {
    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 14, 12, 24),
          children: [
            _libraryTile(
              accent: accent,
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.purple.shade700.withOpacity(0.85),
                ),
                child: const Icon(Icons.favorite, color: Colors.white),
              ),
              title: AppLocalizations.of(context)?.liked ?? 'Liked Songs',
              subtitle: '${_likedSongs.length} ${AppLocalizations.of(context)?.songs ?? 'songs'}',
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => Scaffold(
                      backgroundColor: const Color(0xFF111414),
                      appBar: AppBar(
                        title: Text(AppLocalizations.of(context)?.liked ?? 'Liked songs'),
                      ),
                      body: RefreshIndicator(
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
                                  return ListTile(
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                    leading: song['cover_photo_url'] != null &&
                                            song['cover_photo_url'].toString().isNotEmpty
                                        ? ClipRRect(
                                            borderRadius: BorderRadius.circular(10),
                                            child: Image.network(
                                              song['cover_photo_url'],
                                              width: 44,
                                              height: 44,
                                              fit: BoxFit.cover,
                                              errorBuilder: (_, __, ___) => Container(
                                                width: 44,
                                                height: 44,
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(10),
                                                  color: Colors.grey.shade800,
                                                ),
                                                child: Icon(Icons.music_note, color: accent),
                                              ),
                                            ),
                                          )
                                        : Container(
                                            width: 44,
                                            height: 44,
                                            decoration: BoxDecoration(
                                              borderRadius: BorderRadius.circular(10),
                                              color: Colors.grey.shade800,
                                            ),
                                            child: Icon(Icons.music_note, color: accent),
                                          ),
                                    title: Text(
                                      song['title'] ?? (AppLocalizations.of(context)?.unknown ?? 'Unknown'),
                                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    subtitle: Text(
                                      (song['artist']?['channel_name']?.toString() ??
                                              song['artist']?.toString() ??
                                              '') +
                                          (song['album'] != null && song['album'].toString().isNotEmpty
                                              ? ' • ${song['album']}'
                                              : ''),
                                      style: TextStyle(color: Colors.grey.shade400),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  );
                                },
                              ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 4),
            _libraryTile(
              accent: accent,
              leading: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: Colors.green.shade700.withOpacity(0.85),
                ),
                child: const Icon(Icons.bookmark, color: Colors.white),
              ),
              title: 'Your Episodes',
              subtitle: 'Saved & downloaded episodes',
              onTap: () => showToast('Episodes coming soon'),
            ),
            const SizedBox(height: 16),
            Divider(color: Colors.grey.shade800, height: 1),
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    AppLocalizations.of(context)?.playlists ?? 'Playlists',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => _createPlaylist(context, accent),
                    icon: const Icon(Icons.add, size: 18),
                    label: Text(AppLocalizations.of(context)?.newLabel ?? 'New'),
                    style: TextButton.styleFrom(foregroundColor: accent),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            if (_playlists.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 24),
                child: Center(
                  child: Column(
                    children: [
                      Icon(Icons.playlist_add, size: 56, color: Colors.grey.shade600),
                      const SizedBox(height: 12),
                      Text(
                        AppLocalizations.of(context)?.noPlaylistsYet ?? 'No playlists yet',
                        style: TextStyle(color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._playlists.map((playlist) {
                final name = playlist['name'] ?? (AppLocalizations.of(context)?.playlist ?? 'Playlist');
                final count = playlist['song_count'] ?? 0;
                final coverUrl = playlist['cover_photo_url']?.toString();

                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    color: Colors.black.withOpacity(0.12),
                    border: Border.all(color: Colors.grey.shade900),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    leading: coverUrl != null && coverUrl.isNotEmpty
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Image.network(
                              coverUrl,
                              width: 44,
                              height: 44,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _playlistFallbackIcon(accent),
                            ),
                          )
                        : _playlistFallbackIcon(accent),
                    title: Text(
                      name.toString(),
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    subtitle: Text(
                      '$count ${AppLocalizations.of(context)?.songs ?? 'songs'}',
                      style: TextStyle(color: Colors.grey.shade400),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: Icon(Icons.play_arrow, color: accent),
                          onPressed: () => _playPlaylist(playlist),
                          tooltip: 'Play',
                        ),
                        PopupMenuButton<String>(
                          icon: const Icon(Icons.more_vert, color: Colors.grey),
                          color: Colors.grey.shade900,
                          onSelected: (value) {
                            if (value == 'edit') {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (context) => PlaylistDetailScreen(
                                    playlistId: playlist['id'],
                                    playlistName: playlist['name'] ?? 'Playlist',
                                    isPublic: playlist['is_public'] ?? false,
                                    coverPhotoUrl: playlist['cover_photo_url'],
                                  ),
                                ),
                              ).then((_) => _loadData());
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
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => PlaylistDetailScreen(
                            playlistId: playlist['id'],
                            playlistName: playlist['name'] ?? 'Playlist',
                            isPublic: playlist['is_public'] ?? false,
                            coverPhotoUrl: playlist['cover_photo_url'],
                          ),
                        ),
                      ).then((_) => _loadData());
                    },
                  ),
                );
              }).toList(),
          ],
        );
      },
    );
  }

  Widget _playlistFallbackIcon(Color accent) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: Colors.grey.shade800,
      ),
      child: Icon(Icons.playlist_play, color: accent),
    );
  }

  Widget _libraryTile({
    required Color accent,
    required Widget leading,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.black.withOpacity(0.12),
        border: Border.all(color: Colors.grey.shade900),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: leading,
        title: Text(
          title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          subtitle,
          style: TextStyle(color: Colors.grey.shade400),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        onTap: onTap,
      ),
    );
  }

  Future<void> _playPlaylist(Map<String, dynamic> playlist) async {
    try {
      final playlistData = await _media.getPlaylist(playlist['id']);
      if (playlistData['songs'] != null && (playlistData['songs'] as List).isNotEmpty) {
        final songs = (playlistData['songs'] as List).map((s) => s as Map<String, dynamic>).toList();
        final firstSong = songs[0];
        
        // Check if first song is suspended
        final moderationStatus = firstSong['moderation_status']?.toString().toLowerCase();
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
        
        final playerState = Provider.of<PlayerStateProvider>(context, listen: false);
        playerState.showMini();
        setState(() {
          _currentlyPlayingSong = firstSong;
          _currentPlaylist = songs;
          _currentPlaylistIndex = 0;
        });
        // Initialize shuffle if enabled
        playerState.initializeShuffle(songs, 0);
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

  void _onGuestSkipLimitReached() {
    showToast(
      AppLocalizations.of(context)?.guestSkipLimitReached ??
          'Skip limit reached. Upgrade to NOIZE Listen for unlimited skips.',
    );
  }

  void _advancePlaylistNext() {
    if (_currentPlaylist.isEmpty || _currentPlaylistIndex < 0) return;
    
    final playerState = Provider.of<PlayerStateProvider>(context, listen: false);
    final nextIndex = playerState.getNextIndex(_currentPlaylistIndex, _currentPlaylist.length);
    
    if (nextIndex != null && nextIndex < _currentPlaylist.length) {
      final song = _currentPlaylist[nextIndex];
      final moderationStatus = song['moderation_status']?.toString().toLowerCase();
      if (moderationStatus != 'flagged') {
        setState(() {
          _currentlyPlayingSong = song;
          _currentPlaylistIndex = nextIndex;
        });
        playerState.initializeShuffle(_currentPlaylist, nextIndex);
      } else {
        // Skip flagged song and try next
        _advancePlaylistNext();
      }
    }
  }

  void _advancePlaylistPrevious() {
    if (_currentPlaylist.isEmpty || _currentPlaylistIndex < 0) return;
    
    final playerState = Provider.of<PlayerStateProvider>(context, listen: false);
    final prevIndex = playerState.getPreviousIndex(_currentPlaylistIndex, _currentPlaylist.length);
    
    if (prevIndex != null && prevIndex >= 0 && prevIndex < _currentPlaylist.length) {
      final song = _currentPlaylist[prevIndex];
      final moderationStatus = song['moderation_status']?.toString().toLowerCase();
      if (moderationStatus != 'flagged') {
        setState(() {
          _currentlyPlayingSong = song;
          _currentPlaylistIndex = prevIndex;
        });
        playerState.initializeShuffle(_currentPlaylist, prevIndex);
      } else {
        // Skip flagged song and try previous
        _advancePlaylistPrevious();
      }
    }
  }

  void _playAtIndex(int index) {
    if (_currentPlaylist.isEmpty) return;
    if (index < 0 || index >= _currentPlaylist.length) return;
    final song = _currentPlaylist[index];
    final moderationStatus = song['moderation_status']?.toString().toLowerCase();
    if (moderationStatus == 'flagged') return;
    final playerState = Provider.of<PlayerStateProvider>(context, listen: false);
    setState(() {
      _currentlyPlayingSong = song;
      _currentPlaylistIndex = index;
    });
    playerState.initializeShuffle(_currentPlaylist, index);
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

class _HomeChartCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imageUrl;
  final VoidCallback onTap;

  const _HomeChartCard({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF78E08F);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
      width: 230,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: Colors.grey.shade900,
        border: Border.all(color: Colors.grey.shade800),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(14),
                topRight: Radius.circular(14),
              ),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  Image.network(
                    imageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      color: Colors.grey.shade800,
                      child: Center(
                        child: Icon(Icons.equalizer, color: accent.withOpacity(0.8), size: 34),
                      ),
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          Colors.black.withOpacity(0.05),
                          Colors.black.withOpacity(0.75),
                        ],
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Align(
                      alignment: Alignment.topLeft,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: Colors.white.withOpacity(0.15)),
                        ),
                        child: Text(
                          title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.6,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Text(
              subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12, height: 1.2),
            ),
          ),
        ],
      ),
    ),
    );
  }
}

class _HomeSectionHeader extends StatelessWidget {
  final String title;
  final Widget? trailing;

  const _HomeSectionHeader({required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        if (trailing != null) trailing!,
      ],
    );
  }
}

class _HomePillButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _HomePillButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.grey.shade700),
          color: Colors.black.withOpacity(0.15),
        ),
        child: Text(label, style: const TextStyle(color: Colors.white)),
      ),
    );
  }
}

class _HorizontalMediaRow extends StatelessWidget {
  final List<dynamic> items;
  final String emptyText;
  final void Function(Map<String, dynamic> song) onTapSong;

  const _HorizontalMediaRow({
    required this.items,
    required this.emptyText,
    required this.onTapSong,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF78E08F);
    if (items.isEmpty) {
      return Center(child: Text(emptyText, style: TextStyle(color: Colors.grey.shade500)));
    }
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(width: 14),
      itemBuilder: (context, index) {
        final song = items[index] as Map<String, dynamic>;
        final cover = song['cover_photo_url']?.toString();
        final title = song['title']?.toString() ?? 'Unknown';
        final artist = (song['artist'] is Map)
            ? (song['artist']['channel_name']?.toString() ?? 'Unknown Artist')
            : (song['artist']?.toString() ?? 'Unknown Artist');

        return InkWell(
          onTap: () => onTapSong(song),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 200,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.grey.shade900,
              border: Border.all(color: Colors.grey.shade800),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(14),
                      topRight: Radius.circular(14),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (cover != null && cover.isNotEmpty)
                          Image.network(
                            cover,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) => Container(
                              color: Colors.grey.shade800,
                              child: Center(child: Icon(Icons.music_note, color: accent, size: 34)),
                            ),
                          )
                        else
                          Container(
                            color: Colors.grey.shade800,
                            child: Center(child: Icon(Icons.music_note, color: accent, size: 34)),
                          ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [
                                Colors.black.withOpacity(0.1),
                                Colors.black.withOpacity(0.75),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                        const Center(
                          child: Icon(Icons.play_circle_fill, color: Colors.white, size: 56),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        artist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HorizontalArtistRow extends StatelessWidget {
  final List<dynamic> items;
  final String emptyText;
  final void Function(Map<String, dynamic> artist) onTapArtist;

  const _HorizontalArtistRow({
    required this.items,
    required this.emptyText,
    required this.onTapArtist,
  });

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF78E08F);
    if (items.isEmpty) {
      return Center(child: Text(emptyText, style: TextStyle(color: Colors.grey.shade500)));
    }
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(width: 14),
      itemBuilder: (context, index) {
        final a = items[index] as Map<String, dynamic>;
        final name = a['channel_name']?.toString() ?? 'Artist';
        final photo = a['photo_url']?.toString();
        return InkWell(
          onTap: () => onTapArtist(a),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 120,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: Colors.grey.shade900,
              border: Border.all(color: Colors.grey.shade800),
            ),
            padding: const EdgeInsets.all(10),
            child: Column(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: Colors.grey.shade800,
                  backgroundImage: (photo != null && photo.isNotEmpty) ? NetworkImage(photo) : null,
                  child: (photo == null || photo.isEmpty)
                      ? const Icon(Icons.account_circle, color: Colors.white, size: 44)
                      : null,
                ),
                const SizedBox(height: 10),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  'Followed',
                  style: TextStyle(color: accent.withOpacity(0.9), fontSize: 11),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _HorizontalPopularArtistRow extends StatelessWidget {
  final List<dynamic> items;
  final String emptyText;
  final void Function(Map<String, dynamic> artist) onTapArtist;

  const _HorizontalPopularArtistRow({
    required this.items,
    required this.emptyText,
    required this.onTapArtist,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(child: Text(emptyText, style: TextStyle(color: Colors.grey.shade500)));
    }
    return ListView.separated(
      scrollDirection: Axis.horizontal,
      itemCount: items.length,
      separatorBuilder: (_, __) => const SizedBox(width: 18),
      itemBuilder: (context, index) {
        final a = items[index] as Map<String, dynamic>;
        final name = a['channel_name']?.toString() ?? 'Artist';
        final photo = a['photo_url']?.toString();
        return InkWell(
          onTap: () => onTapArtist(a),
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            width: 160,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 54,
                  backgroundColor: Colors.grey.shade800,
                  backgroundImage: (photo != null && photo.isNotEmpty) ? NetworkImage(photo) : null,
                  child: (photo == null || photo.isEmpty)
                      ? const Icon(Icons.account_circle, color: Colors.white, size: 64)
                      : null,
                ),
                const SizedBox(height: 12),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text('Artist', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
              ],
            ),
          ),
        );
      },
    );
  }
}
