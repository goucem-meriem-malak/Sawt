import 'dart:io';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../core/theme/app_theme.dart';
import 'messages_controller.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:record/record.dart';
import 'package:audioplayers/audioplayers.dart';

class MessagesView extends GetView<MessagesController> {
  const MessagesView({super.key});

  @override
  Widget build(BuildContext context) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final args = Get.arguments;
      final cid = (args is Map) ? (args['conversationId'] as String?) : null;
      if (cid != null && cid.isNotEmpty) {
        args.remove('conversationId');
        Get.off(() => ChatView(conversationId: cid));
      }
    });

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppTheme.primaryColor,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        title: Obx(() {
          if (controller.isSearching.value) {
            return TextField(
              autofocus: true,
              onChanged: controller.updateSearch,
              cursorColor: Colors.black,
              style: const TextStyle(color: Colors.black),
              decoration: InputDecoration(
                hintText: 'Search...',
                hintStyle: const TextStyle(color: Colors.black54),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                filled: true,
                fillColor: Colors.white,
                isDense: true,
                contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                prefixIcon: const Icon(Icons.search, color: Colors.black54),
              ),
            );
          }
          return const Text('Messages', style: TextStyle(color: Colors.white));
        }),
        actions: [
          Obx(() {
            return controller.isSearching.value
                ? IconButton(
              icon: const Icon(Icons.close),
              onPressed: controller.clearSearch,
            )
                : IconButton(
              icon: const Icon(Icons.search),
              onPressed: controller.startSearch,
            );
          }),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Obx(() {
              final items = controller.filteredConversations;
              if (controller.isLoading.value && items.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }
              if (items.isEmpty) {
                return controller.isSearching.value
                    ? const _NoResults()
                    : const _EmptyConversations();
              }

              return RefreshIndicator(
                onRefresh: () => controller.loadConversations(),
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(
                      parent: BouncingScrollPhysics()),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: items.length,
                  separatorBuilder: (_, __) =>
                  const Divider(height: 1, thickness: .6),
                  itemBuilder: (_, i) {
                    final c = items[i];
                    return _ConversationTile(
                      convo: c,
                      onTap: () => Get.to(
                              () => ChatView(conversationId: c['id'].toString())),
                    );
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _EmptyConversations extends StatelessWidget {
  const _EmptyConversations();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text('No conversations yet',
          style: TextStyle(color: AppTheme.textSecondary)),
    );
  }
}

class _NoResults extends StatelessWidget {
  const _NoResults();

  @override
  Widget build(BuildContext context) {
    return const Center(child: Text('No results'));
  }
}

List<TextSpan> _highlightParts(
    String source,
    String query,
    TextStyle base,
    TextStyle hi,
    ) {
  if (query.isEmpty) return [TextSpan(text: source, style: base)];
  final s = source;
  final l = s.toLowerCase();
  final q = query.toLowerCase();
  int start = 0;
  final spans = <TextSpan>[];
  while (true) {
    final i = l.indexOf(q, start);
    if (i < 0) {
      spans.add(TextSpan(text: s.substring(start), style: base));
      break;
    }
    if (i > start) spans.add(TextSpan(text: s.substring(start, i), style: base));
    spans.add(TextSpan(text: s.substring(i, i + q.length), style: hi));
    start = i + q.length;
  }
  return spans;
}

class _ConversationTile extends StatelessWidget {
  const _ConversationTile({
    required this.convo,
    required this.onTap,
  });

  final Map<String, dynamic> convo;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final peerName = (convo['_peer_name'] as String?) ?? 'User';
    final peerAvatar = (convo['_peer_avatar_url'] as String?) ?? '';
    final lastMsg = (convo['last_message'] ?? '') as String? ?? '';
    final lastAt =
        (convo['last_message_time'] as String?) ?? (convo['updated_at']?.toString());
    final unread = (convo['_has_unread'] ?? false) == true;

    final q = Get.find<MessagesController>().searchText.value;

    final baseTitle =
    (Theme.of(context).textTheme.titleMedium ?? const TextStyle(fontSize: 16))
        .copyWith(fontWeight: unread ? FontWeight.w700 : FontWeight.w500);

    final baseSub =
    (Theme.of(context).textTheme.bodyMedium ?? const TextStyle(fontSize: 14))
        .copyWith(
      color: unread ? AppTheme.textPrimary : Colors.black54,
      fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
    );

    final hiTitle =
    baseTitle.copyWith(color: AppTheme.primaryColor, fontWeight: FontWeight.w700);
    final hiSub = baseSub.copyWith(color: AppTheme.primaryColor);

    return ListTile(
      dense: true,
      leading: peerAvatar.isNotEmpty
          ? CircleAvatar(backgroundImage: NetworkImage(peerAvatar))
          : const CircleAvatar(child: Icon(Icons.person)),
      title: RichText(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(children: _highlightParts(peerName, q, baseTitle, hiTitle)),
      ),
      subtitle: lastMsg.isEmpty
          ? const Text('No messages yet',
          maxLines: 1, overflow: TextOverflow.ellipsis)
          : RichText(
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        text: TextSpan(children: _highlightParts(lastMsg, q, baseSub, hiSub)),
      ),
      trailing: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (unread)
            Container(
              width: 8,
              height: 8,
              decoration:
              BoxDecoration(color: AppTheme.primaryColor, shape: BoxShape.circle),
            ),
          if (unread) const SizedBox(height: 6),
          Text(
            _formatTime(lastAt),
            style: TextStyle(
              fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
              color: unread ? AppTheme.textPrimary : AppTheme.textSecondary,
            ),
          ),
        ],
      ),
      onTap: onTap,
    );
  }

  String _formatTime(String? iso) {
    if (iso == null || iso.isEmpty) return '';
    try {
      final dt = DateTime.parse(iso).toLocal();
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    } catch (_) {
      return '';
    }
  }
}

