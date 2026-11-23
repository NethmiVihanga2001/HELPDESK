import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user.dart';
import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../services/notifications_controller.dart';
import '../theme.dart';
import '../utils/validators.dart';
import '../widgets/ui.dart';
import 'admin/categories_screen.dart';
import 'admin/priorities_screen.dart';
import 'admin/users_screen.dart';
import 'notifications_screen.dart';
import 'reports_screen.dart';

/// Profile tab: own profile (USR-2), password reset (AUTH-3), log out, and
/// the role's tools: reports for staff (DSH-6), users, categories and
/// priorities for admins (USR-1, USR-3 to USR-5).
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  void _push(BuildContext context, Widget screen) =>
      Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));

  Future<void> _editName(BuildContext context, String current) async {
    final saved = await showDialog<bool>(context: context, builder: (_) => _EditNameDialog(initialName: current));
    if (saved == true && context.mounted) showSnack(context, 'Profile updated');
  }

  Future<void> _resetPassword(BuildContext context, String email) async {
    if (!await confirmAction(context,
        title: 'Reset password?', message: 'We will email a reset link to $email.', confirmLabel: 'Send link')) {
      return;
    }
    if (!context.mounted) return;
    try {
      await context.read<AuthService>().requestPasswordReset(email);
      if (context.mounted) showSnack(context, 'Reset link sent to $email');
    } on ApiException catch (e) {
      if (context.mounted) showSnack(context, e.message);
    }
  }

  Future<void> _logout(BuildContext context) async {
    if (await confirmAction(context,
            title: 'Log out?', message: 'You will need to sign in again.', confirmLabel: 'Log out', destructive: true) &&
        context.mounted) {
      await context.read<AuthService>().logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final user = auth.user;
    if (user == null) return const SizedBox.shrink();
    final unread = context.select<NotificationsController, int>((c) => c.unreadCount);

    return RefreshIndicator(
      onRefresh: auth.refreshProfile,
      edgeOffset: 120,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 120),
        children: [
          GradientHeader(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 30),
            child: Column(
              children: [
                const HeaderBar(title: 'Profile', actions: [NotificationBell()]),
                const SizedBox(height: 8),
                UserAvatar(name: user.name, initials: user.initials, size: 88, ring: true),
                const SizedBox(height: 12),
                Text(user.name, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
                Text(user.email, style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 13.5)),
                const SizedBox(height: 10),
                Pill(
                  label: user.role.label,
                  color: AppColors.primary,
                  solid: true,
                  icon: switch (user.role) {
                    UserRole.customer => Icons.person_rounded,
                    UserRole.agent => Icons.support_agent_rounded,
                    UserRole.admin => Icons.shield_rounded,
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _GroupTitle('Account'),
                _MenuGroup(items: [
                  _MenuItem(icon: Icons.badge_rounded, color: AppColors.primary, title: 'Name', subtitle: user.name,
                      trailing: const Icon(Icons.edit_rounded, size: 18, color: AppColors.muted),
                      onTap: () => _editName(context, user.name)),
                  _MenuItem(icon: Icons.alternate_email_rounded, color: AppColors.info, title: 'Email', subtitle: user.email),
                  _MenuItem(icon: Icons.lock_reset_rounded, color: AppColors.teal, title: 'Reset password',
                      subtitle: 'Email me a reset link', onTap: () => _resetPassword(context, user.email)),
                  _MenuItem(icon: Icons.notifications_rounded, color: AppColors.orange, title: 'Notifications',
                      subtitle: unread == 0 ? 'All caught up' : '$unread unread',
                      onTap: () => _push(context, const NotificationsScreen())),
                ]),
                if (user.role.isStaff) ...[
                  const _GroupTitle('Workspace'),
                  _MenuGroup(items: [
                    _MenuItem(icon: Icons.bar_chart_rounded, color: AppColors.orange, title: 'Reports',
                        subtitle: user.role == UserRole.admin ? 'All tickets, with export' : 'Your tickets, with export',
                        onTap: () => _push(context, const ReportsScreen())),
                    if (user.role == UserRole.admin) ...[
                      _MenuItem(icon: Icons.group_rounded, color: AppColors.pink, title: 'Users and roles',
                          subtitle: 'Add, edit and deactivate users', onTap: () => _push(context, const UsersScreen())),
                      _MenuItem(icon: Icons.category_rounded, color: AppColors.violet, title: 'Categories',
                          subtitle: 'Ticket categories and default agents', onTap: () => _push(context, const CategoriesScreen())),
                      _MenuItem(icon: Icons.timer_rounded, color: AppColors.info, title: 'Priorities and SLA',
                          subtitle: 'Response and resolution targets', onTap: () => _push(context, const PrioritiesScreen())),
                    ],
                  ]),
                ],
                const SizedBox(height: 22),
                _MenuGroup(items: [
                  _MenuItem(icon: Icons.logout_rounded, color: AppColors.danger, title: 'Log out', onTap: () => _logout(context)),
                ]),
                const SizedBox(height: 22),
                Center(
                  child: Text('HelpDesk Pro · version 1.0.0', style: Theme.of(context).textTheme.bodySmall),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GroupTitle extends StatelessWidget {
  const _GroupTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
        child: Text(text.toUpperCase(),
            style: const TextStyle(fontSize: 12, letterSpacing: 1.1, fontWeight: FontWeight.w600, color: AppColors.muted)),
      );
}

class _MenuGroup extends StatelessWidget {
  const _MenuGroup({required this.items});

  final List<_MenuItem> items;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: AppCard(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            for (var i = 0; i < items.length; i++) ...[
              items[i],
              if (i < items.length - 1) const Divider(indent: 70, endIndent: 16),
            ],
          ],
        ),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  const _MenuItem({required this.icon, required this.color, required this.title, this.subtitle, this.onTap, this.trailing});

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      leading: IconTile(icon: icon, color: color, size: 40),
      title: Text(title, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5, color: color == AppColors.danger ? color : AppColors.ink)),
      subtitle: subtitle == null ? null : Text(subtitle!, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodySmall),
      trailing: trailing ?? (onTap == null ? null : const Icon(Icons.chevron_right_rounded, color: AppColors.muted)),
    );
  }
}

class _EditNameDialog extends StatefulWidget {
  const _EditNameDialog({required this.initialName});

  final String initialName;

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  final _formKey = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.initialName);
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
      await context.read<AuthService>().updateProfile(name: _name.text);
      if (mounted) Navigator.pop(context, true);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = e.fieldErrors['name'] ?? e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit name'),
      content: Form(
        key: _formKey,
        child: TextFormField(
          controller: _name,
          autofocus: true,
          enabled: !_saving,
          textCapitalization: TextCapitalization.words,
          decoration: InputDecoration(labelText: 'Full name', errorText: _error),
          validator: Validators.name,
          onFieldSubmitted: (_) => _save(),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.pop(context, false), child: const Text('Cancel')),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Save'),
        ),
      ],
    );
  }
}
