// Renders every screen of the app to PNG files, using the fictional mock
// data, the real Poppins font and Material icons. Used to make the UI
// handover document for the backend team.
//
//   flutter test tool/ui_screenshots_test.dart --dart-define=SHOT_DIR=<folder>
//
// Not part of the normal test run (it lives outside test/).
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
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

const _outDir = String.fromEnvironment('SHOT_DIR', defaultValue: 'build/ui_screenshots');
final _boundary = GlobalKey();

Future<void> _loadFonts() async {
  final manifest = json.decode(await rootBundle.loadString('FontManifest.json')) as List<dynamic>;
  for (final family in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(family['family'] as String);
    for (final font in (family['fonts'] as List<dynamic>).cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}

/// Phone status bar drawn over the screenshot.
class _StatusBar extends StatelessWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontFamily: 'Poppins', color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600);
    return const SizedBox(
      height: 28,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 22),
        child: Row(
          children: [
            Text('9:41', style: style),
            Spacer(),
            Icon(Icons.signal_cellular_alt_rounded, color: Colors.white, size: 15),
            SizedBox(width: 4),
            Icon(Icons.wifi_rounded, color: Colors.white, size: 15),
            SizedBox(width: 4),
            Icon(Icons.battery_full_rounded, color: Colors.white, size: 15),
          ],
        ),
      ),
    );
  }
}

Future<void> _pumpApp(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 2580); // 400 x 860 logical
  tester.view.devicePixelRatio = 3;
  tester.view.padding = const FakeViewPadding(top: 84);
  tester.view.viewPadding = const FakeViewPadding(top: 84);
  addTearDown(tester.view.reset);

  final tokens = TokenStorage(MemoryKeyValueStore());
  final api = MockHelpdeskApi(tokens, latency: Duration.zero);
  final auth = AuthService(api: api, tokens: tokens);
  await auth.restoreSession();
  await tester.pumpWidget(RepaintBoundary(
    key: _boundary,
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: Stack(
        children: [
          MultiProvider(
            providers: [
              Provider<HelpdeskApi>.value(value: api),
              ChangeNotifierProvider<AuthService>.value(value: auth),
              ChangeNotifierProvider(create: (_) => NotificationsController(api)),
              ChangeNotifierProvider(create: (_) => TicketEvents()),
            ],
            child: const HelpdeskApp(),
          ),
          const Positioned(top: 0, left: 0, right: 0, child: _StatusBar()),
        ],
      ),
    ),
  ));
  await tester.pumpAndSettle();
}

Future<void> _shot(WidgetTester tester, String name) async {
  await tester.pumpAndSettle();
  final boundary = _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  final image = await tester.runAsync(() => boundary.toImage(pixelRatio: 2));
  final data = await tester.runAsync(() => image!.toByteData(format: ui.ImageByteFormat.png));
  final file = File('$_outDir/$name.png')..createSync(recursive: true);
  file.writeAsBytesSync(data!.buffer.asUint8List());
}

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder.first);
  await tester.pumpAndSettle();
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

Future<void> _back(WidgetTester tester) => _tap(tester, find.byTooltip('Back').last);

/// Dismisses a bottom sheet or dialog by tapping the dimmed area.
Future<void> _dismiss(WidgetTester tester) async {
  await tester.tapAt(const Offset(200, 60));
  await tester.pumpAndSettle();
}

Future<void> _login(WidgetTester tester, String email) async {
  await tester.enterText(find.widgetWithText(TextFormField, 'Email'), email);
  await tester.enterText(find.widgetWithText(TextFormField, 'Password'), MockHelpdeskApi.demoPassword);
  await _tap(tester, find.text('Sign in'));
}

Future<void> _tab(WidgetTester tester, String label) =>
    _tap(tester, find.descendant(of: find.byType(BottomAppBar), matching: find.text(label)));

Finder _inList(String text) => find.descendant(of: find.byType(TicketListScreen), matching: find.text(text));

