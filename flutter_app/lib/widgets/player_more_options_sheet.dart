import 'package:flutter/material.dart';
import 'package:share_plus/share_plus.dart';
import '../services/media_service.dart';
import '../utils/toast_util.dart';
import 'artist_channel_page.dart';

enum _MorePanel {
  main,
  addToPlaylist,       // shows "New playlist" + "Your playlists"
  addToPlaylistList,   // shows actual playlists list
  goToArtist,
  share,
}

Future<void> showPlayerMoreOptionsSheet({
  required BuildContext context,
  required Map<String, dynamic>? song,
}) async {
  const accent = Color(0xFF78E08F);
  final media = MediaService();

  final songId = song?['id'] is int ? song!['id'] as int : null;
  final title = song?['title']?.toString().trim().isNotEmpty == true ? song!['title'].toString() : 'Unknown';
  final artistName = _artistNameFromSong(song);

  Widget row({
    required IconData icon,
    required String label,
    bool hasSubmenu = false,
    VoidCallback? onTap,
  }) {
    return ListTile(
      dense: true,
      leading: Icon(icon, color: Colors.white),
      title: Text(label, style: const TextStyle(color: Colors.white, fontSize: 14)),
      trailing: hasSubmenu ? const Icon(Icons.chevron_right, color: Colors.white) : null,
      onTap: onTap,
    );
  }

  await showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setState) {
          _MorePanel panel = _MorePanel.main;

          void go(_MorePanel next) => setState(() => panel = next);
          void back() => setState(() => panel = _MorePanel.main);

          Widget header(String text, {VoidCallback? onBack}) {
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Row(
                children: [
                  if (onBack != null)
                    IconButton(
                      icon: const Icon(Icons.chevron_left, color: Colors.white),
                      onPressed: onBack,
                    )
                  else
                    const SizedBox(width: 48),
                  Expanded(
                    child: Text(
                      text,
                      style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            );
          }

          Widget mainPanel() {
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                header(''),
                row(
                  icon: Icons.playlist_add,
                  label: 'Add to playlist',
                  hasSubmenu: true,
                  onTap: songId == null ? null : () => go(_MorePanel.addToPlaylist),
                ),
                row(
                  icon: Icons.add_circle_outline,
                  label: 'Save to your Liked Songs',
                  onTap: songId == null
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          try {
                            await media.likeSong(songId);
                            showToast('Saved to Liked Songs');
                          } catch (e) {
                            showToast('Failed: $e');
                          }
                        },
                ),
                row(
                  icon: Icons.queue_music,
                  label: 'Add to queue',
                  onTap: () {
                    Navigator.pop(ctx);
                    showToast('Added to queue (coming soon)');
                  },
                ),
                row(
                  icon: Icons.block,
                  label: 'Exclude from your taste profile',
                  onTap: () {
                    Navigator.pop(ctx);
                    showToast('Coming soon');
                  },
                ),
                Divider(height: 1, color: Colors.grey.shade800),
                row(
                  icon: Icons.radio,
                  label: 'Go to song radio',
                  onTap: () {
                    Navigator.pop(ctx);
                    showToast('Coming soon');
                  },
                ),
                row(
                  icon: Icons.person_outline,
                  label: 'Go to artist',
                  hasSubmenu: true,
                  onTap: artistName.trim().isEmpty ? null : () => go(_MorePanel.goToArtist),
                ),
                row(
                  icon: Icons.album_outlined,
                  label: 'Go to album',
                  onTap: () {
                    Navigator.pop(ctx);
                    showToast('Coming soon');
                  },
                ),
                row(
                  icon: Icons.info_outline,
                  label: 'View credits',
                  onTap: () {
                    Navigator.pop(ctx);
                    showDialog<void>(
                      context: context,
                      builder: (_) => AlertDialog(
                        backgroundColor: Colors.grey.shade900,
                        title: const Text('Credits', style: TextStyle(color: Colors.white)),
                        content: Text(
                          'Credits coming soon.',
                          style: TextStyle(color: Colors.grey.shade300),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('OK', style: TextStyle(color: accent)),
                          )
                        ],
                      ),
                    );
                  },
                ),
                row(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  hasSubmenu: true,
                  onTap: () => go(_MorePanel.share),
                ),
                const SizedBox(height: 8),
              ],
            );
          }

          Widget addToPlaylistPanel() {
            return Column(
              children: [
                header('Add to playlist', onBack: back),
                row(
                  icon: Icons.playlist_add,
                  label: 'New playlist',
                  onTap: songId == null
                      ? null
                      : () async {
                          Navigator.pop(ctx);
                          // Simple name prompt
                          final controller = TextEditingController();
                          final ok = await showDialog<bool>(
                            context: context,
                            builder: (_) => AlertDialog(
                              backgroundColor: Colors.grey.shade900,
                              title: const Text('New playlist', style: TextStyle(color: Colors.white)),
                              content: TextField(
                                controller: controller,
                                autofocus: true,
                                style: const TextStyle(color: Colors.white),
                                decoration: const InputDecoration(
                                  hintText: 'Playlist name',
                                  hintStyle: TextStyle(color: Colors.grey),
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(context, false),
                                  child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
                                ),
                                TextButton(
                                  onPressed: () => Navigator.pop(context, true),
                                  child: const Text('Create', style: TextStyle(color: accent)),
                                ),
                              ],
                            ),
                          );
                          final name = controller.text.trim();
                          if (ok != true || name.isEmpty) return;
                          try {
                            final created = await media.createPlaylist(name);
                            final pid = created['id']?.toString();
                            if (pid != null) {
                              await media.addToPlaylist(pid, songId!);
                              showToast('Added to $name');
                            } else {
                              showToast('Playlist created, but no id returned');
                            }
                          } catch (e) {
                            showToast('Failed: $e');
                          }
                        },
                ),
                row(
                  icon: Icons.queue_music,
                  label: 'Your playlists',
                  hasSubmenu: true,
                  onTap: () => go(_MorePanel.addToPlaylistList),
                ),
              ],
            );
          }

          Widget addToPlaylistListPanel() {
            return Column(
              children: [
                header('Your playlists', onBack: () => go(_MorePanel.addToPlaylist)),
                Expanded(
                  child: FutureBuilder<List<dynamic>>(
                    future: media.getPlaylists(),
                    builder: (ctx, snap) {
                      final playlists = snap.data ?? const <dynamic>[];
                      if (snap.connectionState == ConnectionState.waiting) {
                        return const Center(child: CircularProgressIndicator(color: accent));
                      }
                      if (snap.hasError) {
                        return Center(
                          child: Text('Failed to load playlists', style: TextStyle(color: Colors.grey.shade400)),
                        );
                      }
                      if (playlists.isEmpty) {
                        return Center(
                          child: Text('No playlists yet', style: TextStyle(color: Colors.grey.shade400)),
                        );
                      }
                      return ListView.separated(
                        itemCount: playlists.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: Colors.grey.shade800),
                        itemBuilder: (ctx, index) {
                          final p = playlists[index] as Map<String, dynamic>;
                          final name = p['name']?.toString() ?? 'Playlist';
                          final pid = p['id']?.toString();
                          return ListTile(
                            dense: true,
                            title: Text(name, style: const TextStyle(color: Colors.white)),
                            subtitle: Text(
                              p['is_public'] == true ? 'Public' : 'Private',
                              style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                            ),
                            onTap: (pid == null || songId == null)
                                ? null
                                : () async {
                                    try {
                                      await media.addToPlaylist(pid, songId);
                                      Navigator.pop(ctx);
                                      showToast('Added to $name');
                                    } catch (e) {
                                      showToast('Failed: $e');
                                    }
                                  },
                          );
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          }

          Widget goToArtistPanel() {
            final channel = _artistChannelFromSong(song) ?? artistName;
            return Column(
              children: [
                header('Go to artist', onBack: back),
                ListTile(
                  leading: const Icon(Icons.person_outline, color: Colors.white),
                  title: Text(channel, style: const TextStyle(color: Colors.white)),
                  onTap: () {
                    Navigator.pop(ctx);
                    if (channel.trim().isEmpty) {
                      showToast('Artist not available');
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => ArtistChannelPage(channelName: channel)),
                    );
                  },
                ),
              ],
            );
          }

          Widget sharePanel() {
            final msg = artistName.isNotEmpty ? '$title — $artistName' : title;
            return Column(
              children: [
                header('Share', onBack: back),
                row(
                  icon: Icons.share_outlined,
                  label: 'Share',
                  onTap: () async {
                    Navigator.pop(ctx);
                    await Share.share(msg);
                  },
                ),
                row(
                  icon: Icons.copy,
                  label: 'Copy',
                  onTap: () async {
                    Navigator.pop(ctx);
                    // Clipboard util lives in Flutter services; keep it simple via toast for now.
                    showToast('Copy link coming soon');
                  },
                ),
              ],
            );
          }

          Widget panelFor(_MorePanel p) {
            switch (p) {
              case _MorePanel.main:
                return mainPanel();
              case _MorePanel.addToPlaylist:
                return addToPlaylistPanel();
              case _MorePanel.addToPlaylistList:
                return addToPlaylistListPanel();
              case _MorePanel.goToArtist:
                return goToArtistPanel();
              case _MorePanel.share:
                return sharePanel();
            }
          }

          // Side-slide animation: main stays on the left, subpanel slides in from right.
          return LayoutBuilder(
            builder: (ctx, constraints) {
              final w = constraints.maxWidth;
              final h = MediaQuery.of(ctx).size.height * 0.72;
              final showSub = panel != _MorePanel.main;
              return Container(
                height: h,
                decoration: BoxDecoration(
                  color: Colors.grey.shade900,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                ),
                child: ClipRRect(
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
                  child: Stack(
                    children: [
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        left: showSub ? -w : 0,
                        top: 0,
                        bottom: 0,
                        width: w,
                        child: SafeArea(top: false, child: mainPanel()),
                      ),
                      AnimatedPositioned(
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOut,
                        left: showSub ? 0 : w,
                        top: 0,
                        bottom: 0,
                        width: w,
                        child: SafeArea(top: false, child: panelFor(panel)),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    },
  );
}

String _artistNameFromSong(Map<String, dynamic>? song) {
  if (song == null) return '';
  final a = song['artist'];
  if (a is Map && a['channel_name'] != null) return a['channel_name'].toString();
  if (a != null) return a.toString();
  return '';
}

String? _artistChannelFromSong(Map<String, dynamic>? song) {
  if (song == null) return null;
  final a = song['artist'];
  if (a is Map && a['channel_name'] != null) return a['channel_name'].toString();
  return null;
}

