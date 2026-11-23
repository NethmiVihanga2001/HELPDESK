import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../config.dart';
import '../models/app_notification.dart';
import '../models/attachment.dart';
import '../models/insights.dart';
import '../models/lookups.dart';
import '../models/page_result.dart';
import '../models/reply.dart';
import '../models/ticket.dart';
import '../models/user.dart';
import 'api_exception.dart';
import 'helpdesk_api.dart';
import 'token_storage.dart';

/// [HelpdeskApi] with fictional in-memory data (`--dart-define=USE_MOCK=true`).
///
/// It applies the SRS rules the backend must apply (section 7 permissions,
/// BR-1 to BR-7, REP-3), so the screens behave the same against the real
/// API. Data resets when the app restarts.
class MockHelpdeskApi implements HelpdeskApi {
  MockHelpdeskApi(this._tokens, {this.latency = const Duration(milliseconds: 300)}) {
    _seed();
  }

  /// Password of every demo account. Fictional, demo only.
  static const demoPassword = 'Demo@1234';

  /// Reset code the mock "emails" for any account (AUTH-3).
  static const demoResetCode = '123456';

  static const demoAccounts = <({String role, String email})>[
    (role: 'Customer', email: 'customer1@demo.test'),
    (role: 'Agent', email: 'agent1@demo.test'),
    (role: 'Admin', email: 'admin@demo.test'),
  ];

  final TokenStorage _tokens;
  final Duration latency;

  final _users = <_User>[];
  final _categories = <_Category>[];
  final _priorities = <_Priority>[];
  final _tickets = <_Ticket>[];
  final _notifications = <_Notification>[];
  final _articles = <_Article>[];
  final _templates = <ReplyTemplate>[];
  final _files = <String, Uint8List>{};
  final _resetRequests = <String>{};
  int _nextId = 1000;

  // ============================================================ 3.1 auth

  @override
  Future<AuthSession> login(String email, String password) async {
    await _delay();
    final user = _users.where((u) => u.email == email.trim().toLowerCase()).firstOrNull;
    if (user == null || password != user.password) {
      throw const ApiException('Invalid email or password', statusCode: 401);
    }
    if (!user.active) {
      throw const ApiException('This account has been deactivated. Contact your administrator.', statusCode: 401);
    }
    return AuthSession(
      accessToken: 'mock-access-${user.id}',
      refreshToken: 'mock-refresh-${user.id}',
      user: user.toModel(),
    );
  }

  @override
  Future<void> register({required String name, required String email, required String password}) async {
    await _delay();
    final normalized = email.trim().toLowerCase();
    if (_users.any((u) => u.email == normalized)) {
      throw const ApiException(
        'An account with this email already exists.',
        statusCode: 409,
        fieldErrors: {'email': 'An account with this email already exists.'},
      );
    }
    _users.add(_User(_id(), name.trim(), normalized, UserRole.customer, password));
  }

  @override
  Future<void> logout(String? refreshToken) => _delay();

  @override
  Future<void> requestPasswordReset(String email) async {
    await _delay();
    final user = _users.where((u) => u.email == email.trim().toLowerCase()).firstOrNull;
    if (user != null) _resetRequests.add(user.id);
  }

  @override
  Future<void> resetPassword({required String token, required String newPassword}) async {
    await _delay();
    if (token.trim() != demoResetCode || _resetRequests.isEmpty) {
      throw const ApiException('This reset code is invalid or has expired.', statusCode: 400);
    }
    if (newPassword.length < 8) {
      throw const ApiException('Please check the details and try again.',
          statusCode: 400, fieldErrors: {'password': 'Use at least 8 characters'});
    }
    for (final id in _resetRequests) {
      _users.firstWhere((u) => u.id == id).password = newPassword;
    }
    _resetRequests.clear(); // One-time use.
  }

  // ===================================== 3.2 profile, users, categories

  @override
  Future<AppUser> getProfile() async {
    await _delay();
    return (await _me()).toModel();
  }

  @override
  Future<AppUser> updateProfile({required String name}) async {
    await _delay();
    final me = await _me();
    _require(name.trim().isNotEmpty, 'name', 'Name is required');
    me.name = name.trim();
    return me.toModel();
  }

  @override
  Future<List<AppUser>> getUsers({UserRole? role}) async {
    await _delay();
    final me = await _me();
    // Agents may list agents (to reassign); everything else is Admin only.
    if (me.role != UserRole.admin && !(me.role == UserRole.agent && role == UserRole.agent)) {
      throw _forbidden;
    }
    return _users.where((u) => role == null || u.role == role).map((u) => u.toModel()).toList();
  }

  @override
  Future<AppUser> createUser({
    required String name,
    required String email,
    required String password,
    required UserRole role,
  }) async {
    await _delay();
    await _admin();
    final normalized = email.trim().toLowerCase();
    _require(name.trim().isNotEmpty, 'name', 'Name is required');
    _require(password.length >= 8, 'password', 'Use at least 8 characters');
    if (_users.any((u) => u.email == normalized)) {
      throw const ApiException('An account with this email already exists.',
          statusCode: 409, fieldErrors: {'email': 'An account with this email already exists.'});
    }
    final user = _User(_id(), name.trim(), normalized, role, password);
    _users.add(user);
    return user.toModel();
  }

