import 'dart:convert';

import '../../domain/entities/recording.dart';

class RecordingModel {
  RecordingModel({
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

  factory RecordingModel.fromJson(Map<String, dynamic> json) {
    final rawDate = json['date'] ?? json['date_stamp'] ?? json['recorded_at'];
    return RecordingModel(
      id: json['id'].toString(),
      caseNumber: json['case_number'] as String? ?? '',
      title: json['title'] as String? ?? '',
      court: json['court'] as String? ?? '',
      courtroom: json['courtroom'] as String? ?? '',
      judgeName: json['judge_name'] as String? ?? '',
      prosecutionCounsel: json['prosecution_counsel'] as String? ?? '',
      defenseCounsel: json['defense_counsel'] as String? ?? '',
      date: _parseDate(rawDate),
      status: _parseStatus(json),
      audioPath: (json['audio_url'] as String?) ??
          (json['file_path'] as String?) ??
          (json['audio_path'] as String?) ??
          '',
      durationSeconds: (json['duration'] as num?)?.toDouble() ??
          (json['duration_seconds'] as num?)?.toDouble(),
      annotations: _parseAnnotations(json['annotations']),
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

  static String _parseStatus(Map<String, dynamic> json) {
    // Prioritize transcript_status as it is specific to the transcript state
    // 'status' might refer to the recording upload status
    var status = json['transcript_status']?.toString();
    
    // Fallback if transcript_status is null
    if (status == null || status.isEmpty) {
      status = json['transcription_status']?.toString() ??
               json['status']?.toString() ??
               'pending';
    }

    // Normalize
    status = status.trim().toLowerCase().replaceAll(' ', '_');
    
    // Fix known backend inconsistencies
    if (status.contains('progress')) return 'in_progress';
    if (status == 'inprogress') return 'in_progress';
    if (status.contains('review')) return 'reviewed';
    if (status.contains('complete')) return 'completed';
    
    // Default valid statuses
    const valid = ['pending', 'in_progress', 'completed', 'reviewed'];
    if (valid.contains(status)) return status;
    
    return 'pending';
  }

  static List<Map<String, dynamic>> _parseAnnotations(dynamic value) {
    if (value == null) return const [];
    if (value is List) {
      return value
          .whereType<Map<String, dynamic>>()
          .toList();
    }
    if (value is String) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is List) {
          return decoded
              .whereType<Map<String, dynamic>>()
              .toList();
        }
      } catch (_) {
        return const [];
      }
    }
    return const [];
  }

  Recording toEntity() => Recording(
        id: id,
        caseNumber: caseNumber,
        title: title,
        court: court,
        courtroom: courtroom,
        judgeName: judgeName,
        prosecutionCounsel: prosecutionCounsel,
        defenseCounsel: defenseCounsel,
        date: date,
        status: status,
        audioPath: audioPath,
        durationSeconds: durationSeconds,
        annotations: annotations,
      );
}
