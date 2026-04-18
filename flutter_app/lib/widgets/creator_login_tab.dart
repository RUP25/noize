import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/toast_util.dart';
import '../screens/creator_signup_screen.dart';
import '../screens/creator_home_screen.dart';

class CreatorLoginTab extends StatefulWidget {
  const CreatorLoginTab({super.key});

  @override
  State<CreatorLoginTab> createState() => _CreatorLoginTabState();
}

class _CreatorLoginTabState extends State<CreatorLoginTab> {
  final _contactController = TextEditingController();
  final _otpController = TextEditingController();
  final _auth = AuthService();
  bool _otpSent = false;
  bool _loading = false;

  @override
  void dispose() {
    _contactController.dispose();
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _requestOtp() async {
    final contact = _contactController.text.trim();
    if (contact.isEmpty) {
      showToast('Please enter your email or phone');
      return;
    }

    setState(() => _loading = true);
    try {
      final response = await _auth.requestOtp(contact);
      setState(() => _otpSent = true);
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

    setState(() => _loading = true);
    try {
      await _auth.verifyOtp(contact: contact, otp: otp);
      showToast('Login successful!');

      if (mounted) {
        final result = await Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const CreatorSignupScreen()),
        );
        if (result == true) {
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const CreatorHomeScreen()),
            );
          }
        }
      }
    } catch (e) {
      showToast('Login failed: $e');
    } finally {
      setState(() => _loading = false);
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
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Icon(Icons.auto_awesome, size: 48, color: accent),
                const SizedBox(height: 12),
                const Text(
                  'NOIZE Creator',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Curate playlists, promote music,\nearn as a music influencer',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey.shade400,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),
          if (!_otpSent) ...[
            TextField(
              controller: _contactController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Email or phone',
                labelStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade700),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade700),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: accent, width: 2),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _requestOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text('Send OTP', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ] else ...[
            TextField(
              controller: _otpController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Enter OTP',
                labelStyle: const TextStyle(color: Colors.grey),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade700),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: Colors.grey.shade700),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: accent, width: 2),
                ),
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _verifyOtp,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _loading
                    ? const CircularProgressIndicator(color: Colors.black)
                    : const Text('Verify & create profile', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => setState(() => _otpSent = false),
              child: const Text('Change contact', style: TextStyle(color: Colors.grey)),
            ),
          ],
        ],
      ),
    );
  }
}
