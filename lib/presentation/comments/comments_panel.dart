import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/comment.dart';
import '../player/audio_player_controller.dart';
import 'comments_controller.dart';

class CommentsPanel extends ConsumerStatefulWidget {
  const CommentsPanel({super.key, required this.recordingId});

  final String recordingId;

  @override
  ConsumerState<CommentsPanel> createState() => _CommentsPanelState();
}

class _CommentsPanelState extends ConsumerState<CommentsPanel> {
  final _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    ref.read(commentsControllerProvider.notifier).load(widget.recordingId);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(commentsControllerProvider);
    final player = ref.watch(audioPlayerControllerProvider);

    return Column(
      children: [
        Expanded(
          child: state.isLoading
              ? const Center(child: CircularProgressIndicator())
              : ListView.builder(
                  itemCount: state.items.length,
                  itemBuilder: (context, index) {
                    final comment = state.items[index];
                    return _CommentTile(comment: comment);
                  },
                ),
        ),
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.all(8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _controller,
                  decoration: const InputDecoration(
                    labelText: 'Add comment',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () async {
                  if (_controller.text.isEmpty) return;
                  await ref
                      .read(commentsControllerProvider.notifier)
                      .addComment(
                        _controller.text,
                        player.position.inSeconds,
                      );
                  _controller.clear();
                },
                child: const Text('Add'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CommentTile extends ConsumerWidget {
  const _CommentTile({required this.comment});

  final Comment comment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final createdAt = DateFormat.yMMMd().add_jm().format(comment.createdAt);
    return ListTile(
      title: Text(comment.body),
      subtitle: Text('At ${_format(comment.timestampSeconds)} • $createdAt'),
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () async {
              final updated = await showDialog<String>(
                context: context,
                builder: (context) => _EditCommentDialog(initial: comment.body),
              );
              if (updated != null && updated.isNotEmpty) {
                await ref
                    .read(commentsControllerProvider.notifier)
                    .updateComment(comment.id, updated);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: () => ref
                .read(commentsControllerProvider.notifier)
                .deleteComment(comment.id),
          ),
        ],
      ),
      onTap: () => ref
          .read(audioPlayerControllerProvider.notifier)
          .seek(Duration(seconds: comment.timestampSeconds)),
    );
  }

  String _format(int seconds) {
    final duration = Duration(seconds: seconds);
    String two(int n) => n.toString().padLeft(2, '0');
    final minutes = two(duration.inMinutes.remainder(60));
    final secs = two(duration.inSeconds.remainder(60));
    final hours = duration.inHours;
    return hours > 0 ? '$hours:$minutes:$secs' : '$minutes:$secs';
  }
}

class _EditCommentDialog extends StatefulWidget {
  const _EditCommentDialog({required this.initial});

  final String initial;

  @override
  State<_EditCommentDialog> createState() => _EditCommentDialogState();
}

class _EditCommentDialogState extends State<_EditCommentDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit comment'),
      content: TextField(controller: _controller),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
