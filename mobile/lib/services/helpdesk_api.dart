import 'dart:typed_data';

import '../models/app_notification.dart';
import '../models/attachment.dart';
import '../models/insights.dart';
import '../models/lookups.dart';
import '../models/page_result.dart';
import '../models/reply.dart';
import '../models/ticket.dart';
import '../models/user.dart';

/// Result of a successful login.
class AuthSession {
  const AuthSession({
    required this.accessToken,
    required this.user,
    this.refreshToken,
  });

  final String accessToken;
  final String? refreshToken;
  final AppUser user;
}

/// Everything the mobile app asks of the backend, grouped by SRS module.
///
/// [RemoteHelpdeskApi] talks to the real backend and [MockHelpdeskApi] uses
/// fictional in-memory data. Screens depend only on this interface, so
/// switching between them is one `--dart-define`.
///
/// Every method throws an [ApiException] on failure.
abstract class HelpdeskApi {
  // 3.1 Authentication
  Future<AuthSession> login(String email, String password);
  Future<void> register({required String name, required String email, required String password});
  Future<void> logout(String? refreshToken);
  Future<void> requestPasswordReset(String email);
  Future<void> resetPassword({required String token, required String newPassword});

  // 3.2 Profile, users, categories, priorities
  Future<AppUser> getProfile();
  Future<AppUser> updateProfile({required String name});
  Future<List<AppUser>> getUsers({UserRole? role});
  Future<AppUser> createUser({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  });
  Future<AppUser> updateUser(String id, {String? name, UserRole? role, bool? active});
  Future<List<TicketCategory>> getCategories({bool includeInactive = false});
  Future<TicketCategory> saveCategory({
    String? id,
    required String name,
    String? defaultAgentId,
    required bool active,
  });
  Future<List<TicketPriority>> getPriorities();
  Future<TicketPriority> updatePriority(String id, {required int responseHours, required int resolutionHours});

  // 3.3 Tickets
  Future<PageResult<Ticket>> getTickets({
    required int page,
    required int pageSize,
    TicketQuery query = const TicketQuery(),
  });
  Future<Ticket> getTicket(String id);
  Future<Ticket> createTicket({
    required String title,
    required String description,
    required String categoryId,
    required String priorityId,
  });
  Future<void> changeStatus(String ticketId, TicketStatus status);
  Future<void> reopenTicket(String ticketId);
  Future<void> rateTicket(String ticketId, {required int rating, String? comment});
  Future<Attachment> uploadAttachment(String ticketId, {required String filePath, required String fileName});
  Future<Uint8List> downloadAttachment(String attachmentId);

  // 3.4 Assignment
  Future<void> assignTicket(String ticketId, String agentId);

  // 3.5 Replies, internal notes and templates
  Future<TicketReply> addReply(String ticketId, {required String message, bool isInternal = false});
  Future<List<ReplyTemplate>> getReplyTemplates();
  Future<ReplyTemplate> createReplyTemplate({required String title, required String body});

  // 3.7 Notifications
  Future<List<AppNotification>> getNotifications();
  Future<void> markNotificationRead(String id);

  // 3.8 Knowledge base
  Future<List<Article>> getArticles({String search = ''});
  Future<Article> getArticle(String id);
  Future<Article> saveArticle({
    String? id,
    required String title,
    required String body,
    String? categoryId,
    required bool published,
  });

  // 3.9 Dashboard and reports
  Future<DashboardSummary> getDashboard();
  Future<TicketReport> getReport(ReportQuery query);

  /// Report export (DSH-7): `xlsx` or `pdf` file bytes.
  Future<Uint8List> exportReport(ReportQuery query, String format);
}
