import 'package:flutter/material.dart';
import '../services/media_service.dart';
import '../widgets/artist_channel_page.dart';

class PopularArtistsScreen extends StatefulWidget {
  const PopularArtistsScreen({super.key});

  @override
  State<PopularArtistsScreen> createState() => _PopularArtistsScreenState();
}

class _PopularArtistsScreenState extends State<PopularArtistsScreen> {
  final MediaService _media = MediaService();
  bool _loading = true;
  List<dynamic> _artists = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await _media.getPopularArtists(limit: 50);
      if (mounted) setState(() => _artists = res);
    } catch (_) {
      if (mounted) setState(() => _artists = []);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    const accent = Color(0xFF78E08F);
    return Scaffold(
      backgroundColor: const Color(0xFF111414),
      appBar: AppBar(
        backgroundColor: Colors.grey.shade900,
        title: const Text('Popular artists', style: TextStyle(color: Colors.white)),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 5,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.78,
              ),
              itemCount: _artists.length,
              itemBuilder: (context, index) {
                final a = _artists[index] as Map<String, dynamic>;
                final name = a['channel_name']?.toString() ?? 'Artist';
                final photo = a['photo_url']?.toString();

                return InkWell(
                  onTap: () {
                    if (name.isEmpty) return;
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ArtistChannelPage(channelName: name)),
                    );
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(14),
                      color: Colors.grey.shade900,
                      border: Border.all(color: Colors.grey.shade800),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 44,
                          backgroundColor: Colors.grey.shade800,
                          backgroundImage: (photo != null && photo.isNotEmpty) ? NetworkImage(photo) : null,
                          child: (photo == null || photo.isEmpty)
                              ? const Icon(Icons.account_circle, color: Colors.white, size: 56)
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 4),
                        Text('Artist', style: TextStyle(color: Colors.grey.shade400, fontSize: 12)),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: accent.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(color: accent.withOpacity(0.25)),
                          ),
                          child: Text(
                            'Popular',
                            style: TextStyle(color: accent.withOpacity(0.95), fontSize: 11, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
    );
  }
}

