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
        options.headers['organization_id'] = orgId.toString();
      }
      return handler.next(options);
    },
    onError: (DioException e, handler) {
      final status = e.response?.statusCode;
      // debugPrint('DIO onError: status=$status url=${e.requestOptions.uri}');
      // Handle 401 (maybe trigger logout)
      if (e.response?.statusCode == 401) {
        ref.read(authProvider.notifier).logout();
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
