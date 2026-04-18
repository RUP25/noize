import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../l10n/app_localizations.dart';
import '../utils/toast_util.dart';

/// NOIZE Donation — social impact only. NGO discovery with redirects to **official** sites (no in-app revenue).
class NoizeDonationScreen extends StatelessWidget {
  const NoizeDonationScreen({super.key});

  static const List<Map<String, String>> _ngos = [
    {
      'name': 'UNICEF',
      'about': 'Children’s rights & emergency relief worldwide.',
      'url': 'https://www.unicef.org',
    },
    {
      'name': 'GiveIndia',
      'about': 'Trusted giving platform for Indian NGOs & causes.',
      'url': 'https://www.giveindia.org',
    },
    {
      'name': 'World Vision India',
      'about': 'Child-focused development & disaster response.',
      'url': 'https://www.worldvision.in',
    },
    {
      'name': 'Goonj',
      'about': 'Dignity-based relief & rural development (India).',
      'url': 'https://goonj.org',
    },
    {
      'name': 'Doctors Without Borders',
      'about': 'Medical humanitarian aid in crisis zones.',
      'url': 'https://www.doctorswithoutborders.org',
    },
  ];

  Future<void> _openOfficial(BuildContext context, String url) async {
    final uri = Uri.parse(url);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && context.mounted) {
        showToast(AppLocalizations.of(context)?.linkCouldNotOpen ?? 'Could not open link');
      }
    } catch (e) {
      if (context.mounted) showToast('$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF7C9EFF);
    final l10n = AppLocalizations.of(context);

    return Scaffold(
      backgroundColor: const Color(0xFF111414),
      appBar: AppBar(
        title: Text(l10n?.noizeDonationScreenTitle ?? 'NOIZE Donation'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [accent.withOpacity(0.2), accent.withOpacity(0.06)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: accent.withOpacity(0.35)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.volunteer_activism, color: accent, size: 28),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          l10n?.noizeDonationPurpose ?? 'Purpose: Social impact',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    l10n?.noizeDonationFlowDescription ??
                        'Discover NGOs below and continue on each organisation’s official website. NOIZE does not process donations or take a fee — this builds brand credibility only.',
                    style: TextStyle(color: Colors.grey.shade400, fontSize: 13, height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text(
              l10n?.ngoDiscoveryHeading ?? 'NGO discovery',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            ..._ngos.map((n) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Material(
                  color: Colors.grey.shade900,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => _openOfficial(context, n['url']!),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            n['name']!,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            n['about']!,
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 13),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(Icons.open_in_new, size: 16, color: accent),
                              const SizedBox(width: 6),
                              Text(
                                l10n?.ngoVisitOfficialSite ?? 'Open official site',
                                style: TextStyle(color: accent, fontWeight: FontWeight.w600, fontSize: 13),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
            const SizedBox(height: 8),
            Text(
              l10n?.noizeDonationNoRevenueDisclaimer ??
                  'NOIZE does not earn revenue from this section. Always verify the site URL before donating.',
              style: TextStyle(color: Colors.grey.shade600, fontSize: 11, fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}
