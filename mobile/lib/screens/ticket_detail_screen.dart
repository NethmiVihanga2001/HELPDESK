import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/insights.dart';
import '../models/ticket.dart';
import '../models/user.dart';
import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../services/helpdesk_api.dart';
import '../services/ticket_events.dart';
import '../theme.dart';
import '../utils/formatters.dart';
import '../widgets/attachment_tile.dart';
import '../widgets/photo_picker.dart';
import '../widgets/reply_bubble.dart';
import '../widgets/reply_composer.dart';
import '../widgets/state_views.dart';
import '../widgets/ui.dart';

/// One ticket: conversation (REP-1, REP-2), details with SLA and rating
/// (SLA-3, TKT-9) and the change history (TKT-10). The actions shown depend
/// on the role and the ticket (section 7 of the SRS): take from queue,
/// change status, assign or reassign, reopen, rate.
class TicketDetailScreen extends StatefulWidget {
  const TicketDetailScreen({super.key, required this.ticketId, this.ticketNumber});

  final String ticketId;

  /// Shown in the header while the ticket loads.
  final String? ticketNumber;

  @override
  State<TicketDetailScreen> createState() => _TicketDetailScreenState();
}

class _TicketDetailScreenState extends State<TicketDetailScreen> with SingleTickerProviderStateMixin {
  late final _tabs = TabController(length: 3, vsync: this)..addListener(_onTab);
  final _scroll = ScrollController();
  Ticket? _ticket;
  bool _loading = true;
  bool _busy = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _tabs.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _onTab() {
    if (!_tabs.indexIsChanging) setState(() {});
  }

