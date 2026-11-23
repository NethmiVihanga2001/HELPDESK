import 'json_utils.dart';

/// An in-app notification (NOT-1 to NOT-3).
class AppNotification {
  const AppNotification({
    required this.id,
    required this.message,
    required this.isRead,
    this.ticketId,
    this.createdAt,
  });

  factory AppNotification.fromJson(Json json) {
    final ticketId = json['ticketId'] ?? asJson(json['ticket'])['id'];
    return AppNotification(
      id: readString(json['id']),
      message: readString(json['message']),
      isRead: readBool(json['isRead'] ?? json['read']),
      ticketId: ticketId?.toString(),
      createdAt: readDate(json['createdAt']),
    );
  }

  final String id;
  final String message;
  final bool isRead;
  final String? ticketId;
  final DateTime? createdAt;

  AppNotification copyWith({bool? isRead}) => AppNotification(
        id: id,
        message: message,
        isRead: isRead ?? this.isRead,
        ticketId: ticketId,
        createdAt: createdAt,
      );
}
