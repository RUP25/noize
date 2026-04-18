// lib/services/auth_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/api_config.dart';

/// Builds an absolute path under the API base (avoids `//` when the base URL has a trailing slash).
String _apiPath(String relative) {
  final base = Uri.parse(apiBaseUrl);
  var p = base.path;
  if (p.endsWith('/')) {
    p = p.substring(0, p.length - 1);
  }
  final r = relative.startsWith('/') ? relative.substring(1) : relative;
  if (p.isEmpty) return '/$r';
  return '$p/$r';
}

class AuthService {
  AuthService._internal();
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;

  final ValueNotifier<String?> authToken = ValueNotifier<String?>(null);
  static const _prefsKey = 'access_token';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    authToken.value = prefs.getString(_prefsKey);
  }

  bool get isLoggedIn => authToken.value != null && authToken.value!.isNotEmpty;
  String? get token => authToken.value;
  Map<String, String> get authHeader {
    final t = token;
    if (t == null || t.isEmpty) return {};
    return {'Authorization': 'Bearer $t'};
  }

  Future<Map<String, dynamic>> requestOtp(String contact) async {
    if (contact.trim().isEmpty) throw AuthException('Contact cannot be empty');

    final uri = Uri.parse(apiBaseUrl).replace(path: _apiPath('auth/otp/request'));
    try {
      final resp = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'contact': contact.trim()}),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception(
                  'OTP request timeout. No response from $apiBaseUrl. '
                  'For local development use a debug build with the backend running; test/release builds must use your deployed API URL.');
            },
          );

      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      } else {
        var msg = 'OTP request failed (${resp.statusCode})';
        try {
          final parsed = jsonDecode(resp.body);
          msg += ': ${parsed['detail'] ?? parsed}';
        } catch (_) {}
        throw AuthException(msg, statusCode: resp.statusCode);
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Network error: $e');
    }
  }

  Future<String> verifyOtp({required String contact, required String otp}) async {
    if (contact.trim().isEmpty) throw AuthException('Contact cannot be empty');
    if (otp.trim().isEmpty) throw AuthException('OTP cannot be empty');

    final uri = Uri.parse(apiBaseUrl).replace(path: _apiPath('auth/otp/verify'));
    try {
      final resp = await http
          .post(
            uri,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'contact': contact.trim(), 'otp': otp.trim()}),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              throw Exception(
                  'OTP verify timeout. No response from $apiBaseUrl.');
            },
          );

      if (resp.statusCode == 200) {
        final Map<String, dynamic> j = jsonDecode(resp.body);
        final token = j['access_token']?.toString();
        if (token == null || token.isEmpty) {
          throw AuthException('Verify succeeded but no access_token returned');
        }
        await _saveToken(token);
        return token;
      } else {
        var msg = 'OTP verify failed (${resp.statusCode})';
        try {
          final parsed = jsonDecode(resp.body);
          msg += ': ${parsed['detail'] ?? parsed}';
        } catch (_) {}
        throw AuthException(msg, statusCode: resp.statusCode);
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Network error: $e');
    }
  }

  Future<void> _saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, token);
    authToken.value = token;
  }

  Future<Map<String, dynamic>?> getMe() async {
    final base = Uri.parse(apiBaseUrl);
    final uri = base.replace(path: '${base.path}/user/me');
    try {
      final resp = await http.get(uri, headers: authHeader);
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<Map<String, dynamic>> upgradeToPremium({required String role, bool kycVerified = false}) async {
    final base = Uri.parse(apiBaseUrl);
    final uri = base.replace(path: '${base.path}/user/upgrade');
    try {
      final resp = await http.post(
        uri, 
        headers: {...authHeader, 'Content-Type': 'application/json'},
        body: jsonEncode({'role': role, 'kyc_verified': kycVerified}),
      );
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      } else {
        var msg = 'Upgrade failed (${resp.statusCode})';
        try {
          final parsed = jsonDecode(resp.body);
          msg += ': ${parsed['detail'] ?? parsed}';
        } catch (_) {}
        throw AuthException(msg, statusCode: resp.statusCode);
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Network error: $e');
    }
  }

  /// NOIZE Artist+ — channel monetisation (₹299 standard / ₹599 pro per month, prototype).
  Future<Map<String, dynamic>> upgradeArtistPlus({required String tier, bool kycVerified = false}) async {
    final base = Uri.parse(apiBaseUrl);
    final uri = base.replace(path: '${base.path}/user/artist-plus');
    try {
      final resp = await http.post(
        uri,
        headers: {...authHeader, 'Content-Type': 'application/json'},
        body: jsonEncode({'tier': tier, 'kyc_verified': kycVerified}),
      );
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
      var msg = 'Artist+ upgrade failed (${resp.statusCode})';
      try {
        final parsed = jsonDecode(resp.body);
        msg += ': ${parsed['detail'] ?? parsed}';
      } catch (_) {}
      throw AuthException(msg, statusCode: resp.statusCode);
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Network error: $e');
    }
  }

  Future<String> loginEmailPassword({required String email, required String password}) async {
    if (email.trim().isEmpty) throw AuthException('Email cannot be empty');
    if (password.trim().isEmpty) throw AuthException('Password cannot be empty');

    final base = Uri.parse(apiBaseUrl);
    final uri = base.replace(path: '${base.path}/auth/login/email');
    try {
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email.trim(), 'password': password.trim()}),
      );

      if (resp.statusCode == 200) {
        final Map<String, dynamic> j = jsonDecode(resp.body);
        final token = j['access_token']?.toString();
        if (token == null || token.isEmpty) {
          throw AuthException('Login succeeded but no access_token returned');
        }
        await _saveToken(token);
        return token;
      } else {
        var msg = 'Login failed (${resp.statusCode})';
        try {
          final parsed = jsonDecode(resp.body);
          msg += ': ${parsed['detail'] ?? parsed}';
        } catch (_) {}
        throw AuthException(msg, statusCode: resp.statusCode);
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Network error: $e');
    }
  }

  Future<String> signupEmailPassword({
    required String email,
    required String password,
    required String contact,
  }) async {
    if (email.trim().isEmpty) throw AuthException('Email cannot be empty');
    if (password.trim().isEmpty) throw AuthException('Password cannot be empty');
    if (contact.trim().isEmpty) throw AuthException('Phone number cannot be empty');
    if (password.length < 6) throw AuthException('Password must be at least 6 characters');

    final base = Uri.parse(apiBaseUrl);
    final uri = base.replace(path: '${base.path}/auth/signup/email');
    try {
      final resp = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email.trim(),
          'password': password.trim(),
          'contact': contact.trim(),
        }),
      );

      if (resp.statusCode == 200) {
        final Map<String, dynamic> j = jsonDecode(resp.body);
        final token = j['access_token']?.toString();
        if (token == null || token.isEmpty) {
          throw AuthException('Signup succeeded but no access_token returned');
        }
        await _saveToken(token);
        return token;
      } else {
        var msg = 'Signup failed (${resp.statusCode})';
        try {
          final parsed = jsonDecode(resp.body);
          msg += ': ${parsed['detail'] ?? parsed}';
        } catch (_) {}
        throw AuthException(msg, statusCode: resp.statusCode);
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> updateProfile({
    String? channelName,
    String? bannerUrl,
    String? photoUrl,
    String? fullName,
    String? dateOfBirth, // ISO yyyy-mm-dd
  }) async {
    final base = Uri.parse(apiBaseUrl);
    final uri = base.replace(path: '${base.path}/user/profile');
    try {
      final body = <String, dynamic>{};
      if (channelName != null) body['channel_name'] = channelName;
      if (bannerUrl != null) body['banner_url'] = bannerUrl;
      if (photoUrl != null) body['photo_url'] = photoUrl;
      if (fullName != null) body['full_name'] = fullName;
      if (dateOfBirth != null) body['date_of_birth'] = dateOfBirth;
      
      final resp = await http.put(
        uri,
        headers: {...authHeader, 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(
        const Duration(seconds: 30),
        onTimeout: () {
          throw Exception('Request timeout. Check if backend is running at $apiBaseUrl');
        },
      );
      
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      } else {
        var msg = 'Update failed (${resp.statusCode})';
        try {
          final parsed = jsonDecode(resp.body);
          msg += ': ${parsed['detail'] ?? parsed}';
        } catch (_) {
          msg += ': ${resp.body}';
        }
        throw AuthException(msg, statusCode: resp.statusCode);
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      String errorMsg = e.toString();
      if (errorMsg.contains('Failed to fetch') || errorMsg.contains('Network error')) {
        throw AuthException('Cannot connect to backend at $apiBaseUrl. Make sure the backend is running.');
      }
      throw AuthException('Network error: $e');
    }
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    if (currentPassword.isEmpty) throw AuthException('Current password cannot be empty');
    if (newPassword.isEmpty) throw AuthException('New password cannot be empty');
    if (newPassword.length < 6) throw AuthException('New password must be at least 6 characters');

    final base = Uri.parse(apiBaseUrl);
    final uri = base.replace(path: '${base.path}/user/change-password');
    try {
      final resp = await http.post(
        uri,
        headers: {...authHeader, 'Content-Type': 'application/json'},
        body: jsonEncode({
          'current_password': currentPassword,
          'new_password': newPassword,
        }),
      );
      
      if (resp.statusCode == 200) {
        return;
      } else {
        var msg = 'Password change failed (${resp.statusCode})';
        try {
          final parsed = jsonDecode(resp.body);
          msg += ': ${parsed['detail'] ?? parsed}';
        } catch (_) {}
        throw AuthException(msg, statusCode: resp.statusCode);
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Network error: $e');
    }
  }

  Future<void> deleteAccount() async {
    final base = Uri.parse(apiBaseUrl);
    final uri = base.replace(path: '${base.path}/user/account');
    try {
      final resp = await http.delete(
        uri,
        headers: authHeader,
      );
      
      if (resp.statusCode == 200) {
        await logout();
        return;
      } else {
        var msg = 'Account deletion failed (${resp.statusCode})';
        try {
          final parsed = jsonDecode(resp.body);
          msg += ': ${parsed['detail'] ?? parsed}';
        } catch (_) {}
        throw AuthException(msg, statusCode: resp.statusCode);
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> getSettings() async {
    final base = Uri.parse(apiBaseUrl);
    final uri = base.replace(path: '${base.path}/user/settings');
    try {
      final resp = await http.get(uri, headers: authHeader).timeout(
        const Duration(seconds: 5),
        onTimeout: () {
          throw Exception('Request timeout. Check if backend is running at $apiBaseUrl');
        },
      );
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      } else {
        var msg = 'Failed to get settings (${resp.statusCode})';
        try {
          final parsed = jsonDecode(resp.body);
          msg += ': ${parsed['detail'] ?? parsed}';
        } catch (_) {}
        throw AuthException(msg, statusCode: resp.statusCode);
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Network error: $e');
    }
  }

  Future<Map<String, dynamic>> updateSettings({
    Map<String, dynamic>? notificationSettings,
    Map<String, dynamic>? privacySettings,
    String? language,
    String? location,
    Map<String, dynamic>? experiencePreferences,
  }) async {
    final base = Uri.parse(apiBaseUrl);
    final uri = base.replace(path: '${base.path}/user/settings');
    try {
      final body = <String, dynamic>{};
      if (notificationSettings != null) body['notification_settings'] = notificationSettings;
      if (privacySettings != null) body['privacy_settings'] = privacySettings;
      if (language != null) body['language'] = language;
      if (location != null) body['location'] = location;
      if (experiencePreferences != null) body['experience_preferences'] = experiencePreferences;
      
      final resp = await http.put(
        uri,
        headers: {...authHeader, 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      ).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout. Check if backend is running at $apiBaseUrl');
        },
      );
      
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      } else {
        var msg = 'Update failed (${resp.statusCode})';
        try {
          final parsed = jsonDecode(resp.body);
          msg += ': ${parsed['detail'] ?? parsed}';
        } catch (_) {}
        throw AuthException(msg, statusCode: resp.statusCode);
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Network error: $e');
    }
  }

  /// Public UI config (admin-editable): story title + greeting strings.
  Future<Map<String, dynamic>?> getUiConfig() async {
    final base = Uri.parse(apiBaseUrl);
    final uri = base.replace(path: '${base.path}/config/ui');
    try {
      final resp = await http.get(uri).timeout(
        const Duration(seconds: 10),
        onTimeout: () {
          throw Exception('Request timeout. Check if backend is running at $apiBaseUrl');
        },
      );
      if (resp.statusCode == 200) {
        return jsonDecode(resp.body) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> submitFeedback(String feedback, {String? email}) async {
    final base = Uri.parse(apiBaseUrl);
    final uri = base.replace(path: '${base.path}/user/feedback');
    try {
      final body = <String, dynamic>{'feedback': feedback};
      if (email != null && email.isNotEmpty) {
        body['email'] = email;
      }
      
      final resp = await http.post(
        uri,
        headers: {...authHeader, 'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );
      
      if (resp.statusCode == 200) {
        return;
      } else {
        var msg = 'Failed to submit feedback (${resp.statusCode})';
        try {
          final parsed = jsonDecode(resp.body);
          msg += ': ${parsed['detail'] ?? parsed}';
        } catch (_) {}
        throw AuthException(msg, statusCode: resp.statusCode);
      }
    } catch (e) {
      if (e is AuthException) rethrow;
      throw AuthException('Network error: $e');
    }
  }

  Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefsKey);
    authToken.value = null;
  }
}

class AuthException implements Exception {
  final String message;
  final int? statusCode;
  AuthException(this.message, {this.statusCode});
  @override
  String toString() => 'AuthException(${statusCode ?? "n/a"}): $message';
}
