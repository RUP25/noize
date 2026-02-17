import 'package:flutter/material.dart';
import '../services/media_service.dart';
import '../services/auth_service.dart';
import '../utils/toast_util.dart';
import 'artist_channel_page.dart';

class ArtistTab extends StatefulWidget {
  const ArtistTab({super.key});

  @override
  State<ArtistTab> createState() => _ArtistTabState();
}

class _ArtistTabState extends State<ArtistTab> {
  final MediaService _media = MediaService();
  final AuthService _auth = AuthService();
  String? _existingChannel;

  @override
  void initState() {
    super.initState();
    _checkForExistingChannel();
  }

  Future<void> _checkForExistingChannel() async {
    final user = await _auth.getMe();
    if (user != null && user['channel_name'] != null) {
      setState(() {
        _existingChannel = user['channel_name'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: _auth.authToken,
      builder: (_, token, __) {
        if (!_auth.isLoggedIn) {
          return const Center(child: Text('Please log in to upload music.'));
        }
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(32.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.music_note, size: 80, color: Colors.grey.shade600),
                const SizedBox(height: 24),
                const Text(
                  'Welcome to NOIZE Artist',
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Create or open your channel to start uploading music',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade400,
                  ),
                ),
                const SizedBox(height: 32),
                if (_existingChannel != null) ...[
                  // Show existing channel button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ArtistChannelPage(channelName: _existingChannel!),
                          ),
                        );
                      },
                      icon: const Icon(Icons.account_circle),
                      label: const Text('Open My Channel'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF78E08F),
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _createOrOpenChannel,
                    icon: Icon(_existingChannel != null ? Icons.edit : Icons.person),
                    label: Text(_existingChannel != null ? 'Change Channel Name' : 'Create Channel'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade800,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _createOrOpenChannel() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Create Channel'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'Channel Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(context, true), child: const Text('Create')),
        ],
      ),
    );
    if (ok != true) return;

    try {
      final res = await _media.createChannel(controller.text.trim());
      showToast('Channel Created!');
      if (context.mounted) {
        setState(() {
          _existingChannel = res['channel_name'] ?? controller.text.trim();
        });
        Navigator.push(context,
            MaterialPageRoute(builder: (_) => ArtistChannelPage(channelName: res['channel_name'] ?? controller.text.trim())));
      }
    } catch (e) {
      final errorMsg = e.toString();
      if (errorMsg.contains('Already has a channel')) {
        showToast('You already have a channel. Use "Open My Channel" button.');
      } else {
        showToast('Failed: $e');
      }
    }
  }

}
