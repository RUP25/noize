// lib/screens/listener_onboarding_screen.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../services/auth_service.dart';
import '../utils/toast_util.dart';
import 'listener_home_screen.dart';

class ListenerOnboardingScreen extends StatefulWidget {
  const ListenerOnboardingScreen({super.key});

  @override
  State<ListenerOnboardingScreen> createState() => _ListenerOnboardingScreenState();
}

class _ListenerOnboardingScreenState extends State<ListenerOnboardingScreen> {
  final AuthService _auth = AuthService();
  final _fullNameController = TextEditingController();

  Map<String, dynamic>? _user;
  bool _loading = true;
  bool _saving = false;

  DateTime? _dob;
  Uint8List? _photoBytes;
  String? _photoUrl;

  @override
  void initState() {
    super.initState();
    _loadMe();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    super.dispose();
  }

  Future<void> _loadMe() async {
    setState(() => _loading = true);
    final me = await _auth.getMe();
    if (!mounted) return;
    setState(() {
      _user = me;
      _fullNameController.text = (me?['full_name'] ?? '').toString();
      final dobStr = me?['date_of_birth']?.toString();
      if (dobStr != null && dobStr.isNotEmpty) {
        _dob = DateTime.tryParse(dobStr);
      }
      _photoUrl = me?['photo_url']?.toString();
      _loading = false;
    });
  }

  Future<void> _pickDob() async {
    final now = DateTime.now();
    final initial = _dob ?? DateTime(now.year - 18, 1, 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900, 1, 1),
      lastDate: DateTime(now.year, now.month, now.day),
      helpText: 'Select Date of Birth',
    );
    if (picked != null && mounted) {
      setState(() => _dob = picked);
    }
  }

  Future<void> _pickAndUploadPhoto() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(label: 'images', extensions: ['jpg', 'jpeg', 'png', 'webp'])
        ],
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length < 10) return;
      setState(() => _photoBytes = bytes);
      await _uploadPhoto(file.name, bytes);
    } catch (e) {
      showToast('Failed to pick photo: $e');
    }
  }

  Future<void> _uploadPhoto(String filename, Uint8List bytes) async {
    try {
      final base = Uri.parse(apiBaseUrl);
      final uploadUri = base.replace(path: '${base.path}/media/upload-proxy');
      final request = http.MultipartRequest('POST', uploadUri);
      request.headers.addAll(_auth.authHeader);
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));
      final streamed = await request.send();
      final resp = await http.Response.fromStream(streamed);
      if (resp.statusCode != 200) throw Exception('Upload failed: ${resp.statusCode}');
      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final key = data['key'] as String;
      final publicUrl = base.replace(path: '${base.path}/media/public/${Uri.encodeComponent(key)}').toString();
      if (!mounted) return;
      setState(() => _photoUrl = publicUrl);
    } catch (e) {
      showToast('Photo upload failed: $e');
    }
  }

  String _formatDob(DateTime? d) {
    if (d == null) return 'Select date of birth';
    final mm = d.month.toString().padLeft(2, '0');
    final dd = d.day.toString().padLeft(2, '0');
    return '${d.year}-$mm-$dd';
  }

  Future<void> _save() async {
    final fullName = _fullNameController.text.trim();
    if (fullName.isEmpty) {
      showToast('Please enter your full name');
      return;
    }
    if (_dob == null) {
      showToast('Please select your date of birth');
      return;
    }

    setState(() => _saving = true);
    try {
      await _auth.updateProfile(
        fullName: fullName,
        dateOfBirth: _formatDob(_dob),
        photoUrl: _photoUrl,
      );
      showToast('Profile saved!');
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ListenerHomeScreen()),
      );
    } catch (e) {
      showToast('Failed to save: $e');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF78E08F);
    final userId = _user?['id']?.toString() ?? '';

    return Scaffold(
      backgroundColor: const Color(0xFF111414),
      appBar: AppBar(
        title: const Text('Complete your profile'),
        backgroundColor: Colors.grey.shade900,
        foregroundColor: Colors.white,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: accent.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 72,
                          height: 72,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.grey.shade800,
                            border: Border.all(color: accent, width: 3),
                          ),
                          child: _photoUrl != null && _photoUrl!.isNotEmpty
                              ? ClipOval(
                                  child: Image.network(
                                    _photoUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (_, __, ___) => Icon(Icons.person, color: accent, size: 36),
                                  ),
                                )
                              : (_photoBytes != null && _photoBytes!.isNotEmpty)
                                  ? ClipOval(child: Image.memory(_photoBytes!, fit: BoxFit.cover))
                                  : Icon(Icons.person, color: accent, size: 36),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Profile photo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                              const SizedBox(height: 4),
                              Text(
                                'Add a photo so friends recognize you.',
                                style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: _saving ? null : _pickAndUploadPhoto,
                          icon: const Icon(Icons.camera_alt),
                          color: accent,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  TextField(
                    controller: _fullNameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Full name',
                      labelStyle: const TextStyle(color: Colors.grey),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: Colors.grey.shade700),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: accent, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  InkWell(
                    onTap: _saving ? null : _pickDob,
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade900,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade800),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.cake, color: accent),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _formatDob(_dob),
                              style: TextStyle(color: _dob == null ? Colors.grey.shade400 : Colors.white),
                            ),
                          ),
                          Icon(Icons.chevron_right, color: Colors.grey.shade600),
                        ],
                      ),
                    ),
                  ),

                  if (userId.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Your User ID: $userId',
                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                    ),
                  ],

                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving ? null : _save,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: accent,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      child: _saving
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Continue', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

