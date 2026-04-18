import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';
import '../services/media_service.dart';
import '../utils/toast_util.dart';
import '../l10n/app_localizations.dart';
import '../config/api_config.dart';
import '../widgets/media_player_widget.dart';
import '../providers/player_state_provider.dart';

class PlaylistDetailScreen extends StatefulWidget {
  final String playlistId;
  final String playlistName;
  final bool isPublic;
  final String? coverPhotoUrl;

  const PlaylistDetailScreen({
    super.key,
    required this.playlistId,
    required this.playlistName,
    this.isPublic = false,
    this.coverPhotoUrl,
  });

  @override
  State<PlaylistDetailScreen> createState() => _PlaylistDetailScreenState();
}

class _PlaylistDetailScreenState extends State<PlaylistDetailScreen> {
  final MediaService _media = MediaService();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  
  List<dynamic> _songs = [];
  List<dynamic> _searchResults = [];
  bool _loading = false;
  bool _searching = false;
  bool _isEditingName = false;
  String? _coverPhotoUrl;
  String? _shareLink;
  Map<String, dynamic>? _currentlyPlayingSong;
  String? _currentlyPlayingKey;
  List<Map<String, dynamic>> _currentPlaylist = [];
  int _currentPlaylistIndex = -1;

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.playlistName;
    _coverPhotoUrl = widget.coverPhotoUrl;
    _generateShareLink();
    _loadPlaylist();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _generateShareLink() {
    // Generate share link based on playlist ID
    // In a real app, this would be a proper shareable URL
    _shareLink = '${apiBaseUrl.replaceAll('/api', '')}/playlist/${widget.playlistId}';
  }

  Future<void> _loadPlaylist() async {
    setState(() => _loading = true);
    try {
      final playlistData = await _media.getPlaylist(widget.playlistId);
      if (mounted) {
        setState(() {
          _songs = playlistData['songs'] ?? [];
          _nameController.text = playlistData['name'] ?? widget.playlistName;
          _coverPhotoUrl = playlistData['cover_photo_url'] ?? widget.coverPhotoUrl;
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        showToast('Failed to load playlist: $e');
      }
    }
  }

  Future<void> _searchSongs(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _searching = false;
      });
      return;
    }