  @override
  Future<AppUser> updateUser(String id, {String? name, UserRole? role, bool? active}) async {
    await _delay();
    final me = await _admin();
    final user = _users.where((u) => u.id == id).firstOrNull;
    if (user == null) throw const ApiException('User not found.', statusCode: 404);
    if (user.id == me.id && (active == false || (role != null && role != UserRole.admin))) {
      throw const ApiException('You cannot deactivate or demote your own account.', statusCode: 400);
    }
    if (name != null) user.name = name.trim();
    if (role != null) user.role = role;
    if (active != null) user.active = active; // Never deleted (USR-1).
    return user.toModel();
  }

  @override
  Future<List<TicketCategory>> getCategories({bool includeInactive = false}) async {
    await _delay();
    final me = await _me();
    if (includeInactive && me.role != UserRole.admin) throw _forbidden;
    return _categories.where((c) => includeInactive || c.active).map(_categoryModel).toList();
  }

  @override
  Future<TicketCategory> saveCategory({
    String? id,
    required String name,
    String? defaultAgentId,
    required bool active,
  }) async {
    await _delay();
    await _admin();
    _require(name.trim().isNotEmpty, 'name', 'Name is required');
    final duplicate = _categories.any((c) => c.id != id && c.name.toLowerCase() == name.trim().toLowerCase());
    if (duplicate) {
      throw const ApiException('A category with this name already exists.',
          statusCode: 409, fieldErrors: {'name': 'This name is already used'});
    }
    var category = _categories.where((c) => c.id == id).firstOrNull;
    if (category == null) {
      category = _Category(_id(), name.trim(), defaultAgentId);
      _categories.add(category);
    } else {
      category
        ..name = name.trim()
        ..defaultAgentId = defaultAgentId;
    }
    category.active = active;
    return _categoryModel(category);
  }

  @override
  Future<List<TicketPriority>> getPriorities() async {
    await _delay();
    await _me();
    return _priorities.map((p) => p.toModel()).toList();
  }

  @override
  Future<TicketPriority> updatePriority(String id, {required int responseHours, required int resolutionHours}) async {
    await _delay();
    await _admin();
    final p = _priorities.where((p) => p.id == id).firstOrNull;
    if (p == null) throw const ApiException('Priority not found.', statusCode: 404);
    _require(responseHours > 0, 'responseHours', 'Must be at least 1 hour');
    _require(resolutionHours >= responseHours, 'resolutionHours', 'Must be at least the response time');
    p
      ..responseHours = responseHours
      ..resolutionHours = resolutionHours;
    return p.toModel();
  }

  // ========================================================= 3.3 tickets

  @override
  Future<PageResult<Ticket>> getTickets({
    required int page,
    required int pageSize,
    TicketQuery query = const TicketQuery(),
  }) async {
    await _delay();
    final me = await _me();
    final search = query.search.trim().toLowerCase();
    final visible = _tickets.where((t) {
      final inScope = switch ((me.role, query.scope)) {
        (UserRole.customer, _) => t.customerId == me.id,
        (UserRole.agent, TicketScope.mine) => t.assignedAgentId == me.id,
        (UserRole.admin, TicketScope.mine) => true,
        (_, TicketScope.queue) => t.assignedAgentId == null && !t.status.isDone,
      };
      if (!inScope) return false;
      if (query.status != null && t.status != query.status) return false;
      if (query.priorityId != null && t.priorityId != query.priorityId) return false;
      if (query.categoryId != null && t.categoryId != query.categoryId) return false;
      if (query.from != null && t.createdAt.isBefore(query.from!.toUtc())) return false;
      if (query.to != null && t.createdAt.isAfter(query.to!.toUtc())) return false;
      if (search.isNotEmpty &&
          !t.title.toLowerCase().contains(search) &&
          !t.number.toLowerCase().contains(search) &&
          !t.description.toLowerCase().contains(search)) {
        return false;
      }
      return true;
    }).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    final start = (page - 1) * pageSize;
    return PageResult(
      items: visible.skip(start).take(pageSize).map((t) => _ticketModel(t, me, summary: true)).toList(),
      page: page,
      hasMore: start + pageSize < visible.length,
    );
  }

  @override
  Future<Ticket> getTicket(String id) async {
    await _delay();
    final me = await _me();
    return _ticketModel(_find(me, id), me);
  }

  @override
  Future<Ticket> createTicket({
    required String title,
    required String description,
    required String categoryId,
    required String priorityId,
  }) async {
    await _delay();
    final me = await _me();
    final category = _categories.where((c) => c.id == categoryId && c.active).firstOrNull;
    final errors = <String, String>{
      if (title.trim().length < 5 || title.trim().length > 150) 'title': 'Title must be 5 to 150 characters',
      if (description.trim().isEmpty) 'description': 'Description is required',
      if (category == null) 'categoryId': 'Choose a category',
      if (!_priorities.any((p) => p.id == priorityId)) 'priorityId': 'Choose a priority',
    };
    if (errors.isNotEmpty) {
      throw ApiException('Please check the details and try again.', statusCode: 400, fieldErrors: errors);
    }
    final ticket = _Ticket(
      id: _id(),
      number: _nextTicketNumber(),
      title: title.trim(),
      description: description.trim(),
      customerId: me.id,
      categoryId: categoryId,
      priorityId: priorityId,
      status: TicketStatus.open,
      createdAt: _now(),
    );
    _tickets.add(ticket);
    // ASG-4: assign to the category's default agent.
    final agent = _users.where((u) => u.id == category!.defaultAgentId && u.active).firstOrNull;
    if (agent != null) {
      ticket.assignedAgentId = agent.id;
      ticket.history.add(_History('assignedAgent', null, agent.name, me.id, ticket.createdAt));
      _notify(agent.id, ticket, '${ticket.number} was assigned to you');
    }
    return _ticketModel(ticket, me);
  }

