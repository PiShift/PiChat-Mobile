// lib/core/network/error_handler.dart
import 'package:dio/dio.dart';
import 'package:easy_localization/easy_localization.dart';

class ErrorHandler {
  static String getErrorMessage(dynamic error) {
    if (error is DioException) {
      // If API returned a response, try to parse the message
      final response = error.response;
      if (response != null) {
        final data = response.data;

        // If API sends a "message" field
        if (data is Map<String, dynamic> && data['message'] != null) {
          return data['message'].toString();
        }

        // If API sends Laravel-style validation errors
        if (data is Map<String, dynamic> && data['errors'] != null) {
          final errors = data['errors'] as Map<String, dynamic>;
          if (errors.isNotEmpty) {
            // Return first validation error
            return errors.values.first.toString();
          }
        }
      }

      // Otherwise, fallback to type-based handling
      switch (error.type) {
        case DioExceptionType.connectionTimeout:
        case DioExceptionType.sendTimeout:
        case DioExceptionType.receiveTimeout:
          return tr("errors.timeout");

        case DioExceptionType.badResponse:
          final statusCode = error.response?.statusCode;
          if (statusCode == 401) return tr("errors.unauthorized");
          if (statusCode == 404) return tr("errors.not_found");
          if (statusCode == 500) return tr("errors.server_error");
          return tr("errors.unknown");

        case DioExceptionType.connectionError:
          return tr("errors.network");

        case DioExceptionType.cancel:
          return tr("errors.cancelled");

        default:
          return tr("errors.unknown");
      }
    }

    // Non-Dio error (unexpected)
    return tr("errors.unknown");
  }
}