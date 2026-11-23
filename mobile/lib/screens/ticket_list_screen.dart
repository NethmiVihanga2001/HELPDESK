import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../config.dart';
import '../models/lookups.dart';
import '../models/ticket.dart';
import '../models/user.dart';
import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../services/helpdesk_api.dart';
import '../services/ticket_events.dart';
import '../theme.dart';
import '../utils/formatters.dart';
import '../widgets/state_views.dart';
import '../widgets/ticket_card.dart';
import '../widgets/ui.dart';
import 'notifications_screen.dart';
import 'ticket_detail_screen.dart';

/// Tickets tab (TKT-5, TKT-6, ASG-2). Customers see their own tickets;
/// agents switch between "Assigned to me" and the unassigned queue; admins
/// between all tickets and unassigned ones. Search, status chips and a
/// filter sheet (priority, category, dates). Paginated with pull to refresh.
class TicketListScreen extends StatefulWidget {
  const TicketListScreen({super.key});

  @override
  State<TicketListScreen> createState() => _TicketListScreenState();
}

class _TicketListScreenState extends State<TicketListScreen> {
  final _scroll = ScrollController();
  final _search = TextEditingController();
  final _tickets = <Ticket>[];
  TicketQuery _query = const TicketQuery();
  Timer? _debounce;
  int _page = 0;
  bool _hasMore = true;
  bool _loading = true;
  bool _loadingMore = false;
  String? _error;
  String? _moreError;
  int _generation = 0;
  late final TicketEvents _events;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_onScroll);
    _events = context.read<TicketEvents>()..addListener(_reload);
    _reload();
  }

  @override
  void dispose() {
    _events.removeListener(_reload);
    _debounce?.cancel();
    _scroll.dispose();
    _search.dispose();
    super.dispose();
  }

  HelpdeskApi get _api => context.read<HelpdeskApi>();

  Future<void> _reload({bool clear = false}) async {
    final generation = ++_generation;
    setState(() {
      if (clear) _tickets.clear();
      _error = null;
      _moreError = null;
      _loading = _tickets.isEmpty;
      _loadingMore = false;
    });
    try {
      final result = await _api.getTickets(page: 1, pageSize: AppConfig.ticketPageSize, query: _query);
      if (!mounted || generation != _generation) return;
      setState(() {
        _tickets
          ..clear()
          ..addAll(result.items);
        _page = 1;
        _hasMore = result.hasMore;
      });
    } on ApiException catch (e) {
      if (!mounted || generation != _generation) return;
      if (_tickets.isEmpty) {
        setState(() => _error = e.message);
      } else {
        showSnack(context, e.message);
      }
    } finally {
      if (mounted && generation == _generation) setState(() => _loading = false);
    }
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || !_hasMore) return;
    final generation = _generation;
    final nextPage = _page + 1;
    setState(() {
      _loadingMore = true;
      _moreError = null;
    });
    try {
      final result = await _api.getTickets(page: nextPage, pageSize: AppConfig.ticketPageSize, query: _query);
      if (!mounted || generation != _generation) return;
      final known = _tickets.map((t) => t.id).toSet();
      setState(() {
        _tickets.addAll(result.items.where((t) => !known.contains(t.id)));
        _page = nextPage;
        _hasMore = result.hasMore;
      });
    } on ApiException catch (e) {
      if (!mounted || generation != _generation) return;
      setState(() => _moreError = e.message);
    } finally {
      if (mounted && generation == _generation) setState(() => _loadingMore = false);
    }
  }

  void _onScroll() {
    if (_moreError == null && _scroll.position.extentAfter < 400) _loadMore();
  }

  void _setQuery(TicketQuery query) {
    _query = query;
    _reload(clear: true);
  }

  void _onSearchChanged(String text) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), () => _setQuery(_query.copyWith(search: text)));
  }

  Future<void> _openFilters() async {
    final result = await showModalBottomSheet<TicketQuery>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _FilterSheet(initial: _query),
    );
    if (result != null) _setQuery(result);
  }

  void _openTicket(Ticket t) => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => TicketDetailScreen(ticketId: t.id, ticketNumber: t.number),
      ));

  @override
  Widget build(BuildContext context) {
    final role = context.select<AuthService, UserRole>((a) => a.user?.role ?? UserRole.customer);
    final (title, subtitle, tabs) = switch (role) {
      UserRole.customer => ('My tickets', 'Every request you have raised', null),
      UserRole.agent => ('Tickets', 'Your work and the open queue', ['Assigned to me', 'Queue']),
      UserRole.admin => ('All tickets', 'Everything across the helpdesk', ['All tickets', 'Unassigned']),
    };

    return Column(
      children: [
        GradientHeader(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
          child: Column(
            children: [
              HeaderBar(title: title, subtitle: subtitle, actions: const [NotificationBell()]),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: SearchField(
                      controller: _search,
                      hint: 'Search by title or number',
                      onChanged: _onSearchChanged,
                      onClear: () => _setQuery(_query.copyWith(search: '')),
                    ),
                  ),
                  const SizedBox(width: 10),
                  _FilterButton(count: _query.extraFilterCount, onTap: _openFilters),
                ],
              ),
              if (tabs != null) ...[
                const SizedBox(height: 14),
                PillTabs(
                  labels: tabs,
                  selected: _query.scope.index,
                  onGradient: true,
                  onChanged: (i) => _setQuery(_query.copyWith(scope: TicketScope.values[i])),
                ),
              ],
            ],
          ),
        ),
        SizedBox(
          height: 58,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            children: [
              for (final status in <TicketStatus?>[null, ...TicketStatus.values])
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    avatar: status == null
                        ? null
                        : Icon(Icons.circle, size: 10, color: AppTheme.status(status).color),
                    label: Text(status?.label ?? 'All'),
                    selected: status == _query.status,
                    onSelected: (_) => _setQuery(_query.copyWith(status: () => status)),
                  ),
                ),
            ],
          ),
        ),
        Expanded(child: _buildBody(role)),
      ],
    );
  }

  Widget _buildBody(UserRole role) {
    if (_loading && _tickets.isEmpty) return const SkeletonList();
    if (_error != null && _tickets.isEmpty) return ErrorView(message: _error!, onRetry: _reload);
    return RefreshIndicator(
      onRefresh: _reload,
      child: _tickets.isEmpty
          ? _buildEmpty(role)
          : ListView.separated(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
              itemCount: _tickets.length + 1,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                if (index == _tickets.length) return _buildFooter();
                final ticket = _tickets[index];
                return FadeSlideIn(
                  index: index,
                  child: TicketCard(ticket: ticket, showCustomer: role.isStaff, onTap: () => _openTicket(ticket)),
                );
              },
            ),
    );
  }

  Widget _buildEmpty(UserRole role) {
    final filtered = _query.status != null || _query.search.isNotEmpty || _query.extraFilterCount > 0;
    if (filtered) {
      return const EmptyView(
        icon: Icons.filter_alt_off_rounded,
        title: 'No matching tickets',
        message: 'Try another status, search or filter.',
        color: AppColors.violet,
      );
    }
    if (_query.scope == TicketScope.queue) {
      return const EmptyView(
        icon: Icons.inbox_rounded,
        title: 'The queue is empty',
        message: 'Every open ticket has an agent.',
        color: AppColors.success,
      );
    }
    return role.isStaff
        ? const EmptyView(
            icon: Icons.task_alt_rounded,
            title: 'Nothing assigned to you',
            message: 'Take a ticket from the queue, or wait for a new assignment.',
            color: AppColors.success,
          )
        : const EmptyView(
            icon: Icons.confirmation_number_rounded,
            title: 'No tickets yet',
            message: 'Tap + to ask for help. We will reply right here.',
          );
  }

  Widget _buildFooter() {
    if (_loadingMore) {
      return const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()));
    }
    if (_moreError != null) {
      return Center(
        child: TextButton.icon(
          onPressed: _loadMore,
          icon: const Icon(Icons.refresh_rounded),
          label: const Text('Could not load more. Try again'),
        ),
      );
    }
    return const SizedBox(height: 4);
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: SizedBox.square(
          dimension: 54,
          child: Tooltip(
            message: 'Filters',
            child: Badge(
              isLabelVisible: count > 0,
              label: Text('$count'),
              backgroundColor: AppColors.pink,
              child: const Icon(Icons.tune_rounded, color: AppColors.primary),
            ),
          ),
        ),
      ),
    );
  }
}

