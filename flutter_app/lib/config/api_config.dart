// lib/config/api_config.dart

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:io' show Platform;

const String _prefsApiOverride = 'api_base_url_override';

/// Runtime URL set from the Login screen — **debug builds only** (LAN / emulator).
String? _runtimeOverride;

/// HTTPS origin of the deployed API (no trailing slash), e.g. `https://api.noize.app`.
/// Used for **release and profile** builds when [String.fromEnvironment] `API_BASE_URL` is not set.
/// Set this before distributing test APKs/IPAs, or pass `--dart-define=API_BASE_URL=...` when building.
const String kProductionApiBaseUrl = '';

/// Call once at startup (e.g. from [main]) before any HTTP calls.
Future<void> initApiConfig() async {
  final prefs = await SharedPreferences.getInstance();
  if (!kDebugMode) {
    _runtimeOverride = null;
    await prefs.remove(_prefsApiOverride);
    return;
  }
  final v = prefs.getString(_prefsApiOverride);
  _runtimeOverride = (v != null && v.trim().isNotEmpty) ? _normalizeUrl(v) : null;
}

/// Persist a backend base URL for **debug** builds only (e.g. LAN IP). No-op in release/profile.
Future<void> setApiBaseUrlOverride(String? url) async {
  if (!kDebugMode) return;
  final prefs = await SharedPreferences.getInstance();
  if (url == null || url.trim().isEmpty) {
    await prefs.remove(_prefsApiOverride);
    _runtimeOverride = null;
    return;
  }
  final n = _normalizeUrl(url.trim());
  await prefs.setString(_prefsApiOverride, n);
  _runtimeOverride = n;
}

String _normalizeUrl(String raw) {
  var u = raw.trim();
  if (!u.startsWith('http://') && !u.startsWith('https://')) {
    u = 'http://$u';
  }
  while (u.endsWith('/')) {
    u = u.substring(0, u.length - 1);
  }
  return u;
}

/// API base URL resolution:
/// 1. `--dart-define=API_BASE_URL=...` (recommended for CI and store builds).
/// 2. **Release / profile:** [kProductionApiBaseUrl] when the define is empty.
/// 3. **Debug only:** Login → Backend URL override, then local dev defaults
///    (emulator `http://10.0.2.2:8000`, etc.).
String get apiBaseUrl {
  const fromEnv = String.fromEnvironment('API_BASE_URL', defaultValue: '');
  if (fromEnv.isNotEmpty) {
    return _normalizeUrl(fromEnv);
  }

  if (!kDebugMode) {
    final p = kProductionApiBaseUrl.trim();
    if (p.isNotEmpty) {
      return _normalizeUrl(p);
    }
    // Misconfigured release/profile build: set [kProductionApiBaseUrl] or pass --dart-define=API_BASE_URL=...
    return 'https://api-not-configured.invalid';
  }

  if (_runtimeOverride != null && _runtimeOverride!.isNotEmpty) {
    return _runtimeOverride!;
  }
  return _defaultBaseUrlDev();
}

String _defaultBaseUrlDev() {
  if (kIsWeb) {
    return 'http://localhost:8000';
  }
  try {
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
  } catch (_) {
    // Platform not available; fall back to loopback
  }
  return 'http://127.0.0.1:8000';
}
