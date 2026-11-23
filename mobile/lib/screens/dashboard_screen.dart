import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/insights.dart';
import '../models/page_result.dart';
import '../models/ticket.dart';
import '../models/user.dart';
import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../services/helpdesk_api.dart';
import '../services/ticket_events.dart';
import '../theme.dart';
import '../widgets/charts.dart';
import '../widgets/state_views.dart';
import '../widgets/ticket_card.dart';
import '../widgets/ui.dart';
import 'admin/users_screen.dart';
import 'notifications_screen.dart';
import 'reports_screen.dart';
import 'ticket_detail_screen.dart';

/// Home tab: the dashboard (DSH-1 to DSH-5) for the signed-in role, quick
/// actions and recent tickets. Numbers come from the backend and refresh
/// whenever tickets change.
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.onOpenTab, required this.onNewTicket});

  final ValueChanged<int> onOpenTab;
  final VoidCallback onNewTicket;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  DashboardSummary? _summary;
  List<Ticket> _recent = const [];
  String? _error;
  late final TicketEvents _events;

  @override
  void initState() {
    super.initState();
    _events = context.read<TicketEvents>()..addListener(_load);
    _load();
  }

  @override
  void dispose() {
    _events.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final api = context.read<HelpdeskApi>();
    try {
      final results = await Future.wait<Object>([
        api.getDashboard(),
        api.getTickets(page: 1, pageSize: 4),
      ]);
      if (!mounted) return;
      setState(() {
        _summary = results[0] as DashboardSummary;
        _recent = (results[1] as PageResult<Ticket>).items;
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (_summary == null) {
        setState(() => _error = e.message);
      } else {
        showSnack(context, e.message);
      }
    }
  }

  void _openTicket(Ticket t) => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => TicketDetailScreen(ticketId: t.id, ticketNumber: t.number),
      ));

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().user;
    if (user == null) return const SizedBox.shrink();
    final summary = _summary;

    return RefreshIndicator(
      onRefresh: _load,
      edgeOffset: 120,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(child: _Header(user: user, summary: summary)),
          if (summary == null && _error != null)
            SliverFillRemaining(hasScrollBody: false, child: ErrorView(message: _error!, onRetry: _load))
          else if (summary == null)
            const SliverToBoxAdapter(child: SizedBox(height: 420, child: SkeletonList(count: 4)))
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
              sliver: SliverList.list(children: _content(user.role, summary)),
            ),
        ],
      ),
    );
  }

  List<Widget> _content(UserRole role, DashboardSummary s) {
    final stats = switch (role) {
      UserRole.customer => [
          (label: 'Open', value: s.count(TicketStatus.open), icon: Icons.adjust_rounded, color: AppColors.info),
          (label: 'In progress', value: s.count(TicketStatus.inProgress), icon: Icons.autorenew_rounded, color: AppColors.violet),
          (label: 'Waiting on you', value: s.count(TicketStatus.waitingForCustomer), icon: Icons.hourglass_top_rounded, color: AppColors.warning),
          (label: 'Resolved', value: s.count(TicketStatus.resolved), icon: Icons.check_circle_rounded, color: AppColors.success),
        ],
      UserRole.agent => [
          (label: 'New today', value: s.newToday, icon: Icons.today_rounded, color: AppColors.info),
          (label: 'In queue', value: s.unassigned, icon: Icons.inbox_rounded, color: AppColors.violet),
          (label: 'Waiting on customer', value: s.count(TicketStatus.waitingForCustomer), icon: Icons.hourglass_top_rounded, color: AppColors.warning),
          (label: 'Overdue', value: s.overdue, icon: Icons.alarm_rounded, color: AppColors.danger),
        ],
      UserRole.admin => [
          (label: 'New today', value: s.newToday, icon: Icons.today_rounded, color: AppColors.info),
          (label: 'Unassigned', value: s.unassigned, icon: Icons.inbox_rounded, color: AppColors.violet),
          (label: 'Overdue', value: s.overdue, icon: Icons.alarm_rounded, color: AppColors.danger),
          (label: 'Resolved', value: s.count(TicketStatus.resolved), icon: Icons.check_circle_rounded, color: AppColors.success),
        ],
    };
    final slices = [
      for (final status in TicketStatus.values)
        (label: status.label, value: s.count(status), color: AppTheme.status(status).color),
    ];

    return [
      LayoutBuilder(
        builder: (context, c) {
          final w = (c.maxWidth - 14) / 2;
          return Wrap(
            spacing: 14,
            runSpacing: 14,
            children: [
              for (var i = 0; i < stats.length; i++)
                SizedBox(
                  width: w,
                  child: FadeSlideIn(
                    index: i,
                    child: _StatTile(label: stats[i].label, value: stats[i].value, icon: stats[i].icon, color: stats[i].color),
                  ),
                ),
            ],
          );
        },
      ),
      const SizedBox(height: 18),
      if (role.isStaff) ...[
        FadeSlideIn(index: 3, child: _ResolutionCard(hours: s.averageResolutionHours)),
        const SizedBox(height: 18),
      ],
      FadeSlideIn(
        index: 4,
        child: AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(role == UserRole.customer ? 'Your tickets by status' : 'Tickets by status',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              Row(
                children: [
                  DonutChart(slices: slices, size: 140),
                  const SizedBox(width: 20),
                  Expanded(child: ChartLegend(slices: slices)),
                ],
              ),
            ],
          ),
        ),
      ),
      if (role == UserRole.admin && s.workload.isNotEmpty) ...[
        const SizedBox(height: 18),
        FadeSlideIn(
          index: 5,
          child: AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Agent workload', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                BarList(items: [for (final w in s.workload) (label: w.name, value: w.openTickets)]),
              ],
            ),
          ),
        ),
      ],
      const SizedBox(height: 22),
      const SectionHeader('Quick actions'),
      const SizedBox(height: 10),
      _QuickActions(role: role, onOpenTab: widget.onOpenTab, onNewTicket: widget.onNewTicket),
      const SizedBox(height: 22),
      SectionHeader(
        role == UserRole.customer ? 'Recent tickets' : 'Latest activity',
        actionLabel: 'See all',
        onAction: () => widget.onOpenTab(1),
      ),
      const SizedBox(height: 6),
      if (_recent.isEmpty)
        AppCard(
          child: Row(
            children: [
              const IconTile(icon: Icons.inbox_rounded, color: AppColors.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  role == UserRole.customer ? 'No tickets yet. Tap + to raise your first one.' : 'Nothing assigned to you right now.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        )
      else
        for (var i = 0; i < _recent.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FadeSlideIn(
              index: 6 + i,
              child: TicketCard(ticket: _recent[i], showCustomer: role.isStaff, onTap: () => _openTicket(_recent[i])),
            ),
          ),
    ];
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.user, required this.summary});

  final AppUser user;
  final DashboardSummary? summary;

  String get _greeting {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final s = summary;
    final (String label, String detail, IconData icon) = switch (user.role) {
      UserRole.customer => (
          'Active tickets',
          s == null ? ' ' : '${s.count(TicketStatus.waitingForCustomer)} waiting for your reply',
          Icons.confirmation_number_rounded,
        ),
      UserRole.agent => (
          'Your open workload',
          s == null ? ' ' : '${s.overdue} overdue · ${s.unassigned} in the queue',
          Icons.support_agent_rounded,
        ),
      UserRole.admin => (
          'Open tickets across the team',
          s == null ? ' ' : '${s.newToday} new today · ${s.unassigned} unassigned',
          Icons.insights_rounded,
        ),
    };
    return GradientHeader(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              UserAvatar(name: user.name, initials: user.initials, size: 48, ring: true),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('$_greeting,', style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13.5)),
                    Text(user.firstName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 21, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
              const NotificationBell(),
            ],
          ),
          const SizedBox(height: 22),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.22)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
                      const SizedBox(height: 2),
                      Text(s == null ? '–' : '${s.open}',
                          style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w700, height: 1.15)),
                      Text(detail, style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 12.5)),
                    ],
                  ),
                ),
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                  child: Icon(icon, color: Colors.white, size: 30),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.icon, required this.color});

  final String label;
  final int value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(icon: icon, color: color, size: 40),
          const SizedBox(height: 12),
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: value.toDouble()),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
            builder: (context, v, _) => Text('${v.round()}',
                style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: AppColors.ink, height: 1.1)),
          ),
          const SizedBox(height: 2),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12.5, color: AppColors.muted)),
        ],
      ),
    );
  }
}