  @override
  Future<void> changeStatus(String ticketId, TicketStatus status) async {
    await _delay();
    final me = await _me();
    final ticket = _find(me, ticketId);
    if (!_canWork(me, ticket)) throw _forbidden;
    _ensureEditable(ticket);
    if (ticket.status == status) return;
    _setStatus(ticket, status, me);
    _notify(ticket.customerId, ticket, '${ticket.number} is now ${status.label}');
  }

  @override
  Future<void> reopenTicket(String ticketId) async {
    await _delay();
    final me = await _me();
    final ticket = _find(me, ticketId);
    if (ticket.customerId != me.id) throw _forbidden;
    if (ticket.status != TicketStatus.resolved) {
      throw const ApiException('Only a Resolved ticket can be reopened.', statusCode: 400);
    }
    _setStatus(ticket, TicketStatus.open, me);
    final agentId = ticket.assignedAgentId;
    if (agentId != null) _notify(agentId, ticket, '${me.name} reopened ${ticket.number}');
  }

  @override
  Future<void> rateTicket(String ticketId, {required int rating, String? comment}) async {
    await _delay();
    final me = await _me();
    final ticket = _find(me, ticketId);
    if (ticket.customerId != me.id) throw _forbidden;
    if (!ticket.status.isDone) {
      throw const ApiException('You can rate a ticket once it is resolved.', statusCode: 400);
    }
    if (ticket.rating != null) throw const ApiException('This ticket is already rated.', statusCode: 409);
    _require(rating >= 1 && rating <= 5, 'rating', 'Choose 1 to 5 stars');
    ticket
      ..rating = rating
      ..ratingComment = (comment?.trim().isEmpty ?? true) ? null : comment!.trim();
  }

  @override
  Future<Attachment> uploadAttachment(String ticketId, {required String filePath, required String fileName}) async {
    await _delay();
    final me = await _me();
    final ticket = _find(me, ticketId);
    _ensureEditable(ticket);
    final bytes = await File(filePath).readAsBytes();
    if (bytes.length > AppConfig.maxAttachmentBytes) {
      throw const ApiException('The file is too large. The limit is 5 MB.', statusCode: 400);
    }
    final attachment = _Attachment(_id(), fileName, me.id, _now());
    _files[attachment.id] = bytes;
    ticket
      ..attachments.add(attachment)
      ..updatedAt = attachment.uploadedAt;
    return _attachmentModel(attachment);
  }

  @override
  Future<Uint8List> downloadAttachment(String attachmentId) async {
    await _delay();
    await _me();
    final bytes = _files[attachmentId];
    if (bytes == null) throw const ApiException('File not found.', statusCode: 404);
    return bytes;
  }

  // ====================================================== 3.4 assignment

  @override
  Future<void> assignTicket(String ticketId, String agentId) async {
    await _delay();
    final me = await _me();
    final ticket = _find(me, ticketId);
    _ensureEditable(ticket);
    final agent = _users.where((u) => u.id == agentId && u.role == UserRole.agent && u.active).firstOrNull;
    if (agent == null) throw const ApiException('Only active agents can be assigned.', statusCode: 400);
    final allowed = switch (me.role) {
      UserRole.admin => true,
      // Take from the queue (ASG-2) or reassign own ticket (ASG-3).
      UserRole.agent => (ticket.assignedAgentId == null && agentId == me.id) || ticket.assignedAgentId == me.id,
      UserRole.customer => false,
    };
    if (!allowed) throw _forbidden;
    if (ticket.assignedAgentId == agentId) return;
    final old = ticket.assignedAgentId == null ? null : _user(ticket.assignedAgentId!).name;
    ticket
      ..assignedAgentId = agentId
      ..updatedAt = _now()
      ..history.add(_History('assignedAgent', old, agent.name, me.id, _now()));
    if (agentId != me.id) _notify(agentId, ticket, '${ticket.number} was assigned to you');
  }

  // ========================================== 3.5 replies and templates

