import '../../domain/repositories/transcript_repository.dart';
import '../api/api_client.dart';

class TranscriptRepositoryImpl implements TranscriptRepository {
  TranscriptRepositoryImpl(this._client);

  final ApiClient _client;

  @override
  Future<String> fetchTranscript(String recordingId) async {
    final response = await _client.dio.get<Map<String, dynamic>>(
      '/case_recordings/$recordingId/transcript',
    );
    return response.data?['transcript_html'] as String? ?? '';
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
