// lib/config/api_config.dart

import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;

/// API base URL selection with optional compile-time override.
/// - Android emulator: http://10.0.2.2:8000
/// - iOS/desktop/web: http://127.0.0.1:8000
/// - Override via: --dart-define=API_BASE_URL=http://192.168.x.x:8000
final String apiBaseUrl = const String.fromEnvironment('API_BASE_URL').isNotEmpty
    ? const String.fromEnvironment('API_BASE_URL')
    : _defaultBaseUrl();

String _defaultBaseUrl() {
  if (kIsWeb) {
    // For web, prefer localhost over 127.0.0.1 as some browsers handle it better
    return 'http://localhost:8000';
  }
  try {
    if (Platform.isAndroid) return 'http://10.0.2.2:8000';
  } catch (_) {
    // Platform not available; fall back to loopback
  }
  return 'http://127.0.0.1:8000';
}
