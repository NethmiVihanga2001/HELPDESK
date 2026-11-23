import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../config.dart';
import '../models/insights.dart';
import '../models/lookups.dart';
import '../models/ticket.dart';
import '../models/user.dart';
import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../services/helpdesk_api.dart';
import '../theme.dart';
import '../utils/formatters.dart';
import '../widgets/state_views.dart';
import '../widgets/ticket_card.dart';
import '../widgets/ui.dart';
import 'ticket_detail_screen.dart';

/// DSH-6 ticket report by date range, status, category, priority or agent,
/// and DSH-7 export to Excel or PDF. Admin: all tickets; Agent: own.
class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late DateTimeRange _range;
  TicketStatus? _status;
  String? _categoryId;
  String? _priorityId;
  String? _agentId;
  List<TicketCategory> _categories = const [];
  List<TicketPriority> _priorities = const [];
  List<AppUser> _agents = const [];
  TicketReport? _report;
  String? _error;
  bool _loading = true;
  String? _exporting;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _range = DateTimeRange(start: now.subtract(const Duration(days: 30)), end: now);
    _loadLookups();
    _load();
  }

  bool get _isAdmin => context.read<AuthService>().user?.role == UserRole.admin;

  ReportQuery get _query => ReportQuery(
        from: _range.start,
        to: _range.end,
        status: _status,
        categoryId: _categoryId,
        priorityId: _priorityId,
        agentId: _agentId,
      );

  Future<void> _loadLookups() async {
    final api = context.read<HelpdeskApi>();
    try {
      final results = await Future.wait<Object>([
        api.getCategories(),
        api.getPriorities(),
        if (_isAdmin) api.getUsers(role: UserRole.agent),
      ]);
      if (!mounted) return;
      setState(() {
        _categories = results[0] as List<TicketCategory>;
        _priorities = results[1] as List<TicketPriority>;
        if (results.length > 2) _agents = results[2] as List<AppUser>;
      });
    } on ApiException {
      // Filters fall back to "Any"; the report itself still loads.
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final report = await context.read<HelpdeskApi>().getReport(_query);
      if (mounted) setState(() => _report = report);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _pickRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(DateTime.now().year - 3),
      lastDate: DateTime.now(),
      initialDateRange: _range,
    );
    if (picked != null) {
      setState(() => _range = picked);
      _load();
    }
  }

  /// Downloads the export and opens the share sheet so the file can be
  /// saved to Files or Drive, or sent by email.
  Future<void> _export(String format) async {
    setState(() => _exporting = format);
    try {
      final bytes = await context.read<HelpdeskApi>().exportReport(_query, format);
      final ext = AppConfig.useMock ? 'csv' : format;
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/helpdesk-report-${DateTime.now().millisecondsSinceEpoch}.$ext');
      await file.writeAsBytes(bytes);
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path)], subject: 'HelpDesk Pro ticket report'));
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
    } on Exception {
      if (mounted) showSnack(context, 'Could not save the report on this phone.');
    } finally {
      if (mounted) setState(() => _exporting = null);
    }
  }

  Future<String?> _pick(String title, List<({String? id, String label})> options, String? current) {
    return showModalBottomSheet<String?>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(title, style: Theme.of(context).textTheme.titleLarge),
            ),
            for (final o in options)
              ListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 24),
                title: Text(o.label),
                trailing: o.id == current ? const Icon(Icons.check_circle_rounded, color: AppColors.primary) : null,
                onTap: () => Navigator.pop(context, o.id ?? ''),
              ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Future<void> _filter(String title, List<({String? id, String label})> options, String? current, void Function(String?) apply) async {
    final picked = await _pick(title, [(id: null, label: 'Any'), ...options], current);
    if (picked == null) return;
    setState(() => apply(picked.isEmpty ? null : picked));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final report = _report;
    String nameOf<T>(List<T> list, String? id, String Function(T) name, bool Function(T) match) =>
        id == null ? 'Any' : list.where(match).map(name).firstOrNull ?? 'Any';

    return Scaffold(
      body: Column(
        children: [
          GradientHeader(
            child: HeaderBar(
              showBack: true,
              title: 'Reports',
              subtitle: _isAdmin ? 'All tickets' : 'Tickets assigned to you',
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
                children: [
                  AppCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Filters', style: Theme.of(context).textTheme.titleSmall),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ActionChip(
                              avatar: const Icon(Icons.date_range_rounded, size: 18, color: AppColors.primary),
                              label: Text('${formatDate(_range.start)} – ${formatDate(_range.end)}'),
                              onPressed: _pickRange,
                            ),
                            ActionChip(
                              avatar: const Icon(Icons.circle, size: 12, color: AppColors.violet),
                              label: Text('Status: ${_status?.label ?? 'Any'}'),
                              onPressed: () => _filter('Status', [
                                for (final s in TicketStatus.values) (id: s.apiValue, label: s.label),
                              ], _status?.apiValue, (v) => _status = v == null ? null : TicketStatus.parse(v)),
                            ),
                            ActionChip(
                              avatar: const Icon(Icons.label_rounded, size: 16, color: AppColors.teal),
                              label: Text('Category: ${nameOf(_categories, _categoryId, (c) => c.name, (c) => c.id == _categoryId)}'),
                              onPressed: () => _filter('Category', [for (final c in _categories) (id: c.id, label: c.name)],
                                  _categoryId, (v) => _categoryId = v),
                            ),
                            ActionChip(
                              avatar: const Icon(Icons.flag_rounded, size: 16, color: AppColors.orange),
                              label: Text('Priority: ${nameOf(_priorities, _priorityId, (p) => p.name, (p) => p.id == _priorityId)}'),
                              onPressed: () => _filter('Priority', [for (final p in _priorities) (id: p.id, label: p.name)],
                                  _priorityId, (v) => _priorityId = v),
                            ),
                            if (_isAdmin)
                              ActionChip(
                                avatar: const Icon(Icons.support_agent_rounded, size: 16, color: AppColors.pink),
                                label: Text('Agent: ${nameOf(_agents, _agentId, (a) => a.name, (a) => a.id == _agentId)}'),
                                onPressed: () => _filter('Agent', [for (final a in _agents) (id: a.id, label: a.name)],
                                    _agentId, (v) => _agentId = v),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_loading && report == null)
                    const SizedBox(height: 300, child: SkeletonList(count: 3, padding: EdgeInsets.zero))
                  else if (_error != null && report == null)
                    SizedBox(height: 320, child: ErrorView(message: _error!, onRetry: _load))
                  else if (report != null) ...[
                    _Summary(report: report),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _ExportButton(
                            label: 'Excel',
                            icon: Icons.table_view_rounded,
                            color: AppColors.success,
                            busy: _exporting == 'xlsx',
                            onTap: _exporting == null ? () => _export('xlsx') : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _ExportButton(
                            label: 'PDF',
                            icon: Icons.picture_as_pdf_rounded,
                            color: AppColors.danger,
                            busy: _exporting == 'pdf',
                            onTap: _exporting == null ? () => _export('pdf') : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 22),
                    SectionHeader('${report.rows.length} tickets'),
                    const SizedBox(height: 6),
                    if (report.rows.isEmpty)
                      const SizedBox(
                        height: 260,
                        child: EmptyView(icon: Icons.query_stats_rounded, title: 'No tickets match these filters'),
                      )
                    else
                      for (var i = 0; i < report.rows.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: FadeSlideIn(
                            index: i,
                            child: TicketCard(
                              ticket: report.rows[i],
                              showCustomer: true,
                              onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
                                builder: (_) => TicketDetailScreen(ticketId: report.rows[i].id, ticketNumber: report.rows[i].number),
                              )),
                            ),
                          ),
                        ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.report});

  final TicketReport report;

  @override
  Widget build(BuildContext context) {
    final items = [
      (label: 'Tickets', value: '${report.rows.length}', icon: Icons.confirmation_number_rounded, color: AppColors.primary),
      (label: 'Resolved', value: '${report.count(TicketStatus.resolved) + report.count(TicketStatus.closed)}', icon: Icons.task_alt_rounded, color: AppColors.success),
      (label: 'Overdue', value: '${report.overdue}', icon: Icons.alarm_rounded, color: AppColors.danger),
      (label: 'Avg. resolution', value: formatHours(report.averageResolutionHours), icon: Icons.timer_rounded, color: AppColors.info),
    ];
    return LayoutBuilder(
      builder: (context, c) {
        final w = (c.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final i in items)
              SizedBox(
                width: w,
                child: AppCard(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    children: [
                      IconTile(icon: i.icon, color: i.color, size: 40),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(i.value,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.ink)),
                            Text(i.label,
                                maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: AppColors.muted)),
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
    );
  }
}

class _ExportButton extends StatelessWidget {
  const _ExportButton({required this.label, required this.icon, required this.color, required this.busy, required this.onTap});

  final String label;
  final IconData icon;
  final Color color;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          busy
              ? SizedBox.square(dimension: 20, child: CircularProgressIndicator(strokeWidth: 2, color: color))
              : Icon(icon, color: color),
          const SizedBox(width: 8),
          Text('Export $label', style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink)),
        ],
      ),
    );
  }
}