/// Priority, category and date filters (TKT-6).
class _FilterSheet extends StatefulWidget {
  const _FilterSheet({required this.initial});

  final TicketQuery initial;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late TicketQuery _q = widget.initial;
  List<TicketCategory> _categories = const [];
  List<TicketPriority> _priorities = const [];

  @override
  void initState() {
    super.initState();
    final api = context.read<HelpdeskApi>();
    Future.wait<Object>([api.getCategories(), api.getPriorities()]).then((r) {
      if (mounted) {
        setState(() {
          _categories = r[0] as List<TicketCategory>;
          _priorities = r[1] as List<TicketPriority>;
        });
      }
    }).catchError((Object _) {});
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
      initialDateRange: _q.from == null ? null : DateTimeRange(start: _q.from!, end: _q.to ?? now),
    );
    if (range != null) {
      setState(() => _q = _q.copyWith(from: () => range.start, to: () => range.end.add(const Duration(hours: 23, minutes: 59))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Filter tickets', style: theme.textTheme.titleLarge),
            const SizedBox(height: 18),
            Text('Priority', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final p in _priorities)
                  ChoiceChip(
                    avatar: Icon(Icons.flag_rounded, size: 16, color: AppTheme.priority(p.level)),
                    label: Text(p.name),
                    selected: _q.priorityId == p.id,
                    onSelected: (v) => setState(() => _q = _q.copyWith(priorityId: () => v ? p.id : null)),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Text('Category', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final c in _categories)
                  ChoiceChip(
                    avatar: Icon(AppTheme.categoryIcon(c.name), size: 16, color: AppTheme.categoryColor(c.name)),
                    label: Text(c.name),
                    selected: _q.categoryId == c.id,
                    onSelected: (v) => setState(() => _q = _q.copyWith(categoryId: () => v ? c.id : null)),
                  ),
              ],
            ),
            const SizedBox(height: 18),
            Text('Created', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: _pickDates,
              icon: const Icon(Icons.date_range_rounded),
              label: Text(_q.from == null ? 'Any date' : '${formatDate(_q.from)} – ${formatDate(_q.to)}'),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(
                      context,
                      _q.copyWith(priorityId: () => null, categoryId: () => null, from: () => null, to: () => null),
                    ),
                    child: const Text('Reset'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(child: GradientButton(label: 'Apply', height: 50, onPressed: () => Navigator.pop(context, _q))),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
