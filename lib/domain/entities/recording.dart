class Recording {
  const Recording({
    required this.id,
    required this.caseNumber,
    required this.title,
    required this.court,
    required this.courtroom,
    required this.judgeName,
    required this.prosecutionCounsel,
    required this.defenseCounsel,
    required this.date,
    required this.status,
    required this.audioPath,
    required this.durationSeconds,
    required this.annotations,
  });

  final String id;
  final String caseNumber;
  final String title;
  final String court;
  final String courtroom;
  final String judgeName;
  final String prosecutionCounsel;
  final String defenseCounsel;
  final DateTime date;
  final String status;
  final String audioPath;
  final double? durationSeconds;
  final List<Map<String, dynamic>> annotations;

  Recording copyWith({
    String? id,
    String? caseNumber,
    String? title,
    String? court,
    String? courtroom,
    String? judgeName,
    String? prosecutionCounsel,
    String? defenseCounsel,
    DateTime? date,
    String? status,
    String? audioPath,
    double? durationSeconds,
    List<Map<String, dynamic>>? annotations,
  }) {
    return Recording(
      id: id ?? this.id,
      caseNumber: caseNumber ?? this.caseNumber,
      title: title ?? this.title,
      court: court ?? this.court,
      courtroom: courtroom ?? this.courtroom,
      judgeName: judgeName ?? this.judgeName,
      prosecutionCounsel: prosecutionCounsel ?? this.prosecutionCounsel,
      defenseCounsel: defenseCounsel ?? this.defenseCounsel,
      date: date ?? this.date,
      status: status ?? this.status,
      audioPath: audioPath ?? this.audioPath,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      annotations: annotations ?? this.annotations,
    );
  }
}
