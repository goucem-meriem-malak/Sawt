import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';


Color get _primary       => AppTheme.primaryColor;
Color get _secondary     => AppTheme.secondaryColor;
Color get _warn          => AppTheme.warningColor;
Color get _danger        => AppTheme.dangerColor;
Color get _textSecondary => AppTheme.textSecondary;

AppBar _brandBar(String title) {
  const white = Colors.white;
  const titleStyle = TextStyle(
    color: white,
    fontSize: 20,
    fontWeight: FontWeight.w700,
  );
  return AppBar(
    backgroundColor: _primary,
    systemOverlayStyle: SystemUiOverlayStyle.light,
    iconTheme: const IconThemeData(color: white),
    actionsIconTheme: const IconThemeData(color: white),
    titleTextStyle: titleStyle,
    toolbarTextStyle: const TextStyle(color: white),
    title: Text(title, style: titleStyle),
  );
}

class MissingReportsPage extends StatefulWidget {
  const MissingReportsPage({super.key});
  @override
  State<MissingReportsPage> createState() => _MissingReportsPageState();
}

class _MissingReportsPageState extends State<MissingReportsPage> {
  final _sp = Supabase.instance.client;
  Future<List<Map<String, dynamic>>>? _task;

  @override
  void initState() {
    super.initState();
    _task = _fetch();
  }

  Future<List<Map<String, dynamic>>> _fetch() async {
    final uid = _sp.auth.currentUser?.id;
    if (uid == null) return [];

    final rows = await _sp
        .from('missing_persons')
        .select(
      'id,name,age,last_seen_location,last_seen_date,photo_urls,'
          'description,reporter_name,reporter_phone,reporter_email,report_date,status',
    )
        .eq('user_id', uid)
        .order('report_date', ascending: false) as List;

    final futures = rows.map((r) async {
      final ms = await _latestMatchStatus(missingId: r['id'].toString());
      return <String, dynamic>{...r as Map, 'match_status': ms};
    }).toList();

    return Future.wait(futures);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _brandBar('My Missing Reports'),
      body: RefreshIndicator(
        onRefresh: () async => setState(() => _task = _fetch()),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _task,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snap.data ?? [];
            if (data.isEmpty) {
              return _emptyState(
                icon: Icons.person_search,
                text: 'No missing reports yet',
                hint: 'Create a missing report from Home.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: data.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) => _ReportCard(
                row: data[i],
                isMissing: true,
                matchStatus: (data[i]['match_status'] ?? '').toString(),
              ),
            );
          },
        ),
      ),
    );
  }
}

class FoundReportsPage extends StatefulWidget {
  const FoundReportsPage({super.key});
  @override
  State<FoundReportsPage> createState() => _FoundReportsPageState();
}

class _FoundReportsPageState extends State<FoundReportsPage> {
  final _sp = Supabase.instance.client;
  Future<List<Map<String, dynamic>>>? _task;

  @override
  void initState() {
    super.initState();
    _task = _fetch();
  }

  Future<List<Map<String, dynamic>>> _fetch() async {
    final uid = _sp.auth.currentUser?.id;
    if (uid == null) return [];

    final rows = await _sp
        .from('found_persons')
        .select(
      'id,name,estimated_age,location,found_date,photo_urls,'
          'condition,description,finder_name,finder_phone,hospital_info,report_date,status',
    )
        .eq('user_id', uid)
        .order('report_date', ascending: false) as List;

    final futures = rows.map((r) async {
      final ms = await _latestMatchStatus(foundId: r['id'].toString());
      return <String, dynamic>{...r as Map, 'match_status': ms};
    }).toList();

    return Future.wait(futures);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _brandBar('My Found Reports'),
      body: RefreshIndicator(
        onRefresh: () async => setState(() => _task = _fetch()),
        child: FutureBuilder<List<Map<String, dynamic>>>(
          future: _task,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snap.data ?? [];
            if (data.isEmpty) {
              return _emptyState(
                icon: Icons.person_pin_circle,
                text: 'No found reports yet',
                hint: 'Create a found report from Home.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: data.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) => _ReportCard(
                row: data[i],
                isMissing: false,
                matchStatus: (data[i]['match_status'] ?? '').toString(),
              ),
            );
          },
        ),
      ),
    );
  }
}

class ReportHistoryPage extends StatefulWidget {
  const ReportHistoryPage({super.key});
  @override
  State<ReportHistoryPage> createState() => _ReportHistoryPageState();
}

