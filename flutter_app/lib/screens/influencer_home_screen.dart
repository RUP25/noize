// lib/screens/influencer_home_screen.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/toast_util.dart';
import 'welcome_screen.dart';

class InfluencerHomeScreen extends StatefulWidget {
  const InfluencerHomeScreen({super.key});

  @override
  State<InfluencerHomeScreen> createState() => _InfluencerHomeScreenState();
}

class _InfluencerHomeScreenState extends State<InfluencerHomeScreen> with SingleTickerProviderStateMixin {
  final AuthService _auth = AuthService();
  late final TabController _tabController;

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

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF78E08F);

    return Scaffold(
      backgroundColor: const Color(0xFF111414),
      appBar: AppBar(
        title: const Text('NOIZE Influencer'),
        actions: [
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
      body: Column(
        children: [
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Dashboard'),
              Tab(text: 'My Playlists'),
              Tab(text: 'Earnings'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildDashboardTab(accent),
                _buildPlaylistsTab(accent),
                _buildEarningsTab(accent),
              ],
            ),
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
                Icon(Icons.person_outline, color: accent, size: 48),
                const SizedBox(height: 12),
                const Text(
                  'Welcome to NOIZE Influencer',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Start curating playlists and earning rewards',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade300,
                  ),
                ),
              ],
            ),
          ),
          
          // Stats Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your Stats',
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
                        accent,
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
                        'Total Plays',
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

          // Features Section
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'What You Can Do',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                _buildFeatureTile(
                  icon: Icons.playlist_add,
                  title: 'Create Public Playlists',
                  subtitle: 'Curate and share your music',
                  color: accent,
                ),
                const SizedBox(height: 8),
                _buildFeatureTile(
                  icon: Icons.monetization_on,
                  title: 'Earn Revenue Share',
                  subtitle: 'Percentage of subscription pool',
                  color: Colors.orange,
                ),
                const SizedBox(height: 8),
                _buildFeatureTile(
                  icon: Icons.tips_and_updates,
                  title: 'Receive Tips',
                  subtitle: 'Get donations from fans',
                  color: Colors.purple,
                ),
                const SizedBox(height: 8),
                _buildFeatureTile(
                  icon: Icons.card_giftcard,
                  title: 'Referral Rewards',
                  subtitle: 'Earn when you bring new users',
                  color: Colors.blue,
                ),
              ],
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

  Widget _buildPlaylistsTab(Color accent) {
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
            label: const Text('Create Playlist'),
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEarningsTab(Color accent) {
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
            'Start creating playlists to earn rewards',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey.shade500),
          ),
        ],
      ),
    );
  }
}



