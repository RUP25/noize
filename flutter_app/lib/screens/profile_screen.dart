// lib/screens/profile_screen.dart
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import 'dart:typed_data';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../services/auth_service.dart';
import '../utils/toast_util.dart';
import '../config/api_config.dart';
import '../providers/language_provider.dart';
import 'welcome_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final AuthService _auth = AuthService();
  Map<String, dynamic>? _userData;
  bool _loading = true;
  bool _uploadingPhoto = false;
  Uint8List? _profilePhotoBytes;
  String? _profilePhotoUrl;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    setState(() => _loading = true);
    try {
      final user = await _auth.getMe();
      if (mounted) {
        setState(() {
          _userData = user;
          _profilePhotoUrl = user?['photo_url'];
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showToast('Failed to load profile: $e');
      }
    }
  }

  Future<void> _pickAndUploadProfilePhoto() async {
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(label: 'images', extensions: ['jpg', 'jpeg', 'png', 'webp'])
        ],
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty && bytes.length > 10 && mounted) {
          // Validate it's a valid image
          final isValidImage = bytes.length >= 4 && (
            (bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) || // JPEG
            (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) || // PNG
            (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46) // WEBP/RIFF
          );
          if (isValidImage && mounted) {
            setState(() {
              _profilePhotoBytes = bytes;
            });
            await _uploadProfilePhoto(file.name, bytes);
          } else if (mounted) {
            showToast('Invalid image file');
          }
        }
      }
    } catch (e) {
      showToast('Failed to pick profile photo: $e');
    }
  }

  Future<void> _uploadProfilePhoto(String filename, Uint8List bytes) async {
    setState(() => _uploadingPhoto = true);
    try {
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
      
      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Upload timeout. Check if backend is running at $apiBaseUrl');
        },
      );
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode != 200) {
        String errorMsg = 'Upload failed: ${response.statusCode}';
        try {
          final errorData = jsonDecode(response.body);
          errorMsg += ' - ${errorData['detail'] ?? errorData}';
        } catch (_) {
          errorMsg += ' - ${response.body}';
        }
        throw Exception(errorMsg);
      }
      
      final data = jsonDecode(response.body);
      final key = data['key'] as String;
      
      // Get the public URL
      final publicUrl = base.replace(path: '${base.path}/media/public/${Uri.encodeComponent(key)}').toString();
      
      // Update profile with photo URL
      await _auth.updateProfile(photoUrl: publicUrl);
      
      if (mounted) {
        setState(() {
          _profilePhotoUrl = publicUrl;
          _uploadingPhoto = false;
        });
        showToast('Profile photo updated successfully');
        _loadUserData(); // Refresh user data
      }
    } catch (e) {
      if (mounted) {
        setState(() => _uploadingPhoto = false);
        String errorMessage = 'Failed to upload profile photo';
        if (e.toString().contains('Failed to fetch') || e.toString().contains('Network error')) {
          errorMessage = 'Cannot connect to backend at $apiBaseUrl. Make sure the backend is running.';
        } else {
          errorMessage = 'Failed to upload profile photo: $e';
        }
        showToast(errorMessage);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF78E08F);

    return Consumer<LanguageProvider>(
      builder: (context, languageProvider, child) {
        return Scaffold(
          backgroundColor: const Color(0xFF111414),
          appBar: AppBar(
            title: Text(AppLocalizations.of(context)?.profile ?? 'Profile'),
            backgroundColor: Colors.grey.shade900,
            foregroundColor: Colors.white,
          ),
          body: _loading
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                  // Profile Picture Section
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade900,
                      border: Border(
                        bottom: BorderSide(color: Colors.grey.shade800),
                      ),
                    ),
                    child: Column(
                      children: [
                        Stack(
                          children: [
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.grey.shade800,
                                border: Border.all(
                                  color: accent,
                                  width: 3,
                                ),
                              ),
                              child: _profilePhotoUrl != null && _profilePhotoUrl!.isNotEmpty
                                  ? ClipOval(
                                      child: Image.network(
                                        _profilePhotoUrl!,
                                        fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) {
                                          return Icon(Icons.person, size: 60, color: accent);
                                        },
                                      ),
                                    )
                                  : Icon(Icons.person, size: 60, color: accent),
                            ),
                            if (_uploadingPhoto)
                              Positioned.fill(
                                child: Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.black54,
                                  ),
                                  child: const Center(
                                    child: CircularProgressIndicator(),
                                  ),
                                ),
                              ),
                            Positioned(
                              bottom: 0,
                              right: 0,
                              child: Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: accent,
                                  border: Border.all(color: Colors.grey.shade900, width: 3),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.camera_alt, size: 20),
                                  color: Colors.black,
                                  onPressed: _uploadingPhoto ? null : _pickAndUploadProfilePhoto,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _userData?['channel_name'] ?? 'Artist',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        if (_userData?['email'] != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              _userData!['email'],
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade400,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),

                  // Settings Section
                  _buildSection(
                    title: AppLocalizations.of(context)?.settings ?? 'Settings',
                    icon: Icons.settings,
                    color: accent,
                    children: [
                      _buildMenuItem(
                        icon: Icons.notifications,
                        title: AppLocalizations.of(context)?.notifications ?? 'Notifications',
                        subtitle: AppLocalizations.of(context)?.manageNotificationPreferences ?? 'Manage notification preferences',
                        onTap: () => _showSettingsDialog(context, accent),
                      ),
                      _buildMenuItem(
                        icon: Icons.language,
                        title: AppLocalizations.of(context)?.language ?? 'Language',
                        subtitle: Provider.of<LanguageProvider>(context, listen: true).getCurrentLanguageName(),
                        onTap: () => _showLanguageDialog(context, accent),
                      ),
                      _buildMenuItem(
                        icon: Icons.location_on,
                        title: AppLocalizations.of(context)?.location ?? 'Location',
                        subtitle: _userData?['location'] ?? (AppLocalizations.of(context)?.locationNotSet ?? 'Not set'),
                        onTap: () => _showLocationDialog(context, accent),
                      ),
                    ],
                  ),

                  // Account Section
                  _buildSection(
                    title: AppLocalizations.of(context)?.account ?? 'Account',
                    icon: Icons.account_circle,
                    color: Colors.blue,
                    children: [
                      _buildMenuItem(
                        icon: Icons.lock,
                        title: AppLocalizations.of(context)?.changePassword ?? 'Change Password',
                        subtitle: AppLocalizations.of(context)?.updateYourPassword ?? 'Update your password',
                        onTap: () => _showChangePasswordDialog(context, accent),
                      ),
                      _buildMenuItem(
                        icon: Icons.delete_forever,
                        title: AppLocalizations.of(context)?.deleteAccount ?? 'Delete Account',
                        subtitle: AppLocalizations.of(context)?.permanentlyDeleteAccount ?? 'Permanently delete your account',
                        onTap: () => _showDeleteAccountDialog(context, accent),
                        isDestructive: true,
                      ),
                    ],
                  ),

                  // Terms and Conditions Section
                  _buildSection(
                    title: AppLocalizations.of(context)?.legal ?? 'Legal',
                    icon: Icons.description,
                    color: Colors.purple,
                    children: [
                      _buildMenuItem(
                        icon: Icons.description,
                        title: AppLocalizations.of(context)?.termsAndConditions ?? 'Terms and Conditions',
                        subtitle: AppLocalizations.of(context)?.viewTermsAndConditions ?? 'View terms and conditions',
                        onTap: () => _showTermsDialog(context, accent),
                      ),
                      _buildMenuItem(
                        icon: Icons.privacy_tip,
                        title: AppLocalizations.of(context)?.privacyPolicy ?? 'Privacy Policy',
                        subtitle: AppLocalizations.of(context)?.viewPrivacyPolicy ?? 'View privacy policy',
                        onTap: () => _showPrivacyDialog(context, accent),
                      ),
                    ],
                  ),

                  // Support and Feedback Section
                  _buildSection(
                    title: AppLocalizations.of(context)?.support ?? 'Support',
                    icon: Icons.support_agent,
                    color: Colors.orange,
                    children: [
                      _buildMenuItem(
                        icon: Icons.feedback,
                        title: AppLocalizations.of(context)?.sendFeedback ?? 'Send Feedback',
                        subtitle: AppLocalizations.of(context)?.shareYourThoughts ?? 'Share your thoughts and suggestions',
                        onTap: () => _showFeedbackDialog(context, accent),
                      ),
                      _buildMenuItem(
                        icon: Icons.help_outline,
                        title: AppLocalizations.of(context)?.helpAndSupport ?? 'Help & Support',
                        subtitle: AppLocalizations.of(context)?.getHelpWithAccount ?? 'Get help with your account',
                        onTap: () => _showSupportDialog(context, accent),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
        );
      },
    );
  }

  Widget _buildSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
          child: Row(
            children: [
              Icon(icon, color: color, size: 24),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        ...children,
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool isDestructive = false,
  }) {
    final color = isDestructive ? Colors.red : Colors.white;
    return InkWell(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey.shade900,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade800),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (isDestructive ? Colors.red : Colors.grey.shade800).withOpacity(0.3),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade400,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.grey.shade600),
          ],
        ),
      ),
    );
  }

  Future<void> _showSettingsDialog(BuildContext context, Color accent) async {
    Map<String, dynamic>? settings;
    try {
      settings = await _auth.getSettings();
    } catch (e) {
      showToast('Failed to load settings: $e');
      return;
    }

    final notificationSettings = Map<String, dynamic>.from(
      settings?['notification_settings'] ?? {},
    );

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.grey.shade900,
          title: Text(AppLocalizations.of(context)?.notificationSettings ?? 'Notification Settings', style: const TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: Text(AppLocalizations.of(context)?.pushNotifications ?? 'Push Notifications', style: const TextStyle(color: Colors.white)),
                  value: notificationSettings['push_notifications'] ?? true,
                  activeColor: accent,
                  onChanged: (value) {
                    setState(() {
                      notificationSettings['push_notifications'] = value;
                    });
                  },
                ),
                SwitchListTile(
                  title: Text(AppLocalizations.of(context)?.emailNotifications ?? 'Email Notifications', style: const TextStyle(color: Colors.white)),
                  value: notificationSettings['email_notifications'] ?? false,
                  activeColor: accent,
                  onChanged: (value) {
                    setState(() {
                      notificationSettings['email_notifications'] = value;
                    });
                  },
                ),
                SwitchListTile(
                  title: Text(AppLocalizations.of(context)?.newFollower ?? 'New Follower', style: const TextStyle(color: Colors.white)),
                  value: notificationSettings['new_follower'] ?? true,
                  activeColor: accent,
                  onChanged: (value) {
                    setState(() {
                      notificationSettings['new_follower'] = value;
                    });
                  },
                ),
                SwitchListTile(
                  title: Text(AppLocalizations.of(context)?.newLike ?? 'New Like', style: const TextStyle(color: Colors.white)),
                  value: notificationSettings['new_like'] ?? true,
                  activeColor: accent,
                  onChanged: (value) {
                    setState(() {
                      notificationSettings['new_like'] = value;
                    });
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(AppLocalizations.of(context)?.cancel ?? 'Cancel', style: const TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  await _auth.updateSettings(notificationSettings: notificationSettings);
                  if (context.mounted) {
                    Navigator.pop(context);
                    showToast(AppLocalizations.of(context)?.saved ?? 'Settings updated successfully');
                  }
                } catch (e) {
                  if (context.mounted) {
                    showToast('${AppLocalizations.of(context)?.saveFailed ?? 'Failed to update settings'}: $e');
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: accent),
              child: Text(AppLocalizations.of(context)?.save ?? 'Save', style: const TextStyle(color: Colors.black)),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLanguageDialog(BuildContext context, Color accent) async {
    if (!mounted) return;
    
    // Get language provider
    final languageProvider = Provider.of<LanguageProvider>(context, listen: false);
    final supportedLanguages = languageProvider.supportedLanguages;
    String currentLanguageCode = languageProvider.getCurrentLanguageCode();

    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.grey.shade900,
          title: Text(
            AppLocalizations.of(context)?.selectLanguage ?? 'Select Language',
            style: const TextStyle(color: Colors.white),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: supportedLanguages.map((lang) {
              final code = lang['code'] as String;
              final name = lang['name'] as String;
              return RadioListTile<String>(
                title: Text(name, style: const TextStyle(color: Colors.white)),
                value: code,
                groupValue: currentLanguageCode,
                activeColor: accent,
                onChanged: (value) {
                  setState(() => currentLanguageCode = value ?? 'en');
                },
              );
            }).toList(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                AppLocalizations.of(context)?.cancel ?? 'Cancel',
                style: const TextStyle(color: Colors.grey),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                try {
                  // Change language globally
                  await languageProvider.setLanguage(currentLanguageCode);
                  
                  if (context.mounted) {
                    Navigator.pop(context);
                    _loadUserData();
                    showToast(
                      AppLocalizations.of(context)?.languageUpdated ?? 
                      'Language updated successfully'
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    showToast(
                      AppLocalizations.of(context)?.languageUpdateFailed ?? 
                      'Failed to update language: $e'
                    );
                  }
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: accent),
              child: Text(
                AppLocalizations.of(context)?.save ?? 'Save',
                style: const TextStyle(color: Colors.black),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showLocationDialog(BuildContext context, Color accent) async {
    final controller = TextEditingController(text: _userData?['location'] ?? '');

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('Update Location', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Location',
            labelStyle: const TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: accent),
            ),
            focusedBorder: UnderlineInputBorder(
              borderSide: BorderSide(color: accent),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              try {
                await _auth.updateSettings(location: controller.text.trim());
                if (context.mounted) {
                  Navigator.pop(context);
                  _loadUserData();
                  showToast('Location updated successfully');
                }
              } catch (e) {
                if (context.mounted) {
                  showToast('Failed to update location: $e');
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: accent),
            child: const Text('Save', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Future<void> _showChangePasswordDialog(BuildContext context, Color accent) async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('Change Password', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: currentPasswordController,
                style: const TextStyle(color: Colors.white),
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  labelStyle: const TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: accent),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: accent),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: newPasswordController,
                style: const TextStyle(color: Colors.white),
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  labelStyle: const TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: accent),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: accent),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: confirmPasswordController,
                style: const TextStyle(color: Colors.white),
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  labelStyle: const TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: accent),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: accent),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (newPasswordController.text != confirmPasswordController.text) {
                showToast('Passwords do not match');
                return;
              }
              if (newPasswordController.text.length < 6) {
                showToast('Password must be at least 6 characters');
                return;
              }
              try {
                await _auth.changePassword(
                  currentPassword: currentPasswordController.text,
                  newPassword: newPasswordController.text,
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  showToast('Password changed successfully');
                }
              } catch (e) {
                if (context.mounted) {
                  showToast('Failed to change password: $e');
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: accent),
            child: const Text('Change Password', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteAccountDialog(BuildContext context, Color accent) async {
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
        content: const Text(
          'Are you sure you want to delete your account? This action cannot be undone and all your data will be permanently deleted.',
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      try {
        await _auth.deleteAccount();
        if (mounted) {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const WelcomeScreen()),
            (Route<dynamic> route) => false,
          );
          showToast('Account deleted successfully');
        }
      } catch (e) {
        if (mounted) {
          showToast('Failed to delete account: $e');
        }
      }
    }
  }

  Future<void> _showTermsDialog(BuildContext context, Color accent) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('Terms and Conditions', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Text(
            'Terms and Conditions\n\n'
            'By using NOIZE.music, you agree to the following terms:\n\n'
            '1. You are responsible for all content you upload.\n'
            '2. You must not upload copyrighted material without permission.\n'
            '3. You must not use the service for illegal purposes.\n'
            '4. We reserve the right to remove content that violates these terms.\n'
            '5. Your account may be suspended or terminated for violations.\n\n'
            'For the complete terms and conditions, please visit our website.',
            style: TextStyle(color: Colors.grey.shade300),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: accent),
            child: const Text('Close', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Future<void> _showPrivacyDialog(BuildContext context, Color accent) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('Privacy Policy', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Text(
            'Privacy Policy\n\n'
            'Your privacy is important to us. This policy explains how we collect, use, and protect your information:\n\n'
            '1. We collect information you provide when creating an account.\n'
            '2. We use your information to provide and improve our services.\n'
            '3. We do not sell your personal information to third parties.\n'
            '4. You can update or delete your information at any time.\n'
            '5. We use industry-standard security measures to protect your data.\n\n'
            'For the complete privacy policy, please visit our website.',
            style: TextStyle(color: Colors.grey.shade300),
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: accent),
            child: const Text('Close', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Future<void> _showFeedbackDialog(BuildContext context, Color accent) async {
    final feedbackController = TextEditingController();
    final emailController = TextEditingController(text: _userData?['email'] ?? '');

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('Send Feedback', style: TextStyle(color: Colors.white)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  labelText: 'Email (optional)',
                  labelStyle: const TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: accent),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: accent),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: feedbackController,
                style: const TextStyle(color: Colors.white),
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: 'Your Feedback',
                  labelStyle: const TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: accent),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: accent),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () async {
              if (feedbackController.text.trim().isEmpty) {
                showToast('Please enter your feedback');
                return;
              }
              try {
                await _auth.submitFeedback(
                  feedbackController.text.trim(),
                  email: emailController.text.trim().isEmpty ? null : emailController.text.trim(),
                );
                if (context.mounted) {
                  Navigator.pop(context);
                  showToast('Thank you for your feedback!');
                }
              } catch (e) {
                if (context.mounted) {
                  showToast('Failed to submit feedback: $e');
                }
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: accent),
            child: const Text('Send', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }

  Future<void> _showSupportDialog(BuildContext context, Color accent) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('SUPPORT', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Contact us at: support@noize.music',
                style: TextStyle(color: Colors.grey.shade300, fontSize: 14),
              ),
            ],
          ),
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(backgroundColor: accent),
            child: const Text('Close', style: TextStyle(color: Colors.black)),
          ),
        ],
      ),
    );
  }
}