/// DSH-5: average time from creation to Resolved.
class _ResolutionCard extends StatelessWidget {
  const _ResolutionCard({required this.hours});

  final double? hours;

  @override
  Widget build(BuildContext context) {
    final text = hours == null
        ? 'No resolved tickets yet'
        : hours! < 24
            ? '${hours!.toStringAsFixed(1)} hours'
            : '${(hours! / 24).toStringAsFixed(1)} days';
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xFF0EA5E9), Color(0xFF6366F1)]),
        borderRadius: BorderRadius.circular(22),
        boxShadow: AppShadows.glow(const Color(0xFF3B82F6)),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(16)),
            child: const Icon(Icons.timer_rounded, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Average resolution time', style: TextStyle(color: Colors.white.withValues(alpha: 0.85), fontSize: 13)),
                Text(text, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.role, required this.onOpenTab, required this.onNewTicket});

  final UserRole role;
  final ValueChanged<int> onOpenTab;
  final VoidCallback onNewTicket;

  @override
  Widget build(BuildContext context) {
    void push(Widget screen) => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
    final actions = <({String label, IconData icon, Color color, VoidCallback onTap})>[
      (label: 'New ticket', icon: Icons.add_circle_rounded, color: AppColors.primary, onTap: onNewTicket),
      (label: 'Help center', icon: Icons.menu_book_rounded, color: AppColors.teal, onTap: () => onOpenTab(2)),
      if (role.isStaff) (label: 'Reports', icon: Icons.bar_chart_rounded, color: AppColors.orange, onTap: () => push(const ReportsScreen())),
      if (role == UserRole.admin) (label: 'Users', icon: Icons.group_rounded, color: AppColors.pink, onTap: () => push(const UsersScreen())),
      if (role == UserRole.customer) (label: 'My tickets', icon: Icons.confirmation_number_rounded, color: AppColors.violet, onTap: () => onOpenTab(1)),
    ];
    return Row(
      children: [
        for (final a in actions)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: AppCard(
                onTap: a.onTap,
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
                child: Column(
                  children: [
                    IconTile(icon: a.icon, color: a.color, size: 42),
                    const SizedBox(height: 8),
                    Text(a.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.ink)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}
