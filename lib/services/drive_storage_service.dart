import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'google_auth_service.dart';

/// Stores ALL VaultX user data in Google Drive (appDataFolder).
/// JSON manifest file: vaultx_manifest.json
/// Images: uploaded as binary files with unique names.
class DriveStorageService {
  static const _manifestFileName = 'vaultx_manifest.json';
  static const _baseUrl = 'https://www.googleapis.com/drive/v3';
  static const _uploadUrl = 'https://www.googleapis.com/upload/drive/v3';

  // ─── Manifest helpers ────────────────────────────────────────────────────

  static Future<Map<String, String>> _headers() async =>
      await GoogleAuthService.getAuthHeaders();

  /// Find file ID of a named file in appDataFolder
  static Future<String?> _findFileId(String name) async {
    final h = await _headers();
    final uri = Uri.parse(
      '$_baseUrl/files?spaces=appDataFolder&q=name%3D%22$name%22&fields=files(id)',
    );
    final res = await http.get(uri, headers: h);
    if (res.statusCode != 200) return null;
    final files = jsonDecode(res.body)['files'] as List;
    return files.isEmpty ? null : files.first['id'] as String;
  }

  /// Download and parse the manifest JSON
  static Future<Map<String, dynamic>> _loadManifest() async {
    final id = await _findFileId(_manifestFileName);
    if (id == null) return {'documents': [], 'passwords': []};
    final h = await _headers();
    final res = await http.get(
      Uri.parse('$_baseUrl/files/$id?alt=media'),
      headers: h,
    );
    if (res.statusCode != 200) return {'documents': [], 'passwords': []};
    try {
      return jsonDecode(res.body) as Map<String, dynamic>;
    } catch (_) {
      return {'documents': [], 'passwords': []};
    }
  }

  /// Upload/overwrite the manifest
  static Future<void> _saveManifest(Map<String, dynamic> manifest) async {
    final existingId = await _findFileId(_manifestFileName);
    final body = jsonEncode(manifest);
    final h = await _headers();

    if (existingId == null) {
      // Create new
      final metaRes = await http.post(
        Uri.parse('$_uploadUrl/files?uploadType=multipart'),
        headers: {
          ...h,
          'Content-Type':
              'multipart/related; boundary=vaultx_boundary',
        },
        body: _buildMultipart(
          metadata: jsonEncode({
            'name': _manifestFileName,
            'parents': ['appDataFolder'],
          }),
          mimeType: 'application/json',
          content: utf8.encode(body),
        ),
      );
      debugPrint('Manifest create: ${metaRes.statusCode}');
    } else {
      // Update existing
      await http.patch(
        Uri.parse(
            '$_uploadUrl/files/$existingId?uploadType=media'),
        headers: {...h, 'Content-Type': 'application/json'},
        body: body,
      );
    }
  }

  static List<int> _buildMultipart({
    required String metadata,
    required String mimeType,
    required List<int> content,
  }) {
    const boundary = 'vaultx_boundary';
    final buffer = StringBuffer();
    buffer.writeln('--$boundary');
    buffer.writeln('Content-Type: application/json; charset=UTF-8');
    buffer.writeln();
    buffer.writeln(metadata);
    buffer.writeln('--$boundary');
    buffer.writeln('Content-Type: $mimeType');
    buffer.writeln();
    final prefix = utf8.encode(buffer.toString());
    final suffix = utf8.encode('\n--$boundary--');
    return [...prefix, ...content, ...suffix];
  }

  // ─── Image upload ─────────────────────────────────────────────────────────

  /// Upload an image file to Drive appDataFolder, return its Drive file ID
  static Future<String?> uploadImage(File imageFile, String fileName) async {
    try {
      final h = await _headers();
      final bytes = await imageFile.readAsBytes();
      final res = await http.post(
        Uri.parse('$_uploadUrl/files?uploadType=multipart'),
        headers: {
          ...h,
          'Content-Type':
              'multipart/related; boundary=vaultx_boundary',
        },
        body: _buildMultipart(
          metadata: jsonEncode({
            'name': fileName,
            'parents': ['appDataFolder'],
          }),
          mimeType: 'image/jpeg',
          content: bytes,
        ),
      );
      if (res.statusCode == 200 || res.statusCode == 201) {
        final data = jsonDecode(res.body);
        return data['id'] as String?;
      }
      return null;
    } catch (e) {
      debugPrint('Upload image error: $e');
      return null;
    }
  }

