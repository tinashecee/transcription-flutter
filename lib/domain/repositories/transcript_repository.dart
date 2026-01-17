abstract class TranscriptRepository {
  Future<String> fetchTranscript(String recordingId);
  Future<void> saveTranscript({
    required String recordingId,
    required String html,
  });
  Future<void> retranscribe(String recordingId);
}
