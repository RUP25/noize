import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../widgets/listener_search_tab.dart';
import '../services/media_service.dart';
import '../utils/toast_util.dart';
import '../providers/language_provider.dart';
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
  List<dynamic> _topSongs = [];
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _loadPreSeededData();
  }

  Future<void> _loadPreSeededData() async {
    setState(() => _loading = true);
    try {
      // Try to load popular songs from a well-known channel
      _topSongs = await _media.getArtistSongs('popular');
    } catch (e) {
      // If no popular channel exists, that's okay - show empty state
      _topSongs = [];
    } finally {
      setState(() => _loading = false);
    }
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
      body: Consumer<LanguageProvider>(
        builder: (context, languageProvider, child) {
          return SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Upgrade Banner
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
            // Search Section
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
            // Top Charts Section
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
                      itemCount: _topSongs.length > 10 ? 10 : _topSongs.length,
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
                            song['album'] ?? '',
                            style: const TextStyle(color: Colors.grey),
                          ),
                          trailing: Icon(Icons.play_arrow, color: accent),
                          onTap: () {
                            showToast(AppLocalizations.of(context)?.loginRequiredToPlay ?? 'Login required to play');
                          },
                        );
                      },
                    ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            // Guest Limitations Info
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
                      AppLocalizations.of(context)?.listenWithAds ?? '• Listen with ads and limited skips\n• Create private playlists (cannot share)\n• Cannot download or earn rewards',
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
    );
  }
}
