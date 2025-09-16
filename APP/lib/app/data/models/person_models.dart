class MissingPerson {
  final String id;
  final String name;
  final int age;
  final String lastSeenLocation;
  final DateTime lastSeenDate;
  final List<String> photoUrls;
  final String description;
  final String reporterName;
  final String reporterPhone;
  final String reporterEmail;
  final DateTime reportDate;
  final PersonStatus status;

  MissingPerson({
    required this.id,
    required this.name,
    required this.age,
    required this.lastSeenLocation,
    required this.lastSeenDate,
    required this.photoUrls,
    required this.description,
    required this.reporterName,
    required this.reporterPhone,
    required this.reporterEmail,
    required this.reportDate,
    this.status = PersonStatus.missing,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'age': age,
    'lastSeenLocation': lastSeenLocation,
    'lastSeenDate': lastSeenDate.toIso8601String(),
    'photoUrls': photoUrls,
    'description': description,
    'reporterName': reporterName,
    'reporterPhone': reporterPhone,
    'reporterEmail': reporterEmail,
    'reportDate': reportDate.toIso8601String(),
    'status': status.toString().split('.').last,
  };

  factory MissingPerson.fromJson(Map<String, dynamic> json) => MissingPerson(
    id: json['id'],
    name: json['name'],
    age: json['age'],
    lastSeenLocation: json['lastSeenLocation'],
    lastSeenDate: DateTime.parse(json['lastSeenDate']),
    photoUrls: List<String>.from(json['photoUrls']),
    description: json['description'],
    reporterName: json['reporterName'],
    reporterPhone: json['reporterPhone'],
    reporterEmail: json['reporterEmail'],
    reportDate: DateTime.parse(json['reportDate']),
    status: PersonStatus.values.firstWhere(
      (e) => e.toString().split('.').last == json['status'],
      orElse: () => PersonStatus.missing,
    ),
  );
}

class FoundPerson {
  final String id;
  final String? name;
  final int? estimatedAge;
  final String location;
  final DateTime foundDate;
  final List<String> photoUrls;
  final PersonCondition condition;
  final String description;
  final String finderName;
  final String finderPhone;
  final String? hospitalInfo;
  final DateTime reportDate;

  FoundPerson({
    required this.id,
    this.name,
    this.estimatedAge,
    required this.location,
    required this.foundDate,
    required this.photoUrls,
    required this.condition,
    required this.description,
    required this.finderName,
    required this.finderPhone,
    this.hospitalInfo,
    required this.reportDate,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'estimatedAge': estimatedAge,
    'location': location,
    'foundDate': foundDate.toIso8601String(),
    'photoUrls': photoUrls,
    'condition': condition.toString().split('.').last,
    'description': description,
    'finderName': finderName,
    'finderPhone': finderPhone,
    'hospitalInfo': hospitalInfo,
    'reportDate': reportDate.toIso8601String(),
  };

  factory FoundPerson.fromJson(Map<String, dynamic> json) => FoundPerson(
    id: json['id'],
    name: json['name'],
    estimatedAge: json['estimatedAge'],
    location: json['location'],
    foundDate: DateTime.parse(json['foundDate']),
    photoUrls: List<String>.from(json['photoUrls']),
    condition: PersonCondition.values.firstWhere(
      (e) => e.toString().split('.').last == json['condition'],
    ),
    description: json['description'],
    finderName: json['finderName'],
    finderPhone: json['finderPhone'],
    hospitalInfo: json['hospitalInfo'],
    reportDate: DateTime.parse(json['reportDate']),
  );
}

enum PersonStatus { missing, found, reunited }

enum PersonCondition { alive, injured, deceased }