  HelpdeskApi get _api => context.read<HelpdeskApi>();
  AppUser? get _me => context.read<AuthService>().user;

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final ticket = await _api.getTicket(widget.ticketId);
      if (!mounted) return;
      setState(() {
        _ticket = ticket.visibleTo(_me?.role ?? UserRole.customer);
        _error = null;
      });
    } on ApiException catch (e) {
      if (!mounted) return;
      if (_ticket == null) {
        setState(() => _error = e.message);
      } else {
        showSnack(context, e.message);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Runs a change, reloads the ticket and tells other screens.
  Future<bool> _run(Future<void> Function() action, {String? done}) async {
    setState(() => _busy = true);
    try {
      await action();
      await _load(silent: true);
      if (mounted) {
        context.read<TicketEvents>().changed();
        if (done != null) showSnack(context, done);
      }
      return true;
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
      return false;
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _sendReply(String message, bool isInternal) async {
    final ok = await _run(() => _api.addReply(widget.ticketId, message: message, isInternal: isInternal));
    if (ok) _scrollToBottom();
    return ok;
  }

  Future<void> _changeStatus(Ticket t) async {
    final status = await showModalBottomSheet<TicketStatus>(
      context: context,
      builder: (_) => _StatusSheet(current: t.status),
    );
    if (status == null || status == t.status || !mounted) return;
    if (status == TicketStatus.closed &&
        !await confirmAction(context,
            title: 'Close ${t.number}?',
            message: 'A closed ticket cannot be edited or replied to.',
            confirmLabel: 'Close ticket',
            destructive: true)) {
      return;
    }
    await _run(() => _api.changeStatus(t.id, status), done: 'Status changed to ${status.label}');
  }

  Future<void> _assign(Ticket t) async {
    final agent = await showModalBottomSheet<AppUser>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AssignSheet(currentAgentId: t.assignedAgent?.id),
    );
    if (agent == null || !mounted) return;
    await _run(() => _api.assignTicket(t.id, agent.id), done: 'Assigned to ${agent.name}');
  }

  Future<void> _take(Ticket t) async {
    final me = _me;
    if (me == null) return;
    await _run(() => _api.assignTicket(t.id, me.id), done: '${t.number} is now yours');
  }

  Future<void> _reopen(Ticket t) async {
    if (!await confirmAction(context,
        title: 'Reopen ${t.number}?',
        message: 'The support team will pick it up again.',
        confirmLabel: 'Reopen')) {
      return;
    }
    await _run(() => _api.reopenTicket(t.id), done: 'Ticket reopened');
  }

  Future<void> _rate(Ticket t) async {
    final result = await showModalBottomSheet<(int, String)>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _RatingSheet(),
    );
    if (result == null || !mounted) return;
    await _run(() => _api.rateTicket(t.id, rating: result.$1, comment: result.$2), done: 'Thanks for your feedback!');
  }

  Future<void> _addPhoto() async {
    final photo = await pickTicketPhoto(context);
    if (photo == null || !mounted) return;
    await _run(() => _api.uploadAttachment(widget.ticketId, filePath: photo.path, fileName: photo.name), done: 'Photo added');
  }

  Future<ReplyTemplate?> _pickTemplate() => showModalBottomSheet<ReplyTemplate>(
        context: context,
        isScrollControlled: true,
        builder: (_) => const _TemplateSheet(),
      );

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(_scroll.position.maxScrollExtent, duration: const Duration(milliseconds: 350), curve: Curves.easeOut);
    });
  }

  @override
  Widget build(BuildContext context) {
    final me = context.watch<AuthService>().user;
    final t = _ticket;
    if (t == null || me == null) {
      return Scaffold(
        body: Column(
          children: [
            GradientHeader(child: HeaderBar(showBack: true, title: widget.ticketNumber ?? 'Ticket')),
            Expanded(
              child: _loading
                  ? const SkeletonList(count: 4)
                  : ErrorView(message: _error ?? 'Could not load this ticket.', onRetry: _load),
            ),
          ],
        ),
      );
    }

    final role = me.role;
    final mine = t.assignedAgent?.id == me.id;
    final canWork = role == UserRole.admin || (role == UserRole.agent && mine);
    final open = !t.isClosed;
    final canReply = open && (role == UserRole.customer || canWork);

    final actions = <Widget>[
      if (role == UserRole.agent && t.isUnassigned && open)
        _ActionButton(icon: Icons.pan_tool_alt_rounded, label: 'Take ticket', primary: true, onTap: () => _take(t)),
      if (canWork && open) ...[
        _ActionButton(icon: Icons.swap_vert_rounded, label: 'Change status', onTap: () => _changeStatus(t)),
        _ActionButton(
          icon: Icons.person_add_alt_1_rounded,
          label: t.isUnassigned ? 'Assign' : 'Reassign',
          onTap: () => _assign(t),
        ),
      ],
      if (role == UserRole.customer && t.status == TicketStatus.resolved)
        _ActionButton(icon: Icons.replay_rounded, label: 'Reopen', onTap: () => _reopen(t)),
      if (role == UserRole.customer && t.status.isDone && t.rating == null)
        _ActionButton(icon: Icons.star_rounded, label: 'Rate support', primary: true, onTap: () => _rate(t)),
    ];

    return Scaffold(
      body: Column(
        children: [
          _Header(ticket: t, viewer: me),
          if (_busy) const LinearProgressIndicator(minHeight: 2),
          if (actions.isNotEmpty)
            SizedBox(
              height: 64,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
                itemCount: actions.length,
                separatorBuilder: (_, _) => const SizedBox(width: 10),
                itemBuilder: (_, i) => actions[i],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 4),
            child: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: AppColors.line.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(16)),
              child: TabBar(
                controller: _tabs,
                dividerColor: Colors.transparent,
                indicatorSize: TabBarIndicatorSize.tab,
                indicator: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: AppShadows.card),
                labelColor: AppColors.primary,
                unselectedLabelColor: AppColors.inkSoft,
                labelStyle: const TextStyle(fontFamily: 'Poppins', fontWeight: FontWeight.w600, fontSize: 13.5),
                tabs: [
                  Tab(height: 40, text: 'Chat (${t.replies.length})'),
                  const Tab(height: 40, text: 'Details'),
                  const Tab(height: 40, text: 'History'),
                ],
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () => _load(silent: true),
              // The lists sit one level below the horizontal tab pager.
              notificationPredicate: (n) => n.depth == 1,
              child: TabBarView(
                controller: _tabs,
                children: [
                  _Conversation(ticket: t, me: me, controller: _scroll),
                  _Details(ticket: t, viewer: me, onRate: role == UserRole.customer && t.status.isDone ? () => _rate(t) : null),
                  _History(ticket: t),
                ],
              ),
            ),
          ),
          if (_tabs.index == 0 && canReply)
            ReplyComposer(
              canPostInternal: role.isStaff,
              onSend: _sendReply,
              onAttach: _busy ? null : _addPhoto,
              loadTemplates: role.isStaff ? _pickTemplate : null,
            ),
          if (_tabs.index == 0 && !canReply && role == UserRole.agent && t.isUnassigned && open)
            const _FooterNote('Take this ticket to reply to the customer.'),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.ticket, required this.viewer});

  final Ticket ticket;
  final AppUser viewer;

  @override
  Widget build(BuildContext context) {
    final t = ticket;
    return GradientHeader(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HeaderBar(showBack: true, title: t.number, subtitle: t.categoryName),
          const SizedBox(height: 10),
          Text(t.title,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600, height: 1.3)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              StatusChip(t.status, solid: true),
              if (t.priorityName != null) PriorityChip(t.priorityName!, solid: true),
              if (t.isOverdue) const OverdueChip(solid: true),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _PersonPill(label: 'Customer', name: t.customer?.name, isMe: t.customer?.id == viewer.id)),
              const SizedBox(width: 10),
              Expanded(
                child: _PersonPill(label: 'Agent', name: t.assignedAgent?.name, isMe: t.assignedAgent?.id == viewer.id),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PersonPill extends StatelessWidget {
  const _PersonPill({required this.label, required this.name, required this.isMe});

  final String label;
  final String? name;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final shown = name == null ? 'Not assigned' : (isMe ? 'You' : name!);
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(16)),
      child: Row(
        children: [
          name == null
              ? Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), shape: BoxShape.circle),
                  child: const Icon(Icons.person_off_rounded, size: 16, color: Colors.white),
                )
              : UserAvatar(name: name!, initials: initialsOf(name!), size: 32),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.75), fontSize: 11)),
                Text(shown,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({required this.icon, required this.label, required this.onTap, this.primary = false});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final fg = primary ? Colors.white : AppColors.primary;
    return Container(
      decoration: BoxDecoration(
        gradient: primary ? AppColors.brand : null,
        color: primary ? null : Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: primary ? AppShadows.glow(AppColors.primary) : AppShadows.card,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 8),
                Text(label, style: TextStyle(color: fg, fontWeight: FontWeight.w600, fontSize: 13.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Conversation extends StatelessWidget {
  const _Conversation({required this.ticket, required this.me, required this.controller});

  final Ticket ticket;
  final AppUser me;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    final t = ticket;
    final isCustomer = me.role == UserRole.customer;
    return ListView(
      controller: controller,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
      children: [
        if (t.status == TicketStatus.waitingForCustomer && isCustomer) ...[
          const MessageBanner('The support team needs more information from you. Reply below to continue.',
              kind: BannerKind.warning),
          const SizedBox(height: 14),
        ],
        if (t.status == TicketStatus.resolved && isCustomer) ...[
          const MessageBanner('This ticket is resolved. Still having trouble? Reopen it, or rate the help you got.',
              kind: BannerKind.success),
          const SizedBox(height: 14),
        ],
        if (t.isClosed) ...[
          const MessageBanner('This ticket is closed and can no longer be changed.'),
          const SizedBox(height: 14),
        ],
        ReplyBubble(
          message: t.description.isEmpty ? 'No description.' : t.description,
          isMine: t.customer?.id == me.id,
          author: t.customer,
          time: t.createdAt,
          label: 'Original request',
        ),
        if (t.attachments.isNotEmpty) ...[
          AppCard(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Attachments (${t.attachments.length})', style: Theme.of(context).textTheme.titleSmall),
                for (final a in t.attachments) AttachmentTile(key: ValueKey(a.id), attachment: a),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        if (t.replies.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                const Icon(Icons.forum_rounded, color: AppColors.line, size: 48),
                const SizedBox(height: 8),
                Text(isCustomer ? 'No replies yet. We will answer here soon.' : 'No replies yet.',
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          )
        else
          for (final r in t.replies) ReplyBubble.fromReply(r, isMine: isReplyMine(r, me)),
      ],
    );
  }
}

class _Details extends StatelessWidget {
  const _Details({required this.ticket, required this.viewer, this.onRate});

  final Ticket ticket;
  final AppUser viewer;
  final VoidCallback? onRate;

  @override
  Widget build(BuildContext context) {
    final t = ticket;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 40),
      children: [
        AppCard(
          child: Column(
            children: [
              InfoRow(icon: AppTheme.categoryIcon(t.categoryName), label: 'Category', value: t.categoryName ?? '-'),
              InfoRow(icon: Icons.flag_rounded, label: 'Priority', value: t.priorityName ?? '-'),
              InfoRow(icon: AppTheme.status(t.status).icon, label: 'Status', value: t.status.label),
              InfoRow(icon: Icons.person_rounded, label: 'Customer', value: t.customer?.name ?? '-'),
              InfoRow(icon: Icons.support_agent_rounded, label: 'Assigned agent', value: t.assignedAgent?.name ?? 'Not assigned yet'),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AppCard(
          child: Column(
            children: [
              InfoRow(icon: Icons.event_rounded, label: 'Created', value: formatDateTime(t.createdAt)),
              InfoRow(icon: Icons.update_rounded, label: 'Last update', value: formatDateTime(t.updatedAt)),
              if (t.dueAt != null)
                InfoRow(
                  icon: Icons.alarm_rounded,
                  label: t.isOverdue ? 'Due (overdue)' : 'Due by',
                  value: formatDateTime(t.dueAt),
                  valueColor: t.isOverdue ? AppColors.danger : null,
                ),
              if (t.resolvedAt != null)
                InfoRow(icon: Icons.task_alt_rounded, label: 'Resolved', value: formatDateTime(t.resolvedAt)),
            ],
          ),
        ),
        if (t.status.isDone) ...[
          const SizedBox(height: 16),
          AppCard(
            child: t.rating == null
                ? Row(
                    children: [
                      const IconTile(icon: Icons.star_rounded, color: AppColors.warning),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(onRate == null ? 'Not rated yet.' : 'How did we do? Rate the support you got.',
                            style: Theme.of(context).textTheme.bodyMedium),
                      ),
                      if (onRate != null) TextButton(onPressed: onRate, child: const Text('Rate')),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Customer rating', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          for (var i = 1; i <= 5; i++)
                            Icon(i <= t.rating! ? Icons.star_rounded : Icons.star_outline_rounded,
                                color: AppColors.warning, size: 28),
                          const SizedBox(width: 8),
                          Text('${t.rating}/5', style: const TextStyle(fontWeight: FontWeight.w600)),
                        ],
                      ),
                      if (t.ratingComment != null) ...[
                        const SizedBox(height: 8),
                        Text('"${t.ratingComment}"', style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ],
                  ),
          ),
        ],
      ],
    );
  }
}

/// TKT-10: who changed status, priority or assignment, and when.
class _History extends StatelessWidget {
  const _History({required this.ticket});

  final Ticket ticket;

  @override
  Widget build(BuildContext context) {
    final entries = [
      (
        icon: Icons.add_circle_rounded,
        color: AppColors.info,
        title: 'Ticket created',
        by: ticket.customer?.name,
        at: ticket.createdAt,
      ),
      for (final h in ticket.history)
        (
          icon: h.isAssignment ? Icons.person_add_alt_1_rounded : (h.isStatus ? AppTheme.status(TicketStatus.parse(h.newValue)).icon : Icons.edit_rounded),
          color: h.isAssignment ? AppColors.violet : (h.isStatus ? AppTheme.status(TicketStatus.parse(h.newValue)).color : AppColors.orange),
          title: h.summary,
          by: h.changedBy?.name,
          at: h.changedAt,
        ),
    ];
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
      itemCount: entries.length,
      itemBuilder: (context, i) {
        final e = entries[i];
        final last = i == entries.length - 1;
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(color: e.color, shape: BoxShape.circle, boxShadow: AppShadows.glow(e.color)),
                    child: Icon(e.icon, color: Colors.white, size: 18),
                  ),
                  if (!last) Expanded(child: Container(width: 2, color: AppColors.line)),
                ],
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 22, top: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(e.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: AppColors.ink)),
                      const SizedBox(height: 2),
                      Text('${e.by ?? 'System'} · ${formatDateTime(e.at)}',
                          style: const TextStyle(fontSize: 12, color: AppColors.muted)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FooterNote extends StatelessWidget {
  const _FooterNote(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.white,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.info_rounded, color: AppColors.primary, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(text, style: Theme.of(context).textTheme.bodyMedium)),
            ],
          ),
        ),
      ),
    );
  }
}

/// The five statuses from the SRS. The backend decides which changes are
/// allowed and answers 400 for an invalid one.
class _StatusSheet extends StatelessWidget {
  const _StatusSheet({required this.current});

  final TicketStatus current;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Text('Change status', style: Theme.of(context).textTheme.titleLarge),
          ),
          for (final status in TicketStatus.values)
            ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
              leading: IconTile(icon: AppTheme.status(status).icon, color: AppTheme.status(status).color, size: 40),
              title: Text(status.label, style: const TextStyle(fontWeight: FontWeight.w500)),
              trailing: status == current ? const Icon(Icons.check_circle_rounded, color: AppColors.primary) : null,
              enabled: status != current,
              onTap: () => Navigator.pop(context, status),
            ),
          const SizedBox(height: 10),
        ],
      ),
    );
  }
}

