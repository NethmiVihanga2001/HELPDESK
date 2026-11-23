import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme.dart';
import 'ui.dart';

/// Shared layout of the sign-in screens: full brand gradient, logo, and a
/// white floating card holding the form.
class AuthLayout extends StatelessWidget {
  const AuthLayout({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
    this.showBack = false,
  });

  final String title;
  final String subtitle;
  final Widget child;
  final bool showBack;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(statusBarColor: Colors.transparent),
      child: Scaffold(
        backgroundColor: AppColors.primaryDeep,
        body: Container(
          decoration: const BoxDecoration(gradient: AppColors.brand),
          child: Stack(
            children: [
              Positioned(top: -90, right: -70, child: _circle(260, 0.10)),
              Positioned(top: 220, left: -80, child: _circle(180, 0.07)),
              Positioned(bottom: -60, right: -40, child: _circle(200, 0.08)),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) => SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(minHeight: constraints.maxHeight),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 440),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              if (showBack)
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: HeaderIconButton(
                                      icon: Icons.arrow_back_rounded,
                                      tooltip: 'Back',
                                      onPressed: () => Navigator.of(context).maybePop(),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 20),
                              const FadeSlideIn(child: AppLogo(onGradient: true)),
                              const SizedBox(height: 14),
                              const Text('HelpDesk Pro',
                                  style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w700)),
                              Text('Support that moves as fast as you do',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 14)),
                              const SizedBox(height: 28),
                              FadeSlideIn(
                                index: 1,
                                child: Container(
                                  padding: const EdgeInsets.fromLTRB(22, 26, 22, 22),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(30),
                                    boxShadow: [
                                      BoxShadow(
                                          color: Colors.black.withValues(alpha: 0.18), blurRadius: 40, offset: const Offset(0, 20)),
                                    ],
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.stretch,
                                    children: [
                                      Text(title, style: Theme.of(context).textTheme.headlineSmall),
                                      const SizedBox(height: 4),
                                      Text(subtitle, style: Theme.of(context).textTheme.bodyMedium),
                                      const SizedBox(height: 22),
                                      child,
                                    ],
                                  ),
                                ),
                              ),
                              const SizedBox(height: 28),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _circle(double size, double alpha) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withValues(alpha: alpha)),
      );
}

/// Password field with a show/hide toggle.
class PasswordField extends StatefulWidget {
  const PasswordField({
    super.key,
    required this.controller,
    required this.label,
    this.validator,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
    this.forceErrorText,
    this.onChanged,
    this.helperText,
    this.autofillHints,
  });

  final TextEditingController controller;
  final String label;
  final FormFieldValidator<String>? validator;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;
  final String? forceErrorText;
  final ValueChanged<String>? onChanged;
  final String? helperText;
  final Iterable<String>? autofillHints;

  @override
  State<PasswordField> createState() => _PasswordFieldState();
}

class _PasswordFieldState extends State<PasswordField> {
  bool _obscure = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _obscure,
      textInputAction: widget.textInputAction,
      onFieldSubmitted: widget.onSubmitted,
      onChanged: widget.onChanged,
      autofillHints: widget.autofillHints,
      forceErrorText: widget.forceErrorText,
      validator: widget.validator,
      decoration: InputDecoration(
        labelText: widget.label,
        helperText: widget.helperText,
        prefixIcon: const Icon(Icons.lock_rounded),
        suffixIcon: IconButton(
          tooltip: _obscure ? 'Show password' : 'Hide password',
          icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
          onPressed: () => setState(() => _obscure = !_obscure),
        ),
      ),
    );
  }
}