    setState(() => _searching = true);
    try {
      final results = await _media.searchSongs(query);
      if (mounted) {
        setState(() {
          _searchResults = results;
        });
      }
    } catch (e) {
      if (mounted) {
        showToast('Search failed: $e');
        setState(() => _searchResults = []);
      }
    }
  }

  Future<void> _addSongToPlaylist(Map<String, dynamic> song) async {
    try {
      await _media.addToPlaylist(widget.playlistId, song['id']);
      showToast('Song added to playlist');
      _loadPlaylist();
      // Clear search
      _searchController.clear();
      setState(() {
        _searchResults = [];
        _searching = false;
      });
    } catch (e) {
      showToast('Failed to add song: $e');
    }
  }

  Future<void> _removeSongFromPlaylist(int songId) async {
    try {
      await _media.removeFromPlaylist(widget.playlistId, songId);
      showToast('Song removed from playlist');
      _loadPlaylist();
    } catch (e) {
      showToast('Failed to remove song: $e');
    }
  }

  Future<void> _updatePlaylistName() async {
    if (_nameController.text.trim().isEmpty) {
      showToast('Playlist name cannot be empty');
      return;
    }

    try {
      await _media.updatePlaylist(
        widget.playlistId,
        name: _nameController.text.trim(),
      );
      setState(() => _isEditingName = false);
      showToast('Playlist name updated');
    } catch (e) {
      showToast('Failed to update name: $e');
    }
  }

  Future<void> _pickCoverPhoto() async {
    final ImagePicker picker = ImagePicker();
    final XFile? image = await picker.pickImage(source: ImageSource.gallery);
    
    if (image != null) {
      // In a real app, you would upload the image to a server/CDN
      // For now, we'll just use the local file path as a placeholder
      // You would need to implement image upload functionality
      showToast('Image upload functionality needs to be implemented');
      
      // Example: If you have an upload endpoint
      // final uploadedUrl = await _uploadImage(image.path);
      // await _media.updatePlaylist(widget.playlistId, coverPhotoUrl: uploadedUrl);
      // setState(() => _coverPhotoUrl = uploadedUrl);
    }
  }

  Future<void> _sharePlaylist() async {
    if (_shareLink != null) {
      await Share.share('Check out my playlist: ${_nameController.text}\n$_shareLink');
    } else {
      showToast('Share link not available');
    }
  }

  void _playSong(Map<String, dynamic> song) {
    // Check if song is suspended
    final moderationStatus = song['moderation_status']?.toString().toLowerCase();
    if (moderationStatus == 'flagged') {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: Colors.grey.shade900,
          title: Row(
            children: [
              const Text('🎧', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'This Song Is Taking a Break',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          content: Text(
            'Looks like this track has been temporarily suspended.\n\nHang tight — we\'re sorting things out behind the scenes.',
            style: TextStyle(color: Colors.grey.shade300),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('OK', style: TextStyle(color: const Color(0xFF78E08F))),
            ),
          ],
        ),
      );
      return;
    }
    
    final playList = _songs.map((s) => s as Map<String, dynamic>).toList();
    final index = playList.indexWhere((s) => s['r2_key'] == song['r2_key']);
    
    final playerState = Provider.of<PlayerStateProvider>(context, listen: false);
    playerState.showMini();
    
    setState(() {
      _currentPlaylist = playList;
      _currentPlaylistIndex = index >= 0 ? index : 0;
      _currentlyPlayingSong = song;
      _currentlyPlayingKey = song['r2_key'];
    });
    
    // Initialize shuffle if enabled
    playerState.initializeShuffle(playList, _currentPlaylistIndex);
  }

  void _playNext() {
    if (_currentPlaylist.isEmpty || _currentPlaylistIndex < 0) return;
    
    final playerState = Provider.of<PlayerStateProvider>(context, listen: false);
    final nextIndex = playerState.getNextIndex(_currentPlaylistIndex, _currentPlaylist.length);
    
    if (nextIndex != null && nextIndex < _currentPlaylist.length) {
      _playSong(_currentPlaylist[nextIndex]);
    }
  }

  void _playPrevious() {
    if (_currentPlaylist.isEmpty || _currentPlaylistIndex < 0) return;
    
    final playerState = Provider.of<PlayerStateProvider>(context, listen: false);
    final prevIndex = playerState.getPreviousIndex(_currentPlaylistIndex, _currentPlaylist.length);
    
    if (prevIndex != null && prevIndex >= 0 && prevIndex < _currentPlaylist.length) {
      _playSong(_currentPlaylist[prevIndex]);
    }
  }

  void _playAtIndex(int index) {
    if (_currentPlaylist.isEmpty) return;
    if (index < 0 || index >= _currentPlaylist.length) return;
    _playSong(_currentPlaylist[index]);
  }

  void _closePlayer() {
    setState(() {
      _currentlyPlayingSong = null;
      _currentlyPlayingKey = null;
    });
  }

  bool _isVideo(String? contentType) {
    if (contentType == null) return false;
    return contentType.startsWith('video/');
  }

  @override
  Widget build(BuildContext context) {
    final accent = const Color(0xFF78E08F);
    
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade900,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Playlist', style: TextStyle(color: Colors.white)),
        actions: [
          IconButton(
            icon: const Icon(Icons.share, color: Colors.white),
            onPressed: _sharePlaylist,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF78E08F)))
          : Stack(
              children: [
                Column(
                  children: [
                // Playlist Header with Photo and Name
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey.shade900,
                  child: Row(
                    children: [
                      // Cover Photo
                      GestureDetector(
                        onTap: _pickCoverPhoto,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade800,
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: accent, width: 2),
                          ),
                          child: _coverPhotoUrl != null && _coverPhotoUrl!.isNotEmpty
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    _coverPhotoUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Icon(Icons.music_note, size: 48, color: accent);
                                    },
                                  ),
                                )
                              : Icon(Icons.music_note, size: 48, color: accent),
                        ),
                      ),
                      const SizedBox(width: 16),
                      // Playlist Name and Share Link
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Playlist Name
                            Row(
                              children: [
                                Expanded(
                                  child: _isEditingName
                                      ? TextField(
                                          controller: _nameController,
                                          style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                          decoration: InputDecoration(
                                            border: UnderlineInputBorder(borderSide: BorderSide(color: accent)),
                                            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: accent)),
                                          ),
                                        )
                                      : GestureDetector(
                                          onTap: () => setState(() => _isEditingName = true),
                                          child: Text(
                                            _nameController.text,
                                            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                                          ),
                                        ),
                                ),
                                if (_isEditingName)
                                  IconButton(
                                    icon: const Icon(Icons.check, color: Color(0xFF78E08F)),
                                    onPressed: _updatePlaylistName,
                                  ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            // Share Link
                            GestureDetector(
                              onTap: () {
                                Clipboard.setData(ClipboardData(text: _shareLink ?? ''));
                                showToast('Link copied to clipboard');
                              },
                              child: Row(
                                children: [
                                  const Icon(Icons.link, size: 16, color: Colors.grey),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: Text(
                                      _shareLink ?? '',
                                      style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  const Icon(Icons.copy, size: 16, color: Colors.grey),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Search Bar
                Container(
                  padding: const EdgeInsets.all(16),
                  color: Colors.grey.shade900,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Let's find something for your playlist",
                        style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _searchController,
                        style: const TextStyle(color: Colors.white),
                        decoration: InputDecoration(
                          hintText: 'Search for songs or episodes',
                          hintStyle: TextStyle(color: Colors.grey.shade500),
                          prefixIcon: const Icon(Icons.search, color: Colors.grey),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear, color: Colors.grey),
                                  onPressed: () {
                                    _searchController.clear();
                                    setState(() {
                                      _searchResults = [];
                                      _searching = false;
                                    });
                                  },
                                )
                              : null,
                          filled: true,
                          fillColor: Colors.grey.shade800,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide.none,
                          ),
                        ),
                        onChanged: (value) {
                          setState(() {});
                          if (value.trim().isNotEmpty) {
                            _searchSongs(value);
                          } else {
                            setState(() {
                              _searchResults = [];
                              _searching = false;
                            });
                          }
                        },
                      ),
                    ],
                  ),
                ),
                // Search Results or Playlist Songs
                Expanded(
                  child: _searchResults.isNotEmpty || _searching
                      ? _buildSearchResults(accent)
                      : _buildPlaylistSongs(accent),
                ),
                  ],
                ),
                // Media Player at bottom (mini state)
                if (_currentlyPlayingSong != null)
                  Consumer<PlayerStateProvider>(
                    builder: (context, playerState, child) {
                      if (playerState.isFull) {
                        return const SizedBox.shrink();
                      }
                      return Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: MediaPlayerWidget(
                          r2Key: _currentlyPlayingSong!['r2_key'],
                          title: _currentlyPlayingSong!['title'],
                          artist: _currentlyPlayingSong!['artist']?.toString() ?? 'Unknown Artist',
                          coverPhotoUrl: _currentlyPlayingSong!['cover_photo_url'],
                          contentType: _currentlyPlayingSong!['content_type'],
                          isVideo: _isVideo(_currentlyPlayingSong!['content_type']),
                          playlist: _currentPlaylist,
                          currentIndex: _currentPlaylistIndex,
                          isMini: true,
                          moderationStatus: _currentlyPlayingSong!['moderation_status']?.toString(),
                          onClose: () {
                            playerState.hide();
                            _closePlayer();
                          },
                          onNext: _playNext,
                          onPrevious: _playPrevious,
                          onSelectTrackIndex: _playAtIndex,
                        ),
                      );
                    },
                  ),
              ],
            ),
    );
  }

  Widget _buildSearchResults(Color accent) {
    if (_searching && _searchResults.isEmpty) {
      return const Center(child: CircularProgressIndicator(color: Color(0xFF78E08F)));
    }

    if (_searchResults.isEmpty) {
      return const Center(
        child: Text(
          'No songs found',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Search Results',
            style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _searchResults.length,
            itemBuilder: (context, index) {
              final song = _searchResults[index] as Map<String, dynamic>;
              final title = song['title'] ?? 'Untitled';
              final artist = song['artist'] ?? 'Unknown Artist';
              final album = song['album'] ?? '';
              final coverPhotoUrl = song['cover_photo_url'];
              
              // Check if song is already in playlist
              final isInPlaylist = _songs.any((s) => s['id'] == song['id']);

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  leading: coverPhotoUrl != null && coverPhotoUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            coverPhotoUrl,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 50,
                                height: 50,
                                color: Colors.grey.shade700,
                                child: const Icon(Icons.music_note, color: Colors.grey),
                              );
                            },
                          ),
                        )
                      : Container(
                          width: 50,
                          height: 50,
                          color: Colors.grey.shade700,
                          child: const Icon(Icons.music_note, color: Colors.grey),
                        ),
                  title: Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    artist + (album.isNotEmpty ? ' • $album' : ''),
                    style: TextStyle(color: Colors.grey.shade400),
                  ),
                  trailing: isInPlaylist
                      ? const Icon(Icons.check_circle, color: Color(0xFF78E08F))
                      : IconButton(
                          icon: const Icon(Icons.add_circle, color: Color(0xFF78E08F)),
                          onPressed: () => _addSongToPlaylist(song),
                        ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPlaylistSongs(Color accent) {
    if (_songs.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.queue_music, size: 64, color: Colors.grey.shade600),
            const SizedBox(height: 16),
            Text(
              'No songs in playlist',
              style: TextStyle(color: Colors.grey.shade400, fontSize: 18),
            ),
            const SizedBox(height: 8),
            Text(
              'Search for songs above to add them',
              style: TextStyle(color: Colors.grey.shade500),
            ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                'Songs (${_songs.length})',
                style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _songs.length,
            itemBuilder: (context, index) {
              final song = _songs[index] as Map<String, dynamic>;
              final title = song['title'] ?? 'Untitled';
              final artist = song['artist'] ?? 'Unknown Artist';
              final album = song['album'] ?? '';
              final coverPhotoUrl = song['cover_photo_url'];

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: Colors.grey.shade800,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: ListTile(
                  leading: coverPhotoUrl != null && coverPhotoUrl.isNotEmpty
                      ? ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Image.network(
                            coverPhotoUrl,
                            width: 50,
                            height: 50,
                            fit: BoxFit.cover,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 50,
                                height: 50,
                                color: Colors.grey.shade700,
                                child: const Icon(Icons.music_note, color: Colors.grey),
                              );
                            },
                          ),
                        )
                      : Container(
                          width: 50,
                          height: 50,
                          color: Colors.grey.shade700,
                          child: const Icon(Icons.music_note, color: Colors.grey),
                        ),
                  title: Text(
                    title,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    artist + (album.isNotEmpty ? ' • $album' : ''),
                    style: TextStyle(color: Colors.grey.shade400),
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          _currentlyPlayingKey == song['r2_key'] ? Icons.pause_circle : Icons.play_circle,
                          color: accent,
                          size: 32,
                        ),
                        onPressed: () => _playSong(song),
                        tooltip: 'Play',
                      ),
                      IconButton(
                        icon: const Icon(Icons.delete, color: Colors.red),
                        onPressed: () => _removeSongFromPlaylist(song['id']),
                        tooltip: 'Remove',
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
