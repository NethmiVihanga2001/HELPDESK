import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../models/json_utils.dart';
import 'api_endpoints.dart';
import 'api_exception.dart';
import 'token_storage.dart';

/// HTTP client for the HelpDesk Pro backend.
///
/// * Adds `Authorization: Bearer <access token>` to every protected request.
/// * On a 401 it refreshes the access token once with the refresh token and
///   retries the request. If the refresh token is expired or revoked, it
///   calls [onSessionExpired] so the app returns to the login screen.
/// * Unwraps `{ "success": true, "data": ... }` and turns every failure into
///   an [ApiException] with a friendly message.
class ApiClient {
  ApiClient({
    required String baseUrl,
    required TokenStorage tokens,
    required this.onSessionExpired,
  }) : _tokens = tokens {
    final options = BaseOptions(
      baseUrl: baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      contentType: Headers.jsonContentType,
      responseType: ResponseType.json,
    );
    _dio = Dio(options)..interceptors.add(_AuthInterceptor(this));
    // No interceptors: used for the refresh call and for retries, so a
    // failing retry can never wait on itself in the interceptor queue.
    _plain = Dio(options);
  }

  final TokenStorage _tokens;
  final void Function() onSessionExpired;
  late final Dio _dio;
  late final Dio _plain;

  Future<dynamic> get(String path, {Map<String, dynamic>? query}) =>
      _send(() => _dio.get<dynamic>(path, queryParameters: query));

  Future<dynamic> post(String path, {Object? data, bool auth = true}) => _send(
        () => _dio.post<dynamic>(path, data: data, options: _options(auth: auth)),
      );

  Future<dynamic> patch(String path, {Object? data}) =>
      _send(() => _dio.patch<dynamic>(path, data: data));

  Future<dynamic> upload(String path, FormData form) => _send(
        () => _dio.post<dynamic>(
          path,
          data: form,
          options: Options(
            contentType: Headers.multipartFormDataContentType,
            sendTimeout: const Duration(minutes: 2),
          ),
        ),
      );

  Future<Uint8List> getBytes(String path, {Map<String, dynamic>? query}) async {
    try {
      final response = await _dio.get<List<int>>(
        path,
        queryParameters: query,
        options: Options(responseType: ResponseType.bytes),
      );
      return Uint8List.fromList(response.data ?? const []);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  Options _options({required bool auth}) => Options(extra: {'auth': auth});

  Future<dynamic> _send(Future<Response<dynamic>> Function() request) async {
    try {
      final response = await request();
      return _unwrap(response.data, response.statusCode);
    } on DioException catch (e) {
      throw ApiException.fromDio(e);
    }
  }

  static dynamic _unwrap(Object? body, int? statusCode) {
    if (body is Map && body.containsKey('success')) {
      if (body['success'] == true) return body['data'];
      throw ApiException.fromBody(body, statusCode);
    }
    return body;
  }

  /// Returns a new access token, or null when the refresh token is missing,
  /// expired or revoked. Throws [DioException] on network problems so a bad
  /// connection does not sign the user out.
  Future<String?> _refreshAccessToken() async {
    final refreshToken = await _tokens.readRefreshToken();
    if (refreshToken == null) return null;
    try {
      final response = await _plain.post<dynamic>(
        ApiEndpoints.refresh,
        data: {'refreshToken': refreshToken},
      );
      final data = asJson(_unwrap(response.data, response.statusCode));
      final accessToken = data['accessToken'] ?? data['token'];
      if (accessToken is! String) return null;
      final rotated = data['refreshToken'];
      await _tokens.saveTokens(
        accessToken: accessToken,
        refreshToken: rotated is String ? rotated : refreshToken,
      );
      return accessToken;
    } on ApiException {
      return null;
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code != null && code >= 400 && code < 500) return null;
      rethrow;
    }
  }
}

/// Queued so that several requests failing with 401 at the same time cause
/// only one refresh call.
class _AuthInterceptor extends QueuedInterceptor {
  _AuthInterceptor(this._client);

  final ApiClient _client;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    if (options.extra['auth'] != false) {
      final token = await _client._tokens.readAccessToken();
      if (token != null) options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    final canRefresh = err.response?.statusCode == 401 &&
        options.extra['auth'] != false &&
        options.extra['retried'] != true;
    if (!canRefresh) return handler.next(err);

    String? token = await _client._tokens.readAccessToken();
    // Another queued request may already have refreshed the token.
    if (token == null || options.headers['Authorization'] == 'Bearer $token') {
      try {
        token = await _client._refreshAccessToken();
      } on DioException {
        return handler.next(err); // Offline: keep the session, show the error.
      }
    }
    if (token == null) {
      _client.onSessionExpired();
      return handler.next(err);
    }

    options.headers['Authorization'] = 'Bearer $token';
    options.extra['retried'] = true;
    final data = options.data;
    if (data is FormData) options.data = data.clone(); // A FormData is single-use.
    try {
      handler.resolve(await _client._plain.fetch<dynamic>(options));
    } on DioException catch (e) {
      handler.next(e);
    }
  }
}
