import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/app_notification.dart';
import '../models/attachment.dart';
import '../models/insights.dart';
import '../models/json_utils.dart';
import '../models/lookups.dart';
import '../models/page_result.dart';
import '../models/reply.dart';
import '../models/ticket.dart';
import '../models/user.dart';
import 'api_client.dart';
import 'api_endpoints.dart';
import 'api_exception.dart';
import 'helpdesk_api.dart';

/// [HelpdeskApi] backed by the real backend.
class RemoteHelpdeskApi implements HelpdeskApi {
  RemoteHelpdeskApi(this._client);

  final ApiClient _client;

  // ------------------------------------------------------------ 3.1 auth

  @override
  Future<AuthSession> login(String email, String password) async {
    final data = asJson(await _client.post(
      ApiEndpoints.login,
      data: {'email': email, 'password': password},
      auth: false,
    ));
    final accessToken = data['accessToken'] ?? data['token'];
    final refreshToken = data['refreshToken'];
    if (accessToken is! String || data['user'] is! Map) {
      throw const ApiException('Unexpected response from the server.');
    }
    return AuthSession(
      accessToken: accessToken,
      refreshToken: refreshToken is String ? refreshToken : null,
      user: AppUser.fromJson(asJson(data['user'])),
    );
  }

  @override
  Future<void> register({required String name, required String email, required String password}) async {
    await _client.post(
      ApiEndpoints.register,
      data: {'name': name, 'email': email, 'password': password},
      auth: false,
    );
  }

  @override
  Future<void> logout(String? refreshToken) async {
    await _client.post(ApiEndpoints.logout, data: {'refreshToken': refreshToken});
  }

  @override
  Future<void> requestPasswordReset(String email) async {
    await _client.post(ApiEndpoints.forgotPassword, data: {'email': email}, auth: false);
  }

  @override
  Future<void> resetPassword({required String token, required String newPassword}) async {
    await _client.post(
      ApiEndpoints.resetPassword,
      data: {'token': token, 'password': newPassword},
      auth: false,
    );
  }

  // ---------------------------------------- 3.2 profile, users, lookups

  @override
  Future<AppUser> getProfile() async =>
      AppUser.fromJson(asJson(await _client.get(ApiEndpoints.profile)));

  @override
  Future<AppUser> updateProfile({required String name}) async =>
      AppUser.fromJson(asJson(await _client.patch(ApiEndpoints.profile, data: {'name': name})));

  @override
  Future<List<AppUser>> getUsers({UserRole? role}) async {
    final data = await _client.get(ApiEndpoints.users, query: {
      if (role != null) 'role': role.apiValue,
    });
    return _list(data).map(AppUser.fromJson).toList();
  }

