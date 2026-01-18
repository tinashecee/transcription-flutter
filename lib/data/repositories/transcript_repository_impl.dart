import 'package:dio/dio.dart';

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
  Future<Map<String, dynamic>> saveTranscript({
    required String recordingId,
    required String html,
  }) async {
    print('[TranscriptRepo] PUT /case_recordings/$recordingId/transcript');
    print('[TranscriptRepo] Transcript length: ${html.length} chars');
    
    final response = await _client.dio.put<Map<String, dynamic>>(
      '/case_recordings/$recordingId/transcript',
      data: {'transcript': html},
    );
    
    print('[TranscriptRepo] Save response: ${response.data}');
    return response.data ?? {};
  }

  @override
  Future<Map<String, dynamic>> checkTranscriptionStatus(String recordingId) async {
    final response = await _client.dio.get<Map<String, dynamic>>(
      '/case_recordings/$recordingId/transcription_status',
    );
    return response.data ?? {};
  }

  @override
  Future<Map<String, dynamic>> retranscribe(String recordingId, String userId) async {
    print('[TranscriptRepo] POST /retranscribe with recordingId=$recordingId userId=$userId');
    
    // Manually encode as form data (key=value format)
    final formData = 'id=${Uri.encodeComponent(recordingId)}';
    print('[TranscriptRepo] Form data: $formData');
    
    try {
      final response = await _client.dio.post<Map<String, dynamic>>(
        '/retranscribe?user_id=${Uri.encodeComponent(userId)}',
        data: formData,
        options: Options(
          contentType: 'application/x-www-form-urlencoded',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
          },
        ),
      );
      
      print('[TranscriptRepo] Retranscribe response: ${response.data}');
      return response.data ?? {};
    } catch (error, stack) {
      print('[TranscriptRepo] Retranscribe API error: $error');
      print('[TranscriptRepo] Stack: $stack');
      rethrow;
    }
  }
}
