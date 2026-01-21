import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

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
  String _selectedFont = 'Arial';

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'TranscriptEditorFocus');
    _scrollController = ScrollController();

    // Load transcript
    ref.read(transcriptControllerProvider.notifier).load(widget.recordingId);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  TextStyle _getFontStyle(String fontFamily) {
    switch (fontFamily) {
      // Serif fonts
      case 'Times New Roman':
        return GoogleFonts.tinos();
      case 'Garamond':
        return GoogleFonts.ebGaramond();
      case 'Georgia':
        return GoogleFonts.lora();
      case 'Book Antiqua':
        return GoogleFonts.libreBodoni();
      case 'Baskerville':
        return GoogleFonts.libreBaskerville();
      
      // Sans Serif fonts
      case 'Arial':
        return GoogleFonts.inter();
      case 'Calibri':
        return GoogleFonts.openSans();
      case 'Segoe UI':
        return GoogleFonts.notoSans();
      case 'Verdana':
        return GoogleFonts.sourceSans3();
      case 'Helvetica':
        return GoogleFonts.roboto();
      case 'Trebuchet MS':
        return GoogleFonts.firaSans();
      case 'Aptos':
        return GoogleFonts.quicksand();
      
      // Monospace fonts
      case 'Consolas':
        return GoogleFonts.firaCode();
      case 'Courier New':
        return GoogleFonts.robotoMono();
      case 'Lucida Console':
        return GoogleFonts.jetBrainsMono();
      
      // Script & Handwriting fonts
      case 'Brush Script':
        return GoogleFonts.dancingScript();
      case 'Lucida Handwriting':
        return GoogleFonts.caveat();
      case 'Mistral':
        return GoogleFonts.pacifico();
      case 'Edwardian Script':
        return GoogleFonts.greatVibes();
      
      default:
        return GoogleFonts.roboto();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transcriptControllerProvider);
    final canEdit = widget.isAssigned;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (state.errorMessage != null)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.red.shade200),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red.shade700),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        state.errorMessage!,
                        style: GoogleFonts.roboto(
                          color: Colors.red.shade900,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => ref.read(transcriptControllerProvider.notifier).load(widget.recordingId),
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const Text('Retry'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red.shade900,
                    side: BorderSide(color: Colors.red.shade300),
                  ),
                ),
              ],
            ),
          )
        else ...[




        // 4. Quill Toolbar (Minimal/Floating)
        if (canEdit)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                QuillSimpleToolbar(
                  controller: state.controller,
                  config: QuillSimpleToolbarConfig(
                    toolbarSize: 32,
                    showFontFamily: false,
                    showFontSize: false,
                    showBoldButton: true,
                    showItalicButton: true,
                    showUnderLineButton: true,
                    showStrikeThrough: false,
                    showAlignmentButtons: false,
                    showListBullets: true,
                    showListNumbers: true,
                    showUndo: true,
                    showRedo: true,
                  ),
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        // 2. Editor Surface (Page Look)
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey.shade200),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              children: [
                // Warning Banner inside the "page" if read-only
                if (!canEdit)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(12),
                        topRight: Radius.circular(12),
                      ),
                      border: Border(
                        bottom: BorderSide(color: Colors.orange.shade100),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.lock_outline,
                            size: 16, color: Colors.orange.shade800),
                        const SizedBox(width: 8),
                        Text(
                          'Read-only view',
                          style: GoogleFonts.inter(
                            color: Colors.orange.shade900,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),

                // The Actual Editor
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: QuillEditor(
                      controller: state.controller,
                      focusNode: _focusNode,
                      scrollController: _scrollController,
                      config: QuillEditorConfig(
                        padding: const EdgeInsets.all(24),
                        autoFocus: false,
                        readOnlyMouseCursor: SystemMouseCursors.text,
                        enableInteractiveSelection: true,
                        placeholder: 'Start typing transcription...',
                        customStyleBuilder: (attribute) {
                          if (attribute.key == 'font') {
                            return _getFontStyle(attribute.value);
                          }
                          return GoogleFonts.roboto();
                        },
                      ),
                    ),
                  ),
                ),

              ],
            ),
          ),
        ),
        ],
      ],
    );
  }
}


