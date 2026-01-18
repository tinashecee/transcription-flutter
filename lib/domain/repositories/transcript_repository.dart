abstract class TranscriptRepository {
  Future<String> fetchTranscript(String recordingId);
  
  /// Save transcript HTML content
  /// Returns: {message, recording_id, transcript_length}
  Future<Map<String, dynamic>> saveTranscript({
    required String recordingId,
    required String html,
  });
  
  /// Check transcription status for existing jobs
  /// Returns: {active_jobs, status, queue_position}
  Future<Map<String, dynamic>> checkTranscriptionStatus(String recordingId);
  
  /// Queue a retranscription job
  /// Returns: {message, already_exists, job_id, queue_position}
  Future<Map<String, dynamic>> retranscribe(String recordingId, String userId);
}
