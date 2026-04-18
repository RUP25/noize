// lib/services/media_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'auth_service.dart';

class MediaService {
  MediaService._internal();
  static final MediaService _instance = MediaService._internal();
  factory MediaService() => _instance;

  final AuthService _auth = AuthService();

  Future<List<dynamic>> getArtistSongs(String channelName) async {
    try {
      // Validate channel name
      if (channelName.isEmpty) {
        throw Exception('Channel name cannot be empty');
      }
      
      // Construct URI properly - ensure base path ends with / or is empty
      final base = Uri.parse(apiBaseUrl);
      final path = base.path.isEmpty 
          ? '/artist/${Uri.encodeComponent(channelName)}'
          : '${base.path}/artist/${Uri.encodeComponent(channelName)}';
      final uri = base.replace(path: path);
      
      // Debug: print the URL being used (only in debug mode)
      if (kDebugMode) {
        print('🔍 Fetching songs from: $uri');
        print('📡 API Base URL: $apiBaseUrl');
      }
      
      final headers = <String, String>{
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };
      // Add auth header if available (some endpoints may require it)
      if (_auth.isLoggedIn) {
        headers.addAll(_auth.authHeader);
        if (kDebugMode) {
          print('✅ Using auth token');
        }
      } else {
        if (kDebugMode) {
          print('⚠️ No auth token available');
        }
      }
      
      final resp = await http.get(
        uri,
        headers: headers,
      ).timeout(const Duration(seconds: 30));
      
      if (kDebugMode) {
        print('📥 Response status: ${resp.statusCode}');
      }
      
      if (resp.statusCode == 200) {
        final data = jsonDecode(resp.body) as List<dynamic>;
        if (kDebugMode) {
          print('✅ Loaded ${data.length} songs');
        }
        return data;
      }
      
      // Handle specific error codes
      if (resp.statusCode == 404) {
        // Silently return empty list for 404s (expected when channel doesn't exist)
        // Only log if it's not the default "popular" channel lookup
        if (kDebugMode && channelName != 'popular') {
          print('⚠️ Channel "$channelName" not found');
        }
        return []; // Return empty list instead of throwing for 404s
      }
      
      if (resp.statusCode == 401) {
        throw Exception('Authentication required. Please log in again.');
      }
      
      throw Exception('Failed to fetch songs: ${resp.statusCode} ${resp.body}');
    } on http.ClientException catch (e) {
      if (kDebugMode) {
        print('❌ ClientException: $e');
      }
      throw Exception('Cannot connect to server at $apiBaseUrl. Make sure the backend is running. Error: $e');
    } on TimeoutException catch (e) {
      if (kDebugMode) {
        print('⏱️ TimeoutException: $e');
      }
      throw Exception('Request timed out. The server may be slow or unreachable. Try again later.');
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error: $e');
      }
      // Re-throw if it's already a formatted exception
      if (e.toString().contains('Channel') || 
          e.toString().contains('Failed to fetch songs') ||
          e.toString().contains('Authentication required')) {
        rethrow;
      }
      
      if (e.toString().contains('Failed to fetch') || 
          e.toString().contains('ClientException') ||
          e.toString().contains('SocketException') ||
          e.toString().contains('TimeoutException')) {
        throw Exception('Cannot connect to server at $apiBaseUrl. Make sure the backend is running. Error: $e');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> followChannel(String channelName) async {
    try {
      final base = Uri.parse(apiBaseUrl);
      final uri = base.replace(path: '${base.path}/artist/${Uri.encodeComponent(channelName)}/follow');
      final resp = await http.post(uri, headers: _auth.authHeader).timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) return jsonDecode(resp.body);
      throw Exception('Follow failed: ${resp.statusCode}');
    } catch (e) {
      if (e.toString().contains('Failed to fetch') || e.toString().contains('ClientException')) {
        throw Exception('Cannot connect to server at $apiBaseUrl. Make sure the backend is running.');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> createChannel(String name) async {
    final base = Uri.parse(apiBaseUrl);
    final uri = base.replace(path: '${base.path}/artist/create');
    final resp = await http.post(uri,
        headers: {..._auth.authHeader, 'Content-Type': 'application/json'},
        body: jsonEncode({'channel_name': name}));
    if (resp.statusCode == 200) return jsonDecode(resp.body);
    final body = resp.body.isNotEmpty ? ' body=${resp.body}' : '';
    throw Exception('Channel create failed: ${resp.statusCode}$body');
  }

  Future<Map<String, dynamic>> likeSong(int songId) async {
    final base = Uri.parse(apiBaseUrl);
    final uri = base.replace(path: '${base.path}/artist/song/$songId/like');
    final resp = await http.post(uri, headers: _auth.authHeader);
    if (resp.statusCode == 200) return jsonDecode(resp.body);
    throw Exception('Like failed: ${resp.statusCode}');
  }

  Future<Map<String, dynamic>> dislikeSong(int songId) async {
    final base = Uri.parse(apiBaseUrl);
    final uri = base.replace(path: '${base.path}/artist/song/$songId/dislike');
    final resp = await http.post(uri, headers: _auth.authHeader);
    if (resp.statusCode == 200) return jsonDecode(resp.body);
    throw Exception('Dislike failed: ${resp.statusCode}');
  }

  /// Streams (listens), likes, dislikes, subscribers for the signed-in artist.
  Future<Map<String, dynamic>> getArtistEngagementStats() async {
    final base = Uri.parse(apiBaseUrl);
    final uri = base.replace(path: '${base.path}/artist/me/stats');
    final resp = await http.get(uri, headers: _auth.authHeader);
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      if (data is Map<String, dynamic>) return data;
    }
    throw Exception('Artist stats failed: ${resp.statusCode}');
  }

  Future<List<dynamic>> searchArtist(String query) async {
    final base = Uri.parse(apiBaseUrl);
    final uri = base.replace(path: '${base.path}/artist/search', queryParameters: {'q': query});
    final resp = await http.get(uri);
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      if (data is List) {
        return data;
      }
      return const [];
    }
    throw Exception('Search failed: ${resp.statusCode}');
  }

  // Playlist methods
  Future<List<dynamic>> getPlaylists() async {
    final base = Uri.parse(apiBaseUrl);
    final uri = base.replace(path: '${base.path}/user/playlists');
    final resp = await http.get(uri, headers: _auth.authHeader);
    if (resp.statusCode == 200) return jsonDecode(resp.body);
    throw Exception('Failed to fetch playlists: ${resp.statusCode}');
  }

  Future<Map<String, dynamic>> createPlaylist(String name, {bool isPublic = false}) async {
    final base = Uri.parse(apiBaseUrl);
    final uri = base.replace(path: '${base.path}/user/playlist/create');
    final resp = await http.post(uri,
        headers: {..._auth.authHeader, 'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'is_public': isPublic}));
    if (resp.statusCode == 200) return jsonDecode(resp.body);
    throw Exception('Failed to create playlist: ${resp.statusCode}');
  }
  
  Future<List<dynamic>> getPublicPlaylists() async {
    final base = Uri.parse(apiBaseUrl);
    final uri = base.replace(path: '${base.path}/user/playlists/public');
    final resp = await http.get(uri);
    if (resp.statusCode == 200) return jsonDecode(resp.body);
    throw Exception('Failed to fetch public playlists: ${resp.statusCode}');
  }

  Future<Map<String, dynamic>> addToPlaylist(String playlistId, int songId) async {
    final base = Uri.parse(apiBaseUrl);
    final uri = base.replace(path: '${base.path}/user/playlist/$playlistId/add');
    final resp = await http.post(uri,
        headers: {..._auth.authHeader, 'Content-Type': 'application/json'},
        body: jsonEncode({'song_id': songId}));
    if (resp.statusCode == 200) return jsonDecode(resp.body);
    throw Exception('Failed to add song: ${resp.statusCode}');
  }

  Future<Map<String, dynamic>> removeFromPlaylist(String playlistId, int songId) async {
    final base = Uri.parse(apiBaseUrl);
    final uri = base.replace(path: '${base.path}/user/playlist/$playlistId/song/$songId');
    final resp = await http.delete(uri, headers: _auth.authHeader);
    if (resp.statusCode == 200) return jsonDecode(resp.body);
    throw Exception('Failed to remove song: ${resp.statusCode}');
  }

  Future<Map<String, dynamic>> getPlaylist(String playlistId) async {
    final base = Uri.parse(apiBaseUrl);
    final uri = base.replace(path: '${base.path}/user/playlist/$playlistId');
    final resp = await http.get(uri, headers: _auth.authHeader);
    if (resp.statusCode == 200) return jsonDecode(resp.body);
    throw Exception('Failed to fetch playlist: ${resp.statusCode}');
  }

  Future<Map<String, dynamic>> updatePlaylist(String playlistId, {String? name, bool? isPublic, String? coverPhotoUrl}) async {
    final base = Uri.parse(apiBaseUrl);
    final uri = base.replace(path: '${base.path}/user/playlist/$playlistId');
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (isPublic != null) body['is_public'] = isPublic;
    if (coverPhotoUrl != null) body['cover_photo_url'] = coverPhotoUrl;
    final resp = await http.put(
      uri,
      headers: {..._auth.authHeader, 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (resp.statusCode == 200) return jsonDecode(resp.body);
    throw Exception('Failed to update playlist: ${resp.statusCode}');
  }

  Future<List<dynamic>> searchSongs(String query, {int limit = 50}) async {
    final base = Uri.parse(apiBaseUrl);
    final uri = base.replace(path: '${base.path}/user/songs/search', queryParameters: {'q': query, 'limit': limit.toString()});
    final resp = await http.get(uri, headers: _auth.authHeader);
    if (resp.statusCode == 200) return jsonDecode(resp.body);
    throw Exception('Failed to search songs: ${resp.statusCode}');
  }

  Future<Map<String, dynamic>> deletePlaylist(String playlistId) async {
    try {
      final base = Uri.parse(apiBaseUrl);
      // Ensure proper path construction - handle both cases where base.path might be empty or have a value
      final path = base.path.isEmpty 
          ? '/user/playlist/$playlistId'
          : '${base.path}/user/playlist/$playlistId';
      final uri = base.replace(path: path);
      
      if (kDebugMode) {
        print('🗑️ Deleting playlist: $uri');
        print('📋 Playlist ID: $playlistId');
      }
      
      final resp = await http.delete(uri, headers: _auth.authHeader).timeout(const Duration(seconds: 30));
      
      if (kDebugMode) {
        print('📥 Delete response status: ${resp.statusCode}');
        print('📥 Delete response body: ${resp.body}');
      }
      
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body);
      }
      
      // Try to parse error message from response
      String errorMessage = 'Failed to delete playlist';
      try {
        final errorBody = jsonDecode(resp.body);
        if (errorBody is Map && errorBody.containsKey('detail')) {
          errorMessage = errorBody['detail'].toString();
        }
      } catch (_) {
        errorMessage = 'Failed to delete playlist: ${resp.statusCode}';
      }
      
      throw Exception(errorMessage);
    } on http.ClientException catch (e) {
      if (kDebugMode) {
        print('❌ ClientException: $e');
      }
      throw Exception('Cannot connect to server at $apiBaseUrl. Make sure the backend is running.');
    } on TimeoutException catch (e) {
      if (kDebugMode) {
        print('⏱️ TimeoutException: $e');
      }
      throw Exception('Request timed out. The server may be slow or unreachable. Try again later.');
    } catch (e) {
      if (kDebugMode) {
        print('❌ Error deleting playlist: $e');
      }
      rethrow;
    }
  }

  Future<List<int>> getLikedSongs() async {
    final base = Uri.parse(apiBaseUrl);
    final uri = base.replace(path: '${base.path}/user/likes');
    final resp = await http.get(uri, headers: _auth.authHeader);
    if (resp.statusCode == 200) {
      final data = jsonDecode(resp.body);
      return List<int>.from(data['liked_songs'] ?? []);
    }
    throw Exception('Failed to fetch likes: ${resp.statusCode}');
  }

  Future<List<dynamic>> getLikedSongsDetails() async {
    final base = Uri.parse(apiBaseUrl);
    final uri = base.replace(path: '${base.path}/user/likes/songs');
    final resp = await http.get(uri, headers: _auth.authHeader);
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body);
    }
    throw Exception('Failed to fetch liked songs: ${resp.statusCode}');
  }

  Future<List<dynamic>> getFollowingArtists() async {
    final base = Uri.parse(apiBaseUrl);
    final uri = base.replace(path: '${base.path}/user/following');
    final resp = await http.get(uri, headers: _auth.authHeader);
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body);
    }
    if (resp.statusCode == 401) {
      throw Exception('Authentication required. Please log in again.');
    }
    return [];
  }

