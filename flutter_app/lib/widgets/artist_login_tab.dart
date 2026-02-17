import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/toast_util.dart';
import '../screens/artist_signup_screen.dart';
import '../screens/artist_home_screen.dart';

class ArtistLoginTab extends StatefulWidget {
  const ArtistLoginTab({super.key});

  @override
  State<ArtistLoginTab> createState() => _ArtistLoginTabState();
}

class _ArtistLoginTabState extends State<ArtistLoginTab> {
  final _contactController = TextEditingController();
  final _otpController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = AuthService();
  bool _otpSent = false;
  bool _loading = false;
  bool _useEmailPassword = false; // Toggle between OTP and email/password

  @override
  void dispose() {
    _contactController.dispose();
    _otpController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _loginEmailPassword() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    
    if (email.isEmpty || password.isEmpty) {
      showToast('Please enter email and password');
      return;
    }

    setState(() => _loading = true);
    try {
      await _auth.loginEmailPassword(email: email, password: password);
      showToast('Login successful!');
      
      // Check if user already has a channel
      final user = await _auth.getMe();
      if (mounted) {
        if (user != null && user['channel_name'] != null) {
          // User has channel, go directly to dashboard
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const ArtistHomeScreen()),
          );
        } else {
          // No channel, go to signup screen
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ArtistSignupScreen()),
          );
          if (result == true && mounted) {
            // Profile created, navigate to artist home
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const ArtistHomeScreen()),
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
      
      // Check if user already has a channel
      final user = await _auth.getMe();
      if (mounted) {
        if (user != null && user['channel_name'] != null) {
          // User has channel, go directly to dashboard
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const ArtistHomeScreen()),
          );
        } else {
          // No channel, go to signup screen
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const ArtistSignupScreen()),
          );
          if (result == true && mounted) {
            // Profile created, navigate to artist home
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const ArtistHomeScreen()),
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
          // Info Card
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withOpacity(0.3)),
            ),
            child: Column(
              children: [
                Icon(Icons.music_note, size: 48, color: accent),
                const SizedBox(height: 12),
                const Text(
                  'NOIZE Artist',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Upload music, build your fanbase,\nearn from your art',
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
          
          // Toggle between OTP and Email/Password
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ChoiceChip(
                label: const Text('OTP Login'),
                selected: !_useEmailPassword,
                onSelected: (selected) {
                  if (selected) setState(() => _useEmailPassword = false);
                },
                selectedColor: accent,
                labelStyle: TextStyle(
                  color: !_useEmailPassword ? Colors.black : Colors.white,
                ),
              ),
              const SizedBox(width: 16),
              ChoiceChip(
                label: const Text('Email/Password'),
                selected: _useEmailPassword,
                onSelected: (selected) {
                  if (selected) setState(() => _useEmailPassword = true);
                },
                selectedColor: accent,
                labelStyle: TextStyle(
                  color: _useEmailPassword ? Colors.black : Colors.white,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          if (_useEmailPassword) ...[
            // Email/Password Login
            TextField(
              controller: _emailController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Email',
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
                  borderSide: BorderSide(color: accent, width: 2),
                ),
              ),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _passwordController,
              style: const TextStyle(color: Colors.white),
              obscureText: true,
              decoration: InputDecoration(
                labelText: 'Password',
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
                  borderSide: BorderSide(color: accent, width: 2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _loginEmailPassword,
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
                    : const Text('Login', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ] else if (!_otpSent) ...[
            TextField(
              controller: _contactController,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Email or Phone',
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
                  borderSide: BorderSide(color: accent, width: 2),
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
                  borderSide: BorderSide(color: accent, width: 2),
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
                    : const Text('Verify & Continue', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
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
