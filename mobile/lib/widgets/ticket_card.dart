import 'package:flutter/material.dart';

import '../models/ticket.dart';
import '../theme.dart';
import '../utils/formatters.dart';
import 'ui.dart';

/// One ticket in a list (feature 10.2): category icon, number, title,
/// status, priority, overdue flag and the person on the other side.
class TicketCard extends StatelessWidget {
  const TicketCard({super.key, required this.ticket, required this.onTap, this.showCustomer = false});

  final Ticket ticket;
  final VoidCallback onTap;

  /// Staff see who raised the ticket; customers see who handles it.
  final bool showCustomer;

  @override
  Widget build(BuildContext context) {
    final person = showCustomer ? ticket.customer : ticket.assignedAgent;
    final categoryColor = AppTheme.categoryColor(ticket.categoryName);
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(icon: AppTheme.categoryIcon(ticket.categoryName), color: categoryColor, size: 46),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(ticket.number,
                        style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.primary)),
                    if (ticket.categoryName != null)
                      Flexible(
                        child: Text('  ·  ${ticket.categoryName}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
                      ),
                    const Spacer(),
                    Text(formatRelative(ticket.updatedAt ?? ticket.createdAt),
                        style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                  ],
                ),
                const SizedBox(height: 4),
                Text(ticket.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.ink, height: 1.35)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          StatusChip(ticket.status),
                          if (ticket.priorityName != null) PriorityChip(ticket.priorityName!),
                          if (ticket.isOverdue) const OverdueChip(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (person != null)
                      Tooltip(
                        message: person.name,
                        child: UserAvatar(name: person.name, initials: person.initials, size: 30),
                      )
                    else if (!showCustomer || ticket.isUnassigned)
                      const Tooltip(
                        message: 'Not assigned yet',
                        child: CircleAvatar(
                          radius: 15,
                          backgroundColor: AppColors.line,
                          child: Icon(Icons.person_off_rounded, size: 16, color: AppColors.muted),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