  @override
  Future<TicketReply> addReply(String ticketId, {required String message, bool isInternal = false}) async {
    await _delay();
    final me = await _me();
    final ticket = _find(me, ticketId);
    _require(message.trim().isNotEmpty, 'message', 'Message is required');
    if (isInternal && !me.role.isStaff) {
      throw const ApiException('Customers cannot post internal notes.', statusCode: 403);
    }
    if (me.role == UserRole.agent && ticket.assignedAgentId != me.id) {
      throw const ApiException('Take this ticket before replying to it.', statusCode: 403);
    }
    _ensureEditable(ticket);

    final reply = _Reply(_id(), me.id, message.trim(), isInternal, _now());
    ticket
      ..replies.add(reply)
      ..updatedAt = reply.createdAt;

    if (!me.role.isStaff) {
      // REP-4: a customer reply moves "Waiting for Customer" back to "In Progress".
      if (ticket.status == TicketStatus.waitingForCustomer) _setStatus(ticket, TicketStatus.inProgress, me);
      final agentId = ticket.assignedAgentId;
      if (agentId != null) _notify(agentId, ticket, '${me.name} replied to ${ticket.number}');
    } else if (!isInternal) {
      _notify(ticket.customerId, ticket, '${me.name} replied to ${ticket.number}');
    }
    return _replyModel(reply);
  }

  @override
  Future<List<ReplyTemplate>> getReplyTemplates() async {
    await _delay();
    if (!(await _me()).role.isStaff) throw _forbidden;
    return List.of(_templates);
  }

  @override
  Future<ReplyTemplate> createReplyTemplate({required String title, required String body}) async {
    await _delay();
    if (!(await _me()).role.isStaff) throw _forbidden;
    _require(title.trim().isNotEmpty, 'title', 'Title is required');
    _require(body.trim().isNotEmpty, 'body', 'Text is required');
    final template = ReplyTemplate(id: _id(), title: title.trim(), body: body.trim());
    _templates.add(template);
    return template;
  }

  // =================================================== 3.7 notifications

  @override
  Future<List<AppNotification>> getNotifications() async {
    await _delay();
    final me = await _me();
    final mine = _notifications.where((n) => n.userId == me.id).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return mine
        .map((n) => AppNotification(
              id: n.id,
              message: n.message,
              isRead: n.isRead,
              ticketId: n.ticketId,
              createdAt: n.createdAt.toLocal(),
            ))
        .toList();
  }

  @override
  Future<void> markNotificationRead(String id) async {
    await _delay();
    final me = await _me();
    final n = _notifications.where((n) => n.id == id && n.userId == me.id).firstOrNull;
    if (n == null) throw const ApiException('Notification not found.', statusCode: 404);
    n.isRead = true;
  }

  // ================================================== 3.8 knowledge base

  @override
  Future<List<Article>> getArticles({String search = ''}) async {
    await _delay();
    final me = await _me();
    final q = search.trim().toLowerCase();
    final words = q.split(RegExp(r'\s+')).where((w) => w.length > 2).toList();
    final list = _articles.where((a) {
      if (!a.published && !me.role.isStaff) return false; // KB-2: customers read published only.
      if (q.isEmpty) return true;
      final text = '${a.title} ${a.body}'.toLowerCase();
      return text.contains(q) || words.any(text.contains);
    }).toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return list.map(_articleModel).toList();
  }

  @override
  Future<Article> getArticle(String id) async {
    await _delay();
    final me = await _me();
    final article = _articles.where((a) => a.id == id && (a.published || me.role.isStaff)).firstOrNull;
    if (article == null) throw const ApiException('Article not found.', statusCode: 404);
    return _articleModel(article);
  }

  @override
  Future<Article> saveArticle({
    String? id,
    required String title,
    required String body,
    String? categoryId,
    required bool published,
  }) async {
    await _delay();
    final me = await _me();
    if (!me.role.isStaff) throw _forbidden;
    _require(title.trim().length >= 5, 'title', 'Use at least 5 characters');
    _require(body.trim().isNotEmpty, 'body', 'Write the article text');
    var article = _articles.where((a) => a.id == id).firstOrNull;
    if (article != null && article.published && !published && me.role != UserRole.admin) {
      throw const ApiException('Only an Admin can unpublish an article.', statusCode: 403); // KB-4
    }
    if (article == null) {
      article = _Article(_id(), title.trim(), body.trim(), categoryId, me.id, published, _now());
      _articles.add(article);
    } else {
      article
        ..title = title.trim()
        ..body = body.trim()
        ..categoryId = categoryId
        ..published = published
        ..updatedAt = _now();
    }
    return _articleModel(article);
  }

  // ========================================== 3.9 dashboard and reports

  @override
  Future<DashboardSummary> getDashboard() async {
    await _delay();
    final me = await _me();
    final scope = _tickets.where((t) => switch (me.role) {
          UserRole.customer => t.customerId == me.id,
          UserRole.agent => t.assignedAgentId == me.id,
          UserRole.admin => true,
        });
    final midnight = DateTime.now().copyWith(hour: 0, minute: 0, second: 0, millisecond: 0, microsecond: 0).toUtc();
    final agents = _users.where((u) => u.role == UserRole.agent && u.active);
    return DashboardSummary(
      byStatus: {for (final s in TicketStatus.values) s: scope.where((t) => t.status == s).length},
      newToday: scope.where((t) => t.createdAt.isAfter(midnight)).length,
      unassigned: me.role.isStaff ? _tickets.where((t) => t.assignedAgentId == null && !t.status.isDone).length : 0,
      overdue: scope.where(_isOverdue).length,
      averageResolutionHours: _averageResolution(scope),
      workload: [
        for (final a in me.role == UserRole.admin ? agents : agents.where((a) => a.id == me.id))
          AgentWorkload(
            name: a.name,
            openTickets: _tickets.where((t) => t.assignedAgentId == a.id && !t.status.isDone).length,
          ),
      ],
    );
  }

