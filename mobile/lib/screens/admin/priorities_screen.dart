import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../models/lookups.dart';
import '../../services/api_exception.dart';
import '../../services/helpdesk_api.dart';
import '../../theme.dart';
import '../../widgets/state_views.dart';
import '../../widgets/ui.dart';

/// USR-5 / SLA-2: Admin sets each priority's target response and resolution
/// hours. The due time of a ticket is its creation time plus the resolution
/// hours (BR-4).
class PrioritiesScreen extends StatefulWidget {
  const PrioritiesScreen({super.key});

  @override
  State<PrioritiesScreen> createState() => _PrioritiesScreenState();
}

class _PrioritiesScreenState extends State<PrioritiesScreen> {
  List<TicketPriority>? _priorities;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final list = await context.read<HelpdeskApi>().getPriorities();
      if (!mounted) return;
      setState(() {
        _priorities = list;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _edit(TicketPriority p) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PriorityForm(priority: p),
    );
    if (saved == true) {
      _load();
      if (mounted) showSnack(context, '${p.name} targets updated');
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _priorities;
    return Scaffold(
      body: Column(
        children: [
          const GradientHeader(
            child: HeaderBar(showBack: true, title: 'Priorities and SLA', subtitle: 'Target times for each priority'),
          ),
          Expanded(
            child: list == null
                ? (_error != null ? ErrorView(message: _error!, onRetry: _load) : const SkeletonList(itemHeight: 110))
                : ListView(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
                    children: [
                      const MessageBanner('Due time = creation time + resolution hours. '
                          'A ticket past its due time and not yet resolved is overdue.'),
                      const SizedBox(height: 16),
                      for (var i = 0; i < list.length; i++)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: FadeSlideIn(index: i, child: _PriorityCard(priority: list[i], onTap: () => _edit(list[i]))),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _PriorityCard extends StatelessWidget {
  const _PriorityCard({required this.priority, required this.onTap});

  final TicketPriority priority;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.priority(priority.level);
    Widget target(String label, int? hours, IconData icon) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.07), borderRadius: BorderRadius.circular(14)),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(hours == null ? '–' : '$hours h',
                          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16, color: AppColors.ink)),
                      Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              IconTile(icon: Icons.flag_rounded, color: color, size: 42),
              const SizedBox(width: 12),
              Expanded(child: Text(priority.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16, color: AppColors.ink))),
              const Icon(Icons.edit_rounded, size: 18, color: AppColors.muted),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              target('First response', priority.responseHours, Icons.reply_rounded),
              const SizedBox(width: 10),
              target('Resolution', priority.resolutionHours, Icons.task_alt_rounded),
            ],
          ),
        ],
      ),
    );
  }
}

class _PriorityForm extends StatefulWidget {
  const _PriorityForm({required this.priority});

  final TicketPriority priority;

  @override
  State<_PriorityForm> createState() => _PriorityFormState();
}

class _PriorityFormState extends State<_PriorityForm> {
  final _formKey = GlobalKey<FormState>();
  late final _response = TextEditingController(text: '${widget.priority.responseHours ?? ''}');
  late final _resolution = TextEditingController(text: '${widget.priority.resolutionHours ?? ''}');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _response.dispose();
    _resolution.dispose();
    super.dispose();
  }

  String? _hours(String? v) {
    final n = int.tryParse(v ?? '');
    if (n == null || n < 1) return 'Enter whole hours (1 or more)';
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final response = int.parse(_response.text);
    final resolution = int.parse(_resolution.text);
    if (resolution < response) {
      setState(() => _error = 'Resolution time must be at least the response time.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<HelpdeskApi>().updatePriority(widget.priority.id, responseHours: response, resolutionHours: resolution);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.fieldErrors.values.firstOrNull ?? e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(22, 0, 22, 22 + MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${widget.priority.name} priority', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 18),
            TextFormField(
              controller: _response,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'First response (hours)', prefixIcon: Icon(Icons.reply_rounded)),
              validator: _hours,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _resolution,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(labelText: 'Resolution (hours)', prefixIcon: Icon(Icons.task_alt_rounded)),
              validator: _hours,
            ),
            const SizedBox(height: 20),
            if (_error != null) ...[MessageBanner(_error!, kind: BannerKind.error), const SizedBox(height: 12)],
            GradientButton(label: 'Save targets', loading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
