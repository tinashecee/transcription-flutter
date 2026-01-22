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
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF115343).withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: const Color(0xFF115343),
        borderRadius: BorderRadius.circular(30),
        child: InkWell(
          onTap: () async {
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
          borderRadius: BorderRadius.circular(30),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.chat_bubble_outline_rounded, size: 20, color: Colors.white),
                const SizedBox(width: 8),
                Text(
                  'Comments',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
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
      initialChildSize: 0.65,
      minChildSize: 0.45,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 24,
                spreadRadius: 2,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: Column(
            children: [
              // Drag Handle
              Container(
                margin: const EdgeInsets.only(top: 12),
                width: 48,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
                child: Row(
                  children: [
                    Text(
                      'Comments',
                      style: GoogleFonts.inter(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF111827),
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF115343).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '${state.items.length}',
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF115343),
                        ),
                      ),
                    ),
                    const Spacer(),
                    
                    // Custom Dropdown
                    Container(
                      height: 36,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: commentType,
                          icon: Icon(Icons.keyboard_arrow_down_rounded, 
                              size: 18, color: Colors.grey.shade600),
                          isDense: true,
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF374151),
                          ),
                          dropdownColor: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          elevation: 4,
                          items: const [
                            'general',
                            'correction',
                            'question',
                            'feedback',
                            'urgent',
                          ].map((value) => DropdownMenuItem(
                                value: value,
                                child: Text(_labelForType(value)),
                              )).toList(),
                          onChanged: (value) {
                            if (value != null) onTypeChanged(value);
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              
              const Divider(height: 1, color: Color(0xFFF3F4F6)),

              Expanded(
                child: state.items.isEmpty
                    ? const _EmptyComments()
                    : ListView.separated(
                        controller: scrollController,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemCount: state.items.length,
                        itemBuilder: (context, index) {
                          final comment = state.items[index];
                          return _CommentTile(comment: comment);
                        },
                      ),
              ),
              
              if (state.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.shade50,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.shade100),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, size: 16, color: Colors.red),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            state.errorMessage!,
                            style: GoogleFonts.inter(
                              color: Colors.red.shade700,
                              fontWeight: FontWeight.w500,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // Input Area
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      offset: const Offset(0, -4),
                      blurRadius: 16,
                    ),
                  ],
                ),
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 44, maxHeight: 120),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade50,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: Colors.grey.shade200),
                        ),
                        child: TextField(
                          controller: controller,
                          maxLines: null,
                          keyboardType: TextInputType.multiline,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            color: const Color(0xFF111827),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Type a comment...',
                            hintStyle: GoogleFonts.inter(
                              color: Colors.grey.shade400,
                              fontSize: 14,
                            ),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 12,
                            ),
                            isDense: true,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Material(
                      color: const Color(0xFF115343),
                      shape: const CircleBorder(),
                      child: InkWell(
                        onTap: () async {
                          final text = controller.text.trim();
                          if (text.isEmpty) return;
                          await ref
                              .read(commentsControllerProvider.notifier)
                              .addComment(text, commentType);
                          controller.clear();
                        },
                        customBorder: const CircleBorder(),
                        child: const Padding(
                          padding: EdgeInsets.all(12),
                          child: Icon(Icons.send_rounded, color: Colors.white, size: 20),
                        ),
                      ),
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
