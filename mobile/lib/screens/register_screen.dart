import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/api_exception.dart';
import '../services/auth_service.dart';
import '../utils/validators.dart';
import '../widgets/auth_layout.dart';
import '../widgets/ui.dart';

/// AUTH-6: a new customer creates an account and is signed in straight away.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  bool _submitting = false;
  String? _error;
  Map<String, String> _fieldErrors = const {};

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _confirm.dispose();
    super.dispose();
  }

  void _clearFieldError(String field) {
    if (_fieldErrors.containsKey(field)) setState(() => _fieldErrors = Map.of(_fieldErrors)..remove(field));
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _submitting = true;
      _error = null;
    });
    try {
      await context.read<AuthService>().register(name: _name.text, email: _email.text, password: _password.text);
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _fieldErrors = e.fieldErrors;
          const formFields = {'name', 'email', 'password'};
          _error = e.fieldErrors.keys.any(formFields.contains) ? null : e.message;
        });
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthLayout(
      showBack: true,
      title: 'Create account',
      subtitle: 'Raise tickets and follow every reply from your phone.',
      child: AutofillGroup(
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _name,
                textInputAction: TextInputAction.next,
                textCapitalization: TextCapitalization.words,
                autofillHints: const [AutofillHints.name],
                decoration: const InputDecoration(labelText: 'Full name', prefixIcon: Icon(Icons.person_rounded)),
                forceErrorText: _fieldErrors['name'],
                onChanged: (_) => _clearFieldError('name'),
                validator: Validators.name,
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                autofillHints: const [AutofillHints.email],
                decoration: const InputDecoration(labelText: 'Email', prefixIcon: Icon(Icons.alternate_email_rounded)),
                forceErrorText: _fieldErrors['email'],
                onChanged: (_) => _clearFieldError('email'),
                validator: Validators.email,
              ),
              const SizedBox(height: 14),
              PasswordField(
                controller: _password,
                label: 'Password',
                helperText: 'At least 8 characters',
                autofillHints: const [AutofillHints.newPassword],
                forceErrorText: _fieldErrors['password'],
                onChanged: (_) => _clearFieldError('password'),
                validator: Validators.newPassword,
              ),
              const SizedBox(height: 14),
              PasswordField(
                controller: _confirm,
                label: 'Confirm password',
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                validator: (v) => v != _password.text ? 'Passwords do not match' : null,
              ),
              const SizedBox(height: 22),
              if (_error != null) ...[MessageBanner(_error!, kind: BannerKind.error), const SizedBox(height: 14)],
              GradientButton(label: 'Create account', icon: Icons.rocket_launch_rounded, loading: _submitting, onPressed: _submit),
            ],
          ),
        ),
      ),
    );
  }
}
