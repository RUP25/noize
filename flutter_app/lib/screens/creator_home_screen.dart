// lib/screens/creator_home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import '../services/auth_service.dart';
import '../utils/toast_util.dart';
import 'welcome_screen.dart';
import 'charts_screen.dart';

class CreatorHomeScreen extends StatefulWidget {
  const CreatorHomeScreen({super.key});

  @override
  State<CreatorHomeScreen> createState() => _CreatorHomeScreenState();
}

class _CreatorHomeScreenState extends State<CreatorHomeScreen> with SingleTickerProviderStateMixin {
  final AuthService _auth = AuthService();
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  static const _accent = Color(0xFF78E08F);

  Future<void> _copyPromoLink() async {
    const demo = 'https://noize.app/join?ref=creator-demo';
    await Clipboard.setData(const ClipboardData(text: demo));
    showToast('Promo link copied');
  }

  void _showPlaylistTips(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('Playlist promotion', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Text(
            '• Lead with one strong opener track.\n'
            '• Theme each list (mood, genre, story).\n'
            '• Refresh weekly so followers have a reason to return.\n'
            '• Pin your NOIZE link in bio and end every short with a CTA.',
            style: TextStyle(color: Colors.grey.shade300, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Done', style: TextStyle(color: _accent)),
          ),
        ],
      ),
    );
  }

  void _showClipPrompts(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('Short-form hooks', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Text(
            '• "3 songs that got me through this week"\n'
            '• Before / after: the drop hits at 0:12\n'
            '• "Underrated line in this verse…"\n'
            '• Use 15–30s with on-screen lyrics or reaction.\n'
            '• Tag the artist and #NOIZEmusic when you post.',
            style: TextStyle(color: Colors.grey.shade300, height: 1.4),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Done', style: TextStyle(color: _accent)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111414),
      appBar: AppBar(
        title: const Text('NOIZE Creator'),
        actions: [
          ValueListenableBuilder<String?>(
            valueListenable: _auth.authToken,
            builder: (context, token, _) {
              if (token != null) {
                return IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: () async {
                    final nav = Navigator.of(context);
                    await _auth.logout();
                    if (!mounted) return;
                    nav.pushAndRemoveUntil(
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
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabs: const [
              Tab(text: 'Dashboard'),
              Tab(text: 'Toolkit'),
              Tab(text: 'Playlists'),
              Tab(text: 'Earnings'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDashboardTab(),
                _buildToolkitTab(context),
                _buildPlaylistsTab(),
                _buildEarningsTab(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDashboardTab() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [_accent.withOpacity(0.2), _accent.withOpacity(0.1)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _accent.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Icon(Icons.auto_awesome, color: _accent, size: 48),
                const SizedBox(height: 12),
                const Text(
                  'Welcome, Creator',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Curate music, grow your audience, and earn as a music influencer on NOIZE',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade300,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your stats',
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
                        'Playlists',
                        '0',
                        Icons.playlist_play,
                        _accent,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        'Followers',
                        '0',
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
                        'Total plays',
                        '0',
                        Icons.play_circle_outline,
                        Colors.purple,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildStatCard(
                        'Earnings',
                        '₹0',
                        Icons.monetization_on,
                        Colors.orange,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'What you can do',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                _buildFeatureTile(
                  icon: Icons.playlist_add,
                  title: 'Public playlists',
                  subtitle: 'Curate and share — your main lever as a music creator',
                  color: _accent,
                ),
                const SizedBox(height: 8),
                _buildFeatureTile(
                  icon: Icons.campaign,
                  title: 'Discovery & campaigns',
                  subtitle: 'Use the Toolkit tab for links, charts, and content prompts',
                  color: Colors.teal,
                ),
                const SizedBox(height: 8),
                _buildFeatureTile(
                  icon: Icons.monetization_on,
                  title: 'Revenue share',
                  subtitle: 'Percentage of the subscription pool',
                  color: Colors.orange,
                ),
                const SizedBox(height: 8),
                _buildFeatureTile(
                  icon: Icons.tips_and_updates,
                  title: 'Tips',
                  subtitle: 'Receive support from fans',
                  color: Colors.purple,
                ),
                const SizedBox(height: 8),
                _buildFeatureTile(
                  icon: Icons.card_giftcard,
                  title: 'Referral rewards',
                  subtitle: 'Earn when you bring new listeners',
                  color: Colors.blue,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildToolkitTab(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Music influencer toolkit',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade100,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Everything you need to promote tracks, grow reach, and convert fans on NOIZE.',
            style: TextStyle(fontSize: 14, color: Colors.grey.shade400),
          ),
          const SizedBox(height: 20),
          _buildToolkitAction(
            icon: Icons.link,
            title: 'Copy promo link',
            subtitle: 'Share your invite link — great for bios and captions',
            color: _accent,
            onTap: _copyPromoLink,
          ),
          _buildToolkitAction(
            icon: Icons.share,
            title: 'Share promo link',
            subtitle: 'Open the system share sheet',
            color: Colors.lightBlue,
            onTap: () async {
              await Share.share(
                'Discover new music on NOIZE — https://noize.app/join?ref=creator-demo',
                subject: 'NOIZE',
              );
            },
          ),
          _buildToolkitAction(
            icon: Icons.bar_chart,
            title: 'Trending charts',
            subtitle: 'See what is rising — use it for reaction and playlist ideas',
            color: Colors.purple,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => const ChartsScreen()),
              );
            },
          ),
          _buildToolkitAction(
            icon: Icons.queue_music,
            title: 'Playlist promotion tips',
            subtitle: 'How to title, theme, and refresh your lists',
            color: Colors.orange,
            onTap: () => _showPlaylistTips(context),
          ),
          _buildToolkitAction(
            icon: Icons.movie_filter_outlined,
            title: 'Short-form prompts',
            subtitle: 'Hooks for reels, shorts, and TikTok-style clips',
            color: Colors.pinkAccent,
            onTap: () => _showClipPrompts(context),
          ),
          _buildToolkitAction(
            icon: Icons.tag,
            title: 'Hashtag ideas',
            subtitle: '#NOIZEmusic · #NewMusicFriday · mood + genre tags',
            color: Colors.green,
            onTap: () {
              showToast('Pair genre + mood + artist name for searchability');
            },
          ),
          _buildToolkitAction(
            icon: Icons.insights,
            title: 'Audience insights',
            subtitle: 'Plays, saves, and follower growth (coming soon)',
            color: Colors.indigo,
            onTap: () => showToast('Analytics will appear here as your audience grows'),
          ),
          _buildToolkitAction(
            icon: Icons.contact_page_outlined,
            title: 'Creator media kit',
            subtitle: 'One-page stats for brands — export coming soon',
            color: Colors.amber,
            onTap: () => showToast('Media kit export coming soon'),
          ),
        ],
      ),
    );
  }

  Widget _buildToolkitAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.grey.shade900,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 14),
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
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey.shade600),
              ],
            ),
          ),
        ),
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

  Widget _buildFeatureTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color color,
  }) {
    return Container(
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
        ],
      ),
    );
  }

  Widget _buildPlaylistsTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.playlist_add, size: 64, color: Colors.grey.shade600),
          const SizedBox(height: 16),
          Text(
            'No playlists yet',
            style: TextStyle(color: Colors.grey.shade400),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () {
              showToast('Playlist creation coming soon!');
            },
            icon: const Icon(Icons.add),
            label: const Text('Create playlist'),
            style: ElevatedButton.styleFrom(
              backgroundColor: _accent,
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.account_balance_wallet, size: 64, color: Colors.grey.shade600),
          const SizedBox(height: 16),
          Text(
            'No earnings yet',
            style: TextStyle(color: Colors.grey.shade400),
          ),
          const SizedBox(height: 8),
          Text(
            'Create playlists and share your promo link to start earning',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}
