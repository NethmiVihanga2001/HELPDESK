import 'package:dio/dio.dart';

import '../models/json_utils.dart';

/// An error the user can understand (NFR-4, feature 10.8).
///
/// Built from the error format in the delivery plan:
/// `{ "success": false, "message": "...", "errors": [ { "field": "...", "message": "..." } ] }`
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode, this.fieldErrors = const {}});

  factory ApiException.fromDio(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiException(
          'The server is taking too long to respond. Please try again.',
        );
      case DioExceptionType.connectionError:
        return const ApiException(
          "Can't reach the server. Check your internet connection and try again.",
        );
      case DioExceptionType.cancel:
        return const ApiException('The request was cancelled.');
      case DioExceptionType.badCertificate:
        return const ApiException("The server's security certificate is not valid.");
      case DioExceptionType.badResponse:
        return ApiException.fromBody(error.response?.data, error.response?.statusCode);
      case DioExceptionType.unknown:
        return const ApiException(
          "Can't reach the server. Check your internet connection and try again.",
        );
    }
  }

  /// Reads an error envelope returned with any HTTP status.
  factory ApiException.fromBody(Object? body, int? statusCode) {
    final json = asJson(body);
    final fieldErrors = <String, String>{
      for (final e in asJsonList(json['errors']))
        if (e['field'] != null && e['message'] != null)
          e['field'].toString(): e['message'].toString(),
    };
    final serverMessage = json['message']?.toString();
    // Never show raw server errors (500) to the user.
    final useServerMessage = serverMessage != null &&
        serverMessage.isNotEmpty &&
        (statusCode == null || statusCode < 500);
    return ApiException(
      useServerMessage ? serverMessage : _defaultMessage(statusCode),
      statusCode: statusCode,
      fieldErrors: fieldErrors,
    );
  }

  final String message;

  /// HTTP status code, or null when the server could not be reached.
  final int? statusCode;

  /// Validation errors keyed by field name, e.g. `{"title": "Title is required"}`.
  final Map<String, String> fieldErrors;

  bool get isUnauthorized => statusCode == 401;
  bool get isNetworkError => statusCode == null;

  static String _defaultMessage(int? statusCode) {
    switch (statusCode) {
      case 400:
        return 'Please check the details and try again.';
      case 401:
        return 'Your session has expired. Please log in again.';
      case 403:
        return "You don't have permission to do that.";
      case 404:
        return "We couldn't find that. It may have been removed.";
      case 409:
        return 'This already exists.';
      case 413:
        return 'The file is too large. The limit is 5 MB.';
      default:
        return 'Something went wrong on the server. Please try again in a moment.';
    }
  }

  @override
  String toString() => message;
}
