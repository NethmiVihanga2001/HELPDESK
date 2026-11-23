import 'json_utils.dart';
import 'user.dart';

/// A ticket category such as Technical, Billing, Account or General
/// (USR-3), with the agent new tickets go to (USR-4).
class TicketCategory {
  const TicketCategory({
    required this.id,
    required this.name,
    this.active = true,
    this.defaultAgent,
  });

  factory TicketCategory.fromJson(Json json) => TicketCategory(
        id: readString(json['id']),
        name: readString(json['name']),
        active: readBool(json['active'] ?? json['isActive'], fallback: true),
        defaultAgent: PersonRef.read(json, 'defaultAgent'),
      );

  final String id;
  final String name;
  final bool active;
  final PersonRef? defaultAgent;
}

/// The four priority levels from SLA-1.
enum PriorityLevel {
  low,
  medium,
  high,
  urgent,
  unknown;

  static PriorityLevel fromName(String? name) {
    switch (name?.trim().toLowerCase()) {
      case 'low':
        return PriorityLevel.low;
      case 'medium':
        return PriorityLevel.medium;
      case 'high':
        return PriorityLevel.high;
      case 'urgent':
        return PriorityLevel.urgent;
      default:
        return PriorityLevel.unknown;
    }
  }
}

/// A priority with its SLA targets (SLA-2, BR-3).
class TicketPriority {
  const TicketPriority({
    required this.id,
    required this.name,
    this.responseHours,
    this.resolutionHours,
  });

  factory TicketPriority.fromJson(Json json) => TicketPriority(
        id: readString(json['id']),
        name: readString(json['name']),
        responseHours: readInt(json['responseHours']),
        resolutionHours: readInt(json['resolutionHours']),
      );

  final String id;
  final String name;
  final int? responseHours;
  final int? resolutionHours;

  PriorityLevel get level => PriorityLevel.fromName(name);
}
