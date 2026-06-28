import 'package:flutter/material.dart';
import '../models/comment.dart';
import 'user_avatar.dart';
import 'ubex_image.dart';

class CommentTile extends StatelessWidget {
  final Comment comment;
  final bool canDelete;
  final VoidCallback? onDelete;
  final VoidCallback? onImageTap;

  const CommentTile({
    super.key,
    required this.comment,
    this.canDelete = false,
    this.onDelete,
    this.onImageTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(
            userId: comment.userId,
            userName: comment.userName,
            radius: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.userName,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const Spacer(),
                    Text(
                      _formatRelativeTime(comment.createdAt),
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    if (canDelete)
                      IconButton(
                        icon: const Icon(Icons.delete_outline, size: 18),
                        color: Colors.red.shade300,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        onPressed: onDelete,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(comment.text, style: const TextStyle(fontSize: 13)),
                if (comment.imageUrl != null && comment.imageUrl!.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  GestureDetector(
                    onTap: onImageTap,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: UbexImage(
                        imageUrl: comment.imageUrl,
                        width: 200,
                        height: 150,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatRelativeTime(String isoDate) {
    try {
      final date = DateTime.parse(isoDate);
      final now = DateTime.now();
      final diff = now.difference(date);

      if (diff.inMinutes < 1) return 'now';
      if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
      if (diff.inHours < 24) return '${diff.inHours}h ago';
      if (diff.inDays < 7) return '${diff.inDays}d ago';
      return '${date.day}/${date.month}/${date.year}';
    } catch (_) {
      return '';
    }
  }
}
