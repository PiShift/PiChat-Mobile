import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichat/core/network/dio_provider.dart';

final settingsRepositoryProvider = Provider<SettingsRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return SettingsRepository(dio);
});

/// Model for User Profile
class UserProfile {
  final int id;
  final String uuid;
  final String firstName;
  final String lastName;
  final String fullName;
  final String email;
  final String? phone;
  final String? avatar;
  final String role;
  final bool emailVerified;
  final bool twoFactorEnabled;

  UserProfile({
    required this.id,
    required this.uuid,
    required this.firstName,
    required this.lastName,
    required this.fullName,
    required this.email,
    this.phone,
    this.avatar,
    required this.role,
    required this.emailVerified,
    required this.twoFactorEnabled,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['id'] as int,
      uuid: json['uuid'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      fullName: json['full_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      phone: json['phone'] as String?,
      avatar: json['avatar'] as String?,
      role: json['role'] as String? ?? 'user',
      emailVerified: json['email_verified'] as bool? ?? false,
      twoFactorEnabled: json['two_factor_enabled'] as bool? ?? false,
    );
  }
}

/// Model for App Settings
class AppSettings {
  final String theme;
  final String language;
  final bool notificationsEnabled;
  final bool soundEnabled;
  final bool vibrationEnabled;
  final bool enterToSend;
  final String mediaAutoDownload;

  AppSettings({
    this.theme = 'light',
    this.language = 'en',
    this.notificationsEnabled = true,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
    this.enterToSend = true,
    this.mediaAutoDownload = 'wifi',
  });

  factory AppSettings.fromJson(Map<String, dynamic> json) {
    final notifications = json['notifications'] as Map<String, dynamic>? ?? {};
    final chat = json['chat'] as Map<String, dynamic>? ?? {};

    return AppSettings(
      theme: json['theme'] as String? ?? 'light',
      language: json['language'] as String? ?? 'en',
      notificationsEnabled: notifications['enabled'] as bool? ?? true,
      soundEnabled: notifications['sound'] as bool? ?? true,
      vibrationEnabled: notifications['vibration'] as bool? ?? true,
      enterToSend: chat['enter_to_send'] as bool? ?? true,
      mediaAutoDownload: chat['media_auto_download'] as String? ?? 'wifi',
    );
  }

  AppSettings copyWith({
    String? theme,
    String? language,
    bool? notificationsEnabled,
    bool? soundEnabled,
    bool? vibrationEnabled,
    bool? enterToSend,
    String? mediaAutoDownload,
  }) {
    return AppSettings(
      theme: theme ?? this.theme,
      language: language ?? this.language,
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      enterToSend: enterToSend ?? this.enterToSend,
      mediaAutoDownload: mediaAutoDownload ?? this.mediaAutoDownload,
    );
  }
}

class SettingsRepository {
  final Dio _dio;

  SettingsRepository(this._dio);

  /// Get user profile
  Future<UserProfile> getProfile() async {
    try {
      final response = await _dio.get('/user/profile');

      if (response.statusCode == 200 && response.data['success'] == true) {
        return UserProfile.fromJson(response.data['user']);
      }

      throw Exception('Failed to load profile');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to load profile');
    }
  }

  /// Update user profile
  Future<UserProfile> updateProfile({
    String? firstName,
    String? lastName,
    String? phone,
  }) async {
    try {
      final data = <String, dynamic>{};
      if (firstName != null) data['first_name'] = firstName;
      if (lastName != null) data['last_name'] = lastName;
      if (phone != null) data['phone'] = phone;

      final response = await _dio.put('/user/profile', data: data);

      if (response.statusCode == 200 && response.data['success'] == true) {
        return UserProfile.fromJson(response.data['user']);
      }

      throw Exception(response.data['message'] ?? 'Failed to update profile');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to update profile');
    }
  }

  /// Change password
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String confirmPassword,
  }) async {
    try {
      final response = await _dio.post('/user/change-password', data: {
        'current_password': currentPassword,
        'new_password': newPassword,
        'new_password_confirmation': confirmPassword,
      });

      if (response.statusCode != 200 || response.data['success'] != true) {
        throw Exception(response.data['message'] ?? 'Failed to change password');
      }
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to change password');
    }
  }

  /// Get app settings
  Future<AppSettings> getSettings() async {
    try {
      final response = await _dio.get('/user/settings');

      if (response.statusCode == 200 && response.data['success'] == true) {
        return AppSettings.fromJson(response.data['settings']);
      }

      return AppSettings(); // Return defaults if fetch fails
    } on DioException catch (_) {
      return AppSettings();
    }
  }

  /// Update app settings
  Future<void> updateSettings(Map<String, dynamic> settings) async {
    try {
      await _dio.put('/user/settings', data: settings);
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to update settings');
    }
  }

  /// Register device for push notifications
  Future<void> registerDevice(String fcmToken, {String? deviceType}) async {
    try {
      await _dio.post('/notifications/register-device', data: {
        'fcm_token': fcmToken,
        'device_type': deviceType ?? 'android',
      });
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to register device');
    }
  }

  /// Unregister device from push notifications
  Future<void> unregisterDevice(String fcmToken) async {
    try {
      await _dio.post('/notifications/unregister-device', data: {
        'fcm_token': fcmToken,
      });
    } on DioException catch (_) {
      // Silently fail - device may already be unregistered
    }
  }
}

/// Provider for user profile
final userProfileProvider = FutureProvider<UserProfile>((ref) async {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.getProfile();
});

/// Provider for app settings
final appSettingsProvider = FutureProvider<AppSettings>((ref) async {
  final repo = ref.watch(settingsRepositoryProvider);
  return repo.getSettings();
});
