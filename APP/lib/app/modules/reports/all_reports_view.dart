import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'all_reports_controller.dart';

class AllReportsView extends GetView<AllReportsController> {
  const AllReportsView({super.key});

  String _prettyLabel(String key) {
    final k = key.replaceAll('_', ' ').trim();
    if (k.isEmpty) return key;
    return k.split(' ').map((w) {
      if (w.isEmpty) return w;
      return w[0].toUpperCase() + w.substring(1);
    }).join(' ');
  }

  String _formatValue(dynamic v) {
    if (v == null) return '—';
    if (v is List) return v.map((e) => e?.toString() ?? '').join(', ');
    if (v is Map) return v.entries.map((e) => '${e.key}: ${e.value}').join(' • ');
    return v.toString();
  }

  String _dateDMY(DateTime dt) {
    final d = dt.toLocal();
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm/${d.year}';
  }

  String _timeHM(DateTime dt) {
    final d = dt.toLocal();
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  TextSpan _highlightAll(String text, String query) {
    if (query.trim().isEmpty) return TextSpan(text: text);
    final t = text.toLowerCase();
    final q = query.toLowerCase();
    final spans = <TextSpan>[];
    int start = 0;

    while (true) {
      final i = t.indexOf(q, start);
      if (i < 0) {
        spans.add(TextSpan(text: text.substring(start)));
        break;
      }
      if (i > start) spans.add(TextSpan(text: text.substring(start, i)));
      spans.add(TextSpan(
        text: text.substring(i, i + q.length),
        style: const TextStyle(fontWeight: FontWeight.w700, color: Colors.orange),
      ));
      start = i + q.length;
    }
    return TextSpan(children: spans);
  }

  Widget _kv(BuildContext context, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 150,
          child: Text(
            _prettyLabel(label),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: Colors.grey.shade700,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            value.isEmpty ? '—' : value,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }

  static const _hiddenKeys = {
    'id',
    'user_id',
    'owner_id',
    'created_at',
    'updated_at',
    'embedding',
    'embedding_vector',
    'participant_user_ids',
    'primary_photo_url',
    'photo_urls',
    'report_date',
    'status',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: [
          Obx(
                () => PopupMenuButton<String>(
              onSelected: controller.setFilterType,
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'all', child: Text('All')),
                PopupMenuItem(value: 'missing', child: Text('Missing')),
                PopupMenuItem(value: 'found', child: Text('Found')),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Row(
                  children: [
                    const Icon(Icons.filter_list),
                    const SizedBox(width: 6),
                    Text(controller.filterType.value.toUpperCase()),
                  ],
                ),
              ),
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Obx(() {
              final hasText = controller.searchTerm.value.trim().isNotEmpty;
              return TextField(
                onChanged: controller.setSearch,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  hintText: 'Search by name…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: hasText
                      ? IconButton(
                    icon: const Icon(Icons.clear),
                    onPressed: () {
                      controller.setSearch('');
                      controller.fetchReports();
                    },
                  )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  isDense: true,
                  filled: true,
                ),
              );
            }),
          ),
        ),
      ),
      body: Obx(() {
        if (controller.loading.value) {
          return const Center(child: CircularProgressIndicator());
        }
        if (controller.reports.isEmpty) {
          return const Center(child: Text('No reports found'));
        }

        return RefreshIndicator(
          onRefresh: controller.fetchReports,
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: controller.reports.length,
            itemBuilder: (_, i) {
              final r = controller.reports[i];

              final MaterialColor stateColor =
              r.type == 'missing' ? Colors.red : Colors.green;
              final String stateLabel = r.type == 'missing' ? 'Missing' : 'Found';
              final String topDate = _dateDMY(r.createdAt);

              final entries = <MapEntry<String, dynamic>>[];
              r.raw.forEach((k, v) {
                final kk = k.toString().toLowerCase();
                if (_hiddenKeys.contains(kk)) return;
                if (kk.contains('embedding') || kk.contains('vector')) return;
                entries.add(MapEntry(k, v));
              });
              entries.sort((a, b) {
                if (a.key == 'name') return -1;
                if (b.key == 'name') return 1;
                return a.key.compareTo(b.key);
              });

              return Card(
                elevation: 2,
                margin: const EdgeInsets.only(bottom: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              width: 80,
                              height: 80,
                              color: Colors.black12,
                              child: (r.photoUrl != null && r.photoUrl!.isNotEmpty)
                                  ? Image.network(r.photoUrl!, fit: BoxFit.cover)
                                  : const Icon(Icons.person, size: 40),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Obx(() => Text.rich(
                                  _highlightAll(
                                    (r.name?.isNotEmpty == true)
                                        ? r.name!
                                        : 'Unknown',
                                    controller.searchTerm.value,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                )),
                                const SizedBox(height: 6),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Chip(
                                      label: Text(stateLabel),
                                      backgroundColor:
                                      stateColor.withOpacity(0.15),
                                      labelStyle: TextStyle(
                                        color: stateColor.shade700,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 0),
                                      materialTapTargetSize:
                                      MaterialTapTargetSize.shrinkWrap,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    const SizedBox(height: 4),
                                    Text(topDate,
                                        style: const TextStyle(fontSize: 13)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: ElevatedButton.icon(
                              onPressed: () => controller.openChatWithOwner(r),
                              icon: const Icon(Icons.chat_bubble_outline, size: 18),
                              label: const Text('Chat'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: stateColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                shape: const StadiumBorder(),
                                elevation: 2,
                              ),
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: entries.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 14, color: Colors.grey.shade300),
                        itemBuilder: (_, idx) {
                          final e = entries[idx];
                          final kLower = e.key.toLowerCase();

                          if (e.value is String &&
                              (kLower.contains('found_date') ||
                                  kLower.contains('last_seen_date'))) {
                            final dt = DateTime.tryParse((e.value as String).trim());
                            if (dt != null) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _kv(context, e.key, ''),
                                  Padding(
                                    padding: const EdgeInsetsDirectional.only(
                                        start: 160),
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(_dateDMY(dt),
                                            style: Theme.of(context)
                                                .textTheme
                                                .bodyMedium),
                                        const SizedBox(height: 2),
                                        Text(
                                          _timeHM(dt),
                                          style: Theme.of(context)
                                              .textTheme
                                              .bodySmall
                                              ?.copyWith(color: Colors.grey[700]),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              );
                            }
                          }
                          return _kv(context, e.key, _formatValue(e.value));
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      }),
    );
  }
}
