import 'package:flutter/material.dart';
import 'package:flutter_quill/flutter_quill.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import 'transcript_controller.dart';
import '../../data/providers.dart';
import '../recordings/recording_detail_controller.dart';
import '../recordings/recordings_controller.dart';

class TranscriptEditor extends ConsumerStatefulWidget {
  const TranscriptEditor({
    super.key,
    required this.recordingId,
    this.isAssigned = true,
    this.isEditing = false,
  });

  final String recordingId;
  final bool isAssigned;
  final bool isEditing;

  @override
  ConsumerState<TranscriptEditor> createState() => _TranscriptEditorState();
}

class _TranscriptEditorState extends ConsumerState<TranscriptEditor> {
  late final FocusNode _focusNode;
  late final ScrollController _scrollController;
  String _selectedFont = 'Helvetica';
  bool _hasTriggeredProgress = false;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode(debugLabel: 'TranscriptEditorFocus');
    _scrollController = ScrollController();

    // Load transcript
    ref.read(transcriptControllerProvider.notifier).load(widget.recordingId);
    
    // Setup first-edit callback for auto-progress
    ref.read(transcriptControllerProvider.notifier).onFirstEdit = _onFirstEdit;
  }
  
  void _onFirstEdit() {
    if (_hasTriggeredProgress || !widget.isAssigned || !widget.isEditing) return;
    _hasTriggeredProgress = true;
    
    // Update status to 'in_progress' silently in background
    _updateStatusToInProgress();
  }
  
  Future<void> _updateStatusToInProgress() async {
    try {
      await ref.read(statusRepositoryProvider).updateStatus(
        recordingId: widget.recordingId,
        status: 'in_progress',
      );
      // Update the cached list so the patch logic works
      ref.read(recordingsControllerProvider.notifier).updateRecordingStatus(widget.recordingId, 'in_progress');
      // NOTE: We do NOT invalidate recordingDetailProvider here because it causes 
      // the transcript to reload and wipe user's unsaved changes.
    } catch (e) {
      debugPrint('Failed to update status: $e');
    }
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
        return GoogleFonts.inter();
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
        return GoogleFonts.inter();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transcriptControllerProvider);
    final canEdit = widget.isAssigned && widget.isEditing;

    // Enforce read-only state on the controller
    state.controller.readOnly = !canEdit;

    return Stack(
      children: [
        Column(
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
                        style: GoogleFonts.inter(
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




        // 4. Quill Toolbar (Minimal/Floating) + Save Button
        if (canEdit)
        // 4. Quill Toolbar (Minimal/Floating)
        if (canEdit)
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Material(
              color: const Color(0xFFF3F4F6),
              child: SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  child: QuillSimpleToolbar(
                    controller: state.controller,
                    config: QuillSimpleToolbarConfig(
                      toolbarSize: 28,
                      buttonOptions: const QuillSimpleToolbarButtonOptions(
                        base: QuillToolbarBaseButtonOptions(
                          iconSize: 18,
                        ),
                      ),
                      showFontFamily: true,
                      showFontSize: true,
                      showBoldButton: true,
                      showItalicButton: true,
                      showUnderLineButton: true,
                      showStrikeThrough: false,
                      showColorButton: false, 
                      showBackgroundColorButton: false,
                      showAlignmentButtons: false,
                      showListBullets: true,
                      showListNumbers: true,
                      showCodeBlock: false,
                      showQuote: false,
                      showIndent: false,
                      showLink: false,
                      showUndo: true,
                      showRedo: true,
                      showDirection: false,
                      showSearchButton: false,
                      showSubscript: false,
                      showSuperscript: false,
                    ),
                  ),
                ),
              ),
            ),
          ),
        const SizedBox.shrink(),
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
                // Warning Banner inside the "page" if read-only AND NOT ASSIGNED
                // If assigned, we just show the "Edit" button in toolbar, so no need for a warning.
                if (!canEdit && !widget.isAssigned)
                  Container(
                    width: double.infinity,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.only(top: 8, right: 16),
                    child: Tooltip(
                      message: 'This transcript is not assigned to you its on read mode, to be editable you need it assign to you.',
                      padding: const EdgeInsets.all(8),
                      textStyle: GoogleFonts.inter(color: Colors.white, fontSize: 12),
                      decoration: BoxDecoration(
                        color: Colors.black87,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.orange.shade200),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_outline,
                                size: 12, color: Colors.orange.shade800),
                            const SizedBox(width: 4),
                            Text(
                              'Read Only',
                              style: GoogleFonts.inter(
                                color: Colors.orange.shade900,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
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
                        padding: const EdgeInsets.only(left: 16, right: 16, top: 0, bottom: 16),
                        autoFocus: false,
                        readOnlyMouseCursor: SystemMouseCursors.text,
                        enableInteractiveSelection: true,
                        placeholder: 'Start typing transcription...',
                        customStyleBuilder: (attribute) {
                          if (attribute.key == 'font') {
                            return _getFontStyle(attribute.value);
                          }
                          return GoogleFonts.inter(
                            height: 1.4,
                            color: const Color(0xFF374151),
                            fontSize: 14, // Small font size
                          );
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
    ),
    ],
  );
}
}


