/// Every backend path the app calls, in one place.
///
/// Keep this in sync with the API contract in `docs/` (owned by Backend 3).
/// If an endpoint changes, this is the only file that needs editing.
///
/// The mobile contract (`/api/mobile`) covers the core flows. The SRS
/// features beyond it (dashboard, queue, assignment, reopen, rating,
/// templates, knowledge base, reports, admin) use the shared web endpoints
/// from the same contract, with the same login token.
class ApiEndpoints {
  ApiEndpoints._();

  // Mobile authentication (access + refresh token).
  static const login = '/api/mobile/auth/login';
  static const refresh = '/api/mobile/auth/refresh';
  static const logout = '/api/mobile/auth/logout';

  // Shared with the web app.
  static const register = '/api/auth/register';
  static const forgotPassword = '/api/auth/forgot-password';
  static const resetPassword = '/api/auth/reset-password';

  static const profile = '/api/mobile/profile';

  // Tickets (mobile contract).
  static const tickets = '/api/mobile/tickets';
  static String ticket(String id) => '$tickets/${_seg(id)}';
  static String ticketReplies(String id) => '${ticket(id)}/replies';
  static String ticketAttachments(String id) => '${ticket(id)}/attachments';
  static String ticketStatus(String id) => '${ticket(id)}/status';

  // Tickets (shared web contract).
  static String ticketAssign(String id) => '/api/tickets/${_seg(id)}/assign';
  static String ticketReopen(String id) => '/api/tickets/${_seg(id)}/reopen';
  static String ticketRating(String id) => '/api/tickets/${_seg(id)}/rating';
  static String attachment(String id) => '/api/attachments/${_seg(id)}';

  static const categories = '/api/mobile/categories';
  static const priorities = '/api/mobile/priorities';

  static const notifications = '/api/mobile/notifications';
  static String notificationRead(String id) => '$notifications/${_seg(id)}/read';

  // Shared web contract: dashboard, reports, knowledge base, templates, admin.
  static const dashboard = '/api/dashboard/summary';
  static const reportTickets = '/api/reports/tickets';
  static const exportTickets = '/api/export/tickets';
  static const articles = '/api/articles';
  static String article(String id) => '$articles/${_seg(id)}';
  static const replyTemplates = '/api/reply-templates';
  static const users = '/api/users';
  static String user(String id) => '$users/${_seg(id)}';
  static const adminCategories = '/api/categories';
  static String adminCategory(String id) => '$adminCategories/${_seg(id)}';
  static const adminPriorities = '/api/priorities';
  static String adminPriority(String id) => '$adminPriorities/${_seg(id)}';

  static String _seg(String id) => Uri.encodeComponent(id);
}