  @override
  Future<AppUser> createUser({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async =>
      AppUser.fromJson(asJson(await _client.post(ApiEndpoints.users, data: {
        'name': name,
        'email': email,
        'password': password,
        'role': role.apiValue,
      })));

  @override
  Future<AppUser> updateUser(String id, {String? name, UserRole? role, bool? active}) async =>
      AppUser.fromJson(asJson(await _client.patch(ApiEndpoints.user(id), data: {
        'name': ?name,
        if (role != null) 'role': role.apiValue,
        'active': ?active,
      })));

  @override
  Future<List<TicketCategory>> getCategories({bool includeInactive = false}) async {
    final data = await _client.get(
      includeInactive ? ApiEndpoints.adminCategories : ApiEndpoints.categories,
    );
    final all = _list(data).map(TicketCategory.fromJson);
    return (includeInactive ? all : all.where((c) => c.active)).toList();
  }

  @override
  Future<TicketCategory> saveCategory({
    String? id,
    required String name,
    String? defaultAgentId,
    required bool active,
  }) async {
    final body = {
      'name': name,
      'defaultAgentId': defaultAgentId == null ? null : idForApi(defaultAgentId),
      'active': active,
    };
    final data = id == null
        ? await _client.post(ApiEndpoints.adminCategories, data: body)
        : await _client.patch(ApiEndpoints.adminCategory(id), data: body);
    return TicketCategory.fromJson(asJson(data));
  }

  @override
  Future<List<TicketPriority>> getPriorities() async =>
      _list(await _client.get(ApiEndpoints.priorities)).map(TicketPriority.fromJson).toList();

  @override
  Future<TicketPriority> updatePriority(String id, {required int responseHours, required int resolutionHours}) async =>
      TicketPriority.fromJson(asJson(await _client.patch(ApiEndpoints.adminPriority(id), data: {
        'responseHours': responseHours,
        'resolutionHours': resolutionHours,
      })));

  // --------------------------------------------------------- 3.3 tickets

  @override
  Future<PageResult<Ticket>> getTickets({
    required int page,
    required int pageSize,
    TicketQuery query = const TicketQuery(),
  }) async {
    final data = await _client.get(ApiEndpoints.tickets, query: {
      'page': page,
      'pageSize': pageSize,
      if (query.scope == TicketScope.queue) 'scope': 'queue',
      if (query.status != null) 'status': query.status!.apiValue,
      if (query.search.trim().isNotEmpty) 'search': query.search.trim(),
      'priorityId': ?query.priorityId,
      'categoryId': ?query.categoryId,
      if (query.from != null) 'from': query.from!.toUtc().toIso8601String(),
      if (query.to != null) 'to': query.to!.toUtc().toIso8601String(),
    });
    return PageResult.fromJson(data, Ticket.fromJson, page: page, pageSize: pageSize);
  }

  @override
  Future<Ticket> getTicket(String id) async =>
      Ticket.fromJson(asJson(await _client.get(ApiEndpoints.ticket(id))));

  @override
  Future<Ticket> createTicket({
    required String title,
    required String description,
    required String categoryId,
    required String priorityId,
  }) async =>
      Ticket.fromJson(asJson(await _client.post(ApiEndpoints.tickets, data: {
        'title': title,
        'description': description,
        'categoryId': idForApi(categoryId),
        'priorityId': idForApi(priorityId),
      })));

  @override
  Future<void> changeStatus(String ticketId, TicketStatus status) async {
    await _client.patch(ApiEndpoints.ticketStatus(ticketId), data: {'status': status.apiValue});
  }

  @override
  Future<void> reopenTicket(String ticketId) async {
    await _client.post(ApiEndpoints.ticketReopen(ticketId));
  }

  @override
  Future<void> rateTicket(String ticketId, {required int rating, String? comment}) async {
    await _client.post(ApiEndpoints.ticketRating(ticketId), data: {
      'rating': rating,
      if (comment != null && comment.trim().isNotEmpty) 'comment': comment.trim(),
    });
  }

  @override
  Future<Attachment> uploadAttachment(String ticketId, {required String filePath, required String fileName}) async {
    final form = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        filePath,
        filename: fileName,
        contentType: DioMediaType.parse(_mimeTypeOf(fileName)),
      ),
    });
    return Attachment.fromJson(asJson(await _client.upload(ApiEndpoints.ticketAttachments(ticketId), form)));
  }

  @override
  Future<Uint8List> downloadAttachment(String attachmentId) =>
      _client.getBytes(ApiEndpoints.attachment(attachmentId));

  // ------------------------------------------------------ 3.4 assignment

  @override
  Future<void> assignTicket(String ticketId, String agentId) async {
    await _client.patch(ApiEndpoints.ticketAssign(ticketId), data: {'agentId': idForApi(agentId)});
  }

  // --------------------------------------------------- 3.5 replies, notes

  @override
  Future<TicketReply> addReply(String ticketId, {required String message, bool isInternal = false}) async =>
      TicketReply.fromJson(asJson(await _client.post(
        ApiEndpoints.ticketReplies(ticketId),
        data: {'message': message, 'isInternal': isInternal},
      )));

  @override
  Future<List<ReplyTemplate>> getReplyTemplates() async =>
      _list(await _client.get(ApiEndpoints.replyTemplates)).map(ReplyTemplate.fromJson).toList();

  @override
  Future<ReplyTemplate> createReplyTemplate({required String title, required String body}) async =>
      ReplyTemplate.fromJson(asJson(await _client.post(
        ApiEndpoints.replyTemplates,
        data: {'title': title, 'body': body},
      )));

  // --------------------------------------------------- 3.7 notifications

  @override
  Future<List<AppNotification>> getNotifications() async =>
      _list(await _client.get(ApiEndpoints.notifications)).map(AppNotification.fromJson).toList();

  @override
  Future<void> markNotificationRead(String id) async {
    await _client.patch(ApiEndpoints.notificationRead(id));
  }

  // -------------------------------------------------- 3.8 knowledge base

  @override
  Future<List<Article>> getArticles({String search = ''}) async {
    final data = await _client.get(ApiEndpoints.articles, query: {
      if (search.trim().isNotEmpty) 'search': search.trim(),
    });
    return _list(data).map(Article.fromJson).toList();
  }

  @override
  Future<Article> getArticle(String id) async =>
      Article.fromJson(asJson(await _client.get(ApiEndpoints.article(id))));

  @override
  Future<Article> saveArticle({
    String? id,
    required String title,
    required String body,
    String? categoryId,
    required bool published,
  }) async {
    final payload = {
      'title': title,
      'body': body,
      'categoryId': categoryId == null ? null : idForApi(categoryId),
      'published': published,
    };
    final data = id == null
        ? await _client.post(ApiEndpoints.articles, data: payload)
        : await _client.patch(ApiEndpoints.article(id), data: payload);
    return Article.fromJson(asJson(data));
  }

  // --------------------------------------------- 3.9 dashboard, reports

  @override
  Future<DashboardSummary> getDashboard() async =>
      DashboardSummary.fromJson(asJson(await _client.get(ApiEndpoints.dashboard)));

  @override
  Future<TicketReport> getReport(ReportQuery query) async =>
      TicketReport.fromJson(await _client.get(ApiEndpoints.reportTickets, query: query.toQuery()));

  @override
  Future<Uint8List> exportReport(ReportQuery query, String format) =>
      _client.getBytes(ApiEndpoints.exportTickets, query: {...query.toQuery(), 'format': format});

  // ---------------------------------------------------------------------

  /// Accepts a plain list or a paginated object.
  static List<Json> _list(Object? data) => asJsonList(data is List ? data : asJson(data)['items']);

  static String _mimeTypeOf(String fileName) {
    final name = fileName.toLowerCase();
    if (name.endsWith('.png')) return 'image/png';
    if (name.endsWith('.gif')) return 'image/gif';
    if (name.endsWith('.webp')) return 'image/webp';
    if (name.endsWith('.heic')) return 'image/heic';
    return 'image/jpeg';
  }
}
