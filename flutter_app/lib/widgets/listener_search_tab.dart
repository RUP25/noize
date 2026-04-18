import 'package:flutter/material.dart';
import '../services/media_service.dart';
import '../utils/toast_util.dart';
import 'artist_channel_page.dart';

class ListenerSearchTab extends StatefulWidget {
  const ListenerSearchTab({super.key});

  @override
  State<ListenerSearchTab> createState() => _ListenerSearchTabState();
}

class _ListenerSearchTabState extends State<ListenerSearchTab> {
  final _search = TextEditingController();
  final _media = MediaService();
  bool _loading = false;
  List<dynamic> _results = [];

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _search,
                decoration: const InputDecoration(
                  hintText: 'Search songs, albums, channels...',
                  border: OutlineInputBorder(),
                ),
                onSubmitted: (_) => _searchArtist(),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              onPressed: _searchArtist,
              icon: const Icon(Icons.search),
              color: const Color(0xFF78E08F),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_loading)
          const SizedBox(
            height: 100,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_results.isEmpty && _search.text.isEmpty)
          SizedBox(
            height: 100,
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.search, size: 64, color: Colors.grey.shade600),
                  const SizedBox(height: 16),
                  Text(
                    'Search for your favorite music',
                    style: TextStyle(color: Colors.grey.shade400),
                  ),
                ],
              ),
            ),
          )
        else if (_results.isNotEmpty)
          Container(
            height: 300,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _results.length,
              itemBuilder: (_, i) {
                final item = _results[i];
                String name;
                String? photoUrl;
                if (item is String) {
                  name = item;
                } else if (item is Map<String, dynamic>) {
                  name = item['channel_name']?.toString() ??
                      item['name']?.toString() ??
                      'Unknown';
                  photoUrl = item['photo_url']?.toString();
                } else {
                  name = item.toString();
                }
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: const Color(0xFF78E08F),
                    backgroundImage: (photoUrl != null && photoUrl.isNotEmpty)
                        ? NetworkImage(photoUrl)
                        : null,
                    child: (photoUrl == null || photoUrl.isEmpty)
                        ? const Icon(Icons.account_circle, color: Colors.black)
                        : null,
                  ),
                  title: Text(name, style: const TextStyle(color: Colors.white)),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => ArtistChannelPage(channelName: name)),
                  ),
                );
              },
            ),
          ),
      ],
    );
  }

  void _searchArtist() async {
    final q = _search.text.trim();
    if (q.isEmpty) {
      showToast('Enter search query');
      return;
    }
    setState(() => _loading = true);
    try {
      final found = await _media.searchArtist(q);
      setState(() => _results = found);
    } catch (e) {
      showToast('Search failed: $e');
    } finally {
      setState(() => _loading = false);
    }
  }
}