import 'package:flutter/material.dart';

import '../models/reply.dart';
import '../models/user.dart';
import '../theme.dart';
import '../utils/formatters.dart';
import 'ui.dart';

/// One message in the conversation. Your own messages use the brand
/// gradient; internal notes (staff only) are amber with a lock so they are
/// never mistaken for a customer-visible reply.
class ReplyBubble extends StatelessWidget {
  const ReplyBubble({
    super.key,
    required this.message,
    required this.isMine,
    this.author,
    this.time,
    this.isInternal = false,
    this.label,
  });

  factory ReplyBubble.fromReply(TicketReply reply, {required bool isMine}) => ReplyBubble(
        message: reply.message,
        isMine: isMine,
        author: reply.author,
        time: reply.createdAt,
        isInternal: reply.isInternal,
      );

  final String message;
  final bool isMine;
  final PersonRef? author;
  final DateTime? time;
  final bool isInternal;

  /// Optional caption above the text, e.g. "Original request".
  final String? label;

  @override
  Widget build(BuildContext context) {
    final name = isMine ? 'You' : (author?.name ?? 'Unknown user');
    final isStaff = author?.role?.isStaff ?? false;
    final textColor = isMine && !isInternal ? Colors.white : AppColors.ink;
    final subColor = isMine && !isInternal ? Colors.white.withValues(alpha: 0.75) : AppColors.muted;

    final bubble = Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
      decoration: BoxDecoration(
        gradient: isMine && !isInternal ? AppColors.brand : null,
        color: isInternal ? AppColors.noteBg : (isMine ? null : Colors.white),
        border: isInternal ? Border.all(color: AppColors.noteBorder, width: 1.2) : null,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(20),
          topRight: const Radius.circular(20),
          bottomLeft: Radius.circular(isMine ? 20 : 6),
          bottomRight: Radius.circular(isMine ? 6 : 20),
        ),
        boxShadow: isMine && !isInternal ? AppShadows.glow(AppColors.primary) : AppShadows.card,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isInternal)
            const Padding(
              padding: EdgeInsets.only(bottom: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.lock_rounded, size: 14, color: AppColors.noteInk),
                  SizedBox(width: 4),
                  Flexible(
                    child: Text('Internal note · hidden from customer',
                        style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.noteInk)),
                  ),
                ],
              ),
            ),
          if (label != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(label!, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: subColor)),
            ),
          SelectableText(message, style: TextStyle(fontSize: 14.5, color: textColor, height: 1.45)),
          const SizedBox(height: 6),
          Text(formatDateTime(time), style: TextStyle(fontSize: 11, color: subColor)),
        ],
      ),
    );

    final header = Padding(
      padding: const EdgeInsets.only(bottom: 6, left: 4, right: 4),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: Text(name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: AppColors.inkSoft)),
          ),
          if (isStaff && !isMine) ...[
            const SizedBox(width: 6),
            const Pill(label: 'Support', color: AppColors.primary, icon: Icons.verified_rounded),
          ],
        ],
      ),
    );

    final avatar = UserAvatar(name: author?.name ?? name, initials: author?.initials ?? '?', size: 34);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        mainAxisAlignment: isMine ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (!isMine) ...[avatar, const SizedBox(width: 8)],
          Flexible(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.76),
              child: Column(
                crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                children: [header, bubble],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

bool isReplyMine(TicketReply reply, AppUser? me) => me != null && reply.author != null && reply.author!.id == me.id;