/// ASG-1 / ASG-3: choose an active agent.
class _AssignSheet extends StatefulWidget {
  const _AssignSheet({this.currentAgentId});

  final String? currentAgentId;

  @override
  State<_AssignSheet> createState() => _AssignSheetState();
}

class _AssignSheetState extends State<_AssignSheet> {
  late Future<List<AppUser>> _agents;

  @override
  void initState() {
    super.initState();
    _agents = context.read<HelpdeskApi>().getUsers(role: UserRole.agent).then((all) => all.where((u) => u.active).toList());
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text('Assign to an agent', style: Theme.of(context).textTheme.titleLarge),
            ),
            Flexible(
              child: FutureBuilder<List<AppUser>>(
                future: _agents,
                builder: (context, snap) {
                  if (snap.hasError) {
                    final message = snap.error is ApiException ? (snap.error as ApiException).message : 'Could not load agents.';
                    return Padding(padding: const EdgeInsets.all(24), child: MessageBanner(message, kind: BannerKind.error));
                  }
                  if (!snap.hasData) {
                    return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
                  }
                  return ListView(
                    shrinkWrap: true,
                    children: [
                      for (final a in snap.data!)
                        ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 2),
                          leading: UserAvatar(name: a.name, initials: a.initials),
                          title: Text(a.name, style: const TextStyle(fontWeight: FontWeight.w500)),
                          subtitle: Text(a.email),
                          trailing: a.id == widget.currentAgentId
                              ? const Pill(label: 'Current', color: AppColors.primary)
                              : const Icon(Icons.chevron_right_rounded),
                          enabled: a.id != widget.currentAgentId,
                          onTap: () => Navigator.pop(context, a),
                        ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }
}

/// TKT-9: rate a resolved ticket from 1 to 5 with an optional comment.
class _RatingSheet extends StatefulWidget {
  const _RatingSheet();

  @override
  State<_RatingSheet> createState() => _RatingSheetState();
}

class _RatingSheetState extends State<_RatingSheet> {
  final _comment = TextEditingController();
  int _stars = 0;
  static const _words = ['', 'Poor', 'Fair', 'Good', 'Great', 'Excellent'];

  @override
  void dispose() {
    _comment.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('How was the support?', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 4),
          Text('Your rating helps the team improve.', style: Theme.of(context).textTheme.bodyMedium),
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  tooltip: '$i star${i == 1 ? '' : 's'}',
                  iconSize: 44,
                  onPressed: () => setState(() => _stars = i),
                  icon: AnimatedScale(
                    scale: i <= _stars ? 1.15 : 1,
                    duration: const Duration(milliseconds: 180),
                    child: Icon(i <= _stars ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: i <= _stars ? AppColors.warning : AppColors.line),
                  ),
                ),
            ],
          ),
          SizedBox(
            height: 24,
            child: Text(_words[_stars], style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.warning)),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _comment,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(hintText: 'Anything to add? (optional)'),
          ),
          const SizedBox(height: 18),
          GradientButton(
            label: 'Submit rating',
            icon: Icons.send_rounded,
            onPressed: _stars == 0 ? null : () => Navigator.pop(context, (_stars, _comment.text)),
          ),
        ],
      ),
    );
  }
}

