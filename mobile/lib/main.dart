import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'app.dart';
import 'config.dart';
import 'services/api_client.dart';
import 'services/auth_service.dart';
import 'services/helpdesk_api.dart';
import 'services/mock_helpdesk_api.dart';
import 'services/notifications_controller.dart';
import 'services/remote_helpdesk_api.dart';
import 'services/ticket_events.dart';
import 'services/token_storage.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  final tokens = TokenStorage(SecureKeyValueStore());
  late final AuthService auth;

  final HelpdeskApi api = AppConfig.useMock
      ? MockHelpdeskApi(tokens)
      : RemoteHelpdeskApi(ApiClient(
          baseUrl: AppConfig.apiBaseUrl,
          tokens: tokens,
          onSessionExpired: () => auth.handleSessionExpired(),
        ));

  auth = AuthService(api: api, tokens: tokens)..restoreSession();

  runApp(MultiProvider(
    providers: [
      Provider<HelpdeskApi>.value(value: api),
      ChangeNotifierProvider<AuthService>.value(value: auth),
      ChangeNotifierProvider(create: (_) => NotificationsController(api)),
      ChangeNotifierProvider(create: (_) => TicketEvents()),
    ],
    child: const HelpdeskApp(),
  ));
}
