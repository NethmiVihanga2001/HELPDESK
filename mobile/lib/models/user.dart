import 'json_utils.dart';

/// The three roles from the SRS (AUTH-5).
enum UserRole {
  customer('Customer'),
  agent('Agent'),
  admin('Admin');

  const UserRole(this.label);

  final String label;

  /// Value sent to the backend (Prisma enum style).
  String get apiValue => name.toUpperCase();

  /// Agents and Admins are staff: they see internal notes and change status.
  /// The backend enforces this; the app only hides what a role cannot use.
  bool get isStaff => this != UserRole.customer;

  /// Unknown values fall back to Customer, the role with the fewest rights.
  static UserRole parse(Object? value) {
    switch (value?.toString().trim().toLowerCase()) {
      case 'agent':
        return UserRole.agent;
      case 'admin':
        return UserRole.admin;
      default:
        return UserRole.customer;
    }
  }
}

/// A user account: the signed-in user, or a user in the Admin's list (USR-1).
class AppUser {
  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.active = true,
  });

  factory AppUser.fromJson(Json json) => AppUser(
        id: readString(json['id']),
        name: readString(json['name']),
        email: readString(json['email']),
        role: UserRole.parse(json['role']),
        active: readBool(json['active'] ?? json['isActive'], fallback: true),
      );

  final String id;
  final String name;
  final String email;
  final UserRole role;

  /// Users are never deleted, only deactivated (BR-6).
  final bool active;

  Json toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'role': role.apiValue,
        'active': active,
      };

  String get initials => initialsOf(name);
  String get firstName => name.trim().split(RegExp(r'\s+')).first;

  PersonRef toRef() => PersonRef(id: id, name: name, role: role);
}

/// Another user shown on a ticket: the customer, the assigned agent or a
/// reply author.
class PersonRef {
  const PersonRef({required this.id, required this.name, this.role});

  final String id;
  final String name;
  final UserRole? role;

  String get initials => initialsOf(name);

  /// Reads `{"author": {"id": 1, "name": "..."}}` or `{"authorName": "..."}`.
  static PersonRef? read(Json json, String key) {
    final value = json[key];
    if (value is Map) {
      final person = asJson(value);
      return PersonRef(
        id: readString(person['id']),
        name: readString(person['name'], 'Unknown user'),
        role: person['role'] == null ? null : UserRole.parse(person['role']),
      );
    }
    final name = json['${key}Name'];
    if (name == null) return null;
    return PersonRef(id: readString(json['${key}Id']), name: name.toString());
  }
}

String initialsOf(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  final letters = parts.take(2).map((p) => p[0].toUpperCase()).join();
  return letters.isEmpty ? '?' : letters;
}
