import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/user.dart';
import 'api_exception.dart';
import 'helpdesk_api.dart';
import 'token_storage.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Who is signed in. The app root shows the login screen or the home screen
/// based on [status].
class AuthService extends ChangeNotifier {
  AuthService({required HelpdeskApi api, required TokenStorage tokens})
      : _api = api,
        _tokens = tokens;

  final HelpdeskApi _api;
  final TokenStorage _tokens;

  AuthStatus _status = AuthStatus.unknown;
  AppUser? _user;
  String? _notice;
  bool _loggingOut = false;

  AuthStatus get status => _status;
  AppUser? get user => _user;
  bool get isStaff => _user?.role.isStaff ?? false;

  /// A message for the login screen, such as "session expired".
  String? get notice => _notice;

  /// Keeps the user signed in after an app restart (feature 10.1).
  ///
  /// The cached user is shown immediately; the profile is then refreshed in
  /// the background, which also refreshes an expired access token.
  Future<void> restoreSession() async {
    final token = await _tokens.readAccessToken();
    final cachedUser = await _tokens.readUser();
    if (token == null || cachedUser == null) {
      _setStatus(AuthStatus.unauthenticated);
      return;
    }
    _user = cachedUser;
    _setStatus(AuthStatus.authenticated);
    unawaited(refreshProfile());
  }

  Future<void> refreshProfile() async {
    try {
      final fresh = await _api.getProfile();
      if (_status != AuthStatus.authenticated) return;
      _user = fresh;
      await _tokens.saveUser(fresh);
      notifyListeners();
    } on ApiException catch (e) {
      // Offline errors are ignored: the user stays signed in and each screen
      // offers its own retry.
      if (e.isUnauthorized) handleSessionExpired();
    }
  }

  /// Throws [ApiException] with a message safe to show, e.g.
  /// "Invalid email or password".
  Future<void> login(String email, String password) async {
    _notice = null;
    final session = await _api.login(email.trim().toLowerCase(), password);
    await _tokens.saveTokens(
      accessToken: session.accessToken,
      refreshToken: session.refreshToken,
    );
    await _tokens.saveUser(session.user);
    _user = session.user;
    _setStatus(AuthStatus.authenticated);
  }

  /// Creates a Customer account and signs in with it.
  Future<void> register({
    required String name,
    required String email,
    required String password,
  }) async {
    final normalizedEmail = email.trim().toLowerCase();
    await _api.register(name: name.trim(), email: normalizedEmail, password: password);
    await login(normalizedEmail, password);
  }

  Future<void> requestPasswordReset(String email) =>
      _api.requestPasswordReset(email.trim().toLowerCase());

  /// Sets a new password with the one-time code from the reset email (AUTH-3).
  Future<void> resetPassword({required String token, required String newPassword}) =>
      _api.resetPassword(token: token.trim(), newPassword: newPassword);

  Future<void> updateProfile({required String name}) async {
    final updated = await _api.updateProfile(name: name.trim());
    _user = updated;
    await _tokens.saveUser(updated);
    notifyListeners();
  }

  Future<void> logout() async {
    _loggingOut = true;
    try {
      // Revoke the refresh token on the server. Sign out locally even if
      // this fails (for example when offline).
      await _api.logout(await _tokens.readRefreshToken());
    } on ApiException {
      // Ignored on purpose.
    } finally {
      _loggingOut = false;
    }
    await _signOutLocally();
  }

  /// Called when the refresh token is expired or revoked.
  void handleSessionExpired() {
    if (_status != AuthStatus.authenticated || _loggingOut) return;
    _notice = 'Your session has expired. Please log in again.';
    unawaited(_signOutLocally());
  }

  Future<void> _signOutLocally() async {
    _user = null;
    _setStatus(AuthStatus.unauthenticated);
    await _tokens.clear();
  }

  void _setStatus(AuthStatus status) {
    _status = status;
    notifyListeners();
  }
}
