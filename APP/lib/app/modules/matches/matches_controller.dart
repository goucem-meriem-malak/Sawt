import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/models/match_model.dart';
import '../../data/services/match_service.dart';
import '../messages/messages_view.dart' show ChatView;
import '../messages/messages_controller.dart';

class MatchesController extends GetxController {
  final matches = <PersonMatch>[].obs;
  final isLoading = false.obs;
  final selectedFilter = MatchStatus.pending.obs;

  final List<PersonMatch> _all = [];

  final matchService = MatchService();

  @override
  void onInit() {
    super.onInit();
    final args = Get.arguments;
    if (args is Map && args['matches'] is List) {
      _loadFromArguments(args['matches'] as List);
    } else {
      loadMatches();
    }
  }

  Future<void> loadMatches() async {
    isLoading.value = true;
    try {
      final sp = Supabase.instance.client;
      final uid = sp.auth.currentUser?.id;
      if (uid == null) {
        _all.clear();
        matches.value = [];
        return;
      }

      final rows = await sp
          .from('matches')
          .select('id, missing_id, found_id, confidence, match_date, status, missing_user_id, found_user_id')
          .or('missing_user_id.eq.$uid,found_user_id.eq.$uid')
          .order('match_date', ascending: false);

      _all
        ..clear()
        ..addAll((rows as List).map<PersonMatch>((r) => _fromRow(r as Map<String, dynamic>)));

      _applyFilter();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to load matches: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      isLoading.value = false;
    }
  }

  void _loadFromArguments(List rawMatches) {
    try {
      _all
        ..clear()
        ..addAll(rawMatches.map<PersonMatch>((m) {
          final mm = m as Map;
          return PersonMatch(
            id: (mm['id'] ?? '').toString(),
            missingPersonId: (mm['row']?['missing_id'] ?? mm['missing_id'] ?? '').toString(),
            foundPersonId: (mm['row']?['found_id'] ?? mm['found_id'] ?? '').toString(),
            confidenceScore: (mm['score'] is num)
                ? (mm['score'] as num).toDouble()
                : (mm['row']?['confidence'] as num?)?.toDouble() ?? 0.0,
            matchDate: DateTime.tryParse(
              (mm['row']?['match_date'] ?? DateTime.now().toIso8601String()).toString(),
            ) ??
                DateTime.now(),
            status: MatchStatus.pending,
          );
        }));
      _applyFilter();
    } catch (_) {
      _all.clear();
      matches.value = [];
    }
  }

  Future<void> refreshMatches() async {
    await loadMatches();
    Get.snackbar(
      'Refreshed',
      'Matches updated successfully',
      snackPosition: SnackPosition.BOTTOM,
      backgroundColor: Colors.green,
      colorText: Colors.white,
      duration: const Duration(seconds: 2),
    );
  }

  Future<void> confirmMatch(String matchId) async {
    try {
      final confirmed = await Get.dialog<bool>(
        AlertDialog(
          title: const Text('Confirm Match'),
          content: const Text('Are you sure you want to confirm this match?'),
          actions: [
            TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Get.back(result: true), child: const Text('Confirm')),
          ],
        ),
      ) ??
          false;

      if (!confirmed) return;

      final conversationId = await matchService.confirmMatchAndOpenConversation(matchId);

      final i = _all.indexWhere((m) => m.id == matchId);
      if (i != -1) {
        final old = _all[i];
        _all[i] = PersonMatch(
          id: old.id,
          missingPersonId: old.missingPersonId,
          foundPersonId: old.foundPersonId,
          confidenceScore: old.confidenceScore,
          matchDate: old.matchDate,
          status: MatchStatus.confirmed,
        );
        _applyFilter();
      }

      if (Get.isRegistered<MessagesController>()) {
        try {
          final sp = Supabase.instance.client;
          await sp
              .from('conversations')
              .select('id, match_id, participant_user_ids, last_message, last_message_time, is_muted, updated_at')
              .eq('id', conversationId)
              .maybeSingle();

          await Get.find<MessagesController>().loadConversations();
        } catch (_) {}
      }

      Get.off(() => ChatView(conversationId: conversationId));

      Get.snackbar(
        'Match Confirmed',
        'Conversation opened.',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to confirm match: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  Future<void> rejectMatch(String matchId) async {
    try {
      final rejected = await Get.dialog<bool>(
        AlertDialog(
          title: const Text('Reject Match'),
          content: const Text('Are you sure this is not a correct match? This action cannot be undone.'),
          actions: [
            TextButton(onPressed: () => Get.back(result: false), child: const Text('Cancel')),
            TextButton(
              onPressed: () => Get.back(result: true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Reject'),
            ),
          ],
        ),
      ) ??
          false;

      if (!rejected) return;

      final sp = Supabase.instance.client;
      await sp.from('matches').update({'status': 'rejected'}).eq('id', matchId);

      final i = _all.indexWhere((m) => m.id == matchId);
      if (i != -1) {
        final old = _all[i];
        _all[i] = PersonMatch(
          id: old.id,
          missingPersonId: old.missingPersonId,
          foundPersonId: old.foundPersonId,
          confidenceScore: old.confidenceScore,
          matchDate: old.matchDate,
          status: MatchStatus.rejected,
        );
        _applyFilter();
      }

      Get.snackbar(
        'Match Rejected',
        'This match has been marked as incorrect',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.orange,
        colorText: Colors.white,
      );
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to reject match: $e',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
  }

  void showFilterDialog() {
    Get.dialog(
      AlertDialog(
        title: const Text('Filter Matches'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: MatchStatus.values.map((status) {
            return RadioListTile<MatchStatus>(
              title: Text(_getStatusText(status)),
              value: status,
              groupValue: selectedFilter.value,
              onChanged: (value) {
                selectedFilter.value = value!;
                Get.back();
                _applyFilter();
              },
            );
          }).toList(),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('Cancel')),
        ],
      ),
    );
  }

  String _getStatusText(MatchStatus status) {
    switch (status) {
      case MatchStatus.pending:
        return 'Pending Review';
      case MatchStatus.confirmed:
        return 'Confirmed';
      case MatchStatus.rejected:
        return 'Rejected';
      case MatchStatus.investigating:
        return 'Under Investigation';
    }
  }

  void _applyFilter() {
    final s = selectedFilter.value;
    matches.value = _all.where((m) => m.status == s).toList();
  }

  PersonMatch _fromRow(Map<String, dynamic> r) {
    return PersonMatch(
      id: (r['id'] ?? '').toString(),
      missingPersonId: (r['missing_id'] ?? '').toString(),
      foundPersonId: (r['found_id'] ?? '').toString(),
      confidenceScore: (r['confidence'] is num) ? (r['confidence'] as num).toDouble() : 0.0,
      matchDate: DateTime.tryParse((r['match_date'] ?? DateTime.now().toIso8601String()).toString()) ?? DateTime.now(),
      status: _statusFromDb(r['status']),
    );
  }

  MatchStatus _statusFromDb(dynamic v) {
    final s = (v ?? '').toString().toLowerCase();
    switch (s) {
      case 'confirmed':
        return MatchStatus.confirmed;
      case 'rejected':
        return MatchStatus.rejected;
      case 'investigating':
        return MatchStatus.investigating;
      case 'pending':
      default:
        return MatchStatus.pending;
    }
  }
}