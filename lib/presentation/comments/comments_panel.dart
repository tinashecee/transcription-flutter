import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../domain/entities/comment.dart';
import 'comments_controller.dart';

class CommentsPanel extends ConsumerStatefulWidget {
  const CommentsPanel({super.key, required this.recordingId});

  final String recordingId;

  @override
  ConsumerState<CommentsPanel> createState() => _CommentsPanelState();
}

class _CommentsPanelState extends ConsumerState<CommentsPanel> {
  final _controller = TextEditingController();
  String _commentType = 'general';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(commentsControllerProvider.notifier).load(widget.recordingId);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      icon: const Icon(Icons.chat_bubble_outline, size: 18),
      label: Text(
        'Comments',
        style: GoogleFonts.roboto(fontWeight: FontWeight.w600),
      ),
      style: FilledButton.styleFrom(
        backgroundColor: const Color(0xFF115343),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        minimumSize: const Size(0, 0),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
        ),
      ),
      onPressed: () async {
        await showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (context) => _CommentsModal(
            controller: _controller,
            commentType: _commentType,
            onTypeChanged: (value) => setState(() => _commentType = value),
          ),
        );
      },
    );
  }
}

class _CommentsModal extends ConsumerWidget {
  const _CommentsModal({
    required this.controller,
    required this.commentType,
    required this.onTypeChanged,
  });

  final TextEditingController controller;
  final String commentType;
  final ValueChanged<String> onTypeChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(commentsControllerProvider);
    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              Container(
                margin: const EdgeInsets.only(top: 8),
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[400],
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Text(
                      'Comments',
                      style: GoogleFonts.roboto(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFF115343),
                      ),
                    ),
                    const Spacer(),
                    DropdownButton<String>(
                      value: commentType,
                      underline: const SizedBox.shrink(),
                      items: const [
                        'general',
                        'correction',
                        'question',
                        'feedback',
                        'urgent',
                      ]
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(_labelForType(value)),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value != null) onTypeChanged(value);
                      },
                    ),
                  ],
                ),
              ),
              Expanded(
                child: state.items.isEmpty
                    ? const _EmptyComments()
                    : ListView.builder(
                        controller: scrollController,
                        itemCount: state.items.length,
                        itemBuilder: (context, index) {
                          final comment = state.items[index];
                          return _CommentTile(comment: comment);
                        },
                      ),
              ),
              if (state.errorMessage != null)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Text(
                    state.errorMessage!,
                    style: GoogleFonts.roboto(
                      color: Colors.redAccent,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: controller,
                        maxLines: 2,
                        decoration: InputDecoration(
                          hintText: 'Type a comment...',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: () async {
                        final text = controller.text.trim();
                        if (text.isEmpty) return;
                        await ref
                            .read(commentsControllerProvider.notifier)
                            .addComment(text, commentType);
                        controller.clear();
                      },
                      icon: const Icon(Icons.send),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({required this.comment});

  final Comment comment;

  @override
  Widget build(BuildContext context) {
    final createdAt = DateFormat.yMMMd().add_jm().format(comment.createdAt);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
        border: Border.all(color: Colors.grey.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  comment.authorName,
                  style: GoogleFonts.roboto(
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF115343),
                  ),
                ),
              ),
              _CommentTypeBadge(type: comment.commentType),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            comment.content,
            style: GoogleFonts.roboto(color: Colors.grey[800]),
          ),
          const SizedBox(height: 8),
          Text(
            createdAt,
            style: GoogleFonts.roboto(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyComments extends StatelessWidget {
  const _EmptyComments();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'No comments yet.',
        style: GoogleFonts.roboto(
          color: Colors.grey[600],
          fontSize: 13,
        ),
      ),
    );
  }
}

class _CommentTypeBadge extends StatelessWidget {
  const _CommentTypeBadge({required this.type});

  final String type;

  @override
  Widget build(BuildContext context) {
    final normalized = type.toLowerCase();
    Color color;
    switch (normalized) {
      case 'urgent':
        color = Colors.red;
        break;
      case 'correction':
        color = Colors.orange;
        break;
      case 'question':
        color = Colors.blue;
        break;
      case 'feedback':
        color = Colors.teal;
        break;
      default:
        color = Colors.grey;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.4)),
      ),
      child: Text(
        _labelForType(normalized).toUpperCase(),
        style: GoogleFonts.roboto(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

String _labelForType(String value) {
  switch (value) {
    case 'correction':
      return 'Correction';
    case 'question':
      return 'Question';
    case 'feedback':
      return 'Feedback';
    case 'urgent':
      return 'Urgent';
    default:
      return 'General';
  }
}
