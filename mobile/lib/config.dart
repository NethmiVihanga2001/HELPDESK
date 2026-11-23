/// Build-time settings, passed with `--dart-define`.
///
/// ```sh
/// # Real backend (Android emulator reaches the PC through 10.0.2.2)
/// flutter run --dart-define=API_BASE_URL=http://10.0.2.2:5000
///
/// # Fictional in-memory data, until the /api/mobile endpoints are ready
/// flutter run --dart-define=USE_MOCK=true
/// ```
///
/// No secrets belong here: everything compiled into the APK can be read.
class AppConfig {
  AppConfig._();

  /// Address of the HelpDesk Pro backend, without a trailing slash.
  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'http://10.0.2.2:5000',
  );

  /// When true the app uses in-memory fictional data instead of the backend.
  static const bool useMock = bool.fromEnvironment('USE_MOCK');

  /// Tickets requested per page from `GET /api/mobile/tickets`.
  static const int ticketPageSize = 20;

  /// Attachment limit from the validation rules (images and PDF up to 5 MB).
  static const int maxAttachmentBytes = 5 * 1024 * 1024;

  /// How often the notification badge is refreshed while the app is open.
  /// Replaced by push notifications if extra feature E8 is built.
  static const Duration notificationPollInterval = Duration(seconds: 60);
}
