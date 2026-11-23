import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../models/json_utils.dart';
import '../models/user.dart';

/// Minimal key-value store so tests can run without the platform plugin.
abstract class KeyValueStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// Encrypted storage backed by the Android Keystore.
class SecureKeyValueStore implements KeyValueStore {
  SecureKeyValueStore([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

/// In-memory store for tests.
class MemoryKeyValueStore implements KeyValueStore {
  final Map<String, String> values = {};

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;

  @override
  Future<void> delete(String key) async => values.remove(key);
}

/// Keeps the access token, refresh token and signed-in user (feature 10.1:
/// "token stored securely; refresh token keeps the user signed in").
///
/// Values are cached in memory so each API request does not hit the
/// keystore.
class TokenStorage {
  TokenStorage(this._store);

  static const _accessKey = 'access_token';
  static const _refreshKey = 'refresh_token';
  static const _userKey = 'user';

  final KeyValueStore _store;
  bool _loaded = false;
  String? _accessToken;
  String? _refreshToken;
  AppUser? _user;

  Future<void> _ensureLoaded() async {
    if (_loaded) return;
    try {
      _accessToken = await _store.read(_accessKey);
      _refreshToken = await _store.read(_refreshKey);
      final userJson = await _store.read(_userKey);
      if (userJson != null) _user = AppUser.fromJson(asJson(jsonDecode(userJson)));
    } catch (e) {
      // Unreadable storage (for example after an Android backup restore).
      // Start signed out instead of crashing.
      debugPrint('Secure storage could not be read, signing out: $e');
      await clear();
    }
    _loaded = true;
  }

  Future<String?> readAccessToken() async {
    await _ensureLoaded();
    return _accessToken;
  }

  Future<String?> readRefreshToken() async {
    await _ensureLoaded();
    return _refreshToken;
  }

  Future<AppUser?> readUser() async {
    await _ensureLoaded();
    return _user;
  }

  Future<void> saveTokens({required String accessToken, String? refreshToken}) async {
    _loaded = true;
    _accessToken = accessToken;
    await _store.write(_accessKey, accessToken);
    if (refreshToken != null) {
      _refreshToken = refreshToken;
      await _store.write(_refreshKey, refreshToken);
    }
  }

  Future<void> saveUser(AppUser user) async {
    _loaded = true;
    _user = user;
    await _store.write(_userKey, jsonEncode(user.toJson()));
  }

  Future<void> clear() async {
    _loaded = true;
    _accessToken = null;
    _refreshToken = null;
    _user = null;
    for (final key in [_accessKey, _refreshKey, _userKey]) {
      try {
        await _store.delete(key);
      } catch (e) {
        debugPrint('Could not delete $key from secure storage: $e');
      }
    }
  }
}
