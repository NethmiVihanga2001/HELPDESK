import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../utils/validators.dart';
import '../widgets/auth_layout.dart';
import '../widgets/ui.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';

/// AUTH-1: sign in with email and password.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _submitting = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
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
      // On success the app root swaps this screen for the home screen.
      await context.read<AuthService>().login(_email.text, _password.text);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final notice = context.select<AuthService, String?>((a) => a.notice);
    return AuthLayout(
      title: 'Welcome back',
      subtitle: 'Sign in to raise and follow your support tickets.',
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (notice != null && _error == null) ...[MessageBanner(notice), const SizedBox(height: 16)],
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const [AutofillHints.email],
                autocorrect: false,
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.alternate_email_rounded)),
                validator: Validators.email,
              ),
              const SizedBox(height: 14),
              PasswordField(
                controller: _password,
                label: 'Password',
                textInputAction: TextInputAction.done,
                autofillHints: const [AutofillHints.password],
                onSubmitted: (_) => _submit(),
                validator: Validators.loginPassword,
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: _submitting
                      ? null
                      : () => Navigator.of(context).push(MaterialPageRoute<void>(
                            builder: (_) => ForgotPasswordScreen(initialEmail: _email.text),
                          )),
                  child: const Text('Forgot password?'),
                ),
              ),
              if (_error != null) ...[
                MessageBanner(_error!, kind: BannerKind.error),
                const SizedBox(height: 14),
              ],
              GradientButton(label: 'Sign in', icon: Icons.login_rounded, loading: _submitting, onPressed: _submit),
              const SizedBox(height: 18),
              Row(
                children: [
                  const Expanded(child: Divider()),
                  Flexible(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text('New to HelpDesk Pro?',
                          textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodySmall),
                    ),
                  ),
                  const Expanded(child: Divider()),
                ],
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _submitting
                    ? null
                    : () => Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => const RegisterScreen())),
                icon: const Icon(Icons.person_add_alt_1_rounded),
                label: const Text('Create an account'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