  /// Download a Drive image file to local temp cache, returns local path
  static Future<String?> downloadImage(
      String driveFileId, String localName) async {
    try {
      final h = await _headers();
      final res = await http.get(
        Uri.parse('$_baseUrl/files/$driveFileId?alt=media'),
        headers: h,
      );
      if (res.statusCode != 200) return null;
      final dir = Directory.systemTemp;
      final file = File('${dir.path}/vaultx_cache/$localName');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(res.bodyBytes);
      return file.path;
    } catch (e) {
      debugPrint('Download image error: $e');
      return null;
    }
  }

  /// Delete a file from Drive
  static Future<void> deleteFile(String driveFileId) async {
    try {
      final h = await _headers();
      await http.delete(
        Uri.parse('$_baseUrl/files/$driveFileId'),
        headers: h,
      );
    } catch (e) {
      debugPrint('Delete file error: $e');
    }
  }

  // ─── Documents API ────────────────────────────────────────────────────────

  static Future<List<Map<String, dynamic>>> getDocumentsByCategory(
      String category) async {
    final manifest = await _loadManifest();
    final docs = List<Map<String, dynamic>>.from(
        (manifest['documents'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map)));
    return docs
        .where((d) => d['category'] == category)
        .toList()
      ..sort((a, b) =>
          (b['created_at'] as String).compareTo(a['created_at'] as String));
  }

  static Future<List<Map<String, dynamic>>> getAllDocuments() async {
    final manifest = await _loadManifest();
    return List<Map<String, dynamic>>.from(
        (manifest['documents'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map)));
  }

  static Future<int> saveDocument({
    required String name,
    required String category,
    required String frontDriveId,
    String? backDriveId,
    String contentMode = 'card', // 'card' or 'document'
    String? pageSize, // 'A4', 'Letter', 'Custom'
    double? customWidth,
    double? customHeight,
  }) async {
    final manifest = await _loadManifest();
    final docs = List<Map<String, dynamic>>.from(
        (manifest['documents'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map)));
    final id = DateTime.now().millisecondsSinceEpoch;
    docs.add({
      'id': id,
      'name': name,
      'category': category,
      'front_drive_id': frontDriveId,
      'back_drive_id': backDriveId,
      'content_mode': contentMode,
      'page_size': pageSize ?? 'A4',
      'custom_width': customWidth,
      'custom_height': customHeight,
      'created_at': DateTime.now().toIso8601String(),
    });
    manifest['documents'] = docs;
    await _saveManifest(manifest);
    return id;
  }

  static Future<void> deleteDocument(int id) async {
    final manifest = await _loadManifest();
    final docs = List<Map<String, dynamic>>.from(
        (manifest['documents'] as List? ?? [])
            .map((e) => Map<String, dynamic>.from(e as Map)));
    final doc = docs.firstWhere((d) => d['id'] == id,
        orElse: () => {});
    if (doc.isNotEmpty) {
      if (doc['front_drive_id'] != null) {
        await deleteFile(doc['front_drive_id'] as String);
      }
      if (doc['back_drive_id'] != null) {
        await deleteFile(doc['back_drive_id'] as String);
      }
    }
    docs.removeWhere((d) => d['id'] == id);
    manifest['documents'] = docs;
    await _saveManifest(manifest);
  }

  // ─── Passwords API ────────────────────────────────────────────────────────

  static Future<List<Map<String, String>>> getPasswords() async {
    final manifest = await _loadManifest();
    return List<Map<String, String>>.from(
        (manifest['passwords'] as List? ?? [])
            .map((e) => Map<String, String>.from(
                (e as Map).map((k, v) => MapEntry(k.toString(), v.toString())))));
  }

  static Future<void> savePasswords(
      List<Map<String, String>> passwords) async {
    final manifest = await _loadManifest();
    manifest['passwords'] = passwords;
    await _saveManifest(manifest);
  }
}
