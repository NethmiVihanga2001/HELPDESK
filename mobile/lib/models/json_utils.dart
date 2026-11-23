/// Small helpers that keep JSON parsing in one place.
///
/// The API contract is written by Backend 3 during Day 1, so the parsers
/// accept a few equivalent shapes (for example a category sent as an object
/// or as a plain name). Once the contract is final, only this folder needs
/// to change.
library;

typedef Json = Map<String, dynamic>;

Json asJson(Object? value) =>
    value is Map ? value.cast<String, dynamic>() : <String, dynamic>{};

List<Json> asJsonList(Object? value) => value is List
    ? value.whereType<Map>().map((e) => e.cast<String, dynamic>()).toList()
    : <Json>[];

String readString(Object? value, [String fallback = '']) =>
    value == null ? fallback : value.toString();

bool readBool(Object? value, {bool fallback = false}) {
  if (value == null) return fallback;
  return value == true || value == 'true' || value == 1;
}

int? readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return value == null ? null : int.tryParse(value.toString());
}

/// The backend stores times in UTC; the app shows them in local time.
DateTime? readDate(Object? value) {
  if (value is! String) return null;
  return DateTime.tryParse(value)?.toLocal();
}

/// Reads a related record's name from `{"category": {"name": "Billing"}}`,
/// `{"category": "Billing"}` or `{"categoryName": "Billing"}`.
String? readRelationName(Json json, String key) {
  final value = json[key];
  if (value is Map) return value['name']?.toString();
  if (value is String) return value;
  return json['${key}Name']?.toString();
}

/// Sends numeric ids back as numbers and other ids (UUID, cuid) as strings,
/// so the app works whichever id type the Prisma schema uses.
Object idForApi(String id) => int.tryParse(id) ?? id;
