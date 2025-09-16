import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:hive/hive.dart';
import 'package:uuid/uuid.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'supabase_service.dart';

class LocalSyncService {
  static Future<void> syncOne({required String boxName, required dynamic key}) async {
    final sp = Supabase.instance.client;
    final user = sp.auth.currentUser;
    if (user == null) {
      throw Exception('Not signed in – no auth user for sync.');
    }
    final uid = user.id;

    if (!Hive.isBoxOpen(boxName)) {
      await Hive.openBox(boxName);
    }
    final box = Hive.box(boxName);

    Map<String, dynamic> item = Map<String, dynamic>.from(box.get(key));
    item['sync'] ??= {'status': 'pending', 'remote_id': null};

    item['sync']['status'] = 'uploading';
    await box.put(key, item);

    final bool isMissing = boxName == 'missing_local';

    try {
      final List<dynamic> imgs = (item['photos'] ?? item['images'] ?? []) as List<dynamic>;
      final List<List<double>> faceEmbeddings = [];
      final List<String> photoUrls = [];

      final folderId = const Uuid().v4();

      for (int i = 0; i < imgs.length; i++) {
        final m = Map<String, dynamic>.from(imgs[i]);

        final emb = m['embedding'];
        if (emb != null) {
          final vec = (emb as List).map((e) => (e as num).toDouble()).toList();
          if (vec.isNotEmpty) faceEmbeddings.add(List<double>.from(vec));
        }

        final p = (m['path'] ?? '') as String;
        if (p.isEmpty) continue;
        final f = File(p);
        if (!await f.exists()) continue;

        final ext = _extFromPath(p);
        final objectName = '${isMissing ? 'missing' : 'found'}/$folderId/$i.$ext';

        final url = await SupabaseService.uploadPersonPhoto(
          file: f,
          objectName: objectName,
          contentType: 'image/$ext',
        );
        if (url != null) {
          photoUrls.add(url);
        }
      }

      Map<String, dynamic> data;
      if (isMissing) {
        data = {
          'user_id': uid,
          'name': item['name'],
          'age': _tryParseInt(item['age']),
          'location': item['last_seen_location'],
          'last_seen_at': item['last_seen_date'],
          'description': item['description'],
          'reporter_name': item['reporter_name'],
          'reporter_phone': item['reporter_phone'],
          'reporter_email': item['reporter_email'],
          'photo_urls': photoUrls,
          'face_embeddings': faceEmbeddings,
          'created_at': DateTime.now().toIso8601String(),
        };

        final remoteId = await SupabaseService.insertMissing(data);
        item['sync'] = {'status': 'uploaded', 'remote_id': remoteId};
        await box.put(key, item);
      } else {
        data = {
          'user_id': uid,
          'name': item['name'],
          'estimated_age': _tryParseInt(item['estimated_age']),
          'location': item['location'],
          'found_date': item['found_date'],
          'condition': item['condition'],
          'description': item['description'],
          'finder_name': item['finder_name'],
          'finder_phone': item['finder_phone'],
          'finder_email': item['finder_email'],
          'hospital_info': item['hospital_info'],
          'photo_urls': photoUrls,
          'face_embeddings': faceEmbeddings,
          'created_at': DateTime.now().toIso8601String(),
        };

        final remoteId = await SupabaseService.insertFound(data);
        item['sync'] = {'status': 'uploaded', 'remote_id': remoteId};
        await box.put(key, item);
      }

      debugPrint('✅ Sync done for [$boxName:$key]');
    } catch (e, st) {
      debugPrint('❌ Sync failed for [$boxName:$key]: $e\n$st');
      item['sync']['status'] = 'failed';
      await box.put(key, item);
      rethrow;
    }
  }

  static String _extFromPath(String p) {
    final dot = p.lastIndexOf('.');
    if (dot == -1 || dot == p.length - 1) return 'jpg';
    return p.substring(dot + 1).toLowerCase();
  }

  static int? _tryParseInt(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is String) return int.tryParse(v.trim());
    return null;
  }
}
