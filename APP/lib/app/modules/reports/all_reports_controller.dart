import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../messages/messages_view.dart' show ChatView;

class ReportItem {
  final String id;
  final String ownerUserId;
  final String type;
  final String? name;
  final String? photoUrl;
  final DateTime createdAt;
  final Map<String, dynamic> raw;

  ReportItem({
    required this.id,
    required this.ownerUserId,
    required this.type,
    this.name,
    this.photoUrl,
    required this.createdAt,
    required this.raw,
  });
}

class AllReportsController extends GetxController {
  final supa = Supabase.instance.client;

  final reports = <ReportItem>[].obs;
  final loading = false.obs;

  final filterType = 'all'.obs;

  final searchTerm = ''.obs;

  String _normalize(String s) {
    var t = s.toLowerCase();
    t = t
        .replaceAll('أ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('آ', 'ا')
        .replaceAll('ى', 'ي')
        .replaceAll('ئ', 'ي')
        .replaceAll('ؤ', 'و')
        .replaceAll('ة', 'ه')
        .replaceAll('ـ', '')
        .replaceAll(RegExp(r'[^\u0600-\u06FFa-z0-9\s]'), '');
    return t.trim();
  }

  void setFilterType(String v) {
    filterType.value = v;
    fetchReports();
  }

  void setSearch(String v) {
    searchTerm.value = v;
  }

  @override
  void onInit() {
    super.onInit();
    debounce<String>(searchTerm, (_) => fetchReports(),
        time: const Duration(milliseconds: 300));
    fetchReports();
  }

  Future<void> fetchReports() async {
    loading.value = true;
    try {
      final miss = await _fetchTable('missing_persons', 'missing');
      final found = await _fetchTable('found_persons', 'found');

      var all = <ReportItem>[...miss, ...found];

      final me = supa.auth.currentUser?.id?.toString();
      if (me != null && me.isNotEmpty) {
        all = all.where((e) => e.ownerUserId.toString() != me).toList();
      }

      if (filterType.value != 'all') {
        all = all.where((e) => e.type == filterType.value).toList();
      }

      final q = _normalize(searchTerm.value);
      if (q.isNotEmpty) {
        bool matches(ReportItem e) {
          final cands = <String>[
            e.name ?? '',
            e.raw['name']?.toString() ?? '',
            e.raw['full_name']?.toString() ?? '',
            e.raw['person_name']?.toString() ?? '',
          ];
          return cands.any((s) => _normalize(s).contains(q));
        }
        all = all.where(matches).toList();
      }

      all.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      reports.assignAll(all);
    } catch (e) {
      Get.snackbar('Error', 'Failed to load reports: $e',
          snackPosition: SnackPosition.BOTTOM);
    } finally {
      loading.value = false;
    }
  }


  Future<List<ReportItem>> _fetchTable(String table, String type) async {
    final res = await supa.from(table).select('*').limit(1000);

    return (res as List).map((row) {
      final map = Map<String, dynamic>.from(row as Map);

      map.removeWhere((k, v) {
        final kk = k.toString().toLowerCase();
        return kk.contains('embedding') || kk.contains('vector');
      });

      final id = (map['id'] ?? '').toString();
      final owner = (map['user_id'] ?? map['owner_id'] ?? '').toString();

      final name = (map['name'] ?? map['full_name'] ?? map['person_name'] ?? '')
          .toString();
      final nameOrNull = name.isEmpty ? null : name;

      String? photo;
      if (map['primary_photo_url'] is String &&
          (map['primary_photo_url'] as String).isNotEmpty) {
        photo = map['primary_photo_url'] as String;
      } else if (map['photo_urls'] is List &&
          (map['photo_urls'] as List).isNotEmpty) {
        photo = (map['photo_urls'] as List).first?.toString();
      } else if (map['image_url'] is String &&
          (map['image_url'] as String).isNotEmpty) {
        photo = map['image_url'] as String;
      }

      final created =
          DateTime.tryParse(map['created_at']?.toString() ?? '') ??
              DateTime.now();

      return ReportItem(
        id: id,
        ownerUserId: owner,
        type: type,
        name: nameOrNull,
        photoUrl: photo,
        createdAt: created,
        raw: map,
      );
    }).toList();
  }

  Future<void> openChatWithOwner(ReportItem item) async {
    final me = supa.auth.currentUser?.id;
    if (me == null) {
      Get.snackbar('Not signed in', 'Please sign in to start a conversation.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (item.ownerUserId.isEmpty) {
      Get.snackbar('Unavailable', 'This report has no owner linked.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    if (item.ownerUserId == me) {
      Get.snackbar('Info', 'This is your own report.',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    try {
      final participants = [me, item.ownerUserId]..sort();

      final existing = await supa
          .from('conversations')
          .select('id, participant_user_ids')
          .contains('participant_user_ids', participants)
          .maybeSingle();

      String convId;
      if (existing != null && existing['id'] != null) {
        convId = existing['id'] as String;
      } else {
        final inserted = await supa
            .from('conversations')
            .insert({
          'participant_user_ids': participants,
          'created_at': DateTime.now().toIso8601String(),
        })
            .select('id')
            .single();
        convId = inserted['id'] as String;
      }

      Get.to(() => ChatView(conversationId: convId));
    } on PostgrestException catch (e) {
      Get.snackbar('Error', e.message,
          snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 4));
    } catch (e) {
      Get.snackbar('Error', 'Could not open chat: $e',
          snackPosition: SnackPosition.BOTTOM, duration: const Duration(seconds: 4));
    }
  }

}
