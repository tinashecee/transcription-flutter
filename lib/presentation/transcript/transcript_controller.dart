import 'dart:async';

import 'package:dart_quill_delta/dart_quill_delta.dart' as dq;
import 'package:fleather/fleather.dart' as fleather;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quill_html_converter/quill_html_converter.dart';

import '../../data/providers.dart';

class TranscriptState {
  TranscriptState({
    required this.controller,
    required this.isSaving,
    this.errorMessage,
  });

  final fleather.FleatherController controller;
  final bool isSaving;
  final String? errorMessage;

  TranscriptState copyWith({
    fleather.FleatherController? controller,
    bool? isSaving,
    String? errorMessage,
  }) {
    return TranscriptState(
      controller: controller ?? this.controller,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage,
    );
  }
}

class TranscriptController extends StateNotifier<TranscriptState> {
  TranscriptController(this._ref)
      : super(
          TranscriptState(
            controller: fleather.FleatherController(
              document: fleather.ParchmentDocument(),
            ),
            isSaving: false,
          ),
        );

  final Ref _ref;
  Timer? _autoSaveTimer;
  String? _recordingId;

  Future<void> load(String recordingId) async {
    _recordingId = recordingId;
    final repo = _ref.read(transcriptRepositoryProvider);
    final html = await repo.fetchTranscript(recordingId);
    final text = _stripHtml(html);
    final delta = dq.Delta()..insert(text.isEmpty ? '\n' : '$text\n');
    final document = fleather.ParchmentDocument.fromJson(delta.toJson());
    state = state.copyWith(
      controller: fleather.FleatherController(document: document),
    );
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => save(),
    );
  }

  Future<void> save() async {
    final recordingId = _recordingId;
    if (recordingId == null) return;
    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      final repo = _ref.read(transcriptRepositoryProvider);
      final parchmentDelta = state.controller.document.toDelta();
      final html = dq.Delta.fromJson(parchmentDelta.toJson()).toHtml();
      await repo.saveTranscript(recordingId: recordingId, html: html);
      state = state.copyWith(isSaving: false);
    } catch (error) {
      state = state.copyWith(
        isSaving: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<void> retranscribe() async {
    final recordingId = _recordingId;
    if (recordingId == null) return;
    final repo = _ref.read(transcriptRepositoryProvider);
    await repo.retranscribe(recordingId);
    await load(recordingId);
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    super.dispose();
  }

  String _stripHtml(String html) {
    return html
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .trim();
  }
}

final transcriptControllerProvider =
    StateNotifierProvider<TranscriptController, TranscriptState>((ref) {
  return TranscriptController(ref);
});
