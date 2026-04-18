// lib/screens/login_screen.dart
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../config/api_config.dart';
import '../utils/toast_util.dart';
import '../widgets/listener_login_tab.dart';
import '../widgets/artist_login_tab.dart';
import '../widgets/creator_login_tab.dart';

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

  Future<void> _showBackendUrlDialog() async {
    final controller = TextEditingController(text: apiBaseUrl);
    final result = await showDialog<String?>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1E1E1E),
        title: const Text('Backend URL (dev only)', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Debug builds only. Point to your machine\'s LAN IP (same Wi‑Fi), e.g. http://192.168.1.10:8000, '
                'with the API on 0.0.0.0:8000. Release/test builds use the deployed API from the app config.',
                style: TextStyle(color: Colors.white70, fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  hintText: 'http://192.168.x.x:8000',
                  hintStyle: TextStyle(color: Colors.white38),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.white24)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF78E08F))),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, null),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, ''),
            child: const Text('Clear'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (!mounted) return;
    if (result == null) return;
    if (result.isEmpty) {
      await setApiBaseUrlOverride(null);
      showToast('Using default API URL ($apiBaseUrl)');
      return;
    }
    await setApiBaseUrlOverride(result.trim());
    showToast('API: $apiBaseUrl');
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF78E08F);

    return Scaffold(
      backgroundColor: const Color(0xFF111414),
      body: SafeArea(
        child: Column(
          children: [
            if (kDebugMode)
              Padding(
                padding: const EdgeInsets.only(right: 12, top: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: _showBackendUrlDialog,
                      child: const Text(
                        'Backend URL',
                        style: TextStyle(color: Colors.white54, fontSize: 13, decoration: TextDecoration.underline),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
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
                  Tab(text: 'Creator'),
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
                  CreatorLoginTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
