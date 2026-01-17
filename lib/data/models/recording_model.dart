import '../../domain/entities/recording.dart';

class RecordingModel {
  RecordingModel({
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

  factory RecordingModel.fromJson(Map<String, dynamic> json) {
    final rawDate = json['date'] ?? json['date_stamp'] ?? json['recorded_at'];
    return RecordingModel(
      id: json['id'].toString(),
      caseNumber: json['case_number'] as String? ?? '',
      title: json['title'] as String? ?? '',
      court: json['court'] as String? ?? '',
      courtroom: json['courtroom'] as String? ?? '',
      judgeName: json['judge_name'] as String? ?? '',
      date: _parseDate(rawDate),
      status: json['transcript_status'] as String? ??
          json['status'] as String? ??
          'pending',
      audioPath: json['audio_path'] as String? ?? '',
      durationSeconds: (json['duration'] as num?)?.toDouble() ??
          (json['duration_seconds'] as num?)?.toDouble(),
    );
  }

  static DateTime _parseDate(dynamic value) {
    if (value == null) {
      return DateTime.fromMillisecondsSinceEpoch(0);
    }
    if (value is DateTime) {
      return value;
    }
    if (value is String) {
      if (value.isEmpty) {
        return DateTime.fromMillisecondsSinceEpoch(0);
      }
      return DateTime.tryParse(value) ?? DateTime.fromMillisecondsSinceEpoch(0);
    }
    if (value is int) {
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Recording toEntity() => Recording(
        id: id,
        caseNumber: caseNumber,
        title: title,
        court: court,
        courtroom: courtroom,
        judgeName: judgeName,
        date: date,
        status: status,
        audioPath: audioPath,
        durationSeconds: durationSeconds,
      );
}
