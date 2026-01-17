import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:fleather/fleather.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dart_quill_delta/dart_quill_delta.dart' as dq;
import 'package:quill_html_converter/quill_html_converter.dart';

import 'transcript_controller.dart';
import '../player/audio_player_controller.dart';

class TranscriptEditor extends ConsumerStatefulWidget {
  const TranscriptEditor({super.key, required this.recordingId});

  final String recordingId;

  @override
  ConsumerState<TranscriptEditor> createState() => _TranscriptEditorState();
}

class _TranscriptEditorState extends ConsumerState<TranscriptEditor> {
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _focusNode = FocusNode();
    ref.read(transcriptControllerProvider.notifier).load(widget.recordingId);
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(transcriptControllerProvider);
    final controller = ref.read(transcriptControllerProvider.notifier);

    return Column(
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: FleatherToolbar.basic(controller: state.controller),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _ActionIconButton(
                  tooltip: 'Insert timestamp',
                  icon: Icons.access_time,
                  onPressed: () {
                    final position =
                        ref.read(audioPlayerControllerProvider).position;
                    final timestamp = _formatTimestamp(position);
                    final selection = state.controller.selection;
                    final index = selection.baseOffset;
                    state.controller.replaceText(
                      index,
                      0,
                      '[$timestamp] ',
                    );
                  },
                ),
                _ActionIconButton(
                  tooltip: 'Export HTML',
                  icon: Icons.download,
                  onPressed: () async {
                    final location = await getSaveLocation(
                      acceptedTypeGroups: [
                        const XTypeGroup(
                          label: 'HTML',
                          extensions: ['html'],
                        ),
                      ],
                    );
                    if (location == null) return;
                    final parchmentDelta = state.controller.document.toDelta();
                    final html =
                        dq.Delta.fromJson(parchmentDelta.toJson()).toHtml();
                    await File(location.path).writeAsString(html);
                  },
                ),
                _ActionIconButton(
                  tooltip: 'Export Text',
                  icon: Icons.description,
                  onPressed: () async {
                    final location = await getSaveLocation(
                      acceptedTypeGroups: [
                        const XTypeGroup(
                          label: 'Text',
                          extensions: ['txt'],
                        ),
                      ],
                    );
                    if (location == null) return;
                    final text = state.controller.document.toPlainText();
                    await File(location.path).writeAsString(text);
                  },
                ),
                _ActionIconButton(
                  tooltip: 'Save',
                  icon: Icons.save,
                  onPressed: state.isSaving ? null : controller.save,
                ),
                _ActionIconButton(
                  tooltip: 'Retranscribe',
                  icon: Icons.refresh,
                  onPressed: controller.retranscribe,
                ),
              ],
            ),
          ],
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

  String _formatTimestamp(Duration duration) {
    String two(int n) => n.toString().padLeft(2, '0');
    final hours = two(duration.inHours);
    final minutes = two(duration.inMinutes.remainder(60));
    final secs = two(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$secs';
  }
}

class _ActionIconButton extends StatelessWidget {
  const _ActionIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        onPressed: onPressed,
        icon: Icon(icon),
        color: const Color(0xFF115343),
        splashRadius: 20,
      ),
    );
  }
}