  @override
  Future<TicketReport> getReport(ReportQuery query) async {
    await _delay();
    return TicketReport(
      rows: [for (final t in await _reportTickets(query)) _ticketModel(t, await _me(), summary: true)],
      averageResolutionHours: _averageResolution(await _reportTickets(query)),
    );
  }

  @override
  Future<Uint8List> exportReport(ReportQuery query, String format) async {
    await _delay();
    final rows = await _reportTickets(query);
    String cell(String v) => '"${v.replaceAll('"', '""')}"';
    final csv = StringBuffer('Ticket,Title,Status,Priority,Category,Agent,Customer,Created\n');
    for (final t in rows) {
      csv.writeln([
        t.number,
        t.title,
        t.status.label,
        _priority(t.priorityId).name,
        _category(t.categoryId).name,
        t.assignedAgentId == null ? '' : _user(t.assignedAgentId!).name,
        _user(t.customerId).name,
        t.createdAt.toLocal().toIso8601String(),
      ].map(cell).join(','));
    }
    return Uint8List.fromList(utf8.encode(csv.toString()));
  }

  Future<List<_Ticket>> _reportTickets(ReportQuery q) async {
    final me = await _me();
    if (!me.role.isStaff) throw _forbidden;
    return _tickets.where((t) {
      if (me.role == UserRole.agent && t.assignedAgentId != me.id) return false; // Agent: own.
      if (q.agentId != null && t.assignedAgentId != q.agentId) return false;
      if (q.status != null && t.status != q.status) return false;
      if (q.categoryId != null && t.categoryId != q.categoryId) return false;
      if (q.priorityId != null && t.priorityId != q.priorityId) return false;
      if (q.from != null && t.createdAt.isBefore(q.from!.toUtc())) return false;
      if (q.to != null && t.createdAt.isAfter(q.to!.add(const Duration(days: 1)).toUtc())) return false;
      return true;
    }).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  }

  // ============================================================ helpers

  static const _forbidden = ApiException("You don't have permission to do that.", statusCode: 403);

