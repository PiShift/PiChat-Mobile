// lib/core/constants/app_constants.dart
class AppConstants {
  static const appName = 'PiChat';
  
  // Production. The backend moved to pichat.mr; app.pichat.io no longer
  // completes a TLS handshake, which is why every request - including login -
  // failed with a generic error.
  static const apiBaseUrl = 'https://pichat.mr/api/v1';
  static const baseUrl = 'https://pichat.mr';

  // Reverb, behind TLS on 443. The previous value was a retired Laravel Cloud
  // instance left over from before the move to Forge.
  static const wssUrl = 'ws.pichat.mr';
  static const wssOrigin = 'https://pichat.mr'; // Origin header for WebSocket

  // Local development (your Mac's IP):
  // static const apiBaseUrl = 'http://192.168.1.5:8000/api/v1';
  // static const baseUrl = 'http://192.168.1.5:8000';
  // static const wssUrl = '192.168.1.5:8000';
  // static const wssOrigin = 'http://192.168.1.5:8000';
  
  static const kLastEmailKey = 'last_email';
}
