import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:dart_quill_delta/dart_quill_delta.dart';
import 'package:flutter_quill_delta_from_html/flutter_quill_delta_from_html.dart';
import 'package:logging/logging.dart';
import 'package:vsc_quill_delta_to_html/vsc_quill_delta_to_html.dart';

import '../../app/providers.dart';
import '../../data/providers.dart';

class TranscriptState {
  TranscriptState({
    required this.controller,
    required this.isSaving,
    this.errorMessage,
    this.hasStartedEditing = false,
  });

  final QuillController controller;
  final bool isSaving;
  final String? errorMessage;
  final bool hasStartedEditing;

  TranscriptState copyWith({
    QuillController? controller,
    bool? isSaving,
    String? errorMessage,
    bool? hasStartedEditing,
  }) {
    return TranscriptState(
      controller: controller ?? this.controller,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: errorMessage,
      hasStartedEditing: hasStartedEditing ?? this.hasStartedEditing,
    );
  }
}

class TranscriptController extends StateNotifier<TranscriptState> {
  TranscriptController(this._ref)
      : super(
          TranscriptState(
            controller: QuillController.basic(),
            isSaving: false,
          ),
        );

  final Ref _ref;
  String? _recordingId;
  late final Logger _logger = _ref.read(loggingServiceProvider).logger;
  
  /// Callback triggered on first edit
  void Function()? onFirstEdit;

  Future<void> load(String recordingId) async {
    _recordingId = recordingId;
    final repo = _ref.read(transcriptRepositoryProvider);
    try {
      final html = await repo.fetchTranscript(recordingId);
      _logger.info(
        '[TranscriptController] load recording=$recordingId '
        'length=${html.length} content_preview=${html.substring(0, html.length > 200 ? 200 : html.length)}',
      );

      
      // Check if content looks like HTML (basic check)
      // If it doesn't contain tags, standard HTML parsers might strip newlines.
      final isHtml = html.contains('<') && html.contains('>');

      Delta delta;
      if (isHtml) {
         delta = HtmlToDelta().convert(html);
      } else {
         var text = html;
         if (!text.endsWith('\n')) {
            text += '\n';
         }
         delta = Delta()..insert(text);
      }
      
      // Ensure delta ends with newline (double check for HTML conversion too)
      if (delta.isNotEmpty && delta.last.data is String && !(delta.last.data as String).endsWith('\n')) {
        delta.insert('\n');
      }
      
      _logger.info('[TranscriptController] Converted Delta: ${delta.toJson()}');
      
      final newController = QuillController(
        document: Document.fromDelta(delta),
        selection: const TextSelection.collapsed(offset: 0),
      );
      
      // Listen for changes to trigger onFirstEdit
      newController.document.changes.listen((change) {
         if (!state.hasStartedEditing && change.source == ChangeSource.local) {
            state = state.copyWith(hasStartedEditing: true);
            onFirstEdit?.call();
            _logger.info('[TranscriptController] First edit detected');
         }
      });

      state = TranscriptState(
        controller: newController,
        isSaving: false,
      );
    } catch (error, stack) {
      _logger.severe('[TranscriptController] load failed', error, stack);
      state = state.copyWith(
        errorMessage: 'Failed to load transcript.',
      );
    }
  }

  Future<bool> save() async {
    final recordingId = _recordingId;
    if (recordingId == null) return false;
    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      final repo = _ref.read(transcriptRepositoryProvider);
      
      final delta = state.controller.document.toDelta().toJson();
      final converter = QuillDeltaToHtmlConverter(
        List.castFrom(delta),
        ConverterOptions(
          converterOptions: OpConverterOptions(
             inlineStylesFlag: true,
          ),
        ),
      );

      final html = converter.convert();
      
      await repo.saveTranscript(
        recordingId: recordingId,
        html: html,
      );
      
      state = state.copyWith(isSaving: false);
      return true;
    } catch (error, stack) {
      _logger.severe('[TranscriptController] save failed', error, stack);
      state = state.copyWith(
        isSaving: false,
        errorMessage: 'Failed to save transcript.',
      );
      return false;
    }
  }

  String getTranscriptHtml() {
    final delta = state.controller.document.toDelta().toJson();
    final converter = QuillDeltaToHtmlConverter(
      List.castFrom(delta),
      ConverterOptions(
        converterOptions: OpConverterOptions(
           inlineStylesFlag: true,
        ),
      ),
    );
    return converter.convert();
  }
}

final transcriptControllerProvider = StateNotifierProvider<TranscriptController, TranscriptState>((ref) {
  return TranscriptController(ref);
});
