import 'package:flutter/foundation.dart';

/// Tells open screens that tickets changed (created, replied, assigned,
/// status changed...), so the dashboard and lists can refresh quietly.
class TicketEvents extends ChangeNotifier {
  void changed() => notifyListeners();
}
