import '../../domain/repositories/status_repository.dart';
import '../api/api_client.dart';

class StatusRepositoryImpl implements StatusRepository {
  StatusRepositoryImpl(this._client);

  final ApiClient _client;

  @override
  Future<void> updateStatus({
    required String recordingId,
    required String status,
  }) async {
    await _client.dio.post(
      '/api/status/$recordingId',
      data: {'status': status},
    );
  }
}
