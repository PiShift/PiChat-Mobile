import 'dart:io';
import 'package:audio_session/audio_session.dart';
import 'package:dio/dio.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_callkit_incoming/flutter_callkit_incoming.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:just_audio/just_audio.dart';
import 'package:pichat/core/services/notification_sound_service.dart';
import 'package:pichat/features/calls/application/call_fcm_handler.dart';
import 'package:pichat/features/calls/data/call_api.dart';

/// Set when the user taps a message notification, holding the contact uuid to
/// open. Screens watch this so a tap works whether the app was killed or just
/// backgrounded; whoever handles it clears it back to null.
final pendingChatNavigationProvider = StateProvider<String?>((ref) => null);

/// FCM Push Notification Service for handling incoming notifications
class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  static const _ringtoneChannel = MethodChannel('com.pishift.pichat/ringtone');
  final AudioPlayer _soundPlayer = AudioPlayer();

  bool _isInitialized = false;
  Future<void>? _initFuture;
  String? _fcmToken;
  String? _currentSoundUri;
  ProviderContainer? _container;
  Dio? _dio;

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

    // On iOS: suppress the system banner/sound while the app is in the
    // foreground. Reverb delivers live updates; the foreground message handler
    // in this service controls any in-app UI (banners, badges, etc.).
    await _messaging.setForegroundNotificationPresentationOptions(
      alert: false,
      badge: false,
      sound: false,
    );

    // Get FCM token — on iOS the APNS token may not be ready immediately,
    // so retry a few times with a short delay before giving up.
    _fcmToken = await _getTokenWithRetry();
    if (_fcmToken != null) {
      print('NotificationService: FCM Token = ${_fcmToken?.substring(0, 20)}...');
    } else {
      print('NotificationService: Could not obtain FCM token (APNS token unavailable)');
    }

    // Listen for token refresh — re-register with backend so production App Store
    // installs (where the APNs token may arrive after the initial registration
    // attempt) always have a valid token stored server-side.
    _messaging.onTokenRefresh.listen((newToken) {
      print('NotificationService: Token refreshed, re-registering with backend');
      _fcmToken = newToken;
      if (_dio != null) {
        registerTokenWithBackend(_dio!);
      }
      // Calling presence keeps its own copy of the token (AgentCallStatus is
      // what CallRouterService reads to wake this phone for an incoming
      // call), so a refresh has to reach that table too — otherwise the
      // number rings on WhatsApp and nothing happens here.
      registerCallingDevice();
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
      // pichat_messages is the canonical channel. Using a versioned ID forces
      // Android to create a fresh channel even if the old one was registered
      // without proper sound settings on an earlier install.
      const channel = AndroidNotificationChannel(
        'pichat_messages',
        'New Messages',
        description: 'Notifications for new WhatsApp messages',
        importance: Importance.high,
        playSound: true,
        enableVibration: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);
    }
  }

  /// Register FCM token with backend (call after user logs in)
  Future<void> registerTokenWithBackend(Dio dio) async {
    _dio = dio;
    if (_fcmToken == null) {
      print('NotificationService: No FCM token to register');
      return;
    }

    try {
      final deviceType = Platform.isIOS ? 'ios' : 'android';

      // Re-send the chosen sound on every registration. The server keeps it on
      // the `user_devices` row, which is keyed by FCM token — so a reinstall or
      // a token rotation creates a fresh row and the selection was silently
      // lost, leaving background notifications on the default beep until the
      // user happened to open Settings and pick the sound again.
      final soundService = NotificationSoundService();
      final selected = soundService.findById(await soundService.getSelectedId());

      // Must be Map<String, dynamic> to allow interceptor to add organization_id (int)
      final Map<String, dynamic> data = {
        'fcm_token': _fcmToken,
        'device_type': deviceType,
        if (selected?.iosSoundFile != null)
          'notification_sound': selected!.iosSoundFile,
      };
      await dio.post('/notifications/register-device', data: data);
      print('NotificationService: Token registered with backend '
          '(sound ${selected?.iosSoundFile ?? 'default'})');
    } catch (e) {
      print('NotificationService: Failed to register token: $e');
    }
  }

  /// Push the current FCM token into the calling presence table so the
  /// backend can wake this device for an incoming WhatsApp call.
  ///
  /// Safe to call repeatedly; a null token is skipped rather than sent,
  /// because the backend keeps the token it already has when the field is
  /// absent.
  Future<void> registerCallingDevice({String status = 'available'}) async {
    final container = _container;
    if (container == null) return;

    // iOS needs a second credential. An ordinary push cannot launch a killed
    // app and background pushes are throttled, so an incoming call has to
    // arrive as a PushKit VoIP push — and FCM cannot deliver those. The token
    // is captured natively in AppDelegate and handed to
    // flutter_callkit_incoming, which is where we read it back from.
    final voipToken = Platform.isIOS ? await _voipToken() : null;

    try {
      await container.read(callApiProvider).updateAgentStatus(
            status: status,
            deviceToken: _fcmToken,
            devicePlatform: Platform.isIOS ? 'ios' : 'android',
            voipToken: voipToken,
          );
      print('NotificationService: calling presence updated '
          '(fcm ${_fcmToken == null ? 'missing' : 'present'}'
          '${Platform.isIOS ? ', voip ${voipToken == null || voipToken.isEmpty ? 'missing' : 'present'}' : ''})');
    } catch (e) {
      print('NotificationService: calling presence update failed: $e');
    }
  }

  /// The PushKit token is registered asynchronously by iOS, so on a cold start
  /// it can still be empty when presence is first sent. Poll briefly rather
  /// than give up — a missing token means the phone cannot be rung at all
  /// while the app is closed. Presence is re-sent on resume regardless.
  Future<String?> _voipToken({
    Duration timeout = const Duration(seconds: 6),
  }) async {
    final deadline = DateTime.now().add(timeout);

    while (DateTime.now().isBefore(deadline)) {
      try {
        final token = await FlutterCallkitIncoming.getDevicePushTokenVoIP();

        if (token is String && token.isNotEmpty) return token;
      } catch (e) {
        print('NotificationService: VoIP token read failed: $e');
        return null;
      }

      await Future<void>.delayed(const Duration(milliseconds: 500));
    }

    print('NotificationService: no VoIP token after ${timeout.inSeconds}s');

    return null;
  }

  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('NotificationService: Foreground message received: ${message.messageId}');

    // Incoming-call wake-ups go straight to the call controller.
    if (message.data['type'] == 'incoming_call' && _container != null) {
      await handleIncomingCallFcm(_container!, message);
      return;
    }

    // new_message pushes: Reverb handles the live UI update. We only need to
    // play the notification sound so the user hears the alert while the app
    // is open — no banner is shown (that would duplicate Reverb's in-app banner).
    if (message.data['type'] == 'new_message') {
      await playMessageSound();
      return;
    }

    // Any other push type with a notification payload — show it as a local notification.
    final notification = message.notification;
    if (notification == null) return;

    // On iOS, use the sound file the user selected in Settings.
    final soundService = NotificationSoundService();
    final selectedId = await soundService.getSelectedId();
    final selectedSound = soundService.findById(selectedId);

    await _localNotifications.show(
      id: message.hashCode,
      title: notification.title ?? 'New Message',
      body: notification.body ?? '',
      notificationDetails: NotificationDetails(
        android: const AndroidNotificationDetails(
          'pichat_messages',
          'New Messages',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
          icon: '@mipmap/ic_launcher',
        ),
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          // null = system default; otherwise the .caf file bundled in ios/Runner/
          sound: selectedSound.iosSoundFile,
        ),
      ),
      payload: message.data['contact_uuid'],
    );
  }

  /// Plays the user's chosen notification sound while the app is in the
  /// foreground (no banner — Reverb already shows the in-app UI).
  DateTime? _lastSoundPlayedAt;

  /// Play the incoming-message tone while the app is open.
  ///
  /// Both the websocket and the FCM push can announce the same message, and
  /// which arrives first is not predictable, so calls are collapsed inside a
  /// short window to avoid a double beep.
  Future<void> playMessageSound() async {
    final now = DateTime.now();
    final last = _lastSoundPlayedAt;

    if (last != null && now.difference(last) < const Duration(milliseconds: 1500)) {
      return;
    }

    _lastSoundPlayedAt = now;

    await _playForegroundSound();
  }

  Future<void> _playForegroundSound() async {
    try {
      final soundService = NotificationSoundService();
      final sound = soundService.findById(await soundService.getSelectedId());
      if (sound.assetPath == null) return; // default → OS handles it; nothing to play here

      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        avAudioSessionCategory: AVAudioSessionCategory.ambient,
        avAudioSessionCategoryOptions: AVAudioSessionCategoryOptions.mixWithOthers,
        avAudioSessionMode: AVAudioSessionMode.defaultMode,
        avAudioSessionRouteSharingPolicy: AVAudioSessionRouteSharingPolicy.defaultPolicy,
        avAudioSessionSetActiveOptions: AVAudioSessionSetActiveOptions.none,
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.sonification,
          usage: AndroidAudioUsage.notificationRingtone,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
      ));
      try {
        await session.setActive(true);
      } catch (_) {
        // Session activation may fail while VoIP is initialised; continue anyway.
      }

      await _soundPlayer.stop();
      await _soundPlayer.setAudioSource(AudioSource.asset(sound.assetPath!));
      await _soundPlayer.play();
    } catch (e) {
      print('NotificationService: foreground sound error: $e');
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    print('NotificationService: Notification tapped: ${message.messageId}');

    _publishTap(message.data['contact_uuid'] as String?);
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    _publishTap(response.payload);
  }

  /// Records a notification tap for the UI to act on.
  ///
  /// Stored in BOTH places on purpose. The provider is what a screen that is
  /// already mounted reacts to — tapping a notification while the app is
  /// merely backgrounded used to set the field below and nothing more, because
  /// the only reader ran in HomeScreen.initState and had long since finished,
  /// so the app just came to the foreground on the same screen. The field
  /// remains for the cold-start case, where the tap is delivered by
  /// getInitialMessage() before any widget exists to listen.
  void _publishTap(String? contactUuid) {
    if (contactUuid == null || contactUuid.isEmpty) return;

    _pendingNavigation = contactUuid;

    try {
      _container?.read(pendingChatNavigationProvider.notifier).state =
          contactUuid;
    } catch (e) {
      print('NotificationService: could not publish tap: $e');
    }
  }

  String? _pendingNavigation;

  /// Check if there's a pending navigation from notification tap
  String? consumePendingNavigation() {
    final value = _pendingNavigation;
    _pendingNavigation = null;
    return value;
  }

  /// Clear all notifications from the notification center and reset the app
  /// icon badge to zero. Call this whenever the app comes to the foreground.
  Future<void> clearAll() async {
    // cancelAll() on iOS: removes pending + delivered notifications from the
    // notification center AND resets applicationIconBadgeNumber to 0.
    // On Android: removes all local notifications (launcher badge auto-clears).
    await _localNotifications.cancelAll();
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

  /// Opens the system ringtone picker (Android only). After the user picks a
  /// sound, the notification channel is deleted and recreated with that URI so
  /// future notifications play the chosen tone.
  Future<void> openRingtonePicker() async {
    if (!Platform.isAndroid) return;

    final String? selectedUri = await _ringtoneChannel.invokeMethod<String>(
      'openRingtonePicker',
      {'currentUri': _currentSoundUri},
    );

    // null means the user cancelled or chose "Silent"
    if (selectedUri == null) return;
    _currentSoundUri = selectedUri;

    final androidPlugin = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (androidPlugin == null) return;

    // Android locks channel settings after first creation, so delete the old
    // channel and recreate with the new sound URI.
    await androidPlugin.deleteNotificationChannel(channelId: 'pichat_messages');
    final channel = AndroidNotificationChannel(
      'pichat_messages',
      'New Messages',
      description: 'Notifications for new WhatsApp messages',
      importance: Importance.high,
      playSound: true,
      enableVibration: true,
      sound: UriAndroidNotificationSound(selectedUri),
    );
    await androidPlugin.createNotificationChannel(channel);
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

  if (message.data['type'] == 'incoming_call') {
    await backgroundShowCallkitFromFcm(message);
    return;
  }

  // new_message: the server now sends a notification block for reliable
  // App Store / production APNs delivery. When a notification block is present,
  // iOS/Android already display it natively — we must NOT show a second local
  // notification (would double-display). Only show locally for data-only fallback.
  if (message.data['type'] == 'new_message') {
    // Native notification already shown by the OS — nothing to do.
    if (message.notification != null) return;

    // Data-only fallback path (should not happen with current backend, but kept
    // as a safety net in case the server is temporarily rolled back).
    final FlutterLocalNotificationsPlugin localNotifications = FlutterLocalNotificationsPlugin();

    const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
    const iosSettings = DarwinInitializationSettings();
    await localNotifications.initialize(
      settings: const InitializationSettings(android: androidSettings, iOS: iosSettings),
    );

    final title = message.data['sender_name'] as String? ?? 'New message';
    final body = message.data['body'] as String? ?? '';

    await localNotifications.show(
      id: message.hashCode,
      title: title,
      body: body.isEmpty ? 'New message' : body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'pichat_messages',
          'New Messages',
          importance: Importance.high,
          priority: Priority.high,
          playSound: true,
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
}