  Future<void> _delay() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
  }

  DateTime _now() => DateTime.now().toUtc();
  String _id() => '${_nextId++}';
  String _nextTicketNumber() => 'TKT-${(_tickets.length + 1).toString().padLeft(4, '0')}';

  void _require(bool ok, String field, String message) {
    if (!ok) {
      throw ApiException('Please check the details and try again.', statusCode: 400, fieldErrors: {field: message});
    }
  }

  Future<_User> _me() async {
    final token = await _tokens.readAccessToken();
    final id = token?.replaceFirst('mock-access-', '');
    final user = _users.where((u) => u.id == id && u.active).firstOrNull;
    if (user == null) {
      throw const ApiException('Your session has expired. Please log in again.', statusCode: 401);
    }
    return user;
  }

  Future<_User> _admin() async {
    final me = await _me();
    if (me.role != UserRole.admin) throw _forbidden;
    return me;
  }

  _User _user(String id) => _users.firstWhere((u) => u.id == id);
  _Category _category(String id) => _categories.firstWhere((c) => c.id == id);
  _Priority _priority(String id) => _priorities.firstWhere((p) => p.id == id);

  /// Section 7: customers see their own tickets, agents assigned ones and the
  /// queue, admins everything.
  bool _canSee(_User me, _Ticket t) => switch (me.role) {
        UserRole.customer => t.customerId == me.id,
        UserRole.agent => t.assignedAgentId == me.id || t.assignedAgentId == null,
        UserRole.admin => true,
      };

  /// Status changes: agents on assigned tickets, admins on all.
  bool _canWork(_User me, _Ticket t) =>
      me.role == UserRole.admin || (me.role == UserRole.agent && t.assignedAgentId == me.id);

  _Ticket _find(_User me, String id) {
    final ticket = _tickets.where((t) => t.id == id).firstOrNull;
    if (ticket == null) throw const ApiException('Ticket not found.', statusCode: 404);
    if (!_canSee(me, ticket)) {
      throw const ApiException("You don't have permission to view this ticket.", statusCode: 403);
    }
    return ticket;
  }

  void _ensureEditable(_Ticket ticket) {
    if (ticket.status == TicketStatus.closed) {
      throw const ApiException('A closed ticket cannot be edited.', statusCode: 400);
    }
  }

  /// TKT-4 / NFR-8: every status change is saved with who and when.
  void _setStatus(_Ticket ticket, TicketStatus status, _User by) {
    ticket.history.add(_History('status', ticket.status.apiValue, status.apiValue, by.id, _now()));
    ticket
      ..status = status
      ..updatedAt = _now()
      ..resolvedAt = status == TicketStatus.resolved ? _now() : (status.isDone ? ticket.resolvedAt : null);
  }

  void _notify(String userId, _Ticket ticket, String message) {
    _notifications.add(_Notification(_id(), userId, ticket.id, message, _now()));
  }

  DateTime _dueAt(_Ticket t) => t.createdAt.add(Duration(hours: _priority(t.priorityId).resolutionHours));

  /// BR-4: overdue when past its due time and not yet Resolved.
  bool _isOverdue(_Ticket t) => !t.status.isDone && _now().isAfter(_dueAt(t));

  double? _averageResolution(Iterable<_Ticket> tickets) {
    final done = tickets.where((t) => t.resolvedAt != null).toList();
    if (done.isEmpty) return null;
    final hours = done.map((t) => t.resolvedAt!.difference(t.createdAt).inMinutes / 60);
    return hours.reduce((a, b) => a + b) / done.length;
  }

  PersonRef _person(String id) {
    final u = _user(id);
    return PersonRef(id: u.id, name: u.name, role: u.role);
  }

  TicketCategory _categoryModel(_Category c) => TicketCategory(
        id: c.id,
        name: c.name,
        active: c.active,
        defaultAgent: c.defaultAgentId == null ? null : _person(c.defaultAgentId!),
      );

  Ticket _ticketModel(_Ticket t, _User viewer, {bool summary = false}) {
    final replies = t.replies.where((r) => viewer.role.isStaff || !r.isInternal); // REP-3
    return Ticket(
      id: t.id,
      number: t.number,
      title: t.title,
      description: t.description,
      status: t.status,
      categoryId: t.categoryId,
      categoryName: _category(t.categoryId).name,
      priorityId: t.priorityId,
      priorityName: _priority(t.priorityId).name,
      customer: _person(t.customerId),
      assignedAgent: t.assignedAgentId == null ? null : _person(t.assignedAgentId!),
      createdAt: t.createdAt.toLocal(),
      updatedAt: t.updatedAt.toLocal(),
      dueAt: _dueAt(t).toLocal(),
      resolvedAt: t.resolvedAt?.toLocal(),
      isOverdue: _isOverdue(t),
      rating: t.rating,
      ratingComment: t.ratingComment,
      replies: summary ? const [] : replies.map(_replyModel).toList(),
      attachments: summary ? const [] : t.attachments.map(_attachmentModel).toList(),
      history: summary
          ? const []
          : [
              for (final h in t.history)
                TicketHistoryEntry(
                  field: h.field,
                  oldValue: h.oldValue,
                  newValue: h.newValue,
                  changedBy: _person(h.byId),
                  changedAt: h.at.toLocal(),
                ),
            ],
    );
  }

  TicketReply _replyModel(_Reply r) => TicketReply(
        id: r.id,
        message: r.message,
        isInternal: r.isInternal,
        author: _person(r.authorId),
        createdAt: r.createdAt.toLocal(),
      );

  Attachment _attachmentModel(_Attachment a) => Attachment(
        id: a.id,
        fileName: a.fileName,
        uploadedAt: a.uploadedAt.toLocal(),
        uploadedByName: _user(a.uploadedById).name,
      );

  Article _articleModel(_Article a) => Article(
        id: a.id,
        title: a.title,
        body: a.body,
        published: a.published,
        categoryId: a.categoryId,
        categoryName: a.categoryId == null ? null : _category(a.categoryId!).name,
        author: _person(a.authorId),
        updatedAt: a.updatedAt.toLocal(),
      );

  // =============================================================== seed

  void _seed() {
    _users.addAll([
      _User('1', 'Dana Admin', 'admin@demo.test', UserRole.admin, demoPassword),
      _User('2', 'Ari Agent', 'agent1@demo.test', UserRole.agent, demoPassword),
      _User('3', 'Blake Agent', 'agent2@demo.test', UserRole.agent, demoPassword),
      _User('4', 'Casey Customer', 'customer1@demo.test', UserRole.customer, demoPassword),
      _User('5', 'Drew Customer', 'customer2@demo.test', UserRole.customer, demoPassword),
      _User('6', 'Emery Customer', 'customer3@demo.test', UserRole.customer, demoPassword),
      _User('7', 'Finley Former', 'former.agent@demo.test', UserRole.agent, demoPassword)..active = false,
    ]);
    _categories.addAll([
      _Category('1', 'Technical', '2'),
      _Category('2', 'Billing', '3'),
      _Category('3', 'Account', '2'),
      _Category('4', 'General', null),
    ]);
    _priorities.addAll([
      _Priority('1', 'Low', 24, 72),
      _Priority('2', 'Medium', 8, 24),
      _Priority('3', 'High', 2, 8),
      _Priority('4', 'Urgent', 1, 4),
    ]);

    final now = _now();
    DateTime ago({int days = 0, int hours = 0, int minutes = 0}) =>
        now.subtract(Duration(days: days, hours: hours, minutes: minutes));

    _Ticket add(String title, String description,
        {required String customer,
        required String category,
        required String priority,
        required TicketStatus status,
        required DateTime created,
        String? agent}) {
      final t = _Ticket(
        id: _id(),
        number: _nextTicketNumber(),
        title: title,
        description: description,
        customerId: customer,
        categoryId: category,
        priorityId: priority,
        status: status,
        createdAt: created,
        assignedAgentId: agent,
      );
      if (agent != null) t.history.add(_History('assignedAgent', null, _user(agent).name, '1', created.add(const Duration(minutes: 10))));
      _tickets.add(t);
      return t;
    }

    void reply(_Ticket t, String author, String message, DateTime at, {bool internal = false}) {
      t.replies.add(_Reply(_id(), author, message, internal, at));
      if (at.isAfter(t.updatedAt)) t.updatedAt = at;
    }

    void moved(_Ticket t, TicketStatus from, TicketStatus to, String by, DateTime at) {
      t.history.add(_History('status', from.apiValue, to.apiValue, by, at));
      if (to == TicketStatus.resolved) t.resolvedAt = at;
      if (at.isAfter(t.updatedAt)) t.updatedAt = at;
    }

    final t1 = add('Cannot log in to the customer portal',
        'Since this morning I get "Invalid email or password" even after resetting my password.',
        customer: '4', category: '1', priority: '3', agent: '2', status: TicketStatus.inProgress, created: ago(days: 2));
    moved(t1, TicketStatus.open, TicketStatus.inProgress, '2', ago(days: 1, hours: 21));
    reply(t1, '2', 'Thanks for reporting this. We are checking your account now.', ago(days: 1, hours: 20));
    reply(t1, '2', 'Account was locked after 5 failed attempts. Unlocking after identity check.', ago(days: 1, hours: 19),
        internal: true);

    final t2 = add('Invoice shows the wrong amount', 'My November invoice is higher than my plan price.',
        customer: '4', category: '2', priority: '2', agent: '3', status: TicketStatus.waitingForCustomer, created: ago(days: 1));
    moved(t2, TicketStatus.open, TicketStatus.inProgress, '3', ago(hours: 21));
    reply(t2, '3', 'Could you send us the invoice number so we can check it?', ago(hours: 20));
    moved(t2, TicketStatus.inProgress, TicketStatus.waitingForCustomer, '3', ago(hours: 20));

    final t3 = add('How do I change my email address?', 'I want to use my new work email for this account.',
        customer: '4', category: '3', priority: '1', agent: '2', status: TicketStatus.resolved, created: ago(days: 5));
    reply(t3, '2', 'Open Profile, edit your email and confirm the link we send you.', ago(days: 4));
    reply(t3, '4', 'That worked, thank you!', ago(days: 3, hours: 22));
    moved(t3, TicketStatus.open, TicketStatus.resolved, '2', ago(days: 3, hours: 20));

    final t4 = add('App crashes when uploading a file', 'The app closes as soon as I choose a PDF to upload.',
        customer: '5', category: '1', priority: '4', agent: '2', status: TicketStatus.open, created: ago(hours: 6));
    add('Request for a refund', 'I was charged twice for the same month.',
        customer: '5', category: '2', priority: '3', status: TicketStatus.open, created: ago(hours: 1));
    final t6 = add('Password reset email not received', 'I requested a reset link twice but nothing arrived.',
        customer: '6', category: '3', priority: '2', agent: '3', status: TicketStatus.inProgress, created: ago(hours: 20));
    moved(t6, TicketStatus.open, TicketStatus.inProgress, '3', ago(hours: 19));
    reply(t6, '3', 'Mail log shows the address bounced. Ask customer to check spelling.', ago(hours: 18), internal: true);

    final t7 = add('Question about monthly reports', 'Can I get the ticket report as a spreadsheet?',
        customer: '6', category: '4', priority: '1', agent: '2', status: TicketStatus.closed, created: ago(days: 9));
    reply(t7, '2', 'Yes, use the Export button on the Reports page.', ago(days: 8));
    moved(t7, TicketStatus.open, TicketStatus.resolved, '2', ago(days: 8));
    moved(t7, TicketStatus.resolved, TicketStatus.closed, '1', ago(days: 1));

    final t8 = add('Two-factor authentication setup', 'How do I turn on two-factor authentication?',
        customer: '4', category: '3', priority: '2', agent: '2', status: TicketStatus.open, created: ago(minutes: 30));
    final t9 = add('Dashboard pages load slowly', 'The dashboard takes more than 10 seconds to open.',
        customer: '5', category: '1', priority: '2', agent: '3', status: TicketStatus.resolved, created: ago(days: 4));
    moved(t9, TicketStatus.open, TicketStatus.resolved, '3', ago(days: 3, hours: 6));
    t9
      ..rating = 5
      ..ratingComment = 'Quick fix, thanks!';
    final t10 = add('Update company billing address', 'Our office moved. Please update the address on invoices.',
        customer: '6', category: '2', priority: '1', agent: '2', status: TicketStatus.waitingForCustomer, created: ago(days: 2));
    reply(t10, '2', 'Please send the new address including the postcode.', ago(days: 1));
    moved(t10, TicketStatus.open, TicketStatus.waitingForCustomer, '2', ago(days: 1));
    add('Cannot download my invoice as PDF', 'The download button does nothing on the billing page.',
        customer: '4', category: '2', priority: '2', status: TicketStatus.open, created: ago(hours: 3));
    add('Wrong time zone on ticket emails', 'All times in the emails are 5 hours behind.',
        customer: '6', category: '4', priority: '1', status: TicketStatus.open, created: ago(minutes: 50));

    _articles.addAll([
      _Article(_id(), 'How to reset your password',
          'Tap "Forgot password?" on the login screen and enter the email you sign in with.\n\n'
              'We send you a one-time reset link. It works once and expires after a short time. '
              'Open it and choose a new password of at least 8 characters.\n\n'
              'No email? Check your spam folder, then raise a ticket in the Account category.',
          '3', '2', true, ago(days: 12)),
      _Article(_id(), 'Understanding your invoice',
          'Your invoice lists your plan, any extra seats and taxes.\n\n'
              'If an amount looks wrong, raise a ticket in the Billing category and include the invoice number '
              'from the top right corner of the invoice.',
          '2', '3', true, ago(days: 20)),
      _Article(_id(), 'Setting up two-factor authentication',
          'Two-factor authentication adds a second step when you sign in.\n\n'
              '1. Open Profile and choose Security.\n2. Scan the code with an authenticator app.\n'
              '3. Enter the 6-digit code to confirm.\n\nKeep your backup codes somewhere safe.',
          '3', '2', true, ago(days: 6)),
      _Article(_id(), 'Uploading files and screenshots to a ticket',
          'Add a photo when you create a ticket, or later from the ticket screen.\n\n'
              'Images and PDF files up to 5 MB are accepted. A screenshot of the error helps us solve it faster.',
          '1', '2', true, ago(days: 3)),
      _Article(_id(), 'Troubleshooting slow dashboard loading',
          'Draft: clear the browser cache, check the network, then collect the time it takes to load.',
          '1', '3', false, ago(days: 1)),
    ]);
    _templates.addAll(const [
      ReplyTemplate(id: 't1', title: 'Ask for a screenshot',
          body: 'Thanks for the details. Could you send a screenshot of the error so we can look into it?'),
      ReplyTemplate(id: 't2', title: 'Issue resolved',
          body: 'We have fixed the issue. Please check and let us know if anything is still not working.'),
      ReplyTemplate(id: 't3', title: 'Passed to billing',
          body: 'I have passed this to our billing team. We will update you within one working day.'),
    ]);
    _notifications.addAll([
      _Notification(_id(), '4', t1.id, 'Ari Agent replied to ${t1.number}', ago(days: 1, hours: 20)),
      _Notification(_id(), '4', t2.id, '${t2.number} is now Waiting for Customer', ago(hours: 20)),
      _Notification(_id(), '4', t3.id, '${t3.number} is now Resolved', ago(days: 3, hours: 20))..isRead = true,
      _Notification(_id(), '2', t4.id, '${t4.number} was assigned to you', ago(hours: 6)),
      _Notification(_id(), '2', t8.id, '${t8.number} was assigned to you', ago(minutes: 30)),
      _Notification(_id(), '2', t10.id, '${t10.number} is overdue', ago(minutes: 10)),
      _Notification(_id(), '1', t4.id, '${t4.number} is overdue', ago(minutes: 20)),
    ]);
  }
}

