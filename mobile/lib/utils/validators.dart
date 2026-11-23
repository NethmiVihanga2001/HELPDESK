/// Form validators matching the validation rules in the delivery plan
/// (section 13). The backend validates again; these give quick feedback.
class Validators {
  Validators._();

  static final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  static String? email(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your email';
    if (!_emailPattern.hasMatch(v)) return 'Enter a valid email address';
    return null;
  }

  /// For login: only required, so the length rule is not revealed here.
  static String? loginPassword(String? value) =>
      (value == null || value.isEmpty) ? 'Enter your password' : null;

  /// For new passwords: at least 8 characters (AUTH-2).
  static String? newPassword(String? value) {
    if (value == null || value.isEmpty) return 'Enter a password';
    if (value.length < 8) return 'Use at least 8 characters';
    return null;
  }

  static String? name(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter your name';
    if (v.length > 100) return 'Use 100 characters or fewer';
    return null;
  }

  /// Title is required, 5 to 150 characters.
  static String? ticketTitle(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty) return 'Enter a title';
    if (v.length < 5) return 'Use at least 5 characters';
    if (v.length > 150) return 'Use 150 characters or fewer';
    return null;
  }

  static String? ticketDescription(String? value) =>
      (value?.trim() ?? '').isEmpty ? 'Describe the problem' : null;
}
