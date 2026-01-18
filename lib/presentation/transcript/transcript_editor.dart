import 'package:fleather/fleather.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'transcript_controller.dart';

class TranscriptEditor extends ConsumerStatefulWidget {
  const TranscriptEditor({super.key, required this.recordingId});

  final String recordingId;

  @override
  ConsumerState<TranscriptEditor> createState() => _TranscriptEditorState();
}

class _TranscriptEditorState extends ConsumerState<TranscriptEditor> {
  late final FocusNode _focusNode;
  late final ScrollController _toolbarScrollController;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    _toolbarScrollController = ScrollController();
    ref.read(transcriptControllerProvider.notifier).load(widget.recordingId);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _toolbarScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transcriptControllerProvider);

    return Column(
      children: [
        Scrollbar(
          thumbVisibility: true,
          trackVisibility: true,
          controller: _toolbarScrollController,
          child: SingleChildScrollView(
            controller: _toolbarScrollController,
            scrollDirection: Axis.horizontal,
            child: FleatherToolbar(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              children: [
              UndoRedoButton.undo(controller: state.controller),
              UndoRedoButton.redo(controller: state.controller),
              const VerticalDivider(width: 8),
              SelectHeadingButton(controller: state.controller),
              const VerticalDivider(width: 8),
              ToggleStyleButton(
                attribute: ParchmentAttribute.bold,
                icon: Icons.format_bold,
                controller: state.controller,
              ),
              ToggleStyleButton(
                attribute: ParchmentAttribute.italic,
                icon: Icons.format_italic,
                controller: state.controller,
              ),
              ToggleStyleButton(
                attribute: ParchmentAttribute.underline,
                icon: Icons.format_underline,
                controller: state.controller,
              ),
              ToggleStyleButton(
                attribute: ParchmentAttribute.strikethrough,
                icon: Icons.format_strikethrough,
                controller: state.controller,
              ),
              ColorButton(
                controller: state.controller,
                attributeKey: ParchmentAttribute.foregroundColor,
                nullColorLabel: 'Text color',
                builder: (context, value) {
                  final effectiveColor =
                      value ?? DefaultTextStyle.of(context).style.color ?? Colors.black;
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.text_fields_sharp, size: 16),
                      Container(
                        width: 18,
                        height: 3,
                        decoration: BoxDecoration(color: effectiveColor),
                      ),
                    ],
                  );
                },
              ),
              ColorButton(
                controller: state.controller,
                attributeKey: ParchmentAttribute.backgroundColor,
                nullColorLabel: 'Highlight',
                builder: (context, value) => Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.format_color_fill, size: 16),
                    Container(
                      width: 18,
                      height: 3,
                      decoration: BoxDecoration(color: value ?? Colors.transparent),
                    ),
                  ],
                ),
              ),
              const VerticalDivider(width: 8),
              LinkStyleButton(controller: state.controller),
              ToggleStyleButton(
                attribute: ParchmentAttribute.inlineCode,
                icon: Icons.code,
                controller: state.controller,
              ),
              const VerticalDivider(width: 8),
              ToggleStyleButton(
                attribute: ParchmentAttribute.left,
                icon: Icons.format_align_left,
                controller: state.controller,
              ),
              ToggleStyleButton(
                attribute: ParchmentAttribute.center,
                icon: Icons.format_align_center,
                controller: state.controller,
              ),
              ToggleStyleButton(
                attribute: ParchmentAttribute.right,
                icon: Icons.format_align_right,
                controller: state.controller,
              ),
              ToggleStyleButton(
                attribute: ParchmentAttribute.justify,
                icon: Icons.format_align_justify,
                controller: state.controller,
              ),
              const VerticalDivider(width: 8),
              ToggleStyleButton(
                attribute: ParchmentAttribute.ul,
                icon: Icons.format_list_bulleted,
                controller: state.controller,
              ),
              ToggleStyleButton(
                attribute: ParchmentAttribute.ol,
                icon: Icons.format_list_numbered,
                controller: state.controller,
              ),
              ToggleStyleButton(
                attribute: ParchmentAttribute.cl,
                icon: Icons.checklist,
                controller: state.controller,
              ),
              IndentationButton(controller: state.controller, increase: true),
              IndentationButton(controller: state.controller, increase: false),
              const VerticalDivider(width: 8),
              ToggleStyleButton(
                attribute: ParchmentAttribute.bq,
                icon: Icons.format_quote,
                controller: state.controller,
              ),
              ToggleStyleButton(
                attribute: ParchmentAttribute.code,
                icon: Icons.code_off,
                controller: state.controller,
              ),
              InsertEmbedButton(
                controller: state.controller,
                icon: Icons.horizontal_rule,
              ),
              ],
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: FleatherEditor(
            controller: state.controller,
            focusNode: _focusNode,
            readOnly: false,
          ),
        ),
        if (state.errorMessage != null)
          Padding(
            padding: const EdgeInsets.all(8),
            child: Text(
              state.errorMessage!,
              style: const TextStyle(color: Colors.red),
            ),
          ),
      ],
    );
  }

}

