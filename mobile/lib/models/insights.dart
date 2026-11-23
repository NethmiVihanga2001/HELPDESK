import 'json_utils.dart';
import 'ticket.dart';
import 'user.dart';

/// Dashboard numbers (DSH-1 to DSH-5). Admin: all tickets; Agent: own;
/// Customer: own.
class DashboardSummary {
  const DashboardSummary({
    required this.byStatus,
    this.newToday = 0,
    this.unassigned = 0,
    this.overdue = 0,
    this.averageResolutionHours,
    this.workload = const [],
  });

  factory DashboardSummary.fromJson(Json json) {
    final byStatus = <TicketStatus, int>{for (final s in TicketStatus.values) s: 0};
    final raw = json['byStatus'] ?? json['countsByStatus'] ?? json['statusCounts'];
    if (raw is Map) {
      raw.forEach((k, v) => byStatus[TicketStatus.parse(k)] = readInt(v) ?? 0);
    } else {
      for (final row in asJsonList(raw)) {
        byStatus[TicketStatus.parse(row['status'])] = readInt(row['count']) ?? 0;
      }
    }
    final avg = json['averageResolutionHours'];
    return DashboardSummary(
      byStatus: byStatus,
      newToday: readInt(json['newToday']) ?? 0,
      unassigned: readInt(json['unassigned']) ?? 0,
      overdue: readInt(json['overdue']) ?? 0,
      averageResolutionHours: avg is num ? avg.toDouble() : double.tryParse('$avg'),
      workload: asJsonList(json['agentWorkload'] ?? json['workload'])
          .map((w) => AgentWorkload(
                name: readString(w['name'] ?? w['agentName'], 'Agent'),
                openTickets: readInt(w['openTickets'] ?? w['count']) ?? 0,
              ))
          .toList(),
    );
  }

  final Map<TicketStatus, int> byStatus;
  final int newToday;
  final int unassigned;
  final int overdue;
  final double? averageResolutionHours;
  final List<AgentWorkload> workload;

  int get total => byStatus.values.fold(0, (a, b) => a + b);
  int get open => total - count(TicketStatus.resolved) - count(TicketStatus.closed);
  int count(TicketStatus status) => byStatus[status] ?? 0;
}

/// Open tickets per agent (DSH-4).
class AgentWorkload {
  const AgentWorkload({required this.name, required this.openTickets});

  final String name;
  final int openTickets;
}

/// Ticket report filters (DSH-6).
class ReportQuery {
  const ReportQuery({
    this.from,
    this.to,
    this.status,
    this.categoryId,
    this.priorityId,
    this.agentId,
  });

  final DateTime? from;
  final DateTime? to;
  final TicketStatus? status;
  final String? categoryId;
  final String? priorityId;
  final String? agentId;

  Map<String, dynamic> toQuery() => {
        if (from != null) 'from': _day(from!),
        if (to != null) 'to': _day(to!),
        if (status != null) 'status': status!.apiValue,
        if (categoryId != null) 'categoryId': categoryId,
        if (priorityId != null) 'priorityId': priorityId,
        if (agentId != null) 'agentId': agentId,
      };

  static String _day(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Result of `GET /api/reports/tickets`.
class TicketReport {
  const TicketReport({required this.rows, this.averageResolutionHours});

  factory TicketReport.fromJson(Object? data) {
    if (data is List) {
      return TicketReport(rows: asJsonList(data).map(Ticket.fromJson).toList());
    }
    final json = asJson(data);
    final avg = json['averageResolutionHours'];
    return TicketReport(
      rows: asJsonList(json['rows'] ?? json['items'] ?? json['tickets'])
          .map(Ticket.fromJson)
          .toList(),
      averageResolutionHours: avg is num ? avg.toDouble() : double.tryParse('$avg'),
    );
  }

  final List<Ticket> rows;
  final double? averageResolutionHours;

  int count(TicketStatus status) => rows.where((t) => t.status == status).length;
  int get overdue => rows.where((t) => t.isOverdue).length;
}

/// A knowledge base article (KB-1 to KB-4).
class Article {
  const Article({
    required this.id,
    required this.title,
    required this.body,
    required this.published,
    this.categoryId,
    this.categoryName,
    this.author,
    this.updatedAt,
  });

  factory Article.fromJson(Json json) {
    final category = json['category'];
    return Article(
      id: readString(json['id']),
      title: readString(json['title']),
      body: readString(json['body']),
      published: readBool(json['published'] ?? json['isPublished']),
      categoryId: (json['categoryId'] ?? (category is Map ? category['id'] : null))?.toString(),
      categoryName: readRelationName(json, 'category'),
      author: PersonRef.read(json, 'author'),
      updatedAt: readDate(json['updatedAt'] ?? json['createdAt']),
    );
  }

  final String id;
  final String title;
  final String body;
  final bool published;
  final String? categoryId;
  final String? categoryName;
  final PersonRef? author;
  final DateTime? updatedAt;

  /// Rough reading time for the article card.
  int get readMinutes => (body.split(RegExp(r'\s+')).length / 180).ceil().clamp(1, 60);
}

/// A saved reply an agent can insert (REP-5).
class ReplyTemplate {
  const ReplyTemplate({required this.id, required this.title, required this.body});

  factory ReplyTemplate.fromJson(Json json) => ReplyTemplate(
        id: readString(json['id']),
        title: readString(json['title']),
        body: readString(json['body']),
      );

  final String id;
  final String title;
  final String body;
}
