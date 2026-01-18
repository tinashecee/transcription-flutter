import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
