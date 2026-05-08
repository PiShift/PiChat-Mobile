import 'dart:io';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichat/features/calls/application/call_fcm_handler.dart';

/// FCM Push Notification Service for handling incoming notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  bool _isInitialized = false;
  Future<void>? _initFuture;
  String? _fcmToken;
  ProviderContainer? _container;

  /// Get the current FCM token
  String? get fcmToken => _fcmToken;

  /// Wire the global ProviderContainer so foreground call pushes can reach
  /// the CallController. Set from main.dart before any messages arrive.
  void bindContainer(ProviderContainer container) {
    _container = container;
  }

  /// Initialize the notification service (call from main.dart after Firebase.initializeApp)
  Future<void> initialize() async {
    if (_isInitialized) return;
    // Cache the in-flight init future so concurrent callers all await the
    // SAME initialization rather than racing past the bool guard.
    return _initFuture ??= _doInitialize();
  }

  Future<void> _doInitialize() async {
    print('NotificationService: Initializing...');

    // Request permission
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    print('NotificationService: Permission status = ${settings.authorizationStatus}');

    if (settings.authorizationStatus != AuthorizationStatus.authorized &&
        settings.authorizationStatus != AuthorizationStatus.provisional) {
      print('NotificationService: Push notifications not authorized');
      return;
    }

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Get FCM token — on iOS the APNS token may not be ready immediately,
    // so retry a few times with a short delay before giving up.
    _fcmToken = await _getTokenWithRetry();
    if (_fcmToken != null) {
      print('NotificationService: FCM Token = ${_fcmToken?.substring(0, 20)}...');
    } else {
      print('NotificationService: Could not obtain FCM token (APNS token unavailable)');
    }

    // Listen for token refresh
    _messaging.onTokenRefresh.listen((newToken) {
      print('NotificationService: Token refreshed');
      _fcmToken = newToken;
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle notification taps when app is in background
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Handle notification that opened the app from terminated state
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      _handleNotificationTap(initialMessage);
    }

    _isInitialized = true;
    print('NotificationService: Initialized successfully');
  }

  /// On iOS the APNS token registration is asynchronous and may not be ready
  /// by the time `getToken()` is first called. Retry up to [maxAttempts] times
  /// with a short back-off to avoid the `apns-token-not-set` crash.
  Future<String?> _getTokenWithRetry({int maxAttempts = 5}) async {
    for (int attempt = 1; attempt <= maxAttempts; attempt++) {
      try {
        // On iOS, check for the APNS token first before requesting FCM token.
        if (Platform.isIOS) {
          final apnsToken = await _messaging.getAPNSToken();
          if (apnsToken == null) {
            if (attempt < maxAttempts) {
              await Future.delayed(Duration(seconds: attempt));
              continue;
            }
            return null;
          }
        }
        return await _messaging.getToken();
      } catch (e) {
        if (attempt < maxAttempts) {
          await Future.delayed(Duration(seconds: attempt));
        } else {
          print('NotificationService: Failed to get FCM token after $maxAttempts attempts: $e');
          return null;
        }
      }
    }
    return null;
  }

  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      settings: initSettings,
      onDidReceiveNotificationResponse: _onLocalNotificationTap,
    );

    // Create notification channel for Android
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'high_importance_channel',
        'New Messages',
        description: 'Notifications for new WhatsApp messages',
        importance: Importance.high,
        playSound: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  /// Register FCM token with backend (call after user logs in)
  Future<void> registerTokenWithBackend(Dio dio) async {
    if (_fcmToken == null) {
      print('NotificationService: No FCM token to register');
      return;
    }

    try {
      final deviceType = Platform.isIOS ? 'ios' : 'android';
      // Must be Map<String, dynamic> to allow interceptor to add organization_id (int)
      final Map<String, dynamic> data = {
        'fcm_token': _fcmToken,
        'device_type': deviceType,
      };
      await dio.post('/notifications/register-device', data: data);
      print('NotificationService: Token registered with backend');
    } catch (e) {
      print('NotificationService: Failed to register token: $e');
    }
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('NotificationService: Foreground message received: ${message.messageId}');

    // Phase 3: incoming-call wake-ups go straight to the call controller via
    // the global container set up in main.dart.
    if (message.data['type'] == 'incoming_call' && _container != null) {
      await handleIncomingCallFcm(_container!, message);
      return;
    }

    final notification = message.notification;
    if (notification == null) return;

    // Show local notification
    await _localNotifications.show(
      id: message.hashCode,
      title: notification.title ?? 'New Message',
      body: notification.body ?? '',
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'high_importance_channel',
          'New Messages',
          importance: Importance.high,
          priority: Priority.high,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      payload: message.data['contact_uuid'],
    );
  }

  void _handleNotificationTap(RemoteMessage message) {
    print('NotificationService: Notification tapped: ${message.messageId}');
    
    final contactUuid = message.data['contact_uuid'];
    if (contactUuid != null) {
      _pendingNavigation = contactUuid;
    }
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    final contactUuid = response.payload;
    if (contactUuid != null) {
      _pendingNavigation = contactUuid;
    }
  }

  String? _pendingNavigation;

  /// Check if there's a pending navigation from notification tap
  String? consumePendingNavigation() {
    final value = _pendingNavigation;
    _pendingNavigation = null;
    return value;
  }

  /// Unregister device token (call on logout)
  Future<void> unregisterToken(Dio dio) async {
    if (_fcmToken == null) return;
    
    try {
      await dio.post('/notifications/unregister-device', data: {
        'fcm_token': _fcmToken,
      });
      print('NotificationService: Token unregistered');
    } catch (e) {
      print('NotificationService: Failed to unregister token: $e');
    }
  }
}

/// Provider for notification service
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// Background message handler - must be top-level function
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  print('NotificationService: Background message received: ${message.messageId}');
  // Phase 3: high-priority call wake-ups arrive as data-only pushes with
  // `type=incoming_call`. We must surface the native CallKit UI from this
  // background isolate; the SDP exchange happens later from the main isolate
  // when the user accepts and the app is foregrounded.
  if (message.data['type'] == 'incoming_call') {
    // Firebase is already initialized by the system before our handler runs.
    // ignore: avoid_dynamic_calls
    await backgroundShowCallkitFromFcm(message);
  }
}
