import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html_parser;

import 'transcript_controller.dart';

class TranscriptEditor extends ConsumerStatefulWidget {
  const TranscriptEditor({
    super.key,
    required this.recordingId,
    this.isAssigned = true,
  });

  final String recordingId;
  final bool isAssigned;

  @override
  ConsumerState<TranscriptEditor> createState() => _TranscriptEditorState();
}

class _TranscriptEditorState extends ConsumerState<TranscriptEditor> {
  late final FocusNode _focusNode;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'TranscriptEditorFocus');
    _scrollController = ScrollController();

    // Log focus changes
    _focusNode.addListener(() {
      print('[TranscriptEditor] Focus changed: hasFocus=${_focusNode.hasFocus}');
    });

    // Load transcript
    ref.read(transcriptControllerProvider.notifier).load(widget.recordingId);
  }

  @override
  void dispose() {
    print('[TranscriptEditor] dispose called for recordingId=${widget.recordingId}');
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.keyV) {
      // Check for Ctrl or Cmd modifier
      final isModifierPressed = HardwareKeyboard.instance.isControlPressed ||
          HardwareKeyboard.instance.isMetaPressed;
      
      if (isModifierPressed) {
        // Intercept Ctrl+V / Cmd+V to preserve formatting
        _handlePasteWithFormatting();
        return KeyEventResult.handled;
      }
    }
    return KeyEventResult.ignored;
  }

  Future<void> _handlePasteWithFormatting() async {
    final state = ref.read(transcriptControllerProvider);
    final controller = state.controller;
    final selection = controller.selection;
    
    if (!selection.isValid) {
      return;
    }

    try {
      // Try to get HTML from clipboard first (preserves formatting)
      // On some platforms, HTML might not be available, so we fall back to plain text
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      
      if (clipboardData?.text == null || clipboardData!.text!.isEmpty) {
        return;
      }

      // Try to parse as HTML if it contains HTML tags
      final text = clipboardData.text!;
      final isHtml = text.contains(RegExp(r'<[^>]+>'));
      
      if (isHtml) {
        // Parse HTML and convert to Delta with formatting preserved
        final delta = _htmlToDelta(text);
        if (delta != null) {
          final doc = Document();
          final change = doc.toDelta();
          change.retain(selection.start);
          change.delete(selection.end - selection.start);
          
          // Insert the formatted content from HTML
          for (final op in delta.toList()) {
            if (op.isInsert) {
              change.insert(op.data, op.attributes);
            }
          }
          
          controller.document.compose(change, ChangeSource.local);
          return;
        }
      }

      // Fallback: paste as plain text
      final doc = Document();
      final change = doc.toDelta();
      change.retain(selection.start);
      change.delete(selection.end - selection.start);
      change.insert(text);
      controller.document.compose(change, ChangeSource.local);
    } catch (e) {
      print('[TranscriptEditor] Paste error: $e');
      // If error occurs, let default paste behavior handle it
    }
  }

  dynamic _htmlToDelta(String html) {
    try {
      // Use the same HTML parsing logic as transcript_controller
      final document = html_parser.parse(html);
      final body = document.body;
      if (body == null) return null;

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
    } catch (e) {
      print('[TranscriptEditor] HTML parsing error: $e');
      return null;
    }
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
        // Build a delta with attributes and compose it
        final doc = Document();
        final delta = doc.toDelta();
        delta.retain(offset);
        delta.insert(text, attributes.isEmpty ? null : attributes);
        document.compose(delta, ChangeSource.local);
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transcriptControllerProvider);
    final canEdit = widget.isAssigned;

    print('[TranscriptEditor] build isAssigned=${widget.isAssigned} canEdit=$canEdit');
    print('[TranscriptEditor] Controller instance: ${state.controller.hashCode}');
    print('[TranscriptEditor] Document length: ${state.controller.document.length}');

    return Column(
      children: [
        // Show warning banner if user cannot edit
        if (!canEdit)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: Colors.orange.shade100,
            child: Row(
              children: [
                Icon(Icons.info_outline, color: Colors.orange.shade900),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'You are not assigned to this recording. Transcript is read-only.',
                    style: TextStyle(
                      color: Colors.orange.shade900,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),

        // Toolbar (only if user can edit)
        if (canEdit)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              border: Border(
                bottom: BorderSide(color: Colors.grey.shade300),
              ),
            ),
            child: QuillSimpleToolbar(
              controller: state.controller,
              config: QuillSimpleToolbarConfig(
                buttonOptions: QuillSimpleToolbarButtonOptions(
                  base: QuillToolbarBaseButtonOptions(
                    iconSize: 16,
                    iconButtonFactor: 1.2,
                  ),
                ),
                toolbarSize: 32,
                multiRowsDisplay: false,
              ),
            ),
          ),

        // Quill Editor
        Expanded(
          child: Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16),
            child: Focus(
              onKeyEvent: canEdit ? _handleKeyEvent : null,
              child: QuillEditor(
                controller: state.controller,
                focusNode: _focusNode,
                scrollController: _scrollController,
                config: QuillEditorConfig(
                  readOnlyMouseCursor: SystemMouseCursors.forbidden,
                ),
              ),
            ),
          ),
        ),

        // Status bar
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.grey.shade100,
            border: Border(
              top: BorderSide(color: Colors.grey.shade300),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Characters: ${state.controller.document.length}',
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey.shade700,
                ),
              ),
              if (state.isSaving)
                Row(
                  children: [
                    SizedBox(
                      width: 12,
                      height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.blue.shade700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Saving...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }
}
