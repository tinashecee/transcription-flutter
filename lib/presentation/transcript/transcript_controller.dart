import 'dart:io';
import 'dart:async';
import 'package:file_selector/file_selector.dart';
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
  });

  final QuillController controller;
  final bool isSaving;
  final String? errorMessage;

  TranscriptState copyWith({
    QuillController? controller,
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
            controller: QuillController.basic(),
            isSaving: false,
          ),
        );

  final Ref _ref;
  String? _recordingId;
  late final Logger _logger = _ref.read(loggingServiceProvider).logger;
  
  /// Callback triggered on first edit
  /// Callback triggered on user edit
  void Function()? onEdit;

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
      
      // Listen for changes to trigger onEdit
      newController.document.changes.listen((change) {
         if (change.source == ChangeSource.local) {
            onEdit?.call();
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
             inlineStyles: InlineStyles({
                'size': InlineStyleType(
                  fn: (value, op) {
                    // Try to parse as double/int
                    final size = double.tryParse(value);
                    if (size != null) {
                      return 'font-size: ${size}px';
                    }
                    // Fallback to default behavior for small/large/huge if needed, 
                    // or just return plain value which might be invalid.
                    // But default map handles those. We are overriding.
                    // Let's handle standard map keys too just in case mixed usage.
                    const map = {
                      'small': '0.75em',
                      'large': '1.5em',
                      'huge': '2.5em',
                    };
                    if (map.containsKey(value)) {
                       return 'font-size: ${map[value]}';
                    }
                    return 'font-size: $value';
                  },
                ),
                // Re-declare others if needed or just merge? 
                // The library says: "if inlineStyles == null ... inlineStyles = InlineStyles({});"
                // It seems it REPLACES the default if you pass one? 
                // Checking source: 
                // "if (inlineStyles == null && inlineStylesFlag == true) { inlineStyles = InlineStyles({}); }"
                // And later: "final attributeConverter = ... (options.inlineStyles?[attribute]) ... ?? defaultInlineStyles[attribute];"
                // So it prefers options.inlineStyles, fixes fallbacks to default.
                // So we only need to provide 'size'.
             }),
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

  Future<void> exportTranscript(String title) async {
    try {
      final delta = state.controller.document.toDelta().toJson();
      final converter = QuillDeltaToHtmlConverter(
        List.castFrom(delta),
        ConverterOptions(
          converterOptions: OpConverterOptions(
             inlineStylesFlag: true,
             inlineStyles: InlineStyles({
                'size': InlineStyleType(
                  fn: (value, op) {
                    final size = double.tryParse(value);
                    if (size != null) {
                      return 'font-size: ${size}pt';
                    }
                    return 'font-size: $value';
                  },
                ),
             }),
          ),
        ),
      );

      final bodyHtml = converter.convert();
      
      // Wrap in a full HTML document structure compatible with Word
      final fullHtml = '''
<!DOCTYPE html>
<html xmlns:o='urn:schemas-microsoft-com:office:office' xmlns:w='urn:schemas-microsoft-com:office:word' xmlns='http://www.w3.org/TR/REC-html40'>
<head>
<meta charset="utf-8">
<title>$title</title>
<style>
body { font-family: 'Inter', sans-serif; font-size: 12pt; }
</style>
</head>
<body>
$bodyHtml
</body>
</html>
''';

      // Prompt user to save file
      // Aggressive sanitization to fix Linux file picker issue
      String cleanTitle = title;
      // 1. Explicitly replace directory separators
      cleanTitle = cleanTitle.replaceAll('/', '_').replaceAll('\\', '_');
      // 2. Remove anything that isn't alphanumeric, space, dot, dash, or underscore
      cleanTitle = cleanTitle.replaceAll(RegExp(r'[^a-zA-Z0-9\s\.-_]'), '');
      // 3. Trim whitespace
      cleanTitle = cleanTitle.trim();
      // 4. Ensure it's not empty
      if (cleanTitle.isEmpty) cleanTitle = 'Transcript';
      
      final fileName = '$cleanTitle.doc'; 
      _logger.info('[Export] Original title: "$title", Sanitized: "$fileName"');
       final FileSaveLocation? saveLocation = await getSaveLocation(
        suggestedName: fileName,
        acceptedTypeGroups: [
           const XTypeGroup(
            label: 'Word Document',
            extensions: ['doc'],
          ),
        ],
      );
      
      if (saveLocation == null) {
        _logger.info('[Export] User canceled save dialog');
        return;
      }
      
      _logger.info('[Export] Saving to: ${saveLocation.path}');
      final File file = File(saveLocation.path);
      await file.writeAsString(fullHtml);
      _logger.info('[Export] Save complete');
      
    } catch (e, stack) {
      _logger.severe('EXPORT_DEBUG_FAILED', e, stack);
       state = state.copyWith(
        errorMessage: 'Failed to export transcript.',
      );
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
