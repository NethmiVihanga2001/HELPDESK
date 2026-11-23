import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_notification.dart';
import '../services/notifications_controller.dart';
import '../theme.dart';
import '../utils/formatters.dart';
import '../widgets/state_views.dart';
import '../widgets/ui.dart';
import 'ticket_detail_screen.dart';

/// Bell for gradient headers, with the unread count (NOT-1 to NOT-4).
class NotificationBell extends StatelessWidget {
  const NotificationBell({super.key});

  @override
  Widget build(BuildContext context) {
    final unread = context.select<NotificationsController, int>((c) => c.unreadCount);
    return HeaderIconButton(
      icon: Icons.notifications_rounded,
      tooltip: 'Notifications',
      badge: unread,
      onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const NotificationsScreen())),
    );
  }
}

/// Feature 10.6: notifications for assignments, replies, status changes and
/// overdue tickets. Tapping one marks it as read and opens its ticket.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => context.read<NotificationsController>().refresh());
  }

  Future<void> _open(AppNotification n) async {
    final controller = context.read<NotificationsController>();
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final ticketId = n.ticketId;
    if (ticketId != null) {
      navigator.push(MaterialPageRoute<void>(builder: (_) => TicketDetailScreen(ticketId: ticketId)));
    }
    if (!await controller.markRead(n)) {
      messenger.showSnackBar(const SnackBar(content: Text('Could not mark the notification as read.')));
    }
  }

  Future<void> _markAll() async {
    final ok = await context.read<NotificationsController>().markAllRead();
    if (mounted) showSnack(context, ok ? 'All caught up' : 'Some notifications could not be updated.');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.watch<NotificationsController>();
    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            child: HeaderBar(
              showBack: true,
              title: 'Notifications',
              subtitle: c.unreadCount == 0 ? "You're all caught up" : '${c.unreadCount} unread',
              actions: [
                if (c.unreadCount > 0)
                  HeaderIconButton(icon: Icons.done_all_rounded, tooltip: 'Mark all as read', onPressed: _markAll),
              ],
            ),
          ),
          Expanded(child: _body(c)),
        ],
      ),
    );
  }

  Widget _body(NotificationsController c) {
    if (!c.hasLoaded) {
      if (c.error != null && !c.isLoading) return ErrorView(message: c.error!, onRetry: c.refresh);
      return const SkeletonList(itemHeight: 76);
    }
    return RefreshIndicator(
      onRefresh: c.refresh,
      child: c.items.isEmpty
          ? const EmptyView(
              icon: Icons.notifications_none_rounded,
              title: "You're all caught up",
              message: 'Replies, status changes and assignments will appear here.',
            )
          : ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              itemCount: c.items.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, i) => FadeSlideIn(
                index: i,
                child: _NotificationTile(notification: c.items[i], onTap: () => _open(c.items[i])),
              ),
            ),
    );
  }
}

class _NotificationTile extends StatelessWidget {
  const _NotificationTile({required this.notification, required this.onTap});

  final AppNotification notification;
  final VoidCallback onTap;

  /// Picks an icon and colour from the kind of event in the message.
  (IconData, Color) get _look {
    final m = notification.message.toLowerCase();
    if (m.contains('overdue')) return (Icons.alarm_rounded, AppColors.danger);
    if (m.contains('assigned')) return (Icons.person_add_alt_1_rounded, AppColors.violet);
    if (m.contains('replied')) return (Icons.chat_bubble_rounded, AppColors.info);
    if (m.contains('reopened')) return (Icons.replay_rounded, AppColors.orange);
    return (Icons.swap_horiz_rounded, AppColors.teal);
  }

  @override
  Widget build(BuildContext context) {
    final unread = !notification.isRead;
    final (icon, color) = _look;
    return AppCard(
      onTap: onTap,
      color: unread ? Colors.white : Colors.white.withValues(alpha: 0.6),
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          IconTile(icon: icon, color: color, size: 46),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(notification.message,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.ink,
                      fontWeight: unread ? FontWeight.w600 : FontWeight.w400,
                    )),
                const SizedBox(height: 2),
                Text(formatRelative(notification.createdAt), style: const TextStyle(fontSize: 12, color: AppColors.muted)),
              ],
            ),
          ),
          if (unread)
            Semantics(
              label: 'Unread',
              child: Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(shape: BoxShape.circle, gradient: AppColors.brand),
              ),
            ),
        ],
      ),
    );
  }
}
