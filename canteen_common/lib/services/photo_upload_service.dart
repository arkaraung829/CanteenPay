/// Photo Upload Service
///
/// Uploads images to Supabase Storage and returns public URLs.
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

class PhotoUploadService {
  PhotoUploadService._();
  static final PhotoUploadService _instance = PhotoUploadService._();
  static PhotoUploadService get instance => _instance;

  static const _bucket = 'student-photos';
  final _uuid = const Uuid();

  SupabaseClient get _client => Supabase.instance.client;

  /// Upload a photo file and return the public URL.
  /// [folder] groups photos (e.g. 'students', 'profiles').
  Future<String?> upload(File file, {String folder = 'students'}) async {
    try {
      final ext = file.path.split('.').last.toLowerCase();
      final fileName = '${_uuid.v4()}.$ext';
      final path = '$folder/$fileName';

      await _client.storage.from(_bucket).upload(
        path,
        file,
        fileOptions: FileOptions(
          contentType: 'image/$ext',
          upsert: true,
        ),
      );

      final url = _client.storage.from(_bucket).getPublicUrl(path);
      debugPrint('PhotoUploadService: uploaded to $url');
      return url;
    } catch (e) {
      debugPrint('PhotoUploadService: upload failed: $e');
      return null;
    }
  }

  /// Delete a photo by its public URL.
  Future<void> delete(String publicUrl) async {
    try {
      // Extract path from URL
      final uri = Uri.parse(publicUrl);
      final segments = uri.pathSegments;
      final bucketIdx = segments.indexOf(_bucket);
      if (bucketIdx < 0) return;
      final path = segments.sublist(bucketIdx + 1).join('/');

      await _client.storage.from(_bucket).remove([path]);
      debugPrint('PhotoUploadService: deleted $path');
    } catch (e) {
      debugPrint('PhotoUploadService: delete failed: $e');
    }
  }
}
