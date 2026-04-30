// lib/core/constants/app_constants.dart
class AppConstants {
  static const appName = 'PiChat';
  
  // ⚠️ FOR LOCAL TESTING - Change back to production before release!
  // Production:
  static const apiBaseUrl = 'https://app.pichat.io/api/v1';
  static const baseUrl = 'https://app.pichat.io';
  static const wssUrl = 'ws-a103f1b6-c226-40d1-bd26-b924569d4c9c-reverb.laravel.cloud';
  static const wssOrigin = 'https://app.pichat.io'; // Origin header for WebSocket
  
  // Local development (your Mac's IP):
  // static const apiBaseUrl = 'http://192.168.1.5:8000/api/v1';
  // static const baseUrl = 'http://192.168.1.5:8000';
  // static const wssUrl = '192.168.1.5:8000';
  // static const wssOrigin = 'http://192.168.1.5:8000';
  
  static const kLastEmailKey = 'last_email';
}
