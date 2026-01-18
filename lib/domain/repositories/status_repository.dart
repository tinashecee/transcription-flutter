abstract class StatusRepository {
  /// Update the transcript status of a recording
  /// Returns the response from the API: {message, recording_id, transcript_status}
  Future<Map<String, dynamic>> updateStatus({
    required String recordingId,
    required String status,
  });
}
