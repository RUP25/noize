// lib/screens/listener_profile_screen.dart
import 'dart:convert';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../l10n/app_localizations.dart';
import 'package:http/http.dart' as http;

import '../config/api_config.dart';
import '../services/auth_service.dart';
import '../utils/toast_util.dart';
import '../providers/language_provider.dart';
import 'welcome_screen.dart';

class ListenerProfileScreen extends StatefulWidget {
  const ListenerProfileScreen({super.key});

  @override
  State<ListenerProfileScreen> createState() => _ListenerProfileScreenState();
}

class _ListenerProfileScreenState extends State<ListenerProfileScreen> {
  final AuthService _auth = AuthService();

  Map<String, dynamic>? _userData;
  bool _loading = true;

  bool _uploadingPhoto = false;
  bool _uploadingBanner = false;

  String? _photoUrl;
  String? _bannerUrl;

  @override
  void initState() {
    super.initState();
    _loadUser();
  }

  Future<void> _loadUser() async {
    setState(() => _loading = true);
    try {
      final user = await _auth.getMe();
      if (!mounted) return;
      setState(() {
        _userData = user;
        _photoUrl = user?['photo_url']?.toString();
        _bannerUrl = user?['banner_url']?.toString();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      showToast('Failed to load profile: $e');
    }
  }

  Future<void> _pickAndUpload({required bool isBanner}) async {
    try {
      final file = await openFile(
        acceptedTypeGroups: [
          const XTypeGroup(label: 'images', extensions: ['jpg', 'jpeg', 'png', 'webp'])
        ],
      );
      if (file == null) return;
      final bytes = await file.readAsBytes();
      if (bytes.length < 10) return;

      final isValidImage = bytes.length >= 4 &&
          ((bytes[0] == 0xFF && bytes[1] == 0xD8 && bytes[2] == 0xFF) || // JPEG
              (bytes[0] == 0x89 && bytes[1] == 0x50 && bytes[2] == 0x4E && bytes[3] == 0x47) || // PNG
              (bytes[0] == 0x52 && bytes[1] == 0x49 && bytes[2] == 0x46 && bytes[3] == 0x46)); // WEBP/RIFF
      if (!isValidImage) {
        showToast('Invalid image file');
        return;
      }

      await _uploadImage(filename: file.name, bytes: bytes, isBanner: isBanner);
    } catch (e) {
      showToast('Failed to pick image: $e');
    }
  }

  Future<void> _uploadImage({required String filename, required Uint8List bytes, required bool isBanner}) async {
    setState(() {
      if (isBanner) {
        _uploadingBanner = true;
      } else {
        _uploadingPhoto = true;
      }
    });

    try {
      final base = Uri.parse(apiBaseUrl);
      final uploadUri = base.replace(path: '${base.path}/media/upload-proxy');

      final request = http.MultipartRequest('POST', uploadUri);
      request.headers.addAll(_auth.authHeader);
      request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: filename));

      final streamed = await request.send();
      final resp = await http.Response.fromStream(streamed);
      if (resp.statusCode != 200) {
        throw Exception('Upload failed: ${resp.statusCode}');
      }

      final data = jsonDecode(resp.body) as Map<String, dynamic>;
      final key = data['key'] as String;
      final publicUrl = base.replace(path: '${base.path}/media/public/${Uri.encodeComponent(key)}').toString();

      if (isBanner) {
        await _auth.updateProfile(bannerUrl: publicUrl);
      } else {
        await _auth.updateProfile(photoUrl: publicUrl);
      }

      if (!mounted) return;
      setState(() {
        if (isBanner) {
          _bannerUrl = publicUrl;
          _uploadingBanner = false;
        } else {
          _photoUrl = publicUrl;
          _uploadingPhoto = false;
        }
      });
      showToast(isBanner ? 'Banner updated' : 'Profile photo updated');
      _loadUser();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _uploadingBanner = false;
        _uploadingPhoto = false;
      });
      showToast('Upload failed: $e');
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
              : RefreshIndicator(
                  onRefresh: _loadUser,
                  child: SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHeader(accent),
                        const SizedBox(height: 16),
                        _buildSection(
                          title: AppLocalizations.of(context)?.settings ?? 'Settings',
                          icon: Icons.settings,
                          color: accent,
                          children: [
                            _buildMenuItem(
                              icon: Icons.notifications,
                              title: AppLocalizations.of(context)?.notifications ?? 'Notifications',
                              subtitle: AppLocalizations.of(context)?.manageNotificationPreferences ?? 'Manage notification preferences',
                              onTap: () => _showNotificationSettingsDialog(context, accent),
                            ),
                            _buildMenuItem(
                              icon: Icons.privacy_tip,
                              title: AppLocalizations.of(context)?.privacy ?? 'Privacy',
                              subtitle: AppLocalizations.of(context)?.managePrivacyPreferences ?? 'Manage privacy preferences',
                              onTap: () => _showPrivacySettingsDialog(context, accent),
                            ),
                            _buildMenuItem(
                              icon: Icons.language,
                              title: AppLocalizations.of(context)?.language ?? 'Language',
                              subtitle: languageProvider.getCurrentLanguageName(),
                              onTap: () => _showLanguageDialog(context, accent),
                            ),
                            _buildMenuItem(
                              icon: Icons.location_on,
                              title: AppLocalizations.of(context)?.location ?? 'Location',
                              subtitle: (_userData?['location'] ?? (AppLocalizations.of(context)?.locationNotSet ?? 'Not set')).toString(),
                              onTap: () => _showLocationDialog(context, accent),
                            ),
                          ],
                        ),
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
                              icon: Icons.logout,
                              title: AppLocalizations.of(context)?.logout ?? 'Logout',
                              subtitle: AppLocalizations.of(context)?.signOutOfDevice ?? 'Sign out of this device',
                              onTap: () async {
                                await _auth.logout();
                                if (!context.mounted) return;
                                Navigator.of(context).pushAndRemoveUntil(
                                  MaterialPageRoute(builder: (_) => const WelcomeScreen()),
                                  (Route<dynamic> route) => false,
                                );
                              },
                              isDestructive: true,
                            ),
                            _buildMenuItem(
                              icon: Icons.delete_forever,
                              title: AppLocalizations.of(context)?.deleteAccount ?? 'Delete Account',
                              subtitle: AppLocalizations.of(context)?.permanentlyDeleteAccount ?? 'Permanently delete your account',
                              onTap: () => _showDeleteAccountDialog(context),
                              isDestructive: true,
                            ),
                          ],
                        ),
                        _buildSection(
                          title: AppLocalizations.of(context)?.supportAndFeedback ?? 'Support & Feedback',
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
                        _buildSection(
                          title: AppLocalizations.of(context)?.termsOfService ?? 'Terms',
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
                              onTap: () => _showPrivacyPolicyDialog(context, accent),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }

  Widget _buildHeader(Color accent) {
    final fullName = _userData?['full_name']?.toString().trim();
    final channelName = _userData?['channel_name']?.toString().trim();
    final displayName = (fullName != null && fullName.isNotEmpty)
        ? fullName
        : ((channelName != null && channelName.isNotEmpty) ? channelName : 'Listener');
    final email = _userData?['email']?.toString();

    return SizedBox(
      height: 240,
      child: Stack(
        children: [
          // Banner
          Container(
            height: 170,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.grey.shade900,
              gradient: LinearGradient(
                colors: [accent.withOpacity(0.25), Colors.black.withOpacity(0.2)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: _bannerUrl != null && _bannerUrl!.isNotEmpty
                ? Image.network(
                    _bannerUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                  )
                : const SizedBox.shrink(),
          ),
          // Banner edit
          Positioned(
            top: 12,
            right: 12,
            child: _uploadingBanner
                ? Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)),
                  )
                : IconButton.filled(
                    style: IconButton.styleFrom(
                      backgroundColor: Colors.black54,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => _pickAndUpload(isBanner: true),
                    icon: const Icon(Icons.photo_camera),
                    tooltip: 'Change banner',
                  ),
          ),
          // Avatar + info card
          Positioned(
            left: 16,
            right: 16,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              decoration: BoxDecoration(
                color: const Color(0xFF111414),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: Colors.grey.shade800),
              ),
              child: Row(
                children: [
                  Stack(
                    children: [
                      Container(
                        width: 84,
                        height: 84,
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
                                  errorBuilder: (_, __, ___) => Icon(Icons.person, size: 42, color: accent),
                                ),
                              )
                            : Icon(Icons.person, size: 42, color: accent),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: _uploadingPhoto
                            ? Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Colors.black54,
                                  border: Border.all(color: const Color(0xFF111414), width: 2),
                                ),
                                child: const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)),
                              )
                            : Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: accent,
                                  border: Border.all(color: const Color(0xFF111414), width: 2),
                                ),
                                child: IconButton(
                                  icon: const Icon(Icons.camera_alt, size: 18),
                                  color: Colors.black,
                                  onPressed: () => _pickAndUpload(isBanner: false),
                                  tooltip: 'Change profile photo',
                                ),
                              ),
                      ),
                    ],
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                        ),
                        if (email != null && email.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            email,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: Colors.grey.shade400),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
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
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
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
    final iconColor = isDestructive ? Colors.red : Colors.white;
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
              child: Icon(icon, color: iconColor, size: 22),
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
                      color: isDestructive ? Colors.red : Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: TextStyle(fontSize: 13, color: Colors.grey.shade400),
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

  Future<void> _showNotificationSettingsDialog(BuildContext context, Color accent) async {
    Map<String, dynamic> settings;
    try {
      settings = await _auth.getSettings();
    } catch (e) {
      showToast('Failed to load settings: $e');
      return;
    }

    final notificationSettings = Map<String, dynamic>.from(settings['notification_settings'] ?? {});

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.grey.shade900,
          title: const Text('Notification Settings', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('Push Notifications', style: TextStyle(color: Colors.white)),
                  value: notificationSettings['push_notifications'] ?? true,
                  activeColor: accent,
                  onChanged: (v) => setState(() => notificationSettings['push_notifications'] = v),
                ),
                SwitchListTile(
                  title: const Text('Email Notifications', style: TextStyle(color: Colors.white)),
                  value: notificationSettings['email_notifications'] ?? false,
                  activeColor: accent,
                  onChanged: (v) => setState(() => notificationSettings['email_notifications'] = v),
                ),
                SwitchListTile(
                  title: const Text('New Message', style: TextStyle(color: Colors.white)),
                  value: notificationSettings['new_message'] ?? true,
                  activeColor: accent,
                  onChanged: (v) => setState(() => notificationSettings['new_message'] = v),
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
                try {
                  await _auth.updateSettings(notificationSettings: notificationSettings);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  showToast('Saved');
                } catch (e) {
                  showToast('Failed: $e');
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.black),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPrivacySettingsDialog(BuildContext context, Color accent) async {
    Map<String, dynamic> settings;
    try {
      settings = await _auth.getSettings();
    } catch (e) {
      showToast('Failed to load settings: $e');
      return;
    }

    final privacySettings = Map<String, dynamic>.from(settings['privacy_settings'] ?? {});

    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: Colors.grey.shade900,
          title: const Text('Privacy Settings', style: TextStyle(color: Colors.white)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SwitchListTile(
                  title: const Text('Public Profile', style: TextStyle(color: Colors.white)),
                  value: privacySettings['public_profile'] ?? true,
                  activeColor: accent,
                  onChanged: (v) => setState(() => privacySettings['public_profile'] = v),
                ),
                SwitchListTile(
                  title: const Text('Allow Messages', style: TextStyle(color: Colors.white)),
                  value: privacySettings['allow_messages'] ?? true,
                  activeColor: accent,
                  onChanged: (v) => setState(() => privacySettings['allow_messages'] = v),
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
                try {
                  await _auth.updateSettings(privacySettings: privacySettings);
                  if (!context.mounted) return;
                  Navigator.pop(context);
                  showToast('Saved');
                } catch (e) {
                  showToast('Failed: $e');
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.black),
              child: const Text('Save'),
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
                    await _loadUser();
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
              style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.black),
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
    final controller = TextEditingController(text: (_userData?['location'] ?? '').toString());
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('Location', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            labelText: 'Location',
            labelStyle: const TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent)),
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
                if (!context.mounted) return;
                Navigator.pop(context);
                await _loadUser();
                showToast('Updated');
              } catch (e) {
                showToast('Failed: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.black),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showChangePasswordDialog(BuildContext context, Color accent) async {
    final currentController = TextEditingController();
    final newController = TextEditingController();
    final confirmController = TextEditingController();

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
                controller: currentController,
                style: const TextStyle(color: Colors.white),
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Current Password',
                  labelStyle: const TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: newController,
                style: const TextStyle(color: Colors.white),
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'New Password',
                  labelStyle: const TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: confirmController,
                style: const TextStyle(color: Colors.white),
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Confirm New Password',
                  labelStyle: const TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent)),
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
              if (newController.text != confirmController.text) {
                showToast('Passwords do not match');
                return;
              }
              try {
                await _auth.changePassword(currentPassword: currentController.text, newPassword: newController.text);
                if (!context.mounted) return;
                Navigator.pop(context);
                showToast('Password updated');
              } catch (e) {
                showToast('Failed: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.black),
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteAccountDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('Delete Account', style: TextStyle(color: Colors.red)),
        content: const Text(
          'This will permanently delete your account and all data. This cannot be undone.',
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
    if (confirmed != true) return;

    try {
      await _auth.deleteAccount();
      if (!context.mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
        (Route<dynamic> route) => false,
      );
      showToast('Account deleted');
    } catch (e) {
      showToast('Failed: $e');
    }
  }

  Future<void> _showFeedbackDialog(BuildContext context, Color accent) async {
    final feedbackController = TextEditingController();
    final emailController = TextEditingController(text: (_userData?['email'] ?? '').toString());

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
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: feedbackController,
                style: const TextStyle(color: Colors.white),
                maxLines: 5,
                decoration: InputDecoration(
                  labelText: 'Your feedback',
                  labelStyle: const TextStyle(color: Colors.grey),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent)),
                  focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent)),
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
                showToast('Please enter feedback');
                return;
              }
              try {
                await _auth.submitFeedback(
                  feedbackController.text.trim(),
                  email: emailController.text.trim().isEmpty ? null : emailController.text.trim(),
                );
                if (!context.mounted) return;
                Navigator.pop(context);
                showToast('Thanks for the feedback!');
              } catch (e) {
                showToast('Failed: $e');
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: accent, foregroundColor: Colors.black),
            child: const Text('Send'),
          ),
        ],
      ),
    );
  }

  Future<void> _showSupportDialog(BuildContext context, Color accent) async {
    if (!mounted) return;
    final role = _userData?['user_role']?.toString();
    final supportEmail = role == 'rep' ? 'rep@noize.music' : 'support@noize.music';
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
                'Contact: $supportEmail',
                style: TextStyle(color: Colors.grey.shade300, fontSize: 14),
              ),
            ],
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

  Future<void> _showTermsDialog(BuildContext context, Color accent) async {
    if (!mounted) return;
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

  Future<void> _showPrivacyPolicyDialog(BuildContext context, Color accent) async {
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text('Privacy Policy', style: TextStyle(color: Colors.white)),
        content: Text(
          'Privacy Policy\n\n'
          'We use your information to provide and improve NOIZE.music.\n'
          'We do not sell your personal information.\n\n'
          'For full policy details, please visit our website.',
          style: TextStyle(color: Colors.grey.shade300),
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

