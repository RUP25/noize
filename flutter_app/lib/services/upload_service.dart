// lib/services/upload_service.dart
import 'dart:convert';
import 'package:file_selector/file_selector.dart';
import 'package:http/http.dart' as http;
import '../config/api_config.dart';
import 'auth_service.dart';

class UploadService {
  UploadService._internal();
  static final UploadService _instance = UploadService._internal();
  factory UploadService() => _instance;

  final AuthService _auth = AuthService();

  Future<Map<String, dynamic>> requestPresign(String filename, String contentType) async {
    try {
      final base = Uri.parse(apiBaseUrl);
      final uri = base.replace(path: '${base.path}/media/upload-presign');
      final resp = await http.post(uri,
          headers: {..._auth.authHeader, 'Content-Type': 'application/json'},
          body: jsonEncode({'filename': filename, 'content_type': contentType}))
          .timeout(const Duration(seconds: 10));
      if (resp.statusCode == 200) return jsonDecode(resp.body);
      throw Exception('Presign failed: ${resp.statusCode}');
    } catch (e) {
      if (e.toString().contains('Failed to fetch') || e.toString().contains('ClientException')) {
        throw Exception('Cannot connect to server at $apiBaseUrl. Make sure the backend is running.');
      }
      rethrow;
    }
  }

  Future<void> pickAndUpload({required String title, String? album, String? coverPhotoUrl}) async {
    final file = await openFile(
      acceptedTypeGroups: [const XTypeGroup(label: 'audio', extensions: ['mp3', 'm4a', 'wav', 'aac', 'flac'])],
    );
    if (file == null) throw Exception('No file selected');

    final filename = file.name;
    final bytes = await file.readAsBytes();
    final contentType = _lookupContentType(filename);

    try {
      // Use proxy upload to avoid CORS issues with direct R2 uploads from web browsers
      final base = Uri.parse(apiBaseUrl);
      final uploadUri = base.replace(path: '${base.path}/media/upload-proxy');
      
      final request = http.MultipartRequest('POST', uploadUri);
      request.headers.addAll(_auth.authHeader);
      request.files.add(
        http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: filename,
        ),
      );
      
      final streamedResponse = await request.send().timeout(const Duration(seconds: 30));
      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode != 200) {
        throw Exception('Upload failed: ${response.statusCode}');
      }
      
      final data = jsonDecode(response.body);
      final key = data['key'] as String;

      // Register metadata
      final metaUri = base.replace(path: '${base.path}/artist/metadata');
      final headers = <String, String>{
        ..._auth.authHeader,
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
      final metaResp = await http.post(
        metaUri,
        headers: headers,
        body: jsonEncode({
          'title': title,
          if (album != null) 'album': album,
          'r2_key': key,
          'content_type': contentType,
          if (coverPhotoUrl != null) 'cover_photo_url': coverPhotoUrl,
        }),
      ).timeout(const Duration(seconds: 10));

      if (metaResp.statusCode != 200) {
        throw Exception('Metadata failed: ${metaResp.statusCode}');
      }
    } on http.ClientException catch (e) {
      throw Exception('Cannot connect to server at $apiBaseUrl. Make sure the backend is running.');
    } catch (e) {
      if (e.toString().contains('Failed to fetch') || e.toString().contains('ClientException')) {
        throw Exception('Cannot connect to server at $apiBaseUrl. Make sure the backend is running.');
      }
      rethrow;
    }
  }

  String _lookupContentType(String filename) {
    final lower = filename.toLowerCase();
    if (lower.endsWith('.mp3')) return 'audio/mpeg';
    if (lower.endsWith('.m4a')) return 'audio/mp4';
    if (lower.endsWith('.wav')) return 'audio/wav';
    if (lower.endsWith('.aac')) return 'audio/aac';
    if (lower.endsWith('.flac')) return 'audio/flac';
    return 'application/octet-stream';
  }
}
