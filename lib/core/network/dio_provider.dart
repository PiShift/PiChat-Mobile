// lib/core/network/dio_provider.dart
import 'package:dio/dio.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichat/core/constants/app_constants.dart';
import 'package:pichat/core/state/auth_state.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = Dio(
    BaseOptions(
      baseUrl: AppConstants.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      headers: {
        'Accept': 'application/json',
      },
    ),
  );

  // Add interceptors
  dio.interceptors.add(InterceptorsWrapper(
    onRequest: (options, handler) {
      final token = ref.read(authTokenProvider);
      final orgId = ref.read(organizationProvider);
      if (token != null) {
        options.headers['Authorization'] = 'Bearer $token';
      }
      if (orgId != null) {
        final orgIdString = orgId.id.toString();
        options.headers['organization_id'] = orgIdString;

        // Always add to query parameters as string
        // Create a new map to avoid type conflicts with existing parameters
        final newParams = Map<String, dynamic>.from(options.queryParameters);
        newParams['organization_id'] = orgIdString;
        options.queryParameters = newParams;

        // For POST/PUT/PATCH, also include in body as string if body is a Map
        if (options.method != 'GET' && options.method != 'DELETE') {
          if (options.data is Map) {
            // Always re-wrap as Map<String, dynamic> so an inferred
            // Map<String, int> literal at the call site can't reject
            // a String value (was crashing terminate / outbound calls).
            final original = (options.data as Map);
            final rewrapped = <String, dynamic>{
              for (final entry in original.entries)
                entry.key.toString(): entry.value,
            };
            rewrapped['organization_id'] = orgIdString;
            options.data = rewrapped;
          }
        }
      }
      return handler.next(options);
    },
    onError: (DioException e, handler) {
      final status = e.response?.statusCode;
      debugPrint('DIO onError: status=$status url=${e.requestOptions.uri}');
      // Only auto-logout when the request actually carried an auth token.
      // Requests that fire before the token is loaded (e.g. settings fetched
      // during app build) have no Authorization header; treating their 401
      // as a logout would erase the stored credentials from secure storage.
      if (status == 401) {
        final sentAuthHeader = e.requestOptions.headers.containsKey('Authorization');
        if (sentAuthHeader) {
          debugPrint('DIO: 401 Unauthorized - triggering auto-logout');
          ref.read(authTokenProvider.notifier).state = null;
          ref.read(organizationProvider.notifier).clear();
          ref.read(userProvider.notifier).clear();
          ref.read(authProvider.notifier).logout();
        }
      }
      return handler.next(e);
    },
  ));
  // Add logging interceptor in debug mode
  assert(() {
    dio.interceptors.add(LogInterceptor(
      request: true,
      requestBody: true,
      responseBody: true,
      error: true,
      logPrint: (obj) => print(obj),
    ));
    return true;
  }());

  return dio;
});
