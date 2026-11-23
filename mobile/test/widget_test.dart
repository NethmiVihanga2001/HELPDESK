import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:helpdesk_pro_mobile/app.dart';
import 'package:helpdesk_pro_mobile/screens/ticket_list_screen.dart';
import 'package:helpdesk_pro_mobile/services/auth_service.dart';
import 'package:helpdesk_pro_mobile/services/helpdesk_api.dart';
import 'package:helpdesk_pro_mobile/services/mock_helpdesk_api.dart';
import 'package:helpdesk_pro_mobile/services/notifications_controller.dart';
import 'package:helpdesk_pro_mobile/services/ticket_events.dart';
import 'package:helpdesk_pro_mobile/services/token_storage.dart';
import 'package:provider/provider.dart';

void main() {
  late TokenStorage tokens;

  Future<void> pumpApp(WidgetTester tester) async {
    // A typical phone screen (360 x 780 logical pixels) so layout overflows show up.
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.reset);

    tokens = TokenStorage(MemoryKeyValueStore());
    final api = MockHelpdeskApi(tokens, latency: Duration.zero);
    final auth = AuthService(api: api, tokens: tokens);
    await auth.restoreSession();
    await tester.pumpWidget(MultiProvider(
      providers: [
        Provider<HelpdeskApi>.value(value: api),
        ChangeNotifierProvider<AuthService>.value(value: auth),
        ChangeNotifierProvider(create: (_) => NotificationsController(api)),
        ChangeNotifierProvider(create: (_) => TicketEvents()),
      ],
      child: const HelpdeskApp(),
    ));
    await tester.pumpAndSettle();
  }

  Future<void> logIn(WidgetTester tester, String email, [String password = MockHelpdeskApi.demoPassword]) async {
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), email);
    await tester.enterText(find.widgetWithText(TextFormField, 'Password'), password);
    await tester.tap(find.text('Sign in'));
    await tester.pumpAndSettle();
  }

  Future<void> openTab(WidgetTester tester, String label) async {
    await tester.tap(find.descendant(of: find.byType(BottomAppBar), matching: find.text(label)));
    await tester.pumpAndSettle();
  }

  Finder inTicketList(String text) => find.descendant(of: find.byType(TicketListScreen), matching: find.text(text));

  /// Removes the tree so the notification polling timer is cancelled.
  Future<void> tearDownApp(WidgetTester tester) => tester.pumpWidget(const SizedBox());

  testWidgets('login form validates empty fields', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Sign in'));
    await tester.pump();
    expect(find.text('Enter your email'), findsOneWidget);
    expect(find.text('Enter your password'), findsOneWidget);
  });

  testWidgets('wrong password shows a safe error', (tester) async {
    await pumpApp(tester);
    await logIn(tester, 'customer1@demo.test', 'wrong-password');
    expect(find.text('Invalid email or password'), findsOneWidget);
  });

  testWidgets('customer sees the dashboard and only own tickets, then logs out', (tester) async {
    await pumpApp(tester);
    await logIn(tester, 'customer1@demo.test');

    expect(find.text('Casey'), findsOneWidget); // greeting
    expect(find.text('Your tickets by status'), findsOneWidget);

    await openTab(tester, 'Tickets');
    expect(inTicketList('My tickets'), findsOneWidget);
    expect(inTicketList('TKT-0001'), findsOneWidget);
    expect(inTicketList('TKT-0004'), findsNothing); // another customer's ticket

    await openTab(tester, 'Profile');
    await tester.ensureVisible(find.text('Log out'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log out'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Log out'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(await tokens.readAccessToken(), isNull);
  });

  testWidgets('agent sees internal notes and staff actions on an assigned ticket', (tester) async {
    await pumpApp(tester);
    await logIn(tester, 'agent1@demo.test');
    await openTab(tester, 'Tickets');
    await tester.enterText(find.descendant(of: find.byType(TicketListScreen), matching: find.byType(TextField)), 'portal');
    await tester.pump(const Duration(milliseconds: 500)); // search debounce
    await tester.pumpAndSettle();
    expect(inTicketList('TKT-0008'), findsNothing);
    await tester.tap(inTicketList('TKT-0001'));
    await tester.pumpAndSettle();

    expect(find.text('Change status'), findsOneWidget);
    expect(find.text('Reassign'), findsOneWidget);
    expect(find.text('Internal note'), findsOneWidget); // composer switch

    final note = find.text('Internal note · hidden from customer');
    final conversation = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down);
    await tester.scrollUntilVisible(note, 150, scrollable: conversation.first);
    expect(note, findsOneWidget);
    await tearDownApp(tester);
  });

  testWidgets('agent takes a ticket from the queue', (tester) async {
    await pumpApp(tester);
    await logIn(tester, 'agent1@demo.test');
    await openTab(tester, 'Tickets');
    await tester.tap(inTicketList('Queue'));
    await tester.pumpAndSettle();

    expect(inTicketList('TKT-0005'), findsOneWidget);
    expect(inTicketList('TKT-0001'), findsNothing);
    await tester.tap(inTicketList('TKT-0005'));
    await tester.pumpAndSettle();

    expect(find.text('Take this ticket to reply to the customer.'), findsOneWidget);
    await tester.tap(find.text('Take ticket'));
    await tester.pumpAndSettle();
    expect(find.text('TKT-0005 is now yours'), findsOneWidget);
    expect(find.text('Change status'), findsOneWidget);
    await tearDownApp(tester);
  });
}
