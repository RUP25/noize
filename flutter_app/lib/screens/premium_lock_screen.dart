import 'package:flutter/material.dart';
import '../l10n/app_localizations.dart';
import 'upgrade_screen.dart';

class PremiumLockScreen extends StatelessWidget {
  final String planType; // 'listen' or 'rep'

  const PremiumLockScreen({super.key, this.planType = 'listen'});

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF78E08F);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF111414),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock, color: accent, size: 64),
              const SizedBox(height: 16),
              Text(
                l10n?.premiumFeatureLockScreenHeader ??
                    'This feature is for premium members only.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                l10n?.premiumFeatureLockScreenBody ??
                    'Get access to exclusive content, playlists, and earnings by upgrading today.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey.shade400,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => UpgradeScreen(planType: planType)),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    l10n?.premiumFeatureLockScreenCta ?? 'UNLOCK WITH PREMIUM',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

