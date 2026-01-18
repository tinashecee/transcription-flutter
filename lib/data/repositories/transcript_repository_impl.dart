import '../../domain/repositories/transcript_repository.dart';
import '../api/api_client.dart';

class TranscriptRepositoryImpl implements TranscriptRepository {
  TranscriptRepositoryImpl(this._client);

  final ApiClient _client;

  @override
  Future<String> fetchTranscript(String recordingId) async {
    try {
      final response = await _client.dio.get<Map<String, dynamic>>(
        '/recordings/$recordingId',
      );
      final data = response.data ?? const <String, dynamic>{};
      final transcript = _readTranscriptFromMap(data);
      if (transcript != null) return transcript;
    } catch (_) {
      // Fall back to legacy transcript endpoint
    }

    final response = await _client.dio.get<dynamic>(
      '/case_recordings/$recordingId/transcript',
    );
    final data = response.data;
    if (data == null) return '';
    if (data is String) return data;
    if (data is Map<String, dynamic>) {
      final direct = _readTranscriptFromMap(data);
      if (direct != null) return direct;
      final nested = data['data'];
      if (nested is String) return nested;
      if (nested is Map<String, dynamic>) {
        final nestedValue = _readTranscriptFromMap(nested);
        if (nestedValue != null) return nestedValue;
      }
    }
    return '';
  }

  String? _readTranscriptFromMap(Map<String, dynamic> data) {
    const keys = [
      'transcript_html',
      'transcript',
      'html',
      'content',
      'transcript_text',
      'text',
    ];
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.trim().isNotEmpty) {
        return value;
      }
    }
    return null;
  }

  @override
  Future<void> saveTranscript({
    required String recordingId,
    required String html,
  }) async {
    await _client.dio.put(
      '/case_recordings/$recordingId/transcript',
      data: {'transcript_html': html},
    );
  }

  @override
  Future<void> retranscribe(String recordingId) async {
    await _client.dio.post('/case_recordings/$recordingId/retranscribe');
  }
}
