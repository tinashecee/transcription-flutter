import '../../domain/repositories/status_repository.dart';
import '../api/api_client.dart';

class StatusRepositoryImpl implements StatusRepository {
  StatusRepositoryImpl(this._client);

  final ApiClient _client;

  @override
  Future<Map<String, dynamic>> updateStatus({
    required String recordingId,
    required String status,
  }) async {
    // Normalize status to lowercase (API accepts: pending, inprogress, completed)
    final normalizedStatus = status.toLowerCase().replaceAll('_', '');
    
    print('[StatusRepository] PUT /case_recordings/$recordingId/update_status body={"transcript_status": "$normalizedStatus"}');
    
    final response = await _client.dio.put(
      '/case_recordings/$recordingId/update_status',
      data: {'transcript_status': normalizedStatus},
    );
    
    print('[StatusRepository] Response: ${response.data}');
    
    return response.data as Map<String, dynamic>? ?? {};
  }
}
