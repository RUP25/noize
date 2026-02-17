// lib/screens/artist_signup_screen.dart
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import '../services/auth_service.dart';
import '../services/upload_service.dart';
import '../utils/toast_util.dart';
import '../config/api_config.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;

class ArtistSignupScreen extends StatefulWidget {
  const ArtistSignupScreen({super.key});

  @override
  State<ArtistSignupScreen> createState() => _ArtistSignupScreenState();
}

class _ArtistSignupScreenState extends State<ArtistSignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _channelNameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _contactController = TextEditingController();
  final _auth = AuthService();
  final _upload = UploadService();
  bool _loading = false;
  
  XFile? _bannerFile;
  XFile? _photoFile;
  String? _bannerUrl;
  String? _photoUrl;
  Uint8List? _bannerBytes;
  Uint8List? _photoBytes;

  @override
  void dispose() {
    _channelNameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _contactController.dispose();
    super.dispose();
  }

  Future<void> _pickBanner() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(label: 'images', extensions: ['jpg', 'jpeg', 'png', 'webp'])
        ],
      );
      if (file != null) {
        try {
          final bytes = await file.readAsBytes();
          if (bytes.isNotEmpty && bytes.length > 10 && mounted) {
            // Validate it's a valid image by checking magic bytes
            final isValidImage = bytes.length >= 4 && (
              (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) || // JPEG
              (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) || // PNG
              (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46) // WEBP/RIFF
            );
            if (isValidImage && mounted) {
              setState(() {
                _bannerFile = file;
                _bannerBytes = bytes;
              });
              await _uploadImage(file, isBanner: true);
            } else if (mounted) {
              showToast('Invalid image file');
            }
          }
        } catch (e) {
          if (mounted) {
            showToast('Failed to load image: $e');
          }
        }
      }
    } catch (e) {
      showToast('Failed to pick banner: $e');
    }
  }

  Future<void> _pickPhoto() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(label: 'images', extensions: ['jpg', 'jpeg', 'png', 'webp'])
        ],
      );
      if (file != null) {
        try {
          final bytes = await file.readAsBytes();
          if (bytes.isNotEmpty && bytes.length > 10 && mounted) {
            // Validate it's a valid image by checking magic bytes
            final isValidImage = bytes.length >= 4 && (
              (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) || // JPEG
              (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) || // PNG
              (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46) // WEBP/RIFF
            );
            if (isValidImage && mounted) {
              setState(() {
                _photoFile = file;
                _photoBytes = bytes;
              });
              await _uploadImage(file, isBanner: false);
            } else if (mounted) {
              showToast('Invalid image file');
            }
          }
        } catch (e) {
          if (mounted) {
            showToast('Failed to load image: $e');
          }
        }
      }
    } catch (e) {
      showToast('Failed to pick photo: $e');
    }
  }

  Future<void> _uploadImage(XFile file, {required bool isBanner}) async {
    try {
      final filename = file.name;
      final bytes = await file.readAsBytes();
      final contentType = _lookupContentType(filename);

      // Use proxy upload for web to avoid CORS issues
      final base = Uri.parse(apiBaseUrl);
      final uploadUri = base.replace(path: '${base.path}/media/upload-proxy');
      
      final request = http.MultipartRequest('POST', uploadUri);
      request.headers.addAll(_auth.authHeader);
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
        ),
      );
      
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode != 200) {
        throw Exception('Upload failed: ${response.statusCode}');
      }
      
      final data = jsonDecode(response.body);
      final key = data['key'] as String;
      
      // Get the download URL
      final downloadUri = base.replace(path: '${base.path}/media/download/${Uri.encodeComponent(key)}');
      
      setState(() {
        if (isBanner) {
          _bannerUrl = downloadUri.toString();
        } else {
          _photoUrl = downloadUri.toString();
        }
      });
    } catch (e) {
      showToast('Failed to upload image: $e');
    }
  }

  String _lookupContentType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    return 'image/jpeg';
  }

  Future<void> _submitProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _loading = true);
    try {
      // Check if user is already logged in (from OTP or email/password)
      if (!_auth.isLoggedIn) {
        // User not logged in, sign up with email/password first
        final email = _emailController.text.trim();
        final password = _passwordController.text.trim();
        final contact = _contactController.text.trim();
        
        if (email.isEmpty || password.isEmpty || contact.isEmpty) {
          showToast('Please fill in all required fields');
          setState(() => _loading = false);
          return;
        }
        
        await _auth.signupEmailPassword(
          email: email,
          password: password,
          contact: contact,
        );
      }
      
      // Create channel
      await _createChannel();
      showToast('Artist profile created successfully!');
      if (mounted) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      showToast('Failed to create profile: $e');
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _createChannel() async {
    final base = Uri.parse(apiBaseUrl);
    final uri = base.replace(path: '${base.path}/artist/create');
    final resp = await http.post(
      uri,
      headers: {..._auth.authHeader, 'Content-Type': 'application/json'},
      body: jsonEncode({
        'channel_name': _channelNameController.text.trim(),
        if (_bannerUrl != null) 'banner_url': _bannerUrl,
        if (_photoUrl != null) 'photo_url': _photoUrl,
      }),
    );
    
    if (resp.statusCode != 200) {
      final errorBody = resp.body.isNotEmpty ? jsonDecode(resp.body) : {};
      throw Exception(errorBody['detail'] ?? 'Failed to create channel');
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF78E08F);
    
    return Scaffold(
      backgroundColor: const Color(0xFF111414),
      appBar: AppBar(
        title: const Text('Create Artist Profile'),
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
                  // Header
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
                        Icon(Icons.music_note, size: 48, color: accent),
                        const SizedBox(height: 12),
                        const Text(
                          'NOIZE Artist',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Upload music, build your fanbase, earn from your art',
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
                  
                  // Email (if not logged in)
                  if (!_auth.isLoggedIn) ...[
                    Text(
                      'Email',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _emailController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: 'your@email.com',
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
                          borderSide: BorderSide(color: accent, width: 2),
                        ),
                      ),
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Email is required';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    
                    // Password
                    Text(
                      'Password',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _passwordController,
                      style: const TextStyle(color: Colors.white),
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: 'At least 6 characters',
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
                          borderSide: BorderSide(color: accent, width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Password is required';
                        }
                        if (value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    
                    // Confirm Password
                    Text(
                      'Confirm Password',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _confirmPasswordController,
                      style: const TextStyle(color: Colors.white),
                      obscureText: true,
                      decoration: InputDecoration(
                        hintText: 'Re-enter password',
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
                          borderSide: BorderSide(color: accent, width: 2),
                        ),
                      ),
                      validator: (value) {
                        if (value != _passwordController.text) {
                          return 'Passwords do not match';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                    
                    // Phone Number
                    Text(
                      'Phone Number',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _contactController,
                      style: const TextStyle(color: Colors.white),
                      decoration: InputDecoration(
                        hintText: '+1234567890',
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
                          borderSide: BorderSide(color: accent, width: 2),
                        ),
                      ),
                      keyboardType: TextInputType.phone,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Phone number is required';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 24),
                  ],
                  
                  // Channel Name
                  Text(
                    'Channel Name',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _channelNameController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: 'Your artist name',
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
                        borderSide: BorderSide(color: accent, width: 2),
                      ),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Channel name is required';
                      }
                      if (value.trim().length < 3) {
                        return 'Channel name must be at least 3 characters';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                  
                  // Channel Banner
                  Text(
                    'Channel Banner',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickBanner,
                    child: Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade900,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: _bannerFile != null ? accent : Colors.grey.shade700,
                          width: 2,
                        ),
                      ),
                      child: _bannerBytes != null && _bannerBytes!.isNotEmpty
                          ? ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: Image.memory(
                                _bannerBytes!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(Icons.error, color: Colors.red);
                                },
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.image, size: 48, color: Colors.grey.shade600),
                                const SizedBox(height: 8),
                                Text(
                                  'Tap to upload banner',
                                  style: TextStyle(color: Colors.grey.shade400),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Profile Photo
                  Text(
                    'Profile Photo',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: _pickPhoto,
                    child: Container(
                      height: 120,
                      width: 120,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade900,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _photoFile != null ? accent : Colors.grey.shade700,
                          width: 2,
                        ),
                      ),
                      child: _photoBytes != null && _photoBytes!.isNotEmpty
                          ? ClipOval(
                              child: Image.memory(
                                _photoBytes!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) {
                                  return const Icon(Icons.error, color: Colors.red);
                                },
                              ),
                            )
                          : Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.person, size: 48, color: Colors.grey.shade600),
                                const SizedBox(height: 4),
                                Text(
                                  'Photo',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey.shade400,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  
                  // Submit Button
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
                              'Create Profile',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
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
