// lib/screens/welcome_screen.dart
import 'package:flutter/material.dart';
import 'guest_home_screen.dart';
import 'login_screen.dart';
import 'upgrade_screen.dart';
import '../l10n/app_localizations.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF78E08F);
    const bgColor = Color(0xFF111414);

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(height: 40),
                Image.asset(
                  'assets/logo.png',
                  height: 220,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 220,
                      width: 220,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade800,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.music_note, size: 80, color: accent),
                    );
                  },
                ),
                const SizedBox(height: 32),
                Text(
                  'Listen. Create. Earn.',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade400,
                  ),
                ),
                const SizedBox(height: 60),
                // Continue as Guest Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (_) => const GuestHomeScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Continue as Guest',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Sign In Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const LoginScreen()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Sign In',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                // Upgrade Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.blueGrey.shade900.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: accent.withOpacity(0.3)),
                  ),
                  child: Column(
                    children: [
                      Icon(Icons.workspace_premium, color: accent, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        AppLocalizations.of(context)?.listenerOnlySubscriptionPitchHeader ??
                            'Love listening? Listen more with NOIZE Listen.',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        AppLocalizations.of(context)?.listenerOnlySubscriptionPitchBody ??
                            'Ad-free. Unlimited playlists. Offline downloads.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade400,
                        ),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const UpgradeScreen(planType: 'listen')),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          foregroundColor: accent,
                          side: BorderSide(color: accent),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                        ),
                        child: Text(
                          AppLocalizations.of(context)?.listenerOnlySubscriptionPitchCta ?? 'GO PREMIUM',
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 40),
                // Terms and Privacy
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () {},
                      child: Text('Terms of Use', style: TextStyle(color: Colors.grey.shade500)),
                    ),
                    Text('•', style: TextStyle(color: Colors.grey.shade700)),
                    TextButton(
                      onPressed: () {},
                      child: Text('Privacy Policy', style: TextStyle(color: Colors.grey.shade500)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
