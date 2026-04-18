import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/listener_search_tab.dart';
import '../widgets/media_player_widget.dart';
import '../services/media_service.dart';
import '../services/guest_playback_policy.dart';
import '../utils/toast_util.dart';
import '../providers/language_provider.dart';
import '../providers/player_state_provider.dart';
import '../l10n/app_localizations.dart';
import 'login_screen.dart';
import 'upgrade_screen.dart';

class GuestHomeScreen extends StatefulWidget {
  const GuestHomeScreen({super.key});

  @override
  State<GuestHomeScreen> createState() => _GuestHomeScreenState();
}

class _GuestHomeScreenState extends State<GuestHomeScreen> {
  final MediaService _media = MediaService();
  List<Map<String, dynamic>> _topSongs = [];
  bool _loading = false;

  Map<String, dynamic>? _currentlyPlayingSong;
  List<Map<String, dynamic>> _currentPlaylist = [];
  int _currentPlaylistIndex = -1;

  @override
  void initState() {
    super.initState();
    GuestPlaybackPolicy.resetSession();
    _loadPreSeededData();
  }

  Future<void> _loadPreSeededData() async {
    setState(() => _loading = true);
    try {
      final raw = await _media.getArtistSongs('popular');
      _topSongs = raw
          .take(10)
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
    } catch (e) {
      _topSongs = [];
    } finally {
      setState(() => _loading = false);
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
    if (nextIndex == null || nextIndex >= _currentPlaylist.length) return;
    final song = _currentPlaylist[nextIndex];
    if (song['moderation_status']?.toString().toLowerCase() == 'flagged') {
      _advancePlaylistNext();
      return;
    }
    setState(() {
      _currentlyPlayingSong = song;
      _currentPlaylistIndex = nextIndex;
    });
    playerState.initializeShuffle(_currentPlaylist, nextIndex);
  }

  void _advancePlaylistPrevious() {
    if (_currentPlaylist.isEmpty || _currentPlaylistIndex < 0) return;
    final playerState = Provider.of<PlayerStateProvider>(context, listen: false);
    final prevIndex = playerState.getPreviousIndex(_currentPlaylistIndex, _currentPlaylist.length);
    if (prevIndex == null || prevIndex < 0 || prevIndex >= _currentPlaylist.length) return;
    final song = _currentPlaylist[prevIndex];
    if (song['moderation_status']?.toString().toLowerCase() == 'flagged') {
      _advancePlaylistPrevious();
      return;
    }
    setState(() {
      _currentlyPlayingSong = song;
      _currentPlaylistIndex = prevIndex;
    });
    playerState.initializeShuffle(_currentPlaylist, prevIndex);
  }

  void _playAtIndex(int index) {
    if (_currentPlaylist.isEmpty) return;
    if (index < 0 || index >= _currentPlaylist.length) return;
    final song = _currentPlaylist[index];
    if (song['moderation_status']?.toString().toLowerCase() == 'flagged') return;
    final playerState = Provider.of<PlayerStateProvider>(context, listen: false);
    setState(() {
      _currentlyPlayingSong = song;
      _currentPlaylistIndex = index;
    });
    playerState.initializeShuffle(_currentPlaylist, index);
  }

  void _startPlaybackAt(int index) {
    if (index < 0 || index >= _topSongs.length) return;
    final song = _topSongs[index];
    if (song['moderation_status']?.toString().toLowerCase() == 'flagged') {
      showToast(AppLocalizations.of(context)?.unknown ?? 'Unavailable');
      return;
    }
    final playerState = Provider.of<PlayerStateProvider>(context, listen: false);
    setState(() {
      _currentPlaylist = List<Map<String, dynamic>>.from(_topSongs);
      _currentPlaylistIndex = index;
      _currentlyPlayingSong = song;
    });
    playerState.initializeShuffle(_currentPlaylist, index);
    playerState.showMini();
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF78E08F);

    return Scaffold(
      backgroundColor: const Color(0xFF111414),
      appBar: AppBar(
        title: Consumer<LanguageProvider>(
          builder: (context, languageProvider, child) {
            return Text(AppLocalizations.of(context)?.noizeGuest ?? 'NOIZE Guest');
          },
        ),
        actions: [
          Consumer<LanguageProvider>(
            builder: (context, languageProvider, child) {
              return TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const LoginScreen()),
                  );
                },
                child: Text(
                  AppLocalizations.of(context)?.signIn ?? 'Sign In',
                  style: const TextStyle(color: Color(0xFF78E08F)),
                ),
              );
            },
          ),
        ],
      ),
      body: Stack(
        children: [
          Consumer<LanguageProvider>(
            builder: (context, languageProvider, child) {
              return SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                              );
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
                    ),
                    const SizedBox(height: 16),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            AppLocalizations.of(context)?.search ?? 'Search',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const ListenerSearchTab(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
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
                            const Center(
                              child: Padding(
                                padding: EdgeInsets.all(20.0),
                                child: CircularProgressIndicator(),
                              ),
                            )
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
                              itemCount: _topSongs.length,
                              itemBuilder: (context, index) {
                                final song = _topSongs[index];
                                return ListTile(
                                  leading: CircleAvatar(
                                    backgroundColor: accent.withOpacity(0.2),
                                    child: Icon(Icons.music_note, color: accent),
                                  ),
                                  title: Text(
                                    song['title'] ?? (AppLocalizations.of(context)?.unknown ?? 'Unknown'),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  subtitle: Text(
                                    song['album']?.toString() ?? '',
                                    style: const TextStyle(color: Colors.grey),
                                  ),
                                  trailing: Icon(Icons.play_arrow, color: accent),
                                  onTap: () => _startPlaybackAt(index),
                                );
                              },
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade900,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.info_outline, color: accent, size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  AppLocalizations.of(context)?.guestModeLimitations ?? 'Guest Mode Limitations',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              AppLocalizations.of(context)?.listenWithAds ??
                                  '• Limited streaming with ads and limited skips\n• No offline downloads\n• No tokens, tipping, or monetisation — full access on NOIZE Listen',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Colors.grey,
                              ),
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
          if (_currentlyPlayingSong != null)
            Consumer<PlayerStateProvider>(
              builder: (context, playerState, child) {
                if (playerState.isFull) return const SizedBox.shrink();
                return Positioned(
                  bottom: 0,
                  left: 0,
                  right: 0,
                  child: MediaPlayerWidget(
                    r2Key: _currentlyPlayingSong!['r2_key'],
                    title: _currentlyPlayingSong!['title'],
                    artist: _currentlyPlayingSong!['artist']?.toString() ??
                        (_currentlyPlayingSong!['artist'] is Map
                            ? (_currentlyPlayingSong!['artist'] as Map)['channel_name']?.toString()
                            : null),
                    coverPhotoUrl: _currentlyPlayingSong!['cover_photo_url'],
                    contentType: _currentlyPlayingSong!['content_type'],
                    isVideo: _currentlyPlayingSong!['content_type']?.toString().startsWith('video/') ?? false,
                    playlist: _currentPlaylist,
                    currentIndex: _currentPlaylistIndex,
                    isMini: true,
                    moderationStatus: _currentlyPlayingSong!['moderation_status']?.toString(),
                    isNoizeGuest: true,
                    onQueueAdvanceWithoutSkip: _advancePlaylistNext,
                    onNext: _advancePlaylistNext,
                    onPrevious: _advancePlaylistPrevious,
                    onSelectTrackIndex: _playAtIndex,
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
}
