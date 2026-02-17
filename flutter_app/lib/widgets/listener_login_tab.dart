import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/toast_util.dart';
import '../screens/listener_home_screen.dart';
import '../screens/listener_onboarding_screen.dart';

class ListenerLoginTab extends StatefulWidget {
  const ListenerLoginTab({super.key});

  @override
  State<ListenerLoginTab> createState() => _ListenerLoginTabState();
}

class _ListenerLoginTabState extends State<ListenerLoginTab> {
  final _contactController = TextEditingController();
  final _otpController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = AuthService();
  bool _otpSent = false;
  bool _loading = false;
  bool _useEmailPassword = false;
  bool _acceptedTerms = false;

  @override
  void dispose() {
    _contactController.dispose();
    _otpController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    final contact = _contactController.text.trim();
    if (contact.isEmpty) {
      showToast('Please enter your email or phone');
      return;
    }
    if (!_acceptedTerms) {
      showToast('Please accept the Terms and Conditions');
      return;
    }

    setState(() => _loading = true);
    try {
      final response = await _auth.requestOtp(contact);
      setState(() => _otpSent = true);
      // Show the OTP in the toast for demo purposes
      final otp = response['mock_otp'] ?? 'Check console';
      showToast('OTP sent! Demo OTP: $otp');
    } catch (e) {
      showToast('Failed to send OTP: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _verifyOtp() async {
    final contact = _contactController.text.trim();
    final otp = _otpController.text.trim();
    
    if (contact.isEmpty || otp.isEmpty) {
      showToast('Please enter contact and OTP');
      return;
    }
    if (!_acceptedTerms) {
      showToast('Please accept the Terms and Conditions');
      return;
    }

    setState(() => _loading = true);
    try {
      await _auth.verifyOtp(contact: contact, otp: otp);
      showToast('Login successful!');
      final me = await _auth.getMe();
      final needsOnboarding = (me?['full_name'] == null || (me?['full_name']?.toString().trim().isEmpty ?? true)) ||
          (me?['date_of_birth'] == null || (me?['date_of_birth']?.toString().trim().isEmpty ?? true));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => needsOnboarding ? const ListenerOnboardingScreen() : const ListenerHomeScreen()),
      );
    } catch (e) {
      showToast('Login failed: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loginWithEmailPassword() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      showToast('Please enter email and password');
      return;
    }
    if (!_acceptedTerms) {
      showToast('Please accept the Terms and Conditions');
      return;
    }

    setState(() => _loading = true);
    try {
      await _auth.loginEmailPassword(email: email, password: password);
      showToast('Login successful!');
      final me = await _auth.getMe();
      final needsOnboarding = (me?['full_name'] == null || (me?['full_name']?.toString().trim().isEmpty ?? true)) ||
          (me?['date_of_birth'] == null || (me?['date_of_birth']?.toString().trim().isEmpty ?? true));
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => needsOnboarding ? const ListenerOnboardingScreen() : const ListenerHomeScreen()),
      );
    } catch (e) {
      showToast('Login failed: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF78E08F);
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.grey.shade800),
            ),
            child: Row(
              children: [
                Expanded(
                  child: _LoginModeButton(
                    label: 'OTP',
                    selected: !_useEmailPassword,
                    onTap: _loading
                        ? null
                        : () {
                            setState(() {
                              _useEmailPassword = false;
                              _otpSent = false;
                            });
                          },
                    accent: accent,
                  ),
                ),
                Expanded(
                  child: _LoginModeButton(
                    label: 'Email',
                    selected: _useEmailPassword,
                    onTap: _loading
                        ? null
                        : () {
                            setState(() {
                              _useEmailPassword = true;
                              _otpSent = false;
                            });
                          },
                    accent: accent,
                  ),
                ),
              ],
            ),
          ),
            const SizedBox(height: 18),

          // Terms and Conditions Checkbox
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Checkbox(
                value: _acceptedTerms,
                onChanged: _loading
                    ? null
                    : (value) {
                        setState(() => _acceptedTerms = value ?? false);
                      },
                activeColor: accent,
              ),
              Expanded(
                child: GestureDetector(
                  onTap: _loading
                      ? null
                      : () => _showTermsDialog(context, accent),
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: RichText(
                      text: TextSpan(
                        style: TextStyle(
                          color: Colors.grey.shade300,
                          fontSize: 12,
                        ),
                        children: [
                          const TextSpan(text: 'I agree to the '),
                          TextSpan(
                            text: 'Terms and Conditions',
                            style: TextStyle(
                              color: accent,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                          const TextSpan(text: ' for NOIZE LISTEN'),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 48, bottom: 4),
            child: Text(
              'By subscribing, you support a platform that stands for ethical music distribution, peace-focused values, and global artistic inclusion.',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 12, height: 1.25),
            ),
          ),
          const SizedBox(height: 12),

          if (_useEmailPassword) ...[
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(
                labelText: 'Email',
                border: OutlineInputBorder(),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(
                labelText: 'Password',
                border: OutlineInputBorder(),
              ),
              obscureText: true,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: (_loading || !_acceptedTerms) ? null : _loginWithEmailPassword,
                child: _loading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Sign In'),
              ),
            ),
          ] else ...[
            if (!_otpSent) ...[
              TextField(
                controller: _contactController,
                decoration: const InputDecoration(
                  labelText: 'Email or Phone',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_loading || !_acceptedTerms) ? null : _requestOtp,
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Send OTP'),
                ),
              ),
            ] else ...[
              TextField(
                controller: _otpController,
                decoration: const InputDecoration(
                  labelText: 'Enter OTP',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: (_loading || !_acceptedTerms) ? null : _verifyOtp,
                  child: _loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Verify OTP'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _loading ? null : () => setState(() => _otpSent = false),
                child: const Text('Change contact'),
              ),
            ],
          ]
        ],
      ),
    );
  }

  Future<void> _showTermsDialog(BuildContext context, Color accent) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('Terms and Conditions', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Text(
            'NOIZE.MUSIC - LISTENER SUBSCRIPTION TERMS OF ACCESS (NOIZE LISTEN)\n\n'
            'Effective Date: [To Be Inserted]\n\n'
            '1. INTRODUCTION\n'
            'These terms govern access to NOIZE LISTEN - the subscription-based listener tier of NOIZE.music. '
            'By subscribing, you agree to these Terms of Access, our general Terms & Conditions, and Privacy Policy.\n\n'
            '2. FEATURES INCLUDED\n'
            '• Ad-free music streaming\n'
            '• Unlimited playlist creation\n'
            '• Offline listening & downloads\n'
            '• Exclusive editorial content\n'
            '• Access to premium curated stations\n\n'
            '3. LIMITATIONS\n'
            '• This tier does not include monetization features.\n'
            '• Users may not upload or distribute their own music.\n'
            '• Donations and campaign participation are optional.\n\n'
            '4. SUBSCRIPTION FEES\n'
            '• Monthly: \$4.99 USD (adjusted to local currency)\n'
            '• Annual: \$49.99 USD\n'
            'Fees are auto-renewable unless cancelled prior to the renewal date.\n\n'
            '5. REFUNDS & CANCELLATIONS\n'
            '• Subscriptions may be cancelled at any time via your app store account settings.\n'
            '• Refunds follow respective app store policies (Apple App Store or Google Play).\n\n'
            '6. DEVICE USAGE\n'
            '• Subscriptions apply to individual accounts only.\n'
            '• You may use NOIZE Listen on up to 5 devices simultaneously.',
            style: TextStyle(color: Colors.grey.shade300, fontSize: 13),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.black),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

class _LoginModeButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final Color accent;

  const _LoginModeButton({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: selected ? accent : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              color: selected ? Colors.black : Colors.white70,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}