class ChatView extends StatelessWidget {
  const ChatView({super.key, required this.conversationId});
  final String conversationId;

  ChatController _ensure() {
    final tag = conversationId;
    if (Get.isRegistered<ChatController>(tag: tag)) {
      return Get.find<ChatController>(tag: tag);
    }
    return Get.put(ChatController(conversationId), tag: tag);
  }

  @override
  Widget build(BuildContext context) {
    final c = _ensure();

    return GetBuilder<ChatController>(
      tag: conversationId,
      init: c,
      global: false,
      builder: (_) {
        return Scaffold(
          appBar: AppBar(
            backgroundColor: AppTheme.primaryColor,
            foregroundColor: Colors.white,
            iconTheme: const IconThemeData(color: Colors.white),
            actionsIconTheme: const IconThemeData(color: Colors.white),
            title: Obx(() {
              final name = c.peerName.value;
              final avatar = c.peerAvatarUrl.value;
              return Row(
                children: [
                  if (avatar.isNotEmpty)
                    CircleAvatar(radius: 14, backgroundImage: NetworkImage(avatar))
                  else
                    const CircleAvatar(
                      radius: 14,
                      backgroundColor: Colors.white24,
                      child: Icon(Icons.person, size: 16),
                    ),
                  const SizedBox(width: 8),
                  const SizedBox(width: 2),
                  Text(name, style: const TextStyle(color: Colors.white)),
                ],
              );
            }),
            actions: const [
              Icon(Icons.call),
              SizedBox(width: 12),
              Icon(Icons.videocam),
              SizedBox(width: 12),
              Icon(Icons.more_vert),
              SizedBox(width: 8),
            ],
          ),
          body: Column(
            children: [
              Expanded(
                child: Obx(() {
                  final list = c.messages;
                  return ListView.builder(
                    controller: c.scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    itemCount: list.length,
                    itemBuilder: (_, i) {
                      final m = list[i];
                      final mine = c.isMine(m);
                      final sentAt =
                      DateTime.parse(m['sent_at'].toString()).toLocal();
                      final time =
                          '${sentAt.hour.toString().padLeft(2, '0')}:${sentAt.minute.toString().padLeft(2, '0')}';
                      final isRead = (m['read_by'] as List?)?.isNotEmpty ?? false;

                      final otherBubble = Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: .9);
                      final otherText = AppTheme.textPrimary;

                      Widget content;
                      final type = (m['message_type'] ?? 'text').toString();
                      final value = (m['content'] ?? '').toString();
                      final media = ((m['media_urls'] as List?) ?? const [])
                          .map((e) => e.toString())
                          .toList();

                      if (type == 'image' && media.isNotEmpty) {
                        content = ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Image.network(media.first,
                              width: 220, fit: BoxFit.cover),
                        );
                      } else if (type == 'video' && media.isNotEmpty) {
                        content = InkWell(
                          onTap: () => launchUrl(Uri.parse(media.first),
                              mode: LaunchMode.externalApplication),
                          child: Row(mainAxisSize: MainAxisSize.min, children: const [
                            Icon(Icons.play_circle_fill, size: 20, color: Colors.white),
                            SizedBox(width: 6),
                            Text('Open video', style: TextStyle(color: Colors.white)),
                          ]),
                        );
                      } else if (type == 'file' && media.isNotEmpty) {
                        final name = media.first.split('/').isNotEmpty
                            ? media.first.split('/').last
                            : 'Open file';
                        content = InkWell(
                          onTap: () => launchUrl(Uri.parse(media.first),
                              mode: LaunchMode.externalApplication),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.insert_drive_file,
                                size: 18, color: Colors.white),
                            const SizedBox(width: 6),
                            Text(name, style: const TextStyle(color: Colors.white)),
                          ]),
                        );
                      } else if (type == 'location') {
                        final lat = (m['lat'] as num?)?.toDouble();
                        final lng = (m['lng'] as num?)?.toDouble();
                        final url = (lat != null && lng != null)
                            ? 'https://www.google.com/maps/search/?api=1&query=$lat,$lng'
                            : value;
                        content = InkWell(
                          onTap: () => launchUrl(Uri.parse(url),
                              mode: LaunchMode.externalApplication),
                          child: Row(mainAxisSize: MainAxisSize.min, children: const [
                            Icon(Icons.place, size: 18, color: Colors.white),
                            SizedBox(width: 6),
                            Text('Open location', style: TextStyle(color: Colors.white)),
                          ]),
                        );
                      } else if (type == 'audio' && media.isNotEmpty) {
                        content = _AudioBubble(url: media.first, mine: mine);
                      } else {
                        content =
                            Text(value, style: TextStyle(color: mine ? Colors.white : otherText));
                      }

                      return Align(
                        alignment:
                        mine ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          padding: const EdgeInsets.symmetric(
                              vertical: 8, horizontal: 12),
                          decoration: BoxDecoration(
                            color: mine ? AppTheme.primaryColor : otherBubble,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment:
                            mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              content,
                              const SizedBox(height: 4),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    time,
                                    style: TextStyle(
                                      color:
                                      mine ? Colors.white70 : AppTheme.textSecondary,
                                      fontSize: 11,
                                    ),
                                  ),
                                  if (mine) ...[
                                    const SizedBox(width: 6),
                                    Icon(isRead ? Icons.done_all : Icons.done,
                                        size: 16, color: Colors.white70),
                                  ],
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                }),
              ),
              _ChatComposer(tag: conversationId),
            ],
          ),
        );
      },
    );
  }
}

