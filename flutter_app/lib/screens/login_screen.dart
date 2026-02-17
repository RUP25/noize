// lib/screens/login_screen.dart
import 'package:flutter/material.dart';
import '../widgets/listener_login_tab.dart';
import '../widgets/artist_login_tab.dart';
import '../widgets/influencer_login_tab.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
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
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 34),
            Image.asset('assets/logo.png', height: 84),
            const SizedBox(height: 12),
            Text(
              'Welcome to NOIZE',
              style: TextStyle(
                fontSize: 20,
                color: accent,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 18),
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 28),
              decoration: BoxDecoration(
                color: Colors.grey.shade900,
                borderRadius: BorderRadius.circular(32),
              ),
              child: TabBar(
                controller: _tabController,
                indicator: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(32),
                ),
                labelColor: Colors.black,
                unselectedLabelColor: Colors.white70,
                tabs: const [
                  Tab(text: 'Listener'),
                  Tab(text: 'REP(Artist)'),
                  Tab(text: 'Influencer'),
                ],
              ),
            ),
            const SizedBox(height: 18),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const [
                  ListenerLoginTab(),
                  ArtistLoginTab(),
                  InfluencerLoginTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
