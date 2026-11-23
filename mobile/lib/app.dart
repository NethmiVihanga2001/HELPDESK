import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/home_shell.dart';
import 'screens/login_screen.dart';
import 'screens/splash_screen.dart';
import 'services/auth_service.dart';
import 'theme.dart';

class HelpdeskApp extends StatefulWidget {
  const HelpdeskApp({super.key});

  @override
  State<HelpdeskApp> createState() => _HelpdeskAppState();
}

class _HelpdeskAppState extends State<HelpdeskApp> {
  final _navigatorKey = GlobalKey<NavigatorState>();
  late final AuthService _auth;
  late AuthStatus _lastStatus;

  @override
  void initState() {
    super.initState();
    _auth = context.read<AuthService>();
    _lastStatus = _auth.status;
    _auth.addListener(_onAuthChanged);
  }

  @override
  void dispose() {
    _auth.removeListener(_onAuthChanged);
    super.dispose();
  }

  /// When the user signs in or out, drop any pushed screens (register,
  /// ticket details, dialogs) so the new root screen is visible.
  void _onAuthChanged() {
    if (_auth.status == _lastStatus) return;
    _lastStatus = _auth.status;
    _navigatorKey.currentState?.popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HelpDesk Pro',
      navigatorKey: _navigatorKey,
      theme: AppTheme.light(),
      debugShowCheckedModeBanner: false,
      home: Consumer<AuthService>(
        builder: (context, auth, _) => switch (auth.status) {
          AuthStatus.unknown => const SplashScreen(),
          AuthStatus.authenticated => const HomeShell(),
          AuthStatus.unauthenticated => const LoginScreen(),
        },
      ),
    );
  }
}
