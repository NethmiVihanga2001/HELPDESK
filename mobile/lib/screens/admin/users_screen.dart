import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/user.dart';
import '../../services/api_exception.dart';
import '../../services/auth_service.dart';
import '../../services/helpdesk_api.dart';
import '../../theme.dart';
import '../../utils/validators.dart';
import '../../widgets/auth_layout.dart';
import '../../widgets/state_views.dart';
import '../../widgets/ui.dart';

/// USR-1: Admin adds, edits and deactivates users and assigns roles.
/// Users are never deleted (BR-6).
class UsersScreen extends StatefulWidget {
  const UsersScreen({super.key});

  @override
  State<UsersScreen> createState() => _UsersScreenState();
}

class _UsersScreenState extends State<UsersScreen> {
  final _search = TextEditingController();
  List<AppUser>? _users;
  String? _error;
  UserRole? _role;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final users = await context.read<HelpdeskApi>().getUsers();
      if (!mounted) return;
      setState(() {
        _users = users;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _edit([AppUser? user]) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _UserForm(user: user),
    );
    if (saved == true) {
      _load();
      if (mounted) showSnack(context, user == null ? 'User added' : 'User updated');
    }
  }

  Future<void> _toggleActive(AppUser user, bool active) async {
    if (!active &&
        !await confirmAction(context,
            title: 'Deactivate ${user.name}?',
            message: 'They will no longer be able to sign in. Their tickets and history are kept.',
            confirmLabel: 'Deactivate',
            destructive: true)) {
      return;
    }
    if (!mounted) return;
    try {
      await context.read<HelpdeskApi>().updateUser(user.id, active: active);
      _load();
    } on ApiException catch (e) {
      if (mounted) showSnack(context, e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final meId = context.select<AuthService, String?>((a) => a.user?.id);
    final q = _search.text.trim().toLowerCase();
    final shown = _users
        ?.where((u) => _role == null || u.role == _role)
        .where((u) => q.isEmpty || u.name.toLowerCase().contains(q) || u.email.contains(q))
        .toList();

    return Scaffold(
      floatingActionButton: GradientFab(icon: Icons.person_add_alt_1_rounded, label: 'Add user', onPressed: () => _edit()),
      body: Column(
        children: [
          GradientHeader(
            child: Column(
              children: [
                HeaderBar(showBack: true, title: 'Users and roles', subtitle: '${_users?.length ?? 0} accounts'),
                const SizedBox(height: 12),
                SearchField(controller: _search, hint: 'Search by name or email', onChanged: (_) => setState(() {}), onClear: () => setState(() {})),
              ],
            ),
          ),
          SizedBox(
            height: 58,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
              children: [
                for (final r in <UserRole?>[null, ...UserRole.values])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(r == null ? 'Everyone' : '${r.label}s'),
                      selected: _role == r,
                      onSelected: (_) => setState(() => _role = r),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: shown == null
                ? (_error != null ? ErrorView(message: _error!, onRetry: _load) : const SkeletonList(itemHeight: 80))
                : RefreshIndicator(
                    onRefresh: _load,
                    child: shown.isEmpty
                        ? const EmptyView(icon: Icons.person_search_rounded, title: 'No users found')
                        : ListView.separated(
                            physics: const AlwaysScrollableScrollPhysics(),
                            padding: const EdgeInsets.fromLTRB(20, 10, 20, 100),
                            itemCount: shown.length,
                            separatorBuilder: (_, _) => const SizedBox(height: 10),
                            itemBuilder: (context, i) {
                              final u = shown[i];
                              return FadeSlideIn(
                                index: i,
                                child: AppCard(
                                  onTap: () => _edit(u),
                                  padding: const EdgeInsets.all(14),
                                  child: Opacity(
                                    opacity: u.active ? 1 : 0.55,
                                    child: Row(
                                      children: [
                                        UserAvatar(name: u.name, initials: u.initials, size: 46),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(u.id == meId ? '${u.name} (you)' : u.name,
                                                  style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.ink)),
                                              Text(u.email, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
                                              const SizedBox(height: 6),
                                              Wrap(spacing: 6, children: [
                                                _RolePill(role: u.role),
                                                if (!u.active) const Pill(label: 'Deactivated', color: AppColors.muted),
                                              ]),
                                            ],
                                          ),
                                        ),
                                        Switch(
                                          value: u.active,
                                          onChanged: u.id == meId ? null : (v) => _toggleActive(u, v),
                                        ),
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

class _RolePill extends StatelessWidget {
  const _RolePill({required this.role});

  final UserRole role;

  @override
  Widget build(BuildContext context) => switch (role) {
        UserRole.customer => const Pill(label: 'Customer', color: AppColors.info, icon: Icons.person_rounded),
        UserRole.agent => const Pill(label: 'Agent', color: AppColors.violet, icon: Icons.support_agent_rounded),
        UserRole.admin => const Pill(label: 'Admin', color: AppColors.pink, icon: Icons.shield_rounded),
      };
}

class _UserForm extends StatefulWidget {
  const _UserForm({this.user});

  final AppUser? user;

  @override
  State<_UserForm> createState() => _UserFormState();
}

class _UserFormState extends State<_UserForm> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.user?.name);
  late final _email = TextEditingController(text: widget.user?.email);
  final _password = TextEditingController();
  late UserRole _role = widget.user?.role ?? UserRole.customer;
  bool _saving = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};

  bool get _isNew => widget.user == null;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final api = context.read<HelpdeskApi>();
    try {
      if (_isNew) {
        await api.createUser(name: _name.text, email: _email.text, password: _password.text, role: _role);
      } else {
        await api.updateUser(widget.user!.id, name: _name.text, role: _role);
      }
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
          _fieldErrors = e.fieldErrors;
          _error = e.fieldErrors.isEmpty ? e.message : null;
        });
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
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(_isNew ? 'Add user' : 'Edit user', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 18),
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_rounded)),
                forceErrorText: _fieldErrors['name'],
                validator: Validators.name,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _email,
                enabled: _isNew,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.alternate_email_rounded)),
                forceErrorText: _fieldErrors['email'],
                validator: Validators.email,
              ),
              if (_isNew) ...[
                const SizedBox(height: 12),
                PasswordField(
                  controller: _password,
                  label: 'Temporary password',
                  helperText: 'At least 8 characters. Ask them to reset it.',
                  forceErrorText: _fieldErrors['password'],
                  validator: Validators.newPassword,
                ),
              ],
              const SizedBox(height: 16),
              Text('Role', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              SegmentedButton<UserRole>(
                segments: [for (final r in UserRole.values) ButtonSegment(value: r, label: Text(r.label))],
                selected: {_role},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() => _role = s.first),
              ),
              const SizedBox(height: 20),
              if (_error != null) ...[MessageBanner(_error!, kind: BannerKind.error), const SizedBox(height: 12)],
              GradientButton(label: _isNew ? 'Add user' : 'Save changes', loading: _saving, onPressed: _save),
            ],
          ),
        ),
      ),
    );
  }
}