class _AudioBubble extends StatefulWidget {
  const _AudioBubble({required this.url, required this.mine});
  final String url;
  final bool mine;

  @override
  State<_AudioBubble> createState() => _AudioBubbleState();
}

class _AudioBubbleState extends State<_AudioBubble> {
  final AudioPlayer _player = AudioPlayer();
  PlayerState _state = PlayerState.stopped;

  @override
  void initState() {
    super.initState();
    _player.onPlayerStateChanged.listen((s) {
      if (mounted) setState(() => _state = s);
    });
  }

  @override
  void dispose() {
    _player.stop();
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    if (_state == PlayerState.playing) {
      await _player.pause();
    } else {
      await _player.play(UrlSource(widget.url));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPlaying = _state == PlayerState.playing;
    return InkWell(
      onTap: _toggle,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill,
              size: 22, color: Colors.white),
          const SizedBox(width: 6),
          const Text('Voice message', style: TextStyle(color: Colors.white)),
        ],
      ),
    );
  }
}

class _ChatComposer extends StatefulWidget {
  const _ChatComposer({required this.tag});
  final String tag;

  @override
  State<_ChatComposer> createState() => _ChatComposerState();
}

class _ChatComposerState extends State<_ChatComposer> {
  final _tec = TextEditingController();
  final AudioRecorder _rec = AudioRecorder();
  bool _isRecording = false;
  DateTime? _recStart;

  @override
  void dispose() {
    _tec.dispose();
    _rec.dispose();
    super.dispose();
  }

  Future<void> _pickImage(ChatController ctrl) async {
    final x =
    await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (x == null) return;
    await ctrl.sendImage(File(x.path));
  }

