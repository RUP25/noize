// lib/services/admin_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'auth_service.dart';

class AdminService {
  final AuthService _auth = AuthService();

  Map<String, String> get _headers => {
        ..._auth.authHeader,
        'Content-Type': 'application/json',
      };

  // Get admin stats
  Future<Map<String, dynamic>> getStats() async {
    final uri = Uri.parse('$apiBaseUrl/admin/stats');
    final resp = await http.get(uri, headers: _headers).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw Exception('Request timeout');
      },
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to get stats: ${resp.statusCode}');
  }

  // Get pending songs
  Future<List<dynamic>> getPendingSongs({int skip = 0, int limit = 50}) async {
    final uri = Uri.parse('$apiBaseUrl/admin/content/songs/pending')
        .replace(queryParameters: {'skip': skip.toString(), 'limit': limit.toString()});
    final resp = await http.get(uri, headers: _headers).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw Exception('Request timeout');
      },
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as List<dynamic>;
    }
    throw Exception('Failed to get pending songs: ${resp.statusCode}');
  }

  // Get all songs
  Future<List<dynamic>> getAllSongs({int skip = 0, int limit = 50, String? status}) async {
    final params = {'skip': skip.toString(), 'limit': limit.toString()};
    if (status != null) params['status'] = status;
    final uri = Uri.parse('$apiBaseUrl/admin/content/songs/all')
        .replace(queryParameters: params);
    final resp = await http.get(uri, headers: _headers).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw Exception('Request timeout');
      },
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as List<dynamic>;
    }
    throw Exception('Failed to get songs: ${resp.statusCode}');
  }

  // Moderate a song
  Future<Map<String, dynamic>> moderateSong({
    required int songId,
    required String action, // "approve", "reject", "flag"
    String? reason,
  }) async {
    final uri = Uri.parse('$apiBaseUrl/admin/content/songs/moderate');
    final resp = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode({
        'song_id': songId,
        'action': action,
        if (reason != null) 'reason': reason,
      }),
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw Exception('Request timeout');
      },
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to moderate song: ${resp.statusCode}');
  }

  // Get users
  Future<List<dynamic>> getUsers({
    int skip = 0,
    int limit = 50,
    String? role,
    String? search,
  }) async {
    final params = {'skip': skip.toString(), 'limit': limit.toString()};
    if (role != null) params['role'] = role;
    if (search != null) params['search'] = search;
    final uri = Uri.parse('$apiBaseUrl/admin/users')
        .replace(queryParameters: params);
    final resp = await http.get(uri, headers: _headers).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw Exception('Request timeout');
      },
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as List<dynamic>;
    }
    throw Exception('Failed to get users: ${resp.statusCode}');
  }

  // Manage user
  Future<Map<String, dynamic>> manageUser({
    required String userId,
    required String action, // "suspend", "activate", "delete", "promote_to_admin"
    String? reason,
  }) async {
    final uri = Uri.parse('$apiBaseUrl/admin/users/manage');
    final resp = await http.post(
      uri,
      headers: _headers,
      body: jsonEncode({
        'user_id': userId,
        'action': action,
        if (reason != null) 'reason': reason,
      }),
    ).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw Exception('Request timeout');
      },
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as Map<String, dynamic>;
    }
    throw Exception('Failed to manage user: ${resp.statusCode}');
  }

  // Get analytics - upload trends
  Future<List<dynamic>> getUploadTrends({int days = 30}) async {
    final uri = Uri.parse('$apiBaseUrl/admin/analytics/upload-trends')
        .replace(queryParameters: {'days': days.toString()});
    final resp = await http.get(uri, headers: _headers).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw Exception('Request timeout');
      },
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as List<dynamic>;
    }
    throw Exception('Failed to get upload trends: ${resp.statusCode}');
  }

  // Get analytics - user growth
  Future<List<dynamic>> getUserGrowth({int days = 30}) async {
    final uri = Uri.parse('$apiBaseUrl/admin/analytics/user-growth')
        .replace(queryParameters: {'days': days.toString()});
    final resp = await http.get(uri, headers: _headers).timeout(
      const Duration(seconds: 10),
      onTimeout: () {
        throw Exception('Request timeout');
      },
    );
    if (resp.statusCode == 200) {
      return jsonDecode(resp.body) as List<dynamic>;
    }
    throw Exception('Failed to get user growth: ${resp.statusCode}');
  }
}
