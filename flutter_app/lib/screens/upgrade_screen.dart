// lib/screens/upgrade_screen.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/toast_util.dart';
import '../l10n/app_localizations.dart';

class UpgradeScreen extends StatefulWidget {
  final String planType; // 'listen', 'rep', or 'influencer' (Creator)
  
  const UpgradeScreen({super.key, required this.planType});

  @override
  State<UpgradeScreen> createState() => _UpgradeScreenState();
}

class _UpgradeScreenState extends State<UpgradeScreen> {
  final AuthService _auth = AuthService();
  bool _processing = false;
  String _selectedPaymentMethod = 'demo_card';
  
  /// Amounts are in **paise** (1 INR = 100 paise). Display: `(amount / 100)` as rupees.
  final _planData = {
    'listen': {
      'name': 'NOIZE Listen',
      // Core revenue tier: ₹149/mo — ad-free, full access; streams drive revenue distribution.
      'monthly': 14900, // ₹149
      'yearly': 149900, // ₹1499/yr (vs ₹1788 if 12× monthly)
      'features': [
        'Ad-free listening',
        'Unlimited skips',
        'Offline downloads',
        'Full catalog access',
        'Your plays power stream revenue distribution to artists',
      ],
    },
    'rep': {
      'name': 'NOIZE REP',
      // Engagement engine after Listen: ₹399/mo — growth, referrals, token economy (capped).
      'monthly': 39900, // ₹399
      'yearly': 399900, // ₹3999/yr
      'features': [
        'Everything in NOIZE Listen',
        'Referral system (growth + rewards)',
        'Task-based earning',
        'Token dashboard',
        'Token limits: 50/day · 800–1200/month',
        'Earnings from reward pool (not fixed)',
        'KYC for payouts',
      ],
    },
    'influencer': {
      'name': 'NOIZE Creator',
      'monthly': 129900, // ₹1299
      'yearly': 1299900, // ₹12999
      'features': [
        'Everything in NOIZE Listen',
        'Creator toolkit & promo tools',
        'Playlist-led music influencer features',
        'KYC for payouts',
        'Revenue share & tips',
        'Charts & trend insights',
      ],
    },
  };

  String _selectedPeriod = 'monthly';

  Future<void> _processPayment() async {
    setState(() => _processing = true);
    
    // Simulate payment processing
    await Future.delayed(const Duration(seconds: 2));
    
    try {
      // Determine KYC requirement based on plan type
      final requiresKyc = widget.planType == 'rep' || widget.planType == 'influencer';
      
      // Call backend to upgrade user
      final result = await _auth.upgradeToPremium(role: widget.planType, kycVerified: requiresKyc);
      
      if (mounted) {
        if (result['ok'] == true && result['is_upgraded'] == true) {
          final planName = (_planData[widget.planType] ?? _planData['listen']!)['name'];
          showToast('Upgrade successful! Welcome to $planName!');
          Navigator.pop(context, true);
        } else {
          final msg = result['msg'] ?? 'Upgrade failed. Please try again.';
          showToast(msg);
        }
      }
    } catch (e) {
      showToast('Payment failed: $e');
    } finally {
      setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF78E08F);
    final plan = _planData[widget.planType] ?? _planData['listen']!;
    final l10n = AppLocalizations.of(context);
    final pitch = widget.planType == 'rep'
        ? (l10n?.repSubscriptionPitchBody ??
            'The phase after NOIZE Listen: growth + referrals. Task earning, token dashboard, reward-pool payouts.')
        : widget.planType == 'influencer'
            ? 'Grow as a music influencer: playlists, promo links, and creator tools on NOIZE.'
        : (l10n?.listenerOnlySubscriptionPitchBody ??
            'Ad-free. Unlimited playlists. Offline downloads.');
    final pricePaise = (_selectedPeriod == 'monthly' ? plan['monthly'] : plan['yearly']) as int;
    String? savings;
    if (_selectedPeriod == 'yearly') {
      final monthlyPaise = plan['monthly'] as int;
      final yearlyPaise = plan['yearly'] as int;
      final annualIfMonthly = monthlyPaise * 12;
      if (annualIfMonthly > yearlyPaise) {
        final savePercent =
            (((annualIfMonthly - yearlyPaise) / annualIfMonthly) * 100).round();
        savings = 'Save about $savePercent% vs paying monthly';
      }
    }

    return Scaffold(
      backgroundColor: const Color(0xFF111414),
      appBar: AppBar(
        title: Text('Upgrade to ${plan['name']}'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Plan Header
                Container(
                  width: double.infinity,
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
                      Icon(Icons.workspace_premium, size: 48, color: accent),
                      const SizedBox(height: 12),
                      Text(
                        plan['name'] as String,
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        pitch,
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade400),
                      ),
                      if (widget.planType == 'listen') ...[
                        const SizedBox(height: 10),
                        Text(
                          l10n?.noizeListenCoreRevenueLabel ??
                              'Core subscription · Main revenue tier · Streams fund payouts',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: accent.withOpacity(0.95),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      if (widget.planType == 'rep') ...[
                        const SizedBox(height: 10),
                        Text(
                          l10n?.noizeRepEngagementLabel ??
                              'Engagement engine · Controlled growth · Token caps apply',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: accent.withOpacity(0.95),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      // Price Toggle
                      Container(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade900,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildPeriodButton('Monthly', 'monthly'),
                            _buildPeriodButton('Yearly', 'yearly'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '₹${(pricePaise / 100.0).toStringAsFixed(pricePaise % 100 == 0 ? 0 : 2)}',
                            style: TextStyle(
                              fontSize: 48,
                              fontWeight: FontWeight.bold,
                              color: accent,
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              ' / ${_selectedPeriod == 'monthly' ? 'mo' : 'yr'}',
                              style: TextStyle(
                                fontSize: 18,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ),
                        ],
                      ),
                      if (savings != null)
                        Text(
                          savings,
                          style: TextStyle(
                            fontSize: 14,
                            color: accent,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 32),
                
                // Features
                const Text(
                  'Included Features',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                ...(plan['features'] as List<String>).map((feature) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(
                      children: [
                        Icon(Icons.check_circle, color: accent, size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            feature,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey.shade300,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
                
                const SizedBox(height: 32),
                
                // Demo Payment Method
                const Text(
                  'Payment Method',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                _buildPaymentCard('demo_card', 'Demo Credit Card', Icons.credit_card),
                const SizedBox(height: 12),
                _buildPaymentCard('demo_upi', 'Demo UPI', Icons.qr_code),
                
                const SizedBox(height: 32),
                
                // Proceed Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _processing ? null : _processPayment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: _processing
                        ? const SizedBox(
                            height: 20,
                            width: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : Text(
                            'Proceed with Demo Payment',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: 16),
                Center(
                  child: Text(
                    '🔒 Demo Mode - No real charges',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade500,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPeriodButton(String label, String period) {
    final isSelected = _selectedPeriod == period;
    return GestureDetector(
      onTap: () => setState(() => _selectedPeriod = period),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF78E08F) : Colors.transparent,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.black : Colors.white70,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentCard(String id, String label, IconData icon) {
    final isSelected = _selectedPaymentMethod == id;
    return GestureDetector(
      onTap: () => setState(() => _selectedPaymentMethod = id),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF78E08F) : Colors.grey.shade700,
            width: 2,
          ),
        ),
        child: Row(
          children: [
            Icon(icon, color: isSelected ? const Color(0xFF78E08F) : Colors.grey.shade600),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.grey.shade400,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: const Color(0xFF78E08F)),
          ],
        ),
      ),
    );
  }
}

