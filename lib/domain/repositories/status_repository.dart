abstract class StatusRepository {
  Future<void> updateStatus({
    required String recordingId,
    required String status,
  });
}
