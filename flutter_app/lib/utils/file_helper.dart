// Platform-specific file handling helper
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'dart:typed_data';

// Conditional import for platform-specific implementations
import 'file_helper_io.dart' if (dart.library.html) 'file_helper_web.dart' as file_helper;

/// Platform-agnostic file reference
class PlatformFile {
  final String? path;
  final Uint8List? bytes;
  final String? name;
  
  PlatformFile({this.path, this.bytes, this.name});
  
  bool get isWeb => kIsWeb;
}

/// Create a platform file from XFile
Future<PlatformFile> createPlatformFile(dynamic xFile) async {
  if (kIsWeb) {
    final bytes = await xFile.readAsBytes();
    return PlatformFile(bytes: bytes, name: xFile.name);
  } else {
    return PlatformFile(path: xFile.path);
  }
}

/// Build an image widget from a file path (platform-aware)
Widget buildImageFromPath(String path) {
  return file_helper.buildImageFromPath(path);
}
