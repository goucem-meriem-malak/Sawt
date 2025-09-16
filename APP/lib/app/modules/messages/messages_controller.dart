import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class MessagesController extends GetxController {
  final sp = Supabase.instance.client;
  String get uid => sp.auth.currentUser?.id ?? '';

  final RxList<Map<String, dynamic>> conversations = <Map<String, dynamic>>[].obs;

  final RxBool isSearching = false.obs;
  final RxString searchText = ''.obs;

  void startSearch() => isSearching.value = true;
  void clearSearch() { searchText.value = ''; isSearching.value = false; }
  void updateSearch(String v) => searchText.value = v;

  List<Map<String, dynamic>> get filteredConversations {
    final list = conversations;
    final q = searchText.value.trim().toLowerCase();
    if (q.isEmpty) return list;
    return list.where((c) {
      final name = (c['_peer_name'] ?? '').toString().toLowerCase();
      final last = (c['last_message'] ?? '').toString().toLowerCase();
      return name.contains(q) || last.contains(q);
    }).toList();
  }

  final RxBool isLoading = false.obs;

  @override
  void onInit() {
    super.onInit();
    loadConversations();
  }

  Future<void> loadConversations() async {
    isLoading.value = true;
    try {
      final rows = await sp
          .from('conversations')
          .select('id, participant_user_ids, last_message, last_message_time, updated_at')
          .contains('participant_user_ids', [uid])
          .order('updated_at', ascending: false);

      final List data = (rows as List?) ?? <dynamic>[];

      final Set<String> ids = {};
      for (final r in data) {
        final parts = (r['participant_user_ids'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
        if (parts.length == 2) {
          final other = parts.firstWhere((e) => e != uid, orElse: () => '');
          if (other.isNotEmpty) ids.add(other);
        }
      }

      Map<String, Map<String, dynamic>> profilesMap = {};
      if (ids.isNotEmpty) {
        final profiles = await sp
            .from('profiles')
            .select('id, full_name, avatar_url')
            .inFilter('id', ids.toList());

        if (profiles is List) {
          for (final p in profiles) {
            profilesMap[p['id'].toString()] = Map<String, dynamic>.from(p);
          }
        }
      }

      final convs = <Map<String, dynamic>>[];
      for (final r in data) {
        final map = Map<String, dynamic>.from(r as Map);
        final parts = (map['participant_user_ids'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
        String name = 'User';
        String avatar = '';
        if (parts.length == 2) {
          final other = parts.firstWhere((e) => e != uid, orElse: () => '');
          final prof = profilesMap[other];
          if (prof != null) {
            name = (prof['full_name'] ?? 'User').toString();
            avatar = (prof['avatar_url'] ?? '').toString();
          }
        } else {
          name = 'Group chat';
        }
        map['_peer_name'] = name;
        map['_peer_avatar_url'] = avatar;
        convs.add(map);
      }

      for (final map in convs) {
        try {
          final latest = await sp
              .from('messages')
              .select('sender_id, read_by')
              .eq('conversation_id', map['id'])
              .order('sent_at', ascending: false)
              .limit(1)
              .maybeSingle();

          bool hasUnread = false;
          if (latest != null) {
            final sender = (latest['sender_id'] ?? '').toString();
            final readBy = (latest['read_by'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
            hasUnread = sender != uid && !readBy.contains(uid);
          }
          map['_has_unread'] = hasUnread;
        } catch (_) {
          map['_has_unread'] = false;
        }
      }

      conversations.assignAll(convs);
    } catch (_) {
    } finally {
      isLoading.value = false;
    }
  }
}

class ChatController extends GetxController {
  ChatController(this.conversationId);
  final String conversationId;

  final sp = Supabase.instance.client;
  String get uid => sp.auth.currentUser?.id ?? '';

  final RxString peerName = 'Chat'.obs;
  final RxString peerAvatarUrl = ''.obs;

  final RxList<Map<String, dynamic>> messages = <Map<String, dynamic>>[].obs;

  final ScrollController scrollCtrl = ScrollController();

  StreamSubscription<List<Map<String, dynamic>>>? _sub;

  @override
  void onInit() {
    super.onInit();
    _loadPeerInfo();
    _subscribeMessages();
  }

  @override
  void onClose() {
    _sub?.cancel();
    scrollCtrl.dispose();
    super.onClose();
  }

  bool isMine(Map<String, dynamic> m) => m['sender_id'].toString() == uid;

  Future<void> _loadPeerInfo() async {
    try {
      final conv = await sp
          .from('conversations')
          .select('participant_user_ids')
          .eq('id', conversationId)
          .maybeSingle();

      final parts = (conv?['participant_user_ids'] as List?)?.map((e) => e.toString()).toList() ?? <String>[];
      if (parts.length == 2) {
        final other = parts.firstWhere((e) => e != uid, orElse: () => '');
        if (other.isNotEmpty) {
          final p = await sp
              .from('profiles')
              .select('full_name, avatar_url')
              .eq('id', other)
              .maybeSingle();
          if (p != null) {
            peerName.value = (p['full_name'] ?? 'User').toString();
            peerAvatarUrl.value = (p['avatar_url'] ?? '').toString();
          }
        }
      } else {
        peerName.value = 'Group chat';
      }
    } catch (_) {}
  }

  void _subscribeMessages() {
    _sub = sp
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('conversation_id', conversationId)
        .order('sent_at', ascending: true)
        .listen((rows) {
      messages.assignAll(rows.map((e) => Map<String, dynamic>.from(e)));
      Future.delayed(const Duration(milliseconds: 50), _jumpToEnd);
    });
  }

  void _jumpToEnd() {
    if (!scrollCtrl.hasClients) return;
    scrollCtrl.animateTo(
      scrollCtrl.position.maxScrollExtent + 80,
      duration: const Duration(milliseconds: 200),
      curve: Curves.easeOut,
    );
  }

  Future<void> sendText() async {
    final text = _pendingText.trim();
    if (text.isEmpty) return;
    _pendingText = '';
    try {
      await sp.from('messages').insert({
        'conversation_id': conversationId,
        'sender_id': uid,
        'content': text,
        'message_type': 'text',
      });
    } catch (_) {}
  }

  Future<void> sendImage(File file) async {
    final url = await _uploadToStorage(file);
    if (url.isEmpty) return;
    await sp.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': uid,
      'content': '',
      'message_type': 'image',
      'media_urls': [url],
    });
  }

  Future<void> sendVideo(File file) async {
    final url = await _uploadToStorage(file);
    if (url.isEmpty) return;
    await sp.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': uid,
      'content': '',
      'message_type': 'video',
      'media_urls': [url],
    });
  }

  Future<void> sendFile(File file) async {
    final url = await _uploadToStorage(file);
    if (url.isEmpty) return;
    await sp.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': uid,
      'content': '',
      'message_type': 'file',
      'media_urls': [url],
    });
  }

  Future<void> sendLocation(double lat, double lng) async {
    final url = 'https://www.google.com/maps/search/?api=1&query=$lat,$lng';
    await sp.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': uid,
      'content': url,
      'message_type': 'location',
      'lat': lat,
      'lng': lng,
    });
  }

  Future<void> sendAudio(File file, int durationMs) async {
    final url = await _uploadToStorage(file);
    if (url.isEmpty) return;
    await sp.from('messages').insert({
      'conversation_id': conversationId,
      'sender_id': uid,
      'content': '',
      'message_type': 'audio',
      'media_urls': [url],
      'duration_ms': durationMs,
    });
  }

  Future<String> _uploadToStorage(File file) async {
    try {
      final bucket = 'chat';
      final ext = file.path.split('.').isNotEmpty ? file.path.split('.').last : 'bin';
      final name = '${DateTime.now().millisecondsSinceEpoch}.$ext';
      final path = '$conversationId/$name';
      await sp.storage.from(bucket).upload(path, file);
      final url = sp.storage.from(bucket).getPublicUrl(path);
      return url;
    } catch (_) {
      return '';
    }
  }

  String _pendingText = '';
  set composerText(String v) => _pendingText = v;
}