Future<void> _search(WidgetTester tester, String text) async {
  await tester.enterText(find.descendant(of: find.byType(TicketListScreen), matching: find.byType(TextField)), text);
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pumpAndSettle();
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('sign-in screens', (tester) async {
    await _pumpApp(tester);
    await _shot(tester, '01_login');
    await _tap(tester, find.text('Create an account'));
    await _shot(tester, '02_register');
    await _back(tester);
    await tester.enterText(find.widgetWithText(TextFormField, 'Email'), 'customer1@demo.test');
    await _tap(tester, find.text('Forgot password?'));
    await _shot(tester, '03_forgot_password');
    await _tap(tester, find.text('Send reset link'));
    await _shot(tester, '04_reset_link_sent');
    await _tap(tester, find.text('Enter reset code'));
    await _shot(tester, '05_set_new_password');
  });

  testWidgets('customer screens', (tester) async {
    await _pumpApp(tester);
    await _login(tester, 'customer1@demo.test');
    await _shot(tester, '10_customer_home');
    await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -700));
    await _shot(tester, '11_customer_home_more');

    await _tab(tester, 'Tickets');
    await _shot(tester, '12_customer_tickets');

    await _tap(tester, _inList('TKT-0002'));
    await _shot(tester, '13_customer_ticket_waiting');
    await _back(tester);

    await _tap(tester, _inList('TKT-0003'));
    await _shot(tester, '14_customer_ticket_resolved');
    await _tap(tester, find.text('Details'));
    await _shot(tester, '15_customer_ticket_details');
    await _tap(tester, find.text('History'));
    await _shot(tester, '16_customer_ticket_history');
    await _tap(tester, find.text('Rate support'));
    await _tap(tester, find.byTooltip('4 stars'));
    await tester.enterText(find.byType(TextField).last, 'Quick and friendly help.');
    await _shot(tester, '17_customer_rate_ticket');
    await _dismiss(tester);
    await _back(tester);

    await _tap(tester, find.byTooltip('New ticket'));
    await tester.enterText(find.widgetWithText(TextFormField, 'Title'), 'How do I reset my password?');
    await tester.pump(const Duration(milliseconds: 600));
    await tester.pumpAndSettle();
    await tester.enterText(find.widgetWithText(TextFormField, 'Description'), 'The reset email never arrives.');
    await _tap(tester, find.text('Account'));
    await tester.drag(find.byType(ListView).first, const Offset(0, 300));
    await _shot(tester, '18_customer_new_ticket');
    await tester.drag(find.byType(ListView).first, const Offset(0, -900));
    await _shot(tester, '19_customer_new_ticket_more');
    await _back(tester);

    await _tab(tester, 'Help');
    await _shot(tester, '20_customer_help_center');
    await _tap(tester, find.text('How to reset your password'));
    await _shot(tester, '21_customer_article');
    await _back(tester);

    await _tab(tester, 'Tickets');
    await _tap(tester, find.byTooltip('Notifications'));
    await _shot(tester, '22_customer_notifications');
    await _back(tester);

    await _tab(tester, 'Profile');
    await _shot(tester, '23_customer_profile');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('agent screens', (tester) async {
    await _pumpApp(tester);
    await _login(tester, 'agent1@demo.test');
    await _shot(tester, '30_agent_home');

    await _tab(tester, 'Tickets');
    await _shot(tester, '31_agent_assigned');
    await _tap(tester, find.byTooltip('Filters'));
    await _tap(tester, find.text('High'));
    await _shot(tester, '32_agent_filters');
    await _dismiss(tester);

    await _tap(tester, _inList('Queue'));
    await _shot(tester, '33_agent_queue');
    await _tap(tester, _inList('TKT-0005'));
    await _shot(tester, '34_agent_take_ticket');
    await _back(tester);
    await _tap(tester, _inList('Assigned to me'));

    await _search(tester, 'portal');
    await _tap(tester, _inList('TKT-0001'));
    final conversation = find.byWidgetPredicate((w) => w is Scrollable && w.axisDirection == AxisDirection.down);
    await tester.drag(conversation.first, const Offset(0, -600));
    await _shot(tester, '35_agent_ticket_conversation');
    await _tap(tester, find.text('Internal note'));
    await tester.enterText(find.byType(TextField).last, 'Identity verified by phone.');
    await _shot(tester, '36_agent_internal_note');
    await _tap(tester, find.byTooltip('Reply templates'));
    await _shot(tester, '37_agent_reply_templates');
    await _dismiss(tester);
    await _tap(tester, find.text('Change status'));
    await _shot(tester, '38_agent_change_status');
    await _dismiss(tester);
    await _tap(tester, find.text('Reassign'));
    await _shot(tester, '39_agent_reassign');
    await _dismiss(tester);
    await _tap(tester, find.text('History'));
    await _shot(tester, '40_agent_ticket_history');
    await _back(tester);

    await _tab(tester, 'Help');
    await _tap(tester, find.byTooltip('New article'));
    await tester.enterText(find.widgetWithText(TextFormField, 'Title'), 'Fixing the "account locked" message');
    await _shot(tester, '41_agent_new_article');
    await _back(tester);

    await _tab(tester, 'Profile');
    await _shot(tester, '42_agent_profile');
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('admin screens', (tester) async {
    await _pumpApp(tester);
    await _login(tester, 'admin@demo.test');
    await _shot(tester, '50_admin_home');
    await tester.drag(find.byType(CustomScrollView).first, const Offset(0, -760));
    await _shot(tester, '51_admin_home_workload');

    await _tab(tester, 'Tickets');
    await _shot(tester, '52_admin_all_tickets');

    await _tab(tester, 'Profile');
    await _shot(tester, '53_admin_profile');
    await _tap(tester, find.text('Reports'));
    await _shot(tester, '54_admin_reports');
    await _back(tester);
    await _tap(tester, find.text('Users and roles'));
    await _shot(tester, '55_admin_users');
    await _tap(tester, find.text('Add user'));
    await _shot(tester, '56_admin_add_user');
    await _dismiss(tester);
    await _back(tester);
    await _tap(tester, find.text('Categories'));
    await _shot(tester, '57_admin_categories');
    await _tap(tester, find.text('Technical'));
    await _shot(tester, '58_admin_edit_category');
    await _dismiss(tester);
    await _back(tester);
    await _tap(tester, find.text('Priorities and SLA'));
    await _shot(tester, '59_admin_priorities');
    await tester.pumpWidget(const SizedBox());
  });
}
