// lib/screens/creator_signup_screen.dart
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/toast_util.dart';
import '../config/api_config.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;

class CreatorSignupScreen extends StatefulWidget {
  const CreatorSignupScreen({super.key});

  @override
  State<CreatorSignupScreen> createState() => _CreatorSignupScreenState();
}

class _CreatorSignupScreenState extends State<CreatorSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _displayNameController = TextEditingController();
  final _socialHandleController = TextEditingController();
  final _auth = AuthService();
  bool _loading = false;

  String? _selectedSocialPlatform;
  final List<String> _platforms = ['Instagram', 'YouTube', 'TikTok', 'Twitter/X', 'Other'];

  @override
  void dispose() {
    _displayNameController.dispose();
    _socialHandleController.dispose();
    super.dispose();
  }

  Future<void> _submitProfile() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedSocialPlatform == null) {
      showToast('Please select a social platform');
      return;
    }

    setState(() => _loading = true);
    try {
      await _createCreatorProfile();
      showToast('Creator profile created successfully!');
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      showToast('Failed to create profile: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  /// Backend role remains `influencer` for API compatibility; product name is Creator.
  Future<void> _createCreatorProfile() async {
    final base = Uri.parse(apiBaseUrl);
    final uri = base.replace(path: '${base.path}/user/upgrade');
    final resp = await http.post(
      uri,
      headers: {..._auth.authHeader, 'Content-Type': 'application/json'},
      body: jsonEncode({
        'role': 'influencer',
        'kyc_verified': false,
        'display_name': _displayNameController.text.trim(),
        'social_platform': _selectedSocialPlatform,
        'social_handle': _socialHandleController.text.trim(),
      }),
    );

    if (resp.statusCode != 200) {
      throw Exception('Failed to create profile');
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF78E08F);

    return Scaffold(
      backgroundColor: const Color(0xFF111414),
      appBar: AppBar(
        title: const Text('Become a Creator'),
        backgroundColor: Colors.transparent,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                        Icon(Icons.auto_awesome, size: 48, color: accent),
                        const SizedBox(height: 12),
                        const Text(
                          'NOIZE Creator',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Build playlists, promote music like an influencer, and earn rewards',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade300,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Display name',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _displayNameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'How you want to be known',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
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
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Display name is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Primary social platform',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedSocialPlatform,
                    decoration: InputDecoration(
                      hintText: 'Select platform',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
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
                    dropdownColor: Colors.grey.shade900,
                    style: const TextStyle(color: Colors.white),
                    items: _platforms.map((platform) {
                      return DropdownMenuItem(
                        value: platform,
                        child: Text(platform),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedSocialPlatform = value),
                    validator: (value) => value == null ? 'Please select a platform' : null,
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Social handle',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _socialHandleController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: '@yourhandle',
                      hintStyle: TextStyle(color: Colors.grey.shade500),
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
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Social handle is required';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.shade900.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accent.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline, color: accent, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'KYC verification',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Full KYC is required for paid creator payouts.\nYou will need:\n• Government ID\n• Live selfie',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade300,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _submitProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _loading
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.black,
                              ),
                            )
                          : const Text(
                              'Create profile',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: Text(
                      'Demo mode — no real verification required',
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
      ),
    );
  }
}
