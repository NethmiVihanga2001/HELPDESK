import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/lookups.dart';
import '../../models/user.dart';
import '../../services/api_exception.dart';
import '../../services/helpdesk_api.dart';
import '../../theme.dart';
import '../../widgets/state_views.dart';
import '../../widgets/ui.dart';

/// USR-3 / USR-4: Admin creates, edits and deactivates ticket categories and
/// sets each category's default agent.
class CategoriesScreen extends StatefulWidget {
  const CategoriesScreen({super.key});

  @override
  State<CategoriesScreen> createState() => _CategoriesScreenState();
}

class _CategoriesScreenState extends State<CategoriesScreen> {
  List<TicketCategory>? _categories;
  List<AppUser> _agents = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final api = context.read<HelpdeskApi>();
    try {
      final results = await Future.wait<Object>([api.getCategories(includeInactive: true), api.getUsers(role: UserRole.agent)]);
      if (!mounted) return;
      setState(() {
        _categories = results[0] as List<TicketCategory>;
        _agents = (results[1] as List<AppUser>).where((a) => a.active).toList();
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _edit([TicketCategory? category]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CategoryForm(category: category, agents: _agents),
    );
    if (saved == true) _load();
  }

  Future<void> _toggle(TicketCategory c, bool active) async {
    try {
      await context.read<HelpdeskApi>().saveCategory(id: c.id, name: c.name, defaultAgentId: c.defaultAgent?.id, active: active);
      _load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final list = _categories;
    return Scaffold(
      floatingActionButton: GradientFab(icon: Icons.add_rounded, label: 'Add category', onPressed: () => _edit()),
      body: Column(
        children: [
          const GradientHeader(
            child: HeaderBar(showBack: true, title: 'Categories', subtitle: 'Where new tickets go'),
          ),
          Expanded(
            child: list == null
                ? (_error != null ? ErrorView(message: _error!, onRetry: _load) : const SkeletonList(itemHeight: 84))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(20, 20, 20, 100),
                      itemCount: list.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, i) {
                        final c = list[i];
                        return FadeSlideIn(
                          index: i,
                          child: AppCard(
                            onTap: () => _edit(c),
                            padding: const EdgeInsets.all(14),
                            child: Opacity(
                              opacity: c.active ? 1 : 0.55,
                              child: Row(
                                children: [
                                  IconTile(icon: AppTheme.categoryIcon(c.name), color: AppTheme.categoryColor(c.name), size: 46),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(c.name, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15, color: AppColors.ink)),
                                        Text(
                                          c.defaultAgent == null ? 'No default agent' : 'Default agent: ${c.defaultAgent!.name}',
                                          style: Theme.of(context).textTheme.bodySmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                  Switch(value: c.active, onChanged: (v) => _toggle(c, v)),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CategoryForm extends StatefulWidget {
  const _CategoryForm({this.category, required this.agents});

  final TicketCategory? category;
  final List<AppUser> agents;

  @override
  State<_CategoryForm> createState() => _CategoryFormState();
}

class _CategoryFormState extends State<_CategoryForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.category?.name);
  late String? _agentId = widget.category?.defaultAgent?.id;
  late bool _active = widget.category?.active ?? true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<HelpdeskApi>().saveCategory(id: widget.category?.id, name: _name.text, defaultAgentId: _agentId, active: _active);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.fieldErrors['name'] ?? e.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final agentIds = widget.agents.map((a) => a.id).toSet();
    return Padding(
      padding: EdgeInsets.fromLTRB(22, 0, 22, 22 + MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.category == null ? 'Add category' : 'Edit category', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 18),
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Name', prefixIcon: Icon(Icons.label_rounded)),
              validator: (v) => (v?.trim().isEmpty ?? true) ? 'Enter a name' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String?>(
              initialValue: agentIds.contains(_agentId) ? _agentId : null,
              decoration: const InputDecoration(labelText: 'Default agent', prefixIcon: Icon(Icons.support_agent_rounded)),
              items: [
                const DropdownMenuItem<String?>(value: null, child: Text('None (goes to the queue)')),
                for (final a in widget.agents) DropdownMenuItem<String?>(value: a.id, child: Text(a.name)),
              ],
              onChanged: (v) => setState(() => _agentId = v),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              subtitle: const Text('Inactive categories are hidden from the new-ticket form.'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            const SizedBox(height: 10),
            if (_error != null) ...[MessageBanner(_error!, kind: BannerKind.error), const SizedBox(height: 12)],
            GradientButton(label: 'Save category', loading: _saving, onPressed: _save),
          ],
        ),
      ),
    );
  }
}
