import 'attachment.dart';
import 'json_utils.dart';
import 'user.dart';

/// A message in a ticket conversation (REP-1) or a staff-only internal
/// note (REP-2) when [isInternal] is true.
class TicketReply {
  const TicketReply({
    required this.id,
    required this.message,
    required this.isInternal,
    this.author,
    this.createdAt,
    this.attachments = const [],
  });

  factory TicketReply.fromJson(Json json) => TicketReply(
        id: readString(json['id']),
        message: readString(json['message'] ?? json['body']),
        isInternal: readBool(json['isInternal'] ?? json['internal']),
        author: PersonRef.read(json, 'author'),
        createdAt: readDate(json['createdAt']),
        attachments:
            asJsonList(json['attachments']).map(Attachment.fromJson).toList(),
      );

  final String id;
  final String message;
  final bool isInternal;
  final PersonRef? author;
  final DateTime? createdAt;
  final List<Attachment> attachments;
}
