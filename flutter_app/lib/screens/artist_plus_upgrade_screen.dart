import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/toast_util.dart';

/// NOIZE Artist+ — paid tier after free [NOIZE Artist] (₹299–₹599/mo).
class ArtistPlusUpgradeScreen extends StatefulWidget {
  const ArtistPlusUpgradeScreen({super.key});

  @override
  State<ArtistPlusUpgradeScreen> createState() => _ArtistPlusUpgradeScreenState();
}

class _ArtistPlusUpgradeScreenState extends State<ArtistPlusUpgradeScreen> {
  final AuthService _auth = AuthService();
  bool _processing = false;
  String _tier = 'standard';

  Future<void> _process() async {
    setState(() => _processing = true);
    await Future.delayed(const Duration(milliseconds: 800));
    try {
      final requiresKyc = _tier == 'pro';
      final r = await _auth.upgradeArtistPlus(tier: _tier, kycVerified: requiresKyc);
      if (!mounted) return;
      if (r['ok'] == true) {
        showToast('Welcome to NOIZE Artist+!');
        Navigator.pop(context, true);
      } else {
        showToast(r['msg']?.toString() ?? 'Could not activate Artist+');
      }
    } catch (e) {
      if (mounted) showToast('$e');
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF78E08F);
    final pricePaise = _tier == 'standard' ? 29900 : 59900;

    return Scaffold(
      backgroundColor: const Color(0xFF111414),
      appBar: AppBar(
        title: const Text('NOIZE Artist+'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Upgrade from free NOIZE Artist',
                style: TextStyle(color: Colors.grey.shade400, fontSize: 14),
              ),
              const SizedBox(height: 8),
              const Text(
                'Fan tipping · Merchandise · Campaign creation',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Events (Artist+ only): event info, external ticket link, listing on your profile.',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _tierCard(
                      accent,
                      label: 'Standard',
                      paise: 29900,
                      selected: _tier == 'standard',
                      onTap: () => setState(() => _tier = 'standard'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _tierCard(
                      accent,
                      label: 'Pro',
                      paise: 59900,
                      selected: _tier == 'pro',
                      onTap: () => setState(() => _tier = 'pro'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Text(
                'Included',
                style: TextStyle(
                  color: Colors.grey.shade300,
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              ...[
                'Fan tipping',
                'Merchandise store',
                'Campaign creation',
                'Events module (info, external ticket link, profile listing)',
              ].map(
                (f) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.check_circle, color: accent, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(f, style: TextStyle(color: Colors.grey.shade300)),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: Column(
                  children: [
                    Text(
                      '₹${(pricePaise / 100.0).toStringAsFixed(0)} / mo',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: accent,
                      ),
                    ),
                    Text(
                      _tier == 'pro' ? 'Pro tier · KYC may be required for payouts' : 'Standard tier',
                      style: TextStyle(color: Colors.grey.shade500, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _processing ? null : _process,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: accent,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _processing
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                        )
                      : const Text('Continue with demo payment', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Demo mode — no real charges',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 12, fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tierCard(
    Color accent, {
    required String label,
    required int paise,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? accent : Colors.grey.shade800,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Text(
              '₹${(paise / 100).toStringAsFixed(0)}/mo',
              style: TextStyle(color: accent, fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
