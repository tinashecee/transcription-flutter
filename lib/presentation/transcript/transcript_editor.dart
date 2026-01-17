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
        Row(
          children: [
            FleatherToolbar.basic(controller: state.controller),
            const Spacer(),
            TextButton.icon(
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
              icon: const Icon(Icons.access_time),
              label: const Text('Insert timestamp'),
            ),
            TextButton.icon(
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
                final html = dq.Delta.fromJson(parchmentDelta.toJson()).toHtml();
                await File(location.path).writeAsString(html);
              },
              icon: const Icon(Icons.download),
              label: const Text('Export HTML'),
            ),
            TextButton.icon(
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
              icon: const Icon(Icons.description),
              label: const Text('Export Text'),
            ),
            TextButton.icon(
              onPressed: state.isSaving ? null : controller.save,
              icon: const Icon(Icons.save),
              label: const Text('Save'),
            ),
            TextButton.icon(
              onPressed: controller.retranscribe,
              icon: const Icon(Icons.refresh),
              label: const Text('Retranscribe'),
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
