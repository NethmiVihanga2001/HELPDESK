import 'package:flutter_test/flutter_test.dart';
import 'package:helpdesk_pro_mobile/models/page_result.dart';
import 'package:helpdesk_pro_mobile/models/ticket.dart';
import 'package:helpdesk_pro_mobile/models/user.dart';
import 'package:helpdesk_pro_mobile/services/api_exception.dart';
import 'package:helpdesk_pro_mobile/utils/validators.dart';

void main() {
  group('TicketStatus.parse', () {
    test('accepts enum, label and kebab styles', () {
      expect(TicketStatus.parse('IN_PROGRESS'), TicketStatus.inProgress);
      expect(TicketStatus.parse('In Progress'), TicketStatus.inProgress);
      expect(TicketStatus.parse('in-progress'), TicketStatus.inProgress);
      expect(TicketStatus.parse('Waiting for Customer'), TicketStatus.waitingForCustomer);
      expect(TicketStatus.parse('WAITING_CUSTOMER'), TicketStatus.waitingForCustomer);
      expect(TicketStatus.parse('closed'), TicketStatus.closed);
    });
  });

  test('unknown role falls back to Customer (fewest rights)', () {
    expect(UserRole.parse('ADMIN'), UserRole.admin);
    expect(UserRole.parse('agent'), UserRole.agent);
    expect(UserRole.parse('superuser'), UserRole.customer);
    expect(UserRole.parse(null), UserRole.customer);
  });

  test('Ticket.fromJson reads nested relations and sorts replies by time', () {
    final ticket = Ticket.fromJson({
      'id': 7,
      'ticketNumber': 'TKT-0007',
      'title': 'Printer offline',
      'description': 'It stopped working',
      'status': 'WAITING_FOR_CUSTOMER',
      'category': {'id': 1, 'name': 'Technical'},
      'priorityName': 'High',
      'customer': {'id': 4, 'name': 'Casey Customer'},
      'assignedAgent': null,
      'createdAt': '2026-11-23T08:00:00.000Z',
      'isOverdue': true,
      'replies': [
        {'id': 2, 'message': 'second', 'isInternal': false, 'createdAt': '2026-11-23T10:00:00Z', 'author': {'id': 2, 'name': 'Ari', 'role': 'AGENT'}},
        {'id': 1, 'message': 'first', 'isInternal': true, 'createdAt': '2026-11-23T09:00:00Z', 'author': {'id': 2, 'name': 'Ari', 'role': 'AGENT'}},
      ],
    });

    expect(ticket.id, '7');
    expect(ticket.number, 'TKT-0007');
    expect(ticket.status, TicketStatus.waitingForCustomer);
    expect(ticket.categoryName, 'Technical');
    expect(ticket.priorityName, 'High');
    expect(ticket.customer?.name, 'Casey Customer');
    expect(ticket.assignedAgent, isNull);
    expect(ticket.isOverdue, isTrue);
    expect(ticket.replies.map((r) => r.message), ['first', 'second']);
    expect(ticket.replies.first.author?.role, UserRole.agent);
  });

  test('visibleTo removes internal notes for customers only', () {
    final ticket = Ticket.fromJson({
      'id': 1,
      'ticketNumber': 'TKT-0001',
      'title': 'Test',
      'status': 'OPEN',
      'replies': [
        {'id': 1, 'message': 'public', 'isInternal': false},
        {'id': 2, 'message': 'staff only', 'isInternal': true},
      ],
    });
    expect(ticket.visibleTo(UserRole.customer).replies.map((r) => r.message), ['public']);
    expect(ticket.visibleTo(UserRole.agent).replies, hasLength(2));
  });

  group('PageResult.fromJson', () {
    Ticket parse(Map<String, dynamic> json) => Ticket.fromJson(json);
    final rows = List.generate(2, (i) => {'id': i, 'ticketNumber': 'TKT-000$i', 'title': 't', 'status': 'OPEN'});

    test('uses totalPages when present', () {
      final page = PageResult.fromJson({'items': rows, 'page': 1, 'totalPages': 3}, parse, page: 1, pageSize: 2);
      expect(page.items, hasLength(2));
      expect(page.hasMore, isTrue);
    });

    test('uses total under pagination', () {
      final page = PageResult.fromJson({'tickets': rows, 'pagination': {'total': 4}}, parse, page: 2, pageSize: 2);
      expect(page.hasMore, isFalse);
    });

    test('plain list: a short page is the last page', () {
      final page = PageResult.fromJson(rows, parse, page: 1, pageSize: 20);
      expect(page.hasMore, isFalse);
    });
  });

  group('ApiException.fromBody', () {
    test('keeps the server message and field errors for 4xx', () {
      final e = ApiException.fromBody({
        'success': false,
        'message': 'Validation failed',
        'errors': [
          {'field': 'title', 'message': 'Title is required'},
        ],
      }, 400);
      expect(e.message, 'Validation failed');
      expect(e.fieldErrors, {'title': 'Title is required'});
    });

    test('hides raw server errors for 5xx', () {
      final e = ApiException.fromBody({'success': false, 'message': 'PrismaClientKnownRequestError'}, 500);
      expect(e.message, isNot(contains('Prisma')));
    });
  });

  group('Validators', () {
    test('ticket title must be 5 to 150 characters', () {
      expect(Validators.ticketTitle('Help'), isNotNull);
      expect(Validators.ticketTitle('Help me'), isNull);
      expect(Validators.ticketTitle('x' * 151), isNotNull);
    });

    test('new password needs 8 characters', () {
      expect(Validators.newPassword('1234567'), isNotNull);
      expect(Validators.newPassword('12345678'), isNull);
    });

    test('email format', () {
      expect(Validators.email('a@b.co'), isNull);
      expect(Validators.email('not-an-email'), isNotNull);
    });
  });
}
