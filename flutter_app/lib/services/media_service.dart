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
        throw Exception('Channel "$channelName" not found. Make sure the channel exists.');
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

  Future<List<String>> searchArtist(String query) async {
    final base = Uri.parse(apiBaseUrl);
    final uri = base.replace(path: '${base.path}/artist/search', queryParameters: {'q': query});
    final resp = await http.get(uri);
    if (resp.statusCode == 200) {
      return List<String>.from(jsonDecode(resp.body));
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

  Future<Map<String, dynamic>> updatePlaylist(String playlistId, {String? name, bool? isPublic}) async {
    final base = Uri.parse(apiBaseUrl);
    final uri = base.replace(path: '${base.path}/user/playlist/$playlistId');
    final body = <String, dynamic>{};
    if (name != null) body['name'] = name;
    if (isPublic != null) body['is_public'] = isPublic;
    final resp = await http.put(
      uri,
      headers: {..._auth.authHeader, 'Content-Type': 'application/json'},
      body: jsonEncode(body),
    );
    if (resp.statusCode == 200) return jsonDecode(resp.body);
    throw Exception('Failed to update playlist: ${resp.statusCode}');
  }

  Future<Map<String, dynamic>> deletePlaylist(String playlistId) async {
    final base = Uri.parse(apiBaseUrl);
    final uri = base.replace(path: '${base.path}/user/playlist/$playlistId');
    final resp = await http.delete(uri, headers: _auth.authHeader);
    if (resp.statusCode == 200) return jsonDecode(resp.body);
    throw Exception('Failed to delete playlist: ${resp.statusCode}');
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
}