class _ReportHistoryPageState extends State<ReportHistoryPage> {
  final _sp = Supabase.instance.client;
  Future<List<_HistoryItem>>? _task;

  @override
  void initState() {
    super.initState();
    _task = _fetch();
  }

  Future<List<_HistoryItem>> _fetch() async {
    final uid = _sp.auth.currentUser?.id;
    if (uid == null) return [];

    final missing = await _sp
        .from('missing_persons')
        .select(
      'id,name,age,last_seen_location,last_seen_date,photo_urls,'
          'description,report_date,status',
    )
        .eq('user_id', uid) as List;

    final found = await _sp
        .from('found_persons')
        .select(
      'id,name,estimated_age,location,found_date,photo_urls,'
          'condition,description,hospital_info,report_date,status',
    )
        .eq('user_id', uid) as List;

    final missFutures = missing.map((r) async {
      final ms = await _latestMatchStatus(missingId: r['id'].toString());
      final row = {...r as Map<String, dynamic>, 'match_status': ms};
      return _HistoryItem(
        kind: _ReportKind.missing,
        id: r['id'].toString(),
        date: _toDate(r['report_date']),
        row: row,
      );
    });

    final foundFutures = found.map((r) async {
      final ms = await _latestMatchStatus(foundId: r['id'].toString());
      final row = {...r as Map<String, dynamic>, 'match_status': ms};
      return _HistoryItem(
        kind: _ReportKind.found,
        id: r['id'].toString(),
        date: _toDate(r['report_date']),
        row: row,
      );
    });

    final all = await Future.wait([...missFutures, ...foundFutures]);
    all.sort((a, b) => b.date.compareTo(a.date));
    return all;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: _brandBar('My History Reports'),
      body: RefreshIndicator(
        onRefresh: () async => setState(() => _task = _fetch()),
        child: FutureBuilder<List<_HistoryItem>>(
          future: _task,
          builder: (context, snap) {
            if (snap.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            final data = snap.data ?? [];
            if (data.isEmpty) {
              return _emptyState(
                icon: Icons.history,
                text: 'No reports yet',
                hint: 'Your missing & found reports will appear here.',
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: data.length,
              separatorBuilder: (_, __) => const SizedBox(height: 12),
              itemBuilder: (ctx, i) {
                final item = data[i];
                return _ReportCard(
                  row: item.row,
                  isMissing: item.kind == _ReportKind.missing,
                  matchStatus: (item.row['match_status'] ?? '').toString(),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

Widget _emptyState({
  required IconData icon,
  required String text,
  String? hint,
}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 64, color: _textSecondary),
          const SizedBox(height: 12),
          Text(
            text,
            style: TextStyle(
              color: _textSecondary,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (hint != null) ...[
            const SizedBox(height: 6),
            Text(hint, textAlign: TextAlign.center, style: TextStyle(color: _textSecondary)),
          ],
        ],
      ),
    ),
  );
}

class _ReportCard extends StatelessWidget {
  final Map<String, dynamic> row;
  final bool isMissing;
  final String? matchStatus;

  const _ReportCard({
    super.key,
    required this.row,
    required this.isMissing,
    this.matchStatus,
  });

  @override
  Widget build(BuildContext context) {
    final photo      = _firstPhoto(row['photo_urls']);
    final title      = (row['name'] ?? 'Unknown').toString();
    final reportDate = _toDate(row['report_date']);
    final when       = _fmt(reportDate);

    final lines = <_InfoLine>[];
    if (isMissing) {
      lines.addAll([
        _InfoLine('Age', (row['age'] ?? '').toString()),
        _InfoLine('Last seen location', (row['last_seen_location'] ?? '').toString()),
        _InfoLine('Last seen date', _fmt(_toDate(row['last_seen_date']))),
        _InfoLine('Description', (row['description'] ?? '').toString(), big: true),
        _InfoLine('Reporter name', (row['reporter_name'] ?? '').toString()),
        _InfoLine('Reporter phone', (row['reporter_phone'] ?? '').toString()),
        _InfoLine('Reporter email', (row['reporter_email'] ?? '').toString()),
      ]);
    } else {
      lines.addAll([
        _InfoLine('Estimated age', (row['estimated_age'] ?? '').toString()),
        _InfoLine('Location', (row['location'] ?? '').toString()),
        _InfoLine('Found date', _fmt(_toDate(row['found_date']))),
        _InfoLine('Condition', (row['condition'] ?? '').toString()),
        _InfoLine('Hospital info', (row['hospital_info'] ?? '').toString()),
        _InfoLine('Description', (row['description'] ?? '').toString(), big: true),
        _InfoLine('Finder name', (row['finder_name'] ?? '').toString()),
        _InfoLine('Finder phone', (row['finder_phone'] ?? '').toString()),
      ]);
    }

    final raw = (matchStatus ?? '').trim().toLowerCase();
    String statusText  = 'No match yet';
    Color  statusColor = Colors.grey;
    switch (raw) {
      case 'confirmed':
        statusText = 'Confirmed';
        statusColor = _secondary;
        break;
      case 'pending':
        statusText = 'Pending';
        statusColor = _warn;
        break;
      case 'rejected':
        statusText = 'Rejected';
        statusColor = _danger;
        break;
      case 'investigating':
        statusText = 'Investigating';
        statusColor = _primary;
        break;
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _PhotoBox(url: photo),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          _Chip(
                            text: isMissing ? 'Missing' : 'Found',
                            color: isMissing ? _warn : _secondary,
                          ),
                          const SizedBox(width: 8),
                          _Chip(text: statusText, color: statusColor),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          const Icon(Icons.schedule, size: 14, color: Colors.black54),
                          const SizedBox(width: 4),
                          Text(when, style: const TextStyle(fontSize: 12, color: Colors.black54)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),
            const SizedBox(height: 8),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [for (final l in lines) _InfoRow(line: l)],
            ),
          ],
        ),
      ),
    );
  }
}

class _PhotoBox extends StatelessWidget {
  final String? url;
  const _PhotoBox({this.url});
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        width: 84,
        height: 84,
        color: Colors.grey.shade200,
        child: url == null
            ? Icon(Icons.image_not_supported, color: Colors.grey.shade500)
            : Image.network(
          url!,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => Icon(Icons.broken_image, color: Colors.grey.shade500),
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  final Color color;
  const _Chip({required this.text, required this.color});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(.12),
        border: Border.all(color: color.withOpacity(.3)),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _InfoLine {
  final String label;
  final String value;
  final bool big;
  _InfoLine(this.label, this.value, {this.big = false});
}

class _InfoRow extends StatelessWidget {
  final _InfoLine line;
  const _InfoRow({required this.line});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: line.big ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              line.label,
              style: const TextStyle(color: Colors.black54, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              line.value.isEmpty ? '—' : line.value,
              style: TextStyle(color: Colors.grey.shade800),
            ),
          ),
        ],
      ),
    );
  }
}