class _User {
  _User(this.id, this.name, this.email, this.role, this.password);

  final String id;
  String name;
  final String email;
  UserRole role;
  String password;
  bool active = true;

  AppUser toModel() => AppUser(id: id, name: name, email: email, role: role, active: active);
}

class _Category {
  _Category(this.id, this.name, this.defaultAgentId);

  final String id;
  String name;
  String? defaultAgentId;
  bool active = true;
}

class _Priority {
  _Priority(this.id, this.name, this.responseHours, this.resolutionHours);

  final String id;
  final String name;
  int responseHours;
  int resolutionHours;

  TicketPriority toModel() =>
      TicketPriority(id: id, name: name, responseHours: responseHours, resolutionHours: resolutionHours);
}

class _Ticket {
  _Ticket({
    required this.id,
    required this.number,
    required this.title,
    required this.description,
    required this.customerId,
    required this.categoryId,
    required this.priorityId,
    required this.status,
    required this.createdAt,
    this.assignedAgentId,
  }) : updatedAt = createdAt;

  final String id;
  final String number;
  final String title;
  final String description;
  final String customerId;
  final String categoryId;
  final String priorityId;
  final DateTime createdAt;
  String? assignedAgentId;
  TicketStatus status;
  DateTime updatedAt;
  DateTime? resolvedAt;
  int? rating;
  String? ratingComment;
  final replies = <_Reply>[];
  final attachments = <_Attachment>[];
  final history = <_History>[];
}

class _History {
  _History(this.field, this.oldValue, this.newValue, this.byId, this.at);

  final String field;
  final String? oldValue;
  final String? newValue;
  final String byId;
  final DateTime at;
}

class _Reply {
  _Reply(this.id, this.authorId, this.message, this.isInternal, this.createdAt);

  final String id;
  final String authorId;
  final String message;
  final bool isInternal;
  final DateTime createdAt;
}

class _Attachment {
  _Attachment(this.id, this.fileName, this.uploadedById, this.uploadedAt);

  final String id;
  final String fileName;
  final String uploadedById;
  final DateTime uploadedAt;
}

class _Article {
  _Article(this.id, this.title, this.body, this.categoryId, this.authorId, this.published, this.updatedAt);

  final String id;
  String title;
  String body;
  String? categoryId;
  final String authorId;
  bool published;
  DateTime updatedAt;
}

class _Notification {
  _Notification(this.id, this.userId, this.ticketId, this.message, this.createdAt);

  final String id;
  final String userId;
  final String ticketId;
  final String message;
  final DateTime createdAt;
  bool isRead = false;
}
