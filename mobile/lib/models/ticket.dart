import 'package:flutter/foundation.dart';

import 'attachment.dart';
import 'json_utils.dart';
import 'reply.dart';
import 'user.dart';

/// Ticket statuses from TKT-3 / BR-2.
enum TicketStatus {
  open('OPEN', 'Open'),
  inProgress('IN_PROGRESS', 'In Progress'),
  waitingForCustomer('WAITING_FOR_CUSTOMER', 'Waiting for Customer'),
  resolved('RESOLVED', 'Resolved'),
  closed('CLOSED', 'Closed');

  const TicketStatus(this.apiValue, this.label);

  /// Value sent to the backend (Prisma enum style). Confirm with Backend 3.
  final String apiValue;

  /// Text shown to the user.
  final String label;

  /// Resolved and Closed tickets no longer count as open work.
  bool get isDone => this == resolved || this == closed;

  /// Accepts "IN_PROGRESS", "In Progress", "in-progress" and so on.
  static TicketStatus parse(Object? value) {
    final key = (value?.toString() ?? '')
        .trim()
        .toUpperCase()
        .replaceAll(RegExp(r'[\s-]+'), '_');
    if (key.startsWith('WAITING')) return TicketStatus.waitingForCustomer;
    for (final status in values) {
      if (status.apiValue == key) return status;
    }
    return TicketStatus.open;
  }
}

/// Which tickets a list shows.
enum TicketScope {
  /// Customer: own tickets. Agent: assigned to me. Admin: all tickets.
  mine,

  /// Unassigned tickets an agent can take (ASG-2). Admin: unassigned.
  queue,
}

/// Search and filters for the ticket list (TKT-6).
@immutable
class TicketQuery {
  const TicketQuery({
    this.scope = TicketScope.mine,
    this.status,
    this.search = '',
    this.priorityId,
    this.categoryId,
    this.from,
    this.to,
  });

  final TicketScope scope;
  final TicketStatus? status;
  final String search;
  final String? priorityId;
  final String? categoryId;
  final DateTime? from;
  final DateTime? to;

  /// Number of filters set in the filter sheet (not scope, status or search).
  int get extraFilterCount =>
      [priorityId, categoryId, from].where((v) => v != null).length;

  TicketQuery copyWith({
    TicketScope? scope,
    TicketStatus? Function()? status,
    String? search,
    String? Function()? priorityId,
    String? Function()? categoryId,
    DateTime? Function()? from,
    DateTime? Function()? to,
  }) =>
      TicketQuery(
        scope: scope ?? this.scope,
        status: status != null ? status() : this.status,
        search: search ?? this.search,
        priorityId: priorityId != null ? priorityId() : this.priorityId,
        categoryId: categoryId != null ? categoryId() : this.categoryId,
        from: from != null ? from() : this.from,
        to: to != null ? to() : this.to,
      );
}

/// One entry of the change log (TKT-10, NFR-8): who changed what, and when.
class TicketHistoryEntry {
  const TicketHistoryEntry({
    required this.field,
    this.oldValue,
    this.newValue,
    this.changedBy,
    this.changedAt,
  });

  factory TicketHistoryEntry.fromJson(Json json) => TicketHistoryEntry(
        field: readString(json['field']),
        oldValue: json['oldValue']?.toString(),
        newValue: json['newValue']?.toString(),
        changedBy: PersonRef.read(json, 'changedBy'),
        changedAt: readDate(json['changedAt'] ?? json['createdAt']),
      );

  /// "status", "priority" or "assignedAgent".
  final String field;
  final String? oldValue;
  final String? newValue;
  final PersonRef? changedBy;
  final DateTime? changedAt;

  bool get isStatus => field.toLowerCase() == 'status';
  bool get isAssignment => field.toLowerCase().contains('assign');

  String _describe(String? value) {
    if (value == null || value.isEmpty) return isAssignment ? 'nobody' : 'none';
    return isStatus ? TicketStatus.parse(value).label : value;
  }

  String get summary {
    if (isAssignment) {
      return newValue == null || newValue!.isEmpty
          ? 'Unassigned the ticket'
          : 'Assigned to ${_describe(newValue)}';
    }
    final label = isStatus ? 'status' : field;
    return 'Changed $label from ${_describe(oldValue)} to ${_describe(newValue)}';
  }
}