  Future<void> _pickVideo(ChatController ctrl) async {
    final x = await ImagePicker()
        .pickVideo(source: ImageSource.gallery, maxDuration: const Duration(minutes: 5));
    if (x == null) return;
    await ctrl.sendVideo(File(x.path));
  }

  Future<void> _pickFile(ChatController ctrl) async {
    final res = await FilePicker.platform.pickFiles(allowMultiple: false);
    if (res == null || res.files.single.path == null) return;
    await ctrl.sendFile(File(res.files.single.path!));
  }

  Future<void> _sendLocation(ChatController ctrl) async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      await Geolocator.openLocationSettings();
      return;
    }
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    if (p == LocationPermission.deniedForever || p == LocationPermission.denied) return;
    final pos =
    await Geolocator.getCurrentPosition(desiredAccuracy: LocationAccuracy.high);
    await ctrl.sendLocation(pos.latitude, pos.longitude);
  }

  Future<void> _toggleRecord(ChatController ctrl) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      if (_isRecording) {
        final String? p = await _rec.stop();
        setState(() => _isRecording = false);
        if (p != null && p.isNotEmpty) {
          final ms =
              DateTime.now().difference(_recStart ?? DateTime.now()).inMilliseconds;
          await ctrl.sendAudio(File(p), ms);
        } else {
          messenger.showSnackBar(const SnackBar(content: Text('No audio captured')));
        }
        return;
      }

      final ok = await _rec.hasPermission();
      if (!ok) {
        messenger.showSnackBar(
            const SnackBar(content: Text('Microphone permission is required')));
        return;
      }

      _recStart = DateTime.now();
      final outPath =
          '${Directory.systemTemp.path}/rec_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _rec.start(
        RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: outPath,
      );

      setState(() => _isRecording = true);
    } catch (e) {
      setState(() => _isRecording = false);
      messenger.showSnackBar(
          SnackBar(content: Text('Failed to start recording: $e')));
    }
  }

  void _openAttachSheet(ChatController ctrl) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.image),
              title: const Text('Image'),
              onTap: () async {
                Navigator.pop(context);
                await _pickImage(ctrl);
              },
            ),
            ListTile(
              leading: const Icon(Icons.videocam),
              title: const Text('Video'),
              onTap: () async {
                Navigator.pop(context);
                await _pickVideo(ctrl);
              },
            ),
            ListTile(
              leading: const Icon(Icons.attach_file),
              title: const Text('File'),
              onTap: () async {
                Navigator.pop(context);
                await _pickFile(ctrl);
              },
            ),
            ListTile(
              leading: const Icon(Icons.place),
              title: const Text('Location'),
              onTap: () async {
                Navigator.pop(context);
                await _sendLocation(ctrl);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<ChatController>(tag: widget.tag);
    final inputBg = Theme.of(context).colorScheme.surfaceContainerHighest;
    final inputBorderColor = Theme.of(context).dividerColor;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _tec,
                decoration: InputDecoration(
                  hintText: 'Type a message...',
                  filled: true,
                  fillColor: inputBg,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: inputBorderColor),
                  ),
                  isDense: true,
                  contentPadding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
                  prefixIcon: IconButton(
                    icon: const Icon(Icons.attach_file),
                    color: AppTheme.primaryColor,
                    splashRadius: 20,
                    tooltip: 'Attach',
                    onPressed: () => _openAttachSheet(ctrl),
                  ),
                  prefixIconConstraints:
                  const BoxConstraints(minWidth: 40, minHeight: 40),
                  suffixIcon: IconButton(
                    icon: Icon(_isRecording ? Icons.stop_circle : Icons.mic),
                    color: _isRecording ? Colors.red : AppTheme.primaryColor,
                    splashRadius: 20,
                    tooltip: _isRecording ? 'Stop' : 'Voice',
                    onPressed: () => _toggleRecord(ctrl),
                  ),
                  suffixIconConstraints:
                  const BoxConstraints(minWidth: 40, minHeight: 40),
                ),
                onChanged: (v) => ctrl.composerText = v,
                onSubmitted: (_) async {
                  await ctrl.sendText();
                  _tec.clear();
                },
              ),
            ),
            const SizedBox(width: 6),
            CircleAvatar(
              backgroundColor: AppTheme.primaryColor,
              child: IconButton(
                icon: const Icon(Icons.send, color: Colors.white),
                onPressed: () async {
                  await ctrl.sendText();
                  _tec.clear();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