DateTime _toDate(dynamic v) {
  if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
  try {
    return DateTime.parse(v.toString()).toLocal();
  } catch (_) {
    return DateTime.fromMillisecondsSinceEpoch(0);
  }
}

String _fmt(DateTime d) {
  if (d.millisecondsSinceEpoch == 0) return '—';
  final now = DateTime.now();
  final diff = now.difference(d);
  if (diff.inDays == 0) {
    final hh = d.hour.toString().padLeft(2, '0');
    final mm = d.minute.toString().padLeft(2, '0');
    return 'today $hh:$mm';
  }
  if (diff.inDays == 1) return 'yesterday';
  if (diff.inDays < 7) return '${diff.inDays} days ago';
  return '${d.day}/${d.month}/${d.year}';
}

String? _firstPhoto(dynamic v) {
  try {
    if (v is List && v.isNotEmpty) {
      final s = v.first?.toString();
      return (s == null || s.isEmpty) ? null : s;
    }
  } catch (_) {}
  return null;
}

enum _ReportKind { missing, found }

class _HistoryItem {
  final _ReportKind kind;
  final String id;
  final DateTime date;
  final Map<String, dynamic> row;
  _HistoryItem({
    required this.kind,
    required this.id,
    required this.date,
    required this.row,
  });
}

Future<String?> _latestMatchStatus({
  String? missingId,
  String? foundId,
}) async {
  final sp = Supabase.instance.client;

  var q = sp.from('matches').select('status, created_at');
  if (missingId != null) q = q.eq('missing_id', missingId);
  if (foundId != null) q = q.eq('found_id', foundId);

  final row = await q.order('created_at', ascending: false).limit(1).maybeSingle();
  if (row == null) return null;
  final s = (row['status'] ?? '').toString().trim().toLowerCase();
  return s.isEmpty ? null : s;
}
