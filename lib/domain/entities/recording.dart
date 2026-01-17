class Recording {
  const Recording({
    required this.id,
    required this.caseNumber,
    required this.title,
    required this.court,
    required this.courtroom,
    required this.judgeName,
    required this.date,
    required this.status,
    required this.audioPath,
    required this.durationSeconds,
  });

  final String id;
  final String caseNumber;
  final String title;
  final String court;
  final String courtroom;
  final String judgeName;
  final DateTime date;
  final String status;
  final String audioPath;
  final double? durationSeconds;
}
