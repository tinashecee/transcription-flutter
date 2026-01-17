import '../entities/recording.dart';

class RecordingFilters {
  const RecordingFilters({
    this.court,
    this.courtroom,
    this.query,
    this.fromDate,
    this.toDate,
    this.tab = RecordingTab.all,
  });

  final String? court;
  final String? courtroom;
  final String? query;
  final DateTime? fromDate;
  final DateTime? toDate;
  final RecordingTab tab;
}

enum RecordingTab { all, myList }

abstract class RecordingRepository {
  Future<List<Recording>> fetchRecordings({
    required int page,
    required int pageSize,
    required RecordingFilters filters,
    String? userId,
  });

  Future<Recording> fetchRecording(String id);
}