/// REP-5: pick a saved reply, or save a new one.
class _TemplateSheet extends StatefulWidget {
  const _TemplateSheet();

  @override
  State<_TemplateSheet> createState() => _TemplateSheetState();
}

class _TemplateSheetState extends State<_TemplateSheet> {
  late Future<List<ReplyTemplate>> _templates;

  @override
  void initState() {
    super.initState();
    _templates = context.read<HelpdeskApi>().getReplyTemplates();
  }

  Future<void> _create() async {
    final title = TextEditingController();
    final body = TextEditingController();
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New template'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 12),
            TextField(controller: body, maxLines: 4, decoration: const InputDecoration(labelText: 'Reply text')),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Save')),
        ],
      ),
    );
    if (saved != true || !mounted) return;
    try {
      await context.read<HelpdeskApi>().createReplyTemplate(title: title.text, body: body.text);
      if (mounted) setState(() => _templates = context.read<HelpdeskApi>().getReplyTemplates());
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.fieldErrors.values.firstOrNull ?? e.message);
    } finally {
      title.dispose();
      body.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.7),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 12, 8),
              child: Row(
                children: [
                  Expanded(child: Text('Reply templates', style: Theme.of(context).textTheme.titleLarge)),
                  TextButton.icon(onPressed: _create, icon: const Icon(Icons.add_rounded), label: const Text('New')),
                ],
              ),
            ),
            Flexible(
              child: FutureBuilder<List<ReplyTemplate>>(
                future: _templates,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return const Padding(
                      padding: EdgeInsets.all(24),
                      child: MessageBanner('Could not load templates.', kind: BannerKind.error),
                    );
                  }
                  if (!snap.hasData) {
                    return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
                  }
                  return ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                    children: [
                      for (final t in snap.data!)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: AppCard(
                            onTap: () => Navigator.pop(context, t),
                            padding: const EdgeInsets.all(14),
                            child: Row(
                              children: [
                                const IconTile(icon: Icons.bolt_rounded, color: AppColors.violet, size: 40),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(t.title, style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink)),
                                      Text(t.body, maxLines: 2, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
