import 'dart:convert';
import 'dart:math';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../routes/app_routes.dart';

class MatchService {
  static const double threshold = 0.80;
  static const int topK = 10;

  static Future<void> checkAndRoute({
    required bool isMissing,
    required String currentId,
    required List<List<double>> myEmbeddings,
    required BuildContext context,
  }) async {
    try {
      if (myEmbeddings.isEmpty) {
        Navigator.of(context).pushNamed(AppRoutes.NO_MATCH);
        return;
      }

      final sp = Supabase.instance.client;
      final String? uid = sp.auth.currentUser?.id;
      final otherTable = isMissing ? 'found_persons' : 'missing_persons';

      final rows = await sp
          .from(otherTable)
          .select('id, user_id, name, photo_urls, face_embeddings')
          .limit(2000);

      if (rows is! List || rows.isEmpty) {
        Navigator.of(context).pushNamed(AppRoutes.NO_MATCH);
        return;
      }

      final scored = <_ScoredRow>[];
      for (final r in rows) {
        final vectors = _extractVectors(r['face_embeddings']);
        if (vectors.isEmpty) continue;

        double best = -1.0;
        for (final mine in myEmbeddings) {
          for (final theirs in vectors) {
            best = math.max(best, _cosine(mine, theirs));
          }
        }

        if (best >= threshold) {
          scored.add(_ScoredRow(
            id: r['id'].toString(),
            userId: (r['user_id'] ?? "").toString(),
            name: (r['name'] ?? '') as String,
            photoUrls: (r['photo_urls'] is List) ? List<String>.from(r['photo_urls']) : const <String>[],
            score: best,
            raw: r as Map<String, dynamic>,
          ));
        }
      }

      if (scored.isEmpty) {
        Navigator.of(context).pushNamed(AppRoutes.NO_MATCH);
        return;
      }

      scored.sort((a, b) => b.score.compareTo(a.score));
      final top = scored.take(topK).toList();

      final best = top.first;
      try {
        final payload = {
          'missing_id': isMissing ? currentId : best.id,
          'found_id': isMissing ? best.id : currentId,
          'confidence': best.score,
          'missing_user_id': isMissing ? uid : best.userId,
          'found_user_id': isMissing ? best.userId : uid,
        };

        await sp.from('matches').upsert(
          payload,
          onConflict: 'missing_id,found_id',
        );
      } catch (_) {}

      Navigator.of(context).pushNamed(
        AppRoutes.MATCHES,
        arguments: {
          'isMissing': isMissing,
          'matches': top
              .map((e) => {
            'id': e.id,
            'name': e.name,
            'photo_urls': e.photoUrls,
            'score': double.parse(e.score.toStringAsFixed(4)),
            'row': e.raw,
          })
              .toList(),
          'sourceEmbeddings': myEmbeddings,
        },
      );
    } on PostgrestException {
      Navigator.of(context).pushNamed(AppRoutes.NO_MATCH);
    } catch (_) {
      Navigator.of(context).pushNamed(AppRoutes.NO_MATCH);
    }
  }

  static List<List<double>> _extractVectors(dynamic faceEmb) {
    if (faceEmb == null) return const [];

    if (faceEmb is List) {
      return faceEmb
          .where((v) => v is List && v.isNotEmpty)
          .map<List<double>>((v) => List<double>.from((v as List).map((x) => (x as num).toDouble())))
          .toList();
    }

    if (faceEmb is Map) {
      if (faceEmb['vectors'] is List) {
        return (faceEmb['vectors'] as List)
            .where((v) => v is List && v.isNotEmpty)
            .map<List<double>>((v) => List<double>.from((v as List).map((x) => (x as num).toDouble())))
            .toList();
      }
      if (faceEmb['images'] is List) {
        final imgs = faceEmb['images'] as List;
        return imgs
            .where((m) => m is Map && m['embedding'] is List)
            .map<List<double>>((m) => List<double>.from((m['embedding'] as List).map((x) => (x as num).toDouble())))
            .toList();
      }
    }

    return const [];
  }

  static double _cosine(List<double> a, List<double> b) {
    final n = math.min(a.length, b.length);
    double dot = 0, na = 0, nb = 0;
    for (var i = 0; i < n; i++) {
      final x = a[i], y = b[i];
      dot += x * y;
      na += x * x;
      nb += y * y;
    }
    final denom = (math.sqrt(na) * math.sqrt(nb));
    return denom == 0 ? -1.0 : (dot / denom);
  }

  Future<String> confirmMatchAndOpenConversation(String matchId) async {
    final sp = Supabase.instance.client;
    final result = await sp.rpc('confirm_match', params: {
      'p_match_id': matchId,
    });

    String conversationId;
    if (result is Map && result['conversation_id'] != null) {
      conversationId = result['conversation_id'] as String;
    } else if (result is List && result.isNotEmpty) {
      final first = result.first;
      if (first is Map && first['conversation_id'] != null) {
        conversationId = first['conversation_id'] as String;
      } else {
        throw Exception('confirm_match returned unexpected shape');
      }
    } else if (result is String && result.isNotEmpty) {
      conversationId = result;
    } else {
      throw Exception('No conversation_id returned');
    }

    return conversationId;
  }
}

class _ScoredRow {
  final String id;
  final String userId;
  final String name;
  final List<String> photoUrls;
  final double score;
  final Map<String, dynamic> raw;
  _ScoredRow({
    required this.id,
    required this.userId,
    required this.name,
    required this.photoUrls,
    required this.score,
    required this.raw,
  });
}