  Future<List<dynamic>> getPopularArtists({int limit = 12}) async {
    final base = Uri.parse(apiBaseUrl);
    final uri = base.replace(
      path: '${base.path}/artist/popular',
      queryParameters: {'limit': limit.toString()},
    );
    final resp = await http.get(uri);
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body);
    }
    return [];
  }

  Future<List<dynamic>> getArtistMerchandise(String channelName) async {
    try {
      final base = Uri.parse(apiBaseUrl);
      final path = base.path.isEmpty 
          ? '/artist/${Uri.encodeComponent(channelName)}/merchandise'
          : '${base.path}/artist/${Uri.encodeComponent(channelName)}/merchandise';
      final uri = base.replace(path: path);
      
      final resp = await http.get(uri).timeout(const Duration(seconds: 30));
      
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body);
      }
      if (resp.statusCode == 404) {
        return []; // Return empty list if not found
      }
      throw Exception('Failed to fetch merchandise: ${resp.statusCode}');
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching merchandise: $e');
      }
      return []; // Return empty list on error
    }
  }

  Future<Map<String, dynamic>> createMerchandise(Map<String, dynamic> merchData) async {
    try {
      final base = Uri.parse(apiBaseUrl);
      final path = base.path.isEmpty 
          ? '/artist/merchandise'
          : '${base.path}/artist/merchandise';
      final uri = base.replace(path: path);
      
      final resp = await http.post(
        uri,
        headers: {..._auth.authHeader, 'Content-Type': 'application/json'},
        body: jsonEncode(merchData),
      ).timeout(const Duration(seconds: 30));
      
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        return jsonDecode(resp.body);
      }
      throw Exception('Failed to create merchandise: ${resp.statusCode}');
    } catch (e) {
      if (kDebugMode) {
        print('Error creating merchandise: $e');
      }
      rethrow;
    }
  }

  Future<List<dynamic>> getArtistEvents(String channelName) async {
    try {
      final base = Uri.parse(apiBaseUrl);
      final path = base.path.isEmpty 
          ? '/artist/${Uri.encodeComponent(channelName)}/events'
          : '${base.path}/artist/${Uri.encodeComponent(channelName)}/events';
      final uri = base.replace(path: path);
      
      final resp = await http.get(uri).timeout(const Duration(seconds: 30));
      
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body);
      }
      if (resp.statusCode == 404) {
        return []; // Return empty list if not found
      }
      throw Exception('Failed to fetch events: ${resp.statusCode}');
    } catch (e) {
      if (kDebugMode) {
        print('Error fetching events: $e');
      }
      return []; // Return empty list on error
    }
  }

  Future<Map<String, dynamic>> createEvent(Map<String, dynamic> eventData) async {
    try {
      final base = Uri.parse(apiBaseUrl);
      final path = base.path.isEmpty 
          ? '/artist/events'
          : '${base.path}/artist/events';
      final uri = base.replace(path: path);
      
      final resp = await http.post(
        uri,
        headers: {..._auth.authHeader, 'Content-Type': 'application/json'},
        body: jsonEncode(eventData),
      ).timeout(const Duration(seconds: 30));
      
      if (resp.statusCode == 200 || resp.statusCode == 201) {
        return jsonDecode(resp.body);
      }
      throw Exception('Failed to create event: ${resp.statusCode}');
    } catch (e) {
      if (kDebugMode) {
        print('Error creating event: $e');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateMerchandise(int merchId, Map<String, dynamic> updateData) async {
    try {
      final base = Uri.parse(apiBaseUrl);
      final path = base.path.isEmpty 
          ? '/artist/merchandise/$merchId'
          : '${base.path}/artist/merchandise/$merchId';
      final uri = base.replace(path: path);
      
      final resp = await http.put(
        uri,
        headers: {
          ..._auth.authHeader,
          'Content-Type': 'application/json',
        },
        body: jsonEncode(updateData),
      ).timeout(const Duration(seconds: 30));
      
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body);
      }

      // Try to surface backend validation error (e.g., 422)
      try {
        final body = jsonDecode(resp.body);
        if (body is Map && body['detail'] != null) {
          throw Exception('Failed to update merchandise: ${body['detail']}');
        }
      } catch (_) {
        // ignore parse errors, fall back to status code message
      }

      throw Exception('Failed to update merchandise: ${resp.statusCode}');
    } catch (e) {
      if (kDebugMode) {
        print('Error updating merchandise: $e');
      }
      rethrow;
    }
  }

  Future<void> deleteMerchandise(int merchId) async {
    try {
      final base = Uri.parse(apiBaseUrl);
      final path = base.path.isEmpty 
          ? '/artist/merchandise/$merchId'
          : '${base.path}/artist/merchandise/$merchId';
      final uri = base.replace(path: path);
      
      final resp = await http.delete(
        uri,
        headers: _auth.authHeader,
      ).timeout(const Duration(seconds: 30));
      
      if (resp.statusCode != 200) {
        throw Exception('Failed to delete merchandise: ${resp.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting merchandise: $e');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateEvent(int eventId, Map<String, dynamic> updateData) async {
    try {
      final base = Uri.parse(apiBaseUrl);
      final path = base.path.isEmpty 
          ? '/artist/events/$eventId'
          : '${base.path}/artist/events/$eventId';
      final uri = base.replace(path: path);
      
      final resp = await http.put(
        uri,
        headers: _auth.authHeader,
        body: jsonEncode(updateData),
      ).timeout(const Duration(seconds: 30));
      
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body);
      }
      throw Exception('Failed to update event: ${resp.statusCode}');
    } catch (e) {
      if (kDebugMode) {
        print('Error updating event: $e');
      }
      rethrow;
    }
  }

  Future<void> deleteEvent(int eventId) async {
    try {
      final base = Uri.parse(apiBaseUrl);
      final path = base.path.isEmpty 
          ? '/artist/events/$eventId'
          : '${base.path}/artist/events/$eventId';
      final uri = base.replace(path: path);
      
      final resp = await http.delete(
        uri,
        headers: _auth.authHeader,
      ).timeout(const Duration(seconds: 30));
      
      if (resp.statusCode != 200) {
        throw Exception('Failed to delete event: ${resp.statusCode}');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting event: $e');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> updateSong(int songId, {String? title, String? album, String? coverPhotoUrl, String? lyrics}) async {
    try {
      final base = Uri.parse(apiBaseUrl);
      final path = base.path.isEmpty 
          ? '/artist/song/$songId'
          : '${base.path}/artist/song/$songId';
      final uri = base.replace(path: path);
      
      final body = <String, dynamic>{};
      if (title != null) body['title'] = title;
      if (album != null) body['album'] = album;
      if (coverPhotoUrl != null) body['cover_photo_url'] = coverPhotoUrl;
      // Include lyrics if provided (empty string is valid to clear lyrics)
      if (lyrics != null) body['lyrics'] = lyrics;
      
      final resp = await http.put(
        uri,
        headers: {..._auth.authHeader, 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(const Duration(seconds: 30));
      
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body);
      }
      
      String errorMessage = 'Failed to update song';
      try {
        final errorBody = jsonDecode(resp.body);
        if (errorBody is Map && errorBody.containsKey('detail')) {
          errorMessage = errorBody['detail'].toString();
        }
      } catch (_) {
        errorMessage = 'Failed to update song: ${resp.statusCode}';
      }
      
      throw Exception(errorMessage);
    } catch (e) {
      if (kDebugMode) {
        print('Error updating song: $e');
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> deleteSong(int songId) async {
    try {
      final base = Uri.parse(apiBaseUrl);
      final path = base.path.isEmpty 
          ? '/artist/song/$songId'
          : '${base.path}/artist/song/$songId';
      final uri = base.replace(path: path);
      
      if (kDebugMode) {
        print('🗑️ Deleting song: $uri');
        print('🎵 Song ID: $songId');
      }
      
      final resp = await http.delete(uri, headers: _auth.authHeader).timeout(const Duration(seconds: 30));
      
      if (kDebugMode) {
        print('📥 Delete response status: ${resp.statusCode}');
        print('📥 Delete response body: ${resp.body}');
      }
      
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body);
      }
      
      String errorMessage = 'Failed to delete song';
      try {
        final errorBody = jsonDecode(resp.body);
        if (errorBody is Map && errorBody.containsKey('detail')) {
          errorMessage = errorBody['detail'].toString();
        }
      } catch (_) {
        errorMessage = 'Failed to delete song: ${resp.statusCode}';
      }
      
      throw Exception(errorMessage);
    } catch (e) {
      if (kDebugMode) {
        print('Error deleting song: $e');
      }
      rethrow;
    }
  }

  /// Personalized home rail (likes, plays, playlists, collaborative + trending fill).
  Future<List<dynamic>> getForYouRecommendations({int limit = 40}) async {
    final base = Uri.parse(apiBaseUrl);
    final uri = base.replace(
      path: '${base.path}/recommendations/for-you',
      queryParameters: {'limit': limit.toString()},
    );
    final resp = await http.get(uri, headers: _auth.authHeader).timeout(const Duration(seconds: 30));
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as List<dynamic>;
    }
    if (resp.statusCode == 401) {
      return [];
    }
    throw Exception('Failed to load recommendations: ${resp.statusCode}');
  }

  /// Chart rails (Top 50, etc.) — same ranking as trending, keyed by catalog `chart_id`.
  /// [style]: `trending_only` | `balanced` | `new_music_heavy`
  Future<List<dynamic>> getChartTopSongs({
    required String chartId,
    int limit = 50,
    String style = 'balanced',
  }) async {
    final base = Uri.parse(apiBaseUrl);
    final uri = base.replace(
      path: '${base.path}/charts/top',
      queryParameters: {
        'chart_id': chartId,
        'limit': limit.toString(),
        'style': style,
      },
    );
    final resp = await http.get(uri).timeout(const Duration(seconds: 30));
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as List<dynamic>;
    }
    throw Exception('Failed to load chart: ${resp.statusCode}');
  }

  Future<List<dynamic>> getTrendingRecommendations({int limit = 30}) async {
    final base = Uri.parse(apiBaseUrl);
    final uri = base.replace(
      path: '${base.path}/recommendations/trending',
      queryParameters: {'limit': limit.toString()},
    );
    final resp = await http.get(uri).timeout(const Duration(seconds: 30));
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as List<dynamic>;
    }
    return [];
  }

  Future<List<dynamic>> getSimilarSongs(int songId, {int limit = 20}) async {
    final base = Uri.parse(apiBaseUrl);
    final path = base.path.isEmpty
        ? '/recommendations/similar/$songId'
        : '${base.path}/recommendations/similar/$songId';
    final uri = base.replace(path: path, queryParameters: {'limit': limit.toString()});
    final resp = await http.get(uri).timeout(const Duration(seconds: 30));
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as List<dynamic>;
    }
    return [];
  }

  Future<List<dynamic>> getMoodForYou({int limit = 30}) async {
    final base = Uri.parse(apiBaseUrl);
    final uri = base.replace(
      path: '${base.path}/recommendations/mood-for-you',
      queryParameters: {'limit': limit.toString()},
    );
    final resp = await http.get(uri, headers: _auth.authHeader).timeout(const Duration(seconds: 30));
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as List<dynamic>;
    }
    if (resp.statusCode == 401) return [];
    throw Exception('Failed to load mood feed: ${resp.statusCode}');
  }

  Future<List<dynamic>> getExperienceNewReleases({int limit = 24}) async {
    final base = Uri.parse(apiBaseUrl);
    final uri = base.replace(
      path: '${base.path}/experience/new-releases',
      queryParameters: {'limit': limit.toString()},
    );
    final resp = await http.get(uri).timeout(const Duration(seconds: 30));
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as List<dynamic>;
    }
    return [];
  }

  Future<List<dynamic>> getExperienceTrending({int limit = 20}) async {
    final base = Uri.parse(apiBaseUrl);
    final uri = base.replace(
      path: '${base.path}/experience/trending',
      queryParameters: {'limit': limit.toString()},
    );
    final resp = await http.get(uri).timeout(const Duration(seconds: 30));
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as List<dynamic>;
    }
    return [];
  }

  /// Public feed: next upcoming events platform-wide (default 10).
  Future<List<dynamic>> getExperienceEvents({String? locationHint, int limit = 10}) async {
    final base = Uri.parse(apiBaseUrl);
    final q = <String, String>{'limit': limit.toString()};
    if (locationHint != null && locationHint.isNotEmpty) {
      q['location_hint'] = locationHint;
    }
    final uri = base.replace(path: '${base.path}/experience/events', queryParameters: q);
    final resp = await http.get(uri).timeout(const Duration(seconds: 30));
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as List<dynamic>;
    }
    return [];
  }

  Future<List<dynamic>> getExperienceMerchFollowed({int limit = 16}) async {
    final base = Uri.parse(apiBaseUrl);
    final uri = base.replace(
      path: '${base.path}/experience/merch/followed',
      queryParameters: {'limit': limit.toString()},
    );
    final resp = await http.get(uri, headers: _auth.authHeader).timeout(const Duration(seconds: 30));
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as List<dynamic>;
    }
    if (resp.statusCode == 401) return [];
    return [];
  }

  /// Call after ~30s of playback to fuel trending and personalization.
  Future<void> recordListen(int songId, {int? listenMs}) async {
    if (!_auth.isLoggedIn) return;
    try {
      final base = Uri.parse(apiBaseUrl);
      final path = base.path.isEmpty ? '/recommendations/play' : '${base.path}/recommendations/play';
      final uri = base.replace(path: path);
      final body = <String, dynamic>{'song_id': songId};
      if (listenMs != null) body['listen_ms'] = listenMs;
      await http
          .post(
            uri,
            headers: {..._auth.authHeader, 'Content-Type': 'application/json'},
            body: jsonEncode(body),
          )
          .timeout(const Duration(seconds: 8));
    } catch (_) {}
  }
}