/// A support ticket. List responses fill the summary fields only; the
/// details response also has the description, replies, attachments and
/// history.
class Ticket {
  const Ticket({
    required this.id,
    required this.number,
    required this.title,
    required this.status,
    this.description = '',
    this.categoryId,
    this.categoryName,
    this.priorityId,
    this.priorityName,
    this.customer,
    this.assignedAgent,
    this.createdAt,
    this.updatedAt,
    this.dueAt,
    this.resolvedAt,
    this.isOverdue = false,
    this.rating,
    this.ratingComment,
    this.replies = const [],
    this.attachments = const [],
    this.history = const [],
  });

  factory Ticket.fromJson(Json json) {
    final replies = asJsonList(json['replies']).map(TicketReply.fromJson).toList()
      ..sort((a, b) => _compareDates(a.createdAt, b.createdAt));
    final history = asJsonList(json['history']).map(TicketHistoryEntry.fromJson).toList()
      ..sort((a, b) => _compareDates(a.changedAt, b.changedAt));
    final ratingJson = json['rating'];
    final category = json['category'];
    final priority = json['priority'];
    return Ticket(
      id: readString(json['id']),
      number: readString(json['ticketNumber'] ?? json['number']),
      title: readString(json['title']),
      description: readString(json['description']),
      status: TicketStatus.parse(json['status']),
      categoryId: (json['categoryId'] ?? (category is Map ? category['id'] : null))?.toString(),
      categoryName: readRelationName(json, 'category'),
      priorityId: (json['priorityId'] ?? (priority is Map ? priority['id'] : null))?.toString(),
      priorityName: readRelationName(json, 'priority'),
      customer: PersonRef.read(json, 'customer'),
      assignedAgent: PersonRef.read(json, 'assignedAgent') ?? PersonRef.read(json, 'assignee'),
      createdAt: readDate(json['createdAt']),
      updatedAt: readDate(json['updatedAt']),
      dueAt: readDate(json['dueAt']),
      resolvedAt: readDate(json['resolvedAt']),
      isOverdue: readBool(json['isOverdue'] ?? json['overdue']),
      rating: ratingJson is Map ? readInt(ratingJson['rating']) : readInt(ratingJson),
      ratingComment: ratingJson is Map
          ? ratingJson['comment']?.toString()
          : json['ratingComment']?.toString(),
      replies: replies,
      attachments: asJsonList(json['attachments']).map(Attachment.fromJson).toList(),
      history: history,
    );
  }

  final String id;

  /// System-generated number such as TKT-0001 (TKT-2). Never editable.
  final String number;
  final String title;
  final String description;
  final TicketStatus status;
  final String? categoryId;
  final String? categoryName;
  final String? priorityId;
  final String? priorityName;
  final PersonRef? customer;
  final PersonRef? assignedAgent;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// SLA due time (SLA-3) and overdue flag (SLA-4).
  final DateTime? dueAt;
  final DateTime? resolvedAt;
  final bool isOverdue;

  /// Customer rating 1 to 5 (TKT-9), null until rated.
  final int? rating;
  final String? ratingComment;
  final List<TicketReply> replies;
  final List<Attachment> attachments;
  final List<TicketHistoryEntry> history;

  /// A Closed ticket cannot be edited (BR-2).
  bool get isClosed => status == TicketStatus.closed;
  bool get isUnassigned => assignedAgent == null;

  /// Returns the ticket as a customer may see it.
  ///
  /// The backend must never send internal notes to a customer (REP-3). This
  /// is a second safety net only: it logs loudly in debug builds so that a
  /// backend leak is noticed during testing instead of being hidden.
  Ticket visibleTo(UserRole role) {
    if (role.isStaff || !replies.any((r) => r.isInternal)) return this;
    debugPrint(
      'SECURITY: the API returned internal notes for ticket $number to a '
      'customer. Report this to the backend team (REP-3).',
    );
    return Ticket(
      id: id,
      number: number,
      title: title,
      description: description,
      status: status,
      categoryId: categoryId,
      categoryName: categoryName,
      priorityId: priorityId,
      priorityName: priorityName,
      customer: customer,
      assignedAgent: assignedAgent,
      createdAt: createdAt,
      updatedAt: updatedAt,
      dueAt: dueAt,
      resolvedAt: resolvedAt,
      isOverdue: isOverdue,
      rating: rating,
      ratingComment: ratingComment,
      replies: replies.where((r) => !r.isInternal).toList(),
      attachments: attachments,
      history: history,
    );
  }
}

int _compareDates(DateTime? a, DateTime? b) {
  if (a == null || b == null) return 0;
  return a.compareTo(b);
}
