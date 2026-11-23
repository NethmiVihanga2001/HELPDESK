import 'package:flutter_test/flutter_test.dart';
import 'package:helpdesk_pro_mobile/models/insights.dart';
import 'package:helpdesk_pro_mobile/models/ticket.dart';
import 'package:helpdesk_pro_mobile/models/user.dart';
import 'package:helpdesk_pro_mobile/services/api_exception.dart';
import 'package:helpdesk_pro_mobile/services/mock_helpdesk_api.dart';
import 'package:helpdesk_pro_mobile/services/token_storage.dart';

/// The mock follows the SRS rules the backend must also follow, so these
/// tests double as a checklist for testing the real API on Day 8.
void main() {
  late TokenStorage tokens;
  late MockHelpdeskApi api;

  setUp(() {
    tokens = TokenStorage(MemoryKeyValueStore());
    api = MockHelpdeskApi(tokens, latency: Duration.zero);
  });

  Future<AppUser> signIn(String email) async {
    final session = await api.login(email, MockHelpdeskApi.demoPassword);
    await tokens.saveTokens(accessToken: session.accessToken, refreshToken: session.refreshToken);
    return session.user;
  }

  Matcher apiError(int status) => throwsA(isA<ApiException>().having((e) => e.statusCode, 'statusCode', status));

  Future<List<Ticket>> tickets({TicketQuery query = const TicketQuery()}) async =>
      (await api.getTickets(page: 1, pageSize: 100, query: query)).items;

  group('3.1 Authentication', () {
    test('wrong password gives the same safe message', () async {
      await expectLater(
        api.login('customer1@demo.test', 'wrong-password'),
        throwsA(isA<ApiException>().having((e) => e.message, 'message', 'Invalid email or password')),
      );
    });

    test('without a token every call is rejected with 401', () async {
      await expectLater(api.getTickets(page: 1, pageSize: 20), apiError(401));
    });

    test('reset code works once (AUTH-3)', () async {
      await api.requestPasswordReset('customer2@demo.test');
      await api.resetPassword(token: MockHelpdeskApi.demoResetCode, newPassword: 'NewPass123');
      expect((await api.login('customer2@demo.test', 'NewPass123')).user.name, 'Drew Customer');
      await expectLater(api.resetPassword(token: MockHelpdeskApi.demoResetCode, newPassword: 'Again1234'), apiError(400));
    });
  });

  group('3.2 Users and categories', () {
    test('only Admin manages users; a deactivated user cannot sign in (USR-1)', () async {
      await signIn('agent1@demo.test');
      await expectLater(api.getUsers(), apiError(403));
      await signIn('admin@demo.test');
      final drew = (await api.getUsers(role: UserRole.customer)).firstWhere((u) => u.name == 'Drew Customer');
      await api.updateUser(drew.id, active: false);
      await expectLater(api.login('customer2@demo.test', MockHelpdeskApi.demoPassword), apiError(401));
    });

    test('category names are unique (USR-3)', () async {
      await signIn('admin@demo.test');
      await expectLater(api.saveCategory(name: 'billing', active: true), apiError(409));
    });
  });

  group('3.3 Tickets', () {
    test('a customer sees only their own tickets', () async {
      final me = await signIn('customer1@demo.test');
      final mine = await tickets();
      expect(mine, isNotEmpty);
      expect(mine.every((t) => t.customer?.id == me.id), isTrue);
    });

    test('new tickets get the next unique number, start Open and go to the category default agent', () async {
      await signIn('customer2@demo.test');
      final a = await api.createTicket(title: 'Screen is blank', description: 'Nothing shows', categoryId: '1', priorityId: '2');
      final b = await api.createTicket(title: 'Second problem', description: 'Another one', categoryId: '4', priorityId: '1');
      expect(a.status, TicketStatus.open);
      expect(a.number, matches(RegExp(r'^TKT-\d{4}$')));
      expect(a.number, isNot(b.number));
      expect(a.assignedAgent?.name, 'Ari Agent'); // ASG-4: Technical -> Ari
      expect(b.assignedAgent, isNull); // General has no default agent
    });

    test('validation returns field errors', () async {
      await signIn('customer2@demo.test');
      await expectLater(
        api.createTicket(title: 'Hi', description: '', categoryId: '1', priorityId: '2'),
        throwsA(isA<ApiException>().having((e) => e.fieldErrors.keys, 'fields', containsAll(['title', 'description']))),
      );
    });

    test('status changes are recorded with who and when (TKT-4, TKT-10)', () async {
      await signIn('agent1@demo.test');
      final t = (await tickets()).firstWhere((t) => t.status == TicketStatus.open);
      await api.changeStatus(t.id, TicketStatus.inProgress);
      final last = (await api.getTicket(t.id)).history.last;
      expect(last.isStatus, isTrue);
      expect(last.changedBy?.name, 'Ari Agent');
      expect(last.changedAt, isNotNull);
    });

    test('a customer can reopen a Resolved ticket and rate it once (TKT-8, TKT-9)', () async {
      await signIn('customer1@demo.test');
      final resolved = (await tickets(query: const TicketQuery(status: TicketStatus.resolved))).first;
      await api.rateTicket(resolved.id, rating: 4, comment: 'Good');
      expect((await api.getTicket(resolved.id)).rating, 4);
      await expectLater(api.rateTicket(resolved.id, rating: 5), apiError(409));
      await api.reopenTicket(resolved.id);
      expect((await api.getTicket(resolved.id)).status, TicketStatus.open);
      await expectLater(api.reopenTicket(resolved.id), apiError(400));
    });

    test('a closed ticket cannot be changed (BR-2)', () async {
      await signIn('admin@demo.test');
      final closed = (await tickets(query: const TicketQuery(status: TicketStatus.closed))).first;
      await expectLater(api.addReply(closed.id, message: 'Hello?'), apiError(400));
    });

    test('search finds tickets by title', () async {
      await signIn('admin@demo.test');
      final found = await tickets(query: const TicketQuery(search: 'refund'));
      expect(found.map((t) => t.title), ['Request for a refund']);
    });
  });

  group('3.4 Assignment', () {
    test('an agent sees the unassigned queue and can take a ticket from it (ASG-2)', () async {
      final me = await signIn('agent1@demo.test');
      final queue = await tickets(query: const TicketQuery(scope: TicketScope.queue));
      expect(queue, isNotEmpty);
      expect(queue.every((t) => t.isUnassigned), isTrue);
      await expectLater(api.addReply(queue.first.id, message: 'Hi'), apiError(403));
      await api.assignTicket(queue.first.id, me.id);
      expect((await api.getTicket(queue.first.id)).assignedAgent?.id, me.id);
    });

    test("an agent cannot take another agent's ticket", () async {
      final me = await signIn('agent1@demo.test');
      await signIn('admin@demo.test');
      final blakes = (await tickets()).firstWhere((t) => t.assignedAgent?.name == 'Blake Agent');
      await signIn('agent1@demo.test');
      await expectLater(api.assignTicket(blakes.id, me.id), apiError(403));
    });

    test('only active agents can be assigned', () async {
      await signIn('admin@demo.test');
      final former = (await api.getUsers(role: UserRole.agent)).firstWhere((u) => !u.active);
      final t = (await tickets(query: const TicketQuery(scope: TicketScope.queue))).first;
      await expectLater(api.assignTicket(t.id, former.id), apiError(400));
    });
  });

  group('3.5 Replies and internal notes', () {
    test('internal notes are never returned to a customer (REP-3)', () async {
      await signIn('customer1@demo.test');
      for (final summary in await tickets()) {
        final ticket = await api.getTicket(summary.id);
        expect(ticket.replies.where((r) => r.isInternal), isEmpty, reason: ticket.number);
      }
    });

    test('a customer cannot post an internal note or change status', () async {
      await signIn('customer1@demo.test');
      final id = (await tickets()).first.id;
      await expectLater(api.addReply(id, message: 'hi', isInternal: true), apiError(403));
      await expectLater(api.changeStatus(id, TicketStatus.closed), apiError(403));
    });

    test('a customer reply moves Waiting for Customer back to In Progress (REP-4)', () async {
      await signIn('customer1@demo.test');
      final waiting = (await tickets(query: const TicketQuery(status: TicketStatus.waitingForCustomer))).first;
      await api.addReply(waiting.id, message: 'Invoice number is 12345');
      expect((await api.getTicket(waiting.id)).status, TicketStatus.inProgress);
    });

    test('reply templates are for staff only (REP-5)', () async {
      await signIn('agent1@demo.test');
      expect(await api.getReplyTemplates(), isNotEmpty);
      await signIn('customer1@demo.test');
      await expectLater(api.getReplyTemplates(), apiError(403));
    });
  });

  group('3.8 Knowledge base', () {
    test('customers see published articles only; staff also see drafts (KB-2)', () async {
      await signIn('customer1@demo.test');
      expect((await api.getArticles()).every((a) => a.published), isTrue);
      await signIn('agent1@demo.test');
      expect((await api.getArticles()).any((a) => !a.published), isTrue);
    });

    test('only an Admin can unpublish (KB-4)', () async {
      await signIn('agent1@demo.test');
      final a = (await api.getArticles()).firstWhere((a) => a.published);
      await expectLater(api.saveArticle(id: a.id, title: a.title, body: a.body, published: false), apiError(403));
      await signIn('admin@demo.test');
      expect((await api.saveArticle(id: a.id, title: a.title, body: a.body, published: false)).published, isFalse);
    });

    test('search matches words in the title (KB-3)', () async {
      await signIn('customer1@demo.test');
      expect((await api.getArticles(search: 'reset my password')).map((a) => a.title), contains('How to reset your password'));
    });
  });

  group('3.9 Dashboard and reports', () {
    test('dashboard counts match the role (DSH-1, DSH-4)', () async {
      await signIn('customer1@demo.test');
      final mine = await tickets();
      expect((await api.getDashboard()).total, mine.length);
      await signIn('admin@demo.test');
      final all = await api.getDashboard();
      expect(all.workload.map((w) => w.name), containsAll(['Ari Agent', 'Blake Agent']));
      expect(all.unassigned, greaterThan(0));
    });

    test('reports: agents see their own tickets, customers none (DSH-6)', () async {
      await signIn('customer1@demo.test');
      await expectLater(api.getReport(const ReportQuery()), apiError(403));
      await signIn('agent1@demo.test');
      final report = await api.getReport(const ReportQuery());
      expect(report.rows.every((t) => t.assignedAgent?.name == 'Ari Agent'), isTrue);
      expect((await api.exportReport(const ReportQuery(), 'xlsx')).length, greaterThan(50));
    });
  });

  test('pagination returns pages without duplicates', () async {
    await signIn('admin@demo.test');
    final first = await api.getTickets(page: 1, pageSize: 4);
    final second = await api.getTickets(page: 2, pageSize: 4);
    expect(first.hasMore, isTrue);
    expect(first.items.map((t) => t.id).toSet().intersection(second.items.map((t) => t.id).toSet()), isEmpty);
  });
}
