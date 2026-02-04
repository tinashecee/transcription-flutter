import 'package:flutter/widgets.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;
import 'package:logging/logging.dart';

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

  Future<void> load(String recordingId) async {
    _recordingId = recordingId;
    final repo = _ref.read(transcriptRepositoryProvider);
    try {
      final html = await repo.fetchTranscript(recordingId);
      _logger.info(
        '[TranscriptController] load recording=$recordingId '
        'length=${html.length}',
      );

      // Dispose old controller
      final oldController = state.controller;
      oldController.dispose();
      _logger.info('[TranscriptController] Disposed old controller');

      // Convert HTML to Delta
      final delta = _htmlToDelta(html);
      _logger.info('[TranscriptController] Converted to delta: ${delta.length} operations');

      // Create a NEW controller with the document
      final document = Document.fromDelta(delta);
      final newController = QuillController(
        document: document,
        selection: const TextSelection.collapsed(offset: 0),
      );
      _setupControllerListeners(newController);
      _logger.info('[TranscriptController] Created new controller');

      // Update state with the new controller
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

  void _setupControllerListeners(QuillController controller) {
    controller.document.changes.listen((event) {
      _logger.info('[TranscriptController] Document changed');
    });
  }

  Future<bool> save() async {
    final recordingId = _recordingId;
    if (recordingId == null) return false;
    state = state.copyWith(isSaving: true, errorMessage: null);
    try {
      final repo = _ref.read(transcriptRepositoryProvider);
      final delta = state.controller.document.toDelta();

      // Convert delta to HTML
      final html = _deltaToHtml(delta);

      _logger.info('[TranscriptController] Saving transcript for $recordingId (${html.length} chars)');

      final response = await repo.saveTranscript(recordingId: recordingId, html: html);

      _logger.info('[TranscriptController] Save response: $response');

      state = state.copyWith(isSaving: false);
      return true;
    } catch (error, stack) {
      _logger.severe('[TranscriptController] Save failed', error, stack);
      state = state.copyWith(
        isSaving: false,
        errorMessage: error.toString(),
      );
      return false;
    }
  }

  Future<Map<String, dynamic>> checkTranscriptionStatus() async {
    final recordingId = _recordingId;
    if (recordingId == null) return {};
    
    try {
      final repo = _ref.read(transcriptRepositoryProvider);
      final status = await repo.checkTranscriptionStatus(recordingId);
      _logger.info('[TranscriptController] Transcription status: $status');
      return status;
    } catch (error, stack) {
      _logger.severe('[TranscriptController] Failed to check status', error, stack);
      return {};
    }
  }

  Future<Map<String, dynamic>> retranscribe(String userId) async {
    final recordingId = _recordingId;
    if (recordingId == null) return {'error': 'No recording loaded'};
    
    try {
      final repo = _ref.read(transcriptRepositoryProvider);
      
      // Check for existing jobs first
      _logger.info('[TranscriptController] Checking for existing jobs...');
      final status = await repo.checkTranscriptionStatus(recordingId);
      _logger.info('[TranscriptController] Status response: $status');
      
      final activeJobs = status['active_jobs'] as List?;
      final transcriptionState = status['transcription_state'] as String?;
      
      if (activeJobs != null && activeJobs.isNotEmpty) {
        final jobStatus = transcriptionState ?? 'active';
        _logger.warning('[TranscriptController] Job already exists: $jobStatus');
        return {
          'error': 'Job Already Exists',
          'message': 'A transcription job is already $jobStatus for this recording.',
          'already_exists': true,
        };
      }
      
      _logger.info('[TranscriptController] No existing jobs found');
      
      // No existing job - create new one
      _logger.info('[TranscriptController] Starting retranscribe for $recordingId');
      final response = await repo.retranscribe(recordingId, userId);
      _logger.info('[TranscriptController] Retranscribe response: $response');
      
      // Reload transcript after some delay
      if (response['already_exists'] != true) {
        Future.delayed(const Duration(seconds: 2), () {
          if (_recordingId == recordingId) {
            load(recordingId);
          }
        });
      }
      
      return response;
    } catch (error, stack) {
      _logger.severe('[TranscriptController] Retranscribe failed', error, stack);
      return {
        'error': 'Retranscribe Failed',
        'message': error.toString(),
      };
    }
  }

  /// Replace the entire editor content with HTML content
  /// This preserves undo history so users can undo the import
  Future<void> replaceContent(String html) async {
    try {
      _logger.info('[TranscriptController] Replacing content with HTML (${html.length} chars)');

      final controller = state.controller;
      final currentDocument = controller.document;
      final currentLength = currentDocument.length;

      // Convert HTML to Delta
      final newDelta = _htmlToDelta(html);
      _logger.info('[TranscriptController] Converted to delta: ${newDelta.length} operations');

      // Create a change Delta that:
      // 1. Retains 0 (start of document)
      // 2. Deletes all current content
      // 3. Inserts the new content
      final doc = Document();
      final change = doc.toDelta();
      change.retain(0);
      change.delete(currentLength);
      
      // Add all insert operations from the new delta
      for (final op in newDelta.toList()) {
        if (op.isInsert) {
          change.insert(op.data, op.attributes);
        } else if (op.isRetain) {
          change.retain(op.length, op.attributes);
        } else if (op.isDelete) {
          change.delete(op.length);
        }
      }

      // Compose the change with the document
      // Using ChangeSource.local ensures it's recorded in undo history
      currentDocument.compose(change, ChangeSource.local);
      
      // Reset selection to the beginning
      controller.updateSelection(
        const TextSelection.collapsed(offset: 0),
        ChangeSource.local,
      );

      _logger.info('[TranscriptController] Content replaced, undo history preserved');
    } catch (error, stack) {
      _logger.severe('[TranscriptController] Replace content failed', error, stack);
      state = state.copyWith(
        errorMessage: 'Failed to replace content: ${error.toString()}',
      );
      rethrow;
    }
  }

  @override
  void dispose() {
    _logger.info('[TranscriptController] Disposing controller');
    state.controller.dispose();
    super.dispose();
  }

  dynamic _htmlToDelta(String html) {
    if (html.trim().isEmpty) {
      final doc = Document();
      return doc.toDelta();
    }

    final document = html_parser.parse(html);
    final body = document.body;
    if (body == null) {
      final doc = Document();
      return doc.toDelta();
    }

    final doc = Document();
    int offset = 0;
    for (final node in body.nodes) {
      offset = _convertNode(node, doc, offset, {});
    }

    // Ensure trailing newline
    if (offset > 0) {
      doc.insert(offset, '\n');
    }

    return doc.toDelta();
  }

  int _convertNode(
    dom.Node node,
    Document document,
    int offset,
    Map<String, dynamic> attributes,
  ) {
    if (node is dom.Text) {
      final text = node.text;
      if (text.isNotEmpty) {
        document.insert(offset, text);
        offset += text.length;
      }
      return offset;
    }

    if (node is! dom.Element) return offset;

    final tag = node.localName ?? '';
    final newAttributes = Map<String, dynamic>.from(attributes);

    // Handle inline formatting
    switch (tag) {
      case 'strong':
      case 'b':
        newAttributes['bold'] = true;
        break;
      case 'em':
      case 'i':
        newAttributes['italic'] = true;
        break;
      case 'u':
        newAttributes['underline'] = true;
        break;
      case 's':
      case 'strike':
        newAttributes['strike'] = true;
        break;
      case 'a':
        final href = node.attributes['href'];
        if (href != null && href.isNotEmpty) {
          newAttributes['link'] = href;
        }
        break;
    }

    // Process children
    for (final child in node.nodes) {
      offset = _convertNode(child, document, offset, newAttributes);
    }

    // Add newline for block elements
    if (['p', 'div', 'h1', 'h2', 'h3', 'h4', 'h5', 'h6', 'li', 'br'].contains(tag)) {
      document.insert(offset, '\n');
      offset += 1;
    }

    return offset;
  }

  String _deltaToHtml(dynamic delta) {
    final buffer = StringBuffer();
    buffer.write('<!DOCTYPE html>\n<html>\n<head><meta charset="utf-8"></head>\n<body>\n');

    final ops = delta.toList();
    for (var i = 0; i < ops.length; i++) {
      final op = ops[i];
      final data = op.data;
      
      if (data is! String) continue;

      final attributes = op.attributes ?? {};
      final text = data.toString();

      // Check if this is a newline with block attributes
      if (text == '\n') {
        if (i > 0) {
          buffer.write('</p>\n');
        }
        if (i < ops.length - 1) {
          final header = attributes['header'];
          if (header != null) {
            buffer.write('<h$header>');
          } else {
            buffer.write('<p>');
          }
        }
        continue;
      }

      // Start paragraph if needed
      if (i == 0 || (i > 0 && ops[i - 1].data == '\n')) {
        final header = attributes['header'];
        if (header != null) {
          buffer.write('<h$header>');
        } else {
          buffer.write('<p>');
        }
      }

      // Apply inline formatting
      var formattedText = _escapeHtml(text);
      
      if (attributes['bold'] == true) {
        formattedText = '<strong>$formattedText</strong>';
      }
      if (attributes['italic'] == true) {
        formattedText = '<em>$formattedText</em>';
      }
      if (attributes['underline'] == true) {
        formattedText = '<u>$formattedText</u>';
      }
      if (attributes['strike'] == true) {
        formattedText = '<s>$formattedText</s>';
      }
      final link = attributes['link'];
      if (link != null) {
        formattedText = '<a href="$link">$formattedText</a>';
      }

      buffer.write(formattedText);
    }

    buffer.write('</p>\n</body>\n</html>');
    return buffer.toString();
  }

  String _escapeHtml(String text) {
    return text
        .replaceAll('&', '&amp;')
        .replaceAll('<', '&lt;')
        .replaceAll('>', '&gt;')
        .replaceAll('"', '&quot;')
        .replaceAll("'", '&#39;');
  }
}

final transcriptControllerProvider =
    StateNotifierProvider<TranscriptController, TranscriptState>((ref) {
  return TranscriptController(ref);
});
