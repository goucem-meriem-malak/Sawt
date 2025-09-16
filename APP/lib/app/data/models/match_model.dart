class PersonMatch {
  final String id;
  final String missingPersonId;
  final String foundPersonId;
  final double confidenceScore;
  final DateTime matchDate;
  final MatchStatus status;
  final String? notes;

  PersonMatch({
    required this.id,
    required this.missingPersonId,
    required this.foundPersonId,
    required this.confidenceScore,
    required this.matchDate,
    this.status = MatchStatus.pending,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'missingPersonId': missingPersonId,
    'foundPersonId': foundPersonId,
    'confidenceScore': confidenceScore,
    'matchDate': matchDate.toIso8601String(),
    'status': status.toString().split('.').last,
    'notes': notes,
  };

  factory PersonMatch.fromJson(Map<String, dynamic> json) => PersonMatch(
    id: json['id'],
    missingPersonId: json['missingPersonId'],
    foundPersonId: json['foundPersonId'],
    confidenceScore: json['confidenceScore'],
    matchDate: DateTime.parse(json['matchDate']),
    status: MatchStatus.values.firstWhere(
      (e) => e.toString().split('.').last == json['status'],
      orElse: () => MatchStatus.pending,
    ),
    notes: json['notes'],
  );
}

enum MatchStatus { pending, confirmed, rejected, investigating }
