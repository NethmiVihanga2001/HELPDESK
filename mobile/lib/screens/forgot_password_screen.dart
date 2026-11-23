import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../utils/validators.dart';
import '../widgets/auth_layout.dart';
import '../widgets/ui.dart';

/// AUTH-3, step 1: request a password reset link (sent to the test inbox).
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key, this.initialEmail = ''});

  final String initialEmail;

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  late final _email = TextEditingController(text: widget.initialEmail.trim());
  bool _submitting = false;
  bool _sent = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await context.read<AuthService>().requestPasswordReset(_email.text);
      if (mounted) setState(() => _sent = true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      showBack: true,
      title: _sent ? 'Check your email' : 'Forgot password?',
      subtitle: _sent
          ? 'If an account exists for ${_email.text.trim()}, a reset link and code are on their way.'
          : "Enter the email you sign in with and we'll send you a reset link.",
      child: _sent ? _buildSent() : _buildForm(),
    );
  }

  Widget _buildForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _email,
            keyboardType: TextInputType.emailAddress,
            autocorrect: false,
            textInputAction: TextInputAction.done,
            onFieldSubmitted: (_) => _submit(),
            decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.alternate_email_rounded)),
            validator: Validators.email,
          ),
          const SizedBox(height: 20),
          if (_error != null) ...[MessageBanner(_error!, kind: BannerKind.error), const SizedBox(height: 14)],
          GradientButton(label: 'Send reset link', icon: Icons.send_rounded, loading: _submitting, onPressed: _submit),
        ],
      ),
    );
  }

  Widget _buildSent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Same message whether or not the account exists, so the screen
        // cannot be used to find out which emails are registered.
        const MessageBanner('The link works once and expires. You can also enter the code from the email here.',
            kind: BannerKind.success),
        const SizedBox(height: 18),
        GradientButton(
          label: 'Enter reset code',
          icon: Icons.password_rounded,
          onPressed: () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const ResetPasswordScreen())),
        ),
        const SizedBox(height: 10),
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Back to sign in')),
      ],
    );
  }
}

/// AUTH-3, step 2: set a new password with the one-time code.
class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _code = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _submitting = false;
  bool _done = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await context.read<AuthService>().resetPassword(token: _code.text, newPassword: _password.text);
      if (mounted) setState(() => _done = true);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.fieldErrors['password'] ?? e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      showBack: true,
      title: _done ? 'Password changed' : 'Set a new password',
      subtitle: _done ? 'You can now sign in with your new password.' : 'Enter the code from the email and choose a new password.',
      child: _done
          ? GradientButton(
              label: 'Back to sign in',
              icon: Icons.login_rounded,
              onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            )
          : Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _code,
                    textInputAction: TextInputAction.next,
                    decoration: const InputDecoration(labelText: 'Reset code', prefixIcon: Icon(Icons.pin_rounded)),
                    validator: (v) => (v?.trim().isEmpty ?? true) ? 'Enter the code from the email' : null,
                  ),
                  const SizedBox(height: 14),
                  PasswordField(
                    controller: _password,
                    label: 'New password',
                    helperText: 'At least 8 characters',
                    validator: Validators.newPassword,
                  ),
                  const SizedBox(height: 14),
                  PasswordField(
                    controller: _confirm,
                    label: 'Confirm new password',
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    validator: (v) => v != _password.text ? 'Passwords do not match' : null,
                  ),
                  const SizedBox(height: 20),
                  if (_error != null) ...[MessageBanner(_error!, kind: BannerKind.error), const SizedBox(height: 14)],
                  GradientButton(label: 'Change password', icon: Icons.check_rounded, loading: _submitting, onPressed: _submit),
                ],
              ),
            ),
    );
  }
}
