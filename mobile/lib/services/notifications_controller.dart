import 'dart:async';

import 'package:flutter/widgets.dart';

import '../config.dart';
import '../models/app_notification.dart';
import 'api_exception.dart';
import 'helpdesk_api.dart';

/// Notification list and unread badge (feature 10.6).
///
/// Shared by the bottom navigation badge and the notifications screen.
/// Refreshes every [AppConfig.notificationPollInterval] while the app is in
/// the foreground.
class NotificationsController extends ChangeNotifier {
  NotificationsController(this._api);

  final HelpdeskApi _api;

  List<AppNotification> _items = const [];
  bool _loading = false;
  bool _loaded = false;
  String? _error;
  Timer? _timer;

  /// Increased on [stop] so responses for a signed-out user are ignored.
  int _session = 0;

  List<AppNotification> get items => _items;
  bool get isLoading => _loading;
  bool get hasLoaded => _loaded;
  String? get error => _error;
  int get unreadCount => _items.where((n) => !n.isRead).length;

  /// Starts loading and polling. Called when the home screen opens.
  void start() {
    _timer?.cancel();
    _timer = Timer.periodic(AppConfig.notificationPollInterval, (_) {
      if (WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        refresh();
      }
    });
    refresh();
  }

  /// Stops polling and forgets the list. Called when the user signs out.
  /// Does not notify, because the listening widgets are being removed.
  void stop() {
    _timer?.cancel();
    _timer = null;
    _session++;
    _items = const [];
    _loaded = false;
    _loading = false;
    _error = null;
  }

  Future<void> refresh() async {
    if (_loading) return;
    final session = _session;
    _loading = true;
    notifyListeners();
    try {
      final items = await _api.getNotifications();
      if (session != _session) return;
      _items = items;
      _loaded = true;
      _error = null;
    } on ApiException catch (e) {
      if (session != _session) return;
      _error = e.message;
    } finally {
      if (session == _session) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  /// Marks one notification as read straight away and undoes it if the
  /// server call fails. Returns false on failure.
  Future<bool> markRead(AppNotification notification) async {
    if (notification.isRead) return true;
    final session = _session;
    _replace(notification.id, notification.copyWith(isRead: true));
    try {
      await _api.markNotificationRead(notification.id);
      return true;
    } on ApiException {
      if (session == _session) _replace(notification.id, notification);
      return false;
    }
  }

  /// Marks every unread notification as read. Returns false if any failed.
  Future<bool> markAllRead() async {
    final unread = _items.where((n) => !n.isRead).toList();
    final results = await Future.wait(unread.map(markRead));
    return results.every((ok) => ok);
  }

  void _replace(String id, AppNotification value) {
    _items = [for (final n in _items) n.id == id ? value : n];
    notifyListeners();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
