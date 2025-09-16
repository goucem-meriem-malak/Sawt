import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final _sp = Supabase.instance.client;
  static const _bucket = 'person';

  static Future<String?> uploadPersonPhoto({
    required File file,
    required String objectName,
    String? contentType,
  }) async {
    try {
      await _sp.storage.from(_bucket).upload(
        objectName,
        file,
        fileOptions: FileOptions(
          upsert: true,
          contentType: contentType,
        ),
      );

      final publicUrl = _sp.storage.from(_bucket).getPublicUrl(objectName);
      return publicUrl;
    } on StorageException catch (e) {
      print('Storage upload error (${e.statusCode}): ${e.message} @ $objectName');
      return null;
    } catch (e) {
      print('Upload unknown error: $e');
      return null;
    }
  }

  static Future<String> insertMissing(Map<String, dynamic> data) async {
    final res = await _sp.from('missing_persons').insert(data).select('id').single();
    return res['id'] as String;
  }

  static Future<String> insertFound(Map<String, dynamic> data) async {
    final res = await _sp.from('found_persons').insert(data).select('id').single();
    return res['id'] as String;
  }
}
