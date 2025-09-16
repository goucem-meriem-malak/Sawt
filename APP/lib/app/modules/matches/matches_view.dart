import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/match_model.dart';
import 'matches_controller.dart';

class MatchesView extends GetView<MatchesController> {
  static final Map<String, _PersonBrief> _missingCache = {};
  static final Map<String, _PersonBrief> _foundCache = {};

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Text(
                  'Potential Matches',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.filter_list),
                  onPressed: controller.showFilterDialog,
                ),
              ],
            ),
          ),
          Expanded(
            child: Obx(() {
              if (controller.isLoading.value) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 16),
                      Text(
                        'Analyzing faces and finding matches...',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ],
                  ),
                );
              }

              if (controller.matches.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off, size: 64, color: AppTheme.textSecondary),
                      const SizedBox(height: 16),
                      Text(
                        'No matches found yet',
                        style: Theme.of(context)
                            .textTheme
                            .headlineMedium
                            ?.copyWith(color: AppTheme.textSecondary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'We\'ll notify you when potential matches are detected',
                        style: Theme.of(context)
                            .textTheme
                            .bodyLarge
                            ?.copyWith(color: AppTheme.textSecondary),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: controller.refreshMatches,
                        child: const Text('Refresh'),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: controller.refreshMatches,
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: controller.matches.length,
                  itemBuilder: (_, i) {
                    final match = controller.matches[i];
                    return _buildMatchCard(context, match);
                  },
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildMatchCard(BuildContext context, PersonMatch match) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(
            children: [
              _buildConfidenceIndicator(match.confidenceScore),
              const SizedBox(width: 12),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Potential Match',
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold)),
                  Text(
                    '${(match.confidenceScore * 100).toInt()}% confidence',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: _getConfidenceColor(match.confidenceScore),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ]),
              ),
              _buildStatusChip(match.status),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: FutureBuilder<_PersonBrief>(
                  future: _loadMissingBrief(match.missingPersonId),
                  builder: (_, snap) {
                    final p = snap.data ?? _PersonBrief.placeholderMissing();
                    return _buildPersonPreview(
                      context,
                      title: 'Missing Person',
                      name: p.name ?? 'Unknown',
                      age: p.age,
                      lastSeen: p.location ?? '—',
                      imageUrl: p.imageUrl,
                    );
                  },
                ),
              ),
              const SizedBox(width: 16),
              Icon(Icons.compare_arrows, color: AppTheme.primaryColor, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: FutureBuilder<_PersonBrief>(
                  future: _loadFoundBrief(match.foundPersonId),
                  builder: (_, snap) {
                    final p = snap.data ?? _PersonBrief.placeholderFound();
                    return _buildPersonPreview(
                      context,
                      title: 'Found Person',
                      name: p.name ?? 'Unknown',
                      age: p.age,
                      lastSeen: p.location ?? '—',
                      imageUrl: p.imageUrl,
                    );
                  },
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Icon(Icons.schedule, size: 16, color: AppTheme.textSecondary),
              const SizedBox(width: 4),
              Text(
                'Matched ${_formatDate(match.matchDate)}',
                style:
                Theme.of(context).textTheme.bodySmall?.copyWith(color: AppTheme.textSecondary),
              ),
            ],
          ),

          const SizedBox(height: 16),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => controller.rejectMatch(match.id),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.dangerColor,
                    side: BorderSide(color: AppTheme.dangerColor),
                  ),
                  child: const Text('Not a Match'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => controller.confirmMatch(match.id),
                  child: const Text('Confirm Match'),
                ),
              ),
            ],
          ),
        ]),
      ),
    );
  }

  Widget _buildConfidenceIndicator(double c) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: _getConfidenceColor(c).withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        c >= 0.8
            ? Icons.verified
            : c >= 0.6
            ? Icons.help_outline
            : Icons.warning_outlined,
        color: _getConfidenceColor(c),
        size: 24,
      ),
    );
  }

  Color _getConfidenceColor(double c) {
    if (c >= 0.8) return AppTheme.secondaryColor;
    if (c >= 0.6) return AppTheme.warningColor;
    return AppTheme.dangerColor;
  }

  Widget _buildStatusChip(MatchStatus status) {
    late Color color;
    late String text;
    switch (status) {
      case MatchStatus.pending:
        color = AppTheme.warningColor;
        text = 'Pending';
        break;
      case MatchStatus.confirmed:
        color = AppTheme.secondaryColor;
        text = 'Confirmed';
        break;
      case MatchStatus.rejected:
        color = AppTheme.dangerColor;
        text = 'Rejected';
        break;
      case MatchStatus.investigating:
        color = AppTheme.primaryColor;
        text = 'Investigating';
        break;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(text,
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  Widget _buildPersonPreview(
      BuildContext context, {
        required String title,
        required String name,
        required int? age,
        required String lastSeen,
        required String? imageUrl,
      }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w600, color: AppTheme.textSecondary)),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: 120,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            color: Colors.grey.shade200,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: imageUrl == null || imageUrl.isEmpty
                ? Container(
              color: Colors.grey.shade300,
              child: Icon(Icons.person, size: 40, color: Colors.grey.shade500),
            )
                : Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: Colors.grey.shade300,
                child: Icon(Icons.person, size: 40, color: Colors.grey.shade500),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
        Text('Age: ${age ?? '--'}',
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppTheme.textSecondary)),
        Text(lastSeen,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppTheme.textSecondary)),
      ],
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final d = now.difference(date);
    if (d.inDays == 0) return 'today';
    if (d.inDays == 1) return 'yesterday';
    if (d.inDays < 7) return '${d.inDays} days ago';
    return '${date.day}/${date.month}/${date.year}';
  }

  Future<_PersonBrief> _loadMissingBrief(String id) async {
    if (id.isEmpty) return _PersonBrief.placeholderMissing();
    if (_missingCache.containsKey(id)) return _missingCache[id]!;

    final sp = Supabase.instance.client;
    try {
      final res = await sp
          .from('missing_persons')
          .select('name, age, last_seen_location, photo_urls')
          .eq('id', id)
          .limit(1);
      if (res is List && res.isNotEmpty) {
        final r = res.first as Map<String, dynamic>;
        final photos = (r['photo_urls'] is List)
            ? List<String>.from(r['photo_urls'] as List)
            : const <String>[];
        final brief = _PersonBrief(
          name: (r['name'] as String?)?.trim(),
          age: (r['age'] as num?)?.toInt(),
          location: (r['last_seen_location'] as String?)?.trim(),
          imageUrl: photos.isNotEmpty ? photos.first : null,
        );
        _missingCache[id] = brief;
        return brief;
      }
    } catch (_) {}
    return _PersonBrief.placeholderMissing();
  }

  Future<_PersonBrief> _loadFoundBrief(String id) async {
    if (id.isEmpty) return _PersonBrief.placeholderFound();
    if (_foundCache.containsKey(id)) return _foundCache[id]!;

    final sp = Supabase.instance.client;
    try {
      final res = await sp
          .from('found_persons')
          .select('name, estimated_age, location, photo_urls')
          .eq('id', id)
          .limit(1);
      if (res is List && res.isNotEmpty) {
        final r = res.first as Map<String, dynamic>;
        final photos = (r['photo_urls'] is List)
            ? List<String>.from(r['photo_urls'] as List)
            : const <String>[];
        final brief = _PersonBrief(
          name: (r['name'] as String?)?.trim(),
          age: (r['estimated_age'] as num?)?.toInt(),
          location: (r['location'] as String?)?.trim(),
          imageUrl: photos.isNotEmpty ? photos.first : null,
        );
        _foundCache[id] = brief;
        return brief;
      }
    } catch (_) {}
    return _PersonBrief.placeholderFound();
  }
}

class _PersonBrief {
  final String? name;
  final int? age;
  final String? location;
  final String? imageUrl;

  _PersonBrief({this.name, this.age, this.location, this.imageUrl});

  factory _PersonBrief.placeholderMissing() =>
      _PersonBrief(name: 'Unknown', age: null, location: '—', imageUrl: null);

  factory _PersonBrief.placeholderFound() =>
      _PersonBrief(name: 'Unknown', age: null, location: '—', imageUrl: null);
}
