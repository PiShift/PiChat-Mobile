import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage_x/flutter_secure_storage_x.dart';
import 'package:pichat/core/state/auth_state.dart';
import 'package:pichat/data/db/app_database.dart';
import 'package:pichat/data/models/chat_model.dart';
import 'package:pichat/features/calls/application/call_controller.dart';
import 'package:pichat/features/chat/application/main_controller.dart';
import 'package:pichat/features/chat/application/message_provider.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:http/http.dart' as http;

class ReverbService {
  final String host;
  final String appKey;
  final bool useSecure;
  final String origin;
  IOWebSocketChannel? _channel;
  bool _connected = false;
  int _reconnectAttempts = 0;
  String? organizationId;
  int? _userId;
  late AppDatabase _db;
  final Ref _ref;

  ReverbService({
    required this.host,
    required this.appKey,
    this.useSecure = true,
    required this.origin,
    required this.organizationId,
    required AppDatabase db,
    required Ref ref,
  }) : _db = db,
        _ref = ref;

  void init({required String orgId, required AppDatabase database, int? userId}) {
    organizationId = orgId;
    _db = database;
    _userId = userId;
  }

  void connect() async {
    if (_connected) return;
    if (organizationId == null) {
      print("❌ Cannot connect: orgId is null");
      return;
    }

    final scheme = useSecure ? 'wss' : 'ws';
    final uri = Uri.parse('$scheme://$host/app/$appKey');
    print('Reverb connecting to $uri');

    // Dispose old channel if any
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;

    try {
      // Include Origin header to satisfy Reverb's allowed_origins check
      _channel = IOWebSocketChannel.connect(
        uri,
        headers: {
          'Origin': origin,
        },
      );

      _connected = true;
      _reconnectAttempts = 0; // reset on success
      print('🔗 Reverb connected');

      _channel!.stream.listen(
            (message) async {
          print("Reverb is Listening...");
          final data = json.decode(message);
          print('📩 Reverb Event: ${data['event']}  Channel: ${data['channel']}  Data: ${data['data']}');
          if (data['event'] == 'pusher:connection_established') {
            final payload = json.decode(data['data']);
            final activityTimeout = payload['activity_timeout'] ?? 30;
            _startPing(activityTimeout - 5); // ping a little earlier than timeout
            final channelName = "chats.ch$organizationId";
            await subscribeToPrivateChannel(channelName, _channel);

            // Also subscribe to the per-org calls channel + per-agent channel
            // so we receive IncomingCall / CallAccepted / CallEnded broadcasts.
            await subscribeToPrivateChannel("calls.org.$organizationId", _channel);
            if (_userId != null) {
              await subscribeToPrivateChannel("calls.agent.$_userId", _channel);
            }
          } else if (data['event'] == 'pusher:pong') {
            print("📩 Reverb Got pong");
          } else if (data['event'] == 'NewChatEvent') {
            final payload = json.decode(data['data']);

            final chatList = payload['chat'] as List;
            final chat = Chat.fromJson(chatList.first['value']);

            print("✅ New chat received: $chat");
            _handleIncomingChat(chat);
          } else if (_isCallEvent(data['event'])) {
            final payload = json.decode(data['data']);
            _handleCallEvent(_normalizeEventName(data['event']), payload);
          } else {
            print('📩 Reverb message: $data');
          }
        },
        onDone: () {
          _stopPing();
          _handleDisconnect();
        },
        onError: (error) {
          _stopPing();
          print('⚠️ Reverb error: $error');
          _handleDisconnect();
        },
        cancelOnError: false,
      );
    } catch (e) {
      print('❌ Reverb connection failed: $e');
      _connected = false;
      _scheduleReconnect();
    }
  }

  void _handleDisconnect() {
    if (!_connected) return;
    _connected = false;
    _channel = null;
    _scheduleReconnect();
  }

  void _scheduleReconnect() {
    _reconnectAttempts++;
    final delay = (_reconnectAttempts > 5 ? 30 : 5 * _reconnectAttempts);
    print('Reverb reconnect in $delay seconds');
    Future.delayed(Duration(seconds: delay), connect);
  }

  void disconnect() {
    _connected = false;
    try {
      _channel?.sink.close();
    } catch (_) {}
    _channel = null;
  }

  void sendEvent(String event, Map<String, dynamic> payload) {
    if (!_connected) return;
    _channel?.sink.add(json.encode({'event': event, 'data': payload}));
  }

  Timer? _pingTimer;

  void _startPing(int interval) {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(Duration(seconds: interval), (_) {
      if (_connected) {
        _channel?.sink.add(jsonEncode({"event": "pusher:ping", "data": {}}));
        print("📤 Sent pusher:ping");
      }
    });
  }

  void _stopPing() {
    _pingTimer?.cancel();
    _pingTimer = null;
  }

  Future<String?> broadcastAuthentication(String socketId, String channelName, String appUrl, String sanctumToken) async {
    try {
      print("===== Socket: $socketId");
      print("===== Channel: $channelName");
      final response = await http.post(
        Uri.parse('https://$appUrl/api/broadcasting/auth'),
        headers: {
          'Authorization': 'Bearer $sanctumToken',
          'Content-Type': 'application/x-www-form-urlencoded',
          'Accept': 'application/json',
        },
        body: Uri(queryParameters: {
          'socket_id': socketId,
          'channel_name': channelName,
        }).query,
      );
      if (response.statusCode == 200) {
        final authData = jsonDecode(response.body);
        final authToken = authData['auth'];
        return authToken;
      } else {
        throw HttpException('Authentication failed: ${response.statusCode} - ${response.body}');
      }
    } catch (e) {
      print('Authentication Error: $e');
      rethrow;
    }
  }



  Future<void> subscribeToPrivateChannel(String channelName, channel) async {

    final subscriptionMessage = {
      'event': 'pusher:subscribe',
      'data': {
        'channel': channelName,
      }
    };
    channel?.sink.add(jsonEncode(subscriptionMessage));
    print('Reverb Subscription message sent');
  }

  void _handleIncomingChat(Chat chat) async {
    // --- Atomic DB update to avoid flicker ---
    await _db.transaction(() async {
      String? inheritedLocalPath;
      Map<String, dynamic>? inheritedCaptionMap; // caption block from temp row

      if (chat.type == 'outbound') {
        // Find the OLDEST pending/sent temp row for this contact (FIFO matching).
        // Temp rows have negative IDs. Since id = -(timestamp), the least-negative
        // value is the oldest message, so we ORDER BY id DESC and take the first.
        final tempRows = await (_db.select(_db.chats)
          ..where((t) =>
              t.contactId.equals(chat.contactId) & t.id.isSmallerThanValue(0))
          ..orderBy([(t) => OrderingTerm(expression: t.id, mode: OrderingMode.desc)])
          ..limit(1))
            .get();

        if (tempRows.isNotEmpty) {
          final tempRow = tempRows.first;
          // metadata is stored as a JSON String in SQLite — must decode it
          try {
            final rawMeta = tempRow.metadata;
            if (rawMeta != null) {
              final meta = jsonDecode(rawMeta) as Map<String, dynamic>;
              inheritedLocalPath = meta['_localFilePath'] as String?;
              // Also inherit caption if server metadata won't have one
              if (inheritedCaptionMap == null) {
                final type = meta['type'] as String?;
                if (type != null && meta[type] is Map) {
                  final mediaBlock = Map<String, dynamic>.from(meta[type] as Map);
                  final cap = mediaBlock['caption'] as String?;
                  if (cap != null && cap.isNotEmpty) {
                    inheritedCaptionMap = {type: mediaBlock};
                  }
                }
              }
            }
          } catch (_) {}
          // Delete inside the same transaction so no intermediate empty state
          await (_db.delete(_db.chats)..where((t) => t.id.equals(tempRow.id))).go();
        }
      }

      // Build the final chat, injecting the local file path into metadata
      Chat finalChat = chat;
      if (inheritedLocalPath != null || inheritedCaptionMap != null) {
        final updatedMeta = Map<String, dynamic>.from(chat.metadata ?? {});
        if (inheritedLocalPath != null) {
          updatedMeta['_localFilePath'] = inheritedLocalPath;
        }
        // If server didn't store caption (old records), restore it from temp row
        if (inheritedCaptionMap != null) {
          final type = updatedMeta['type'] as String?;
          if (type != null && inheritedCaptionMap!.containsKey(type)) {
            final serverBlock = updatedMeta[type] as Map? ?? {};
            if (serverBlock['caption'] == null) {
              final mergedBlock = Map<String, dynamic>.from(serverBlock);
              final inherited = inheritedCaptionMap![type] as Map<String, dynamic>;
              mergedBlock['caption'] = inherited['caption'];
              updatedMeta[type] = mergedBlock;
            }
          }
        }
        finalChat = chat.copyWith(metadata: updatedMeta);
      }

      await _db.into(_db.chats).insertOnConflictUpdate(finalChat.toCompanion());

      // Save media row so getChatWithRelations can find it — preserving locally-downloaded paths
      if (chat.media != null) {
        await _db.upsertMediaPreservingLocal(chat.media!.toCompanion());
      }
    });

    // Update contact lastChat info (outside the chat transaction is fine)
    final contact = await (_db.select(_db.contacts)
      ..where((c) => c.id.equals(chat.contactId)))
        .getSingleOrNull();

    if (contact != null) {
      // Only real inbound content bumps the unread badge.
      // Reactions and unsupported events (stickers sent as reactions, polls,
      // etc.) are inbound+unread on the server but should not count as new
      // messages from the user's perspective.
      final metaType = chat.metadata?['type'] as String?;
      final isReaction = metaType == 'reaction';
      final isUnsupported = metaType == 'unsupported';
      final shouldBumpUnread = chat.type == 'inbound' && !chat.isRead && !isReaction && !isUnsupported;
      final updated = contact.copyWith(
        lastChatId: Value(chat.id),
        latestChatCreatedAt: Value(chat.createdAt),
        unreadCount: (contact.unreadCount ?? 0) + (shouldBumpUnread ? 1 : 0),
      );
      await _db.into(_db.contacts).insertOnConflictUpdate(updated.toCompanion(true));

      if (shouldBumpUnread) {
        _showLocalNotification(contact.fullName ?? contact.phone, chat);
      }
    }

    final controller = _ref.read(mainDataProvider.notifier);
    controller.updateContactWithNewMessage(chat);

    // Drift's watch() on the chats table automatically delivers the new row
    // to any active StreamProvider listener — no invalidate needed.
    // Calling invalidate here caused a loading→data cycle that remounted
    // ScrollablePositionedList and triggered a hard snap-to-bottom bounce.
  }

  /// Handle notifications for incoming messages.
  ///
  /// - App in background/killed  → system local notification.
  /// - App in foreground, same chat open → do nothing (user sees the message live).
  /// - App in foreground, different chat or another screen → in-app banner.
  void _showLocalNotification(String contactName, Chat chat) async {
    final messageBody = _buildMessageBody(chat);
    final appState = WidgetsBinding.instance.lifecycleState;
    final isInForeground = appState == AppLifecycleState.resumed;

    if (!isInForeground) {
      final localNotifications = FlutterLocalNotificationsPlugin();
      await localNotifications.show(
        id: chat.id,
        title: contactName,
        body: messageBody,
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
        payload: chat.contactId.toString(),
      );
      return;
    }

    // App is in foreground — show in-app banner only if this isn't the open chat.
    final activeContactId = _ref.read(activeContactIdProvider);
    if (activeContactId == chat.contactId) {
      // User is already reading this conversation — no banner needed.
      return;
    }

    _ref.read(inAppNotificationProvider.notifier).state = InAppNotification(
      contactId: chat.contactId,
      contactName: contactName,
      body: messageBody,
    );
  }

  /// Build a short human-readable description of the message for notifications.
  String _buildMessageBody(Chat chat) {
    String body = 'New message';
    try {
      final meta = chat.metadata;
      if (meta != null) {
        final metaType = meta['type'] as String? ?? 'text';
        String? rawText;
        switch (metaType) {
          case 'text':
            rawText = meta['text']?['body'] as String?;
            body = rawText ?? 'New message';
            break;
          case 'image':
            rawText = meta['image']?['caption'] as String?;
            body = rawText != null ? '📷 $rawText' : '📷 Image';
            break;
          case 'video':
            rawText = meta['video']?['caption'] as String?;
            body = rawText != null ? '🎥 $rawText' : '🎥 Video';
            break;
          case 'audio':
            body = '🎵 Audio';
            break;
          case 'document':
            rawText = meta['document']?['caption'] as String?
                ?? meta['document']?['filename'] as String?;
            body = rawText != null ? '📄 $rawText' : '📄 Document';
            break;
          case 'sticker':
            body = '🎨 Sticker';
            break;
          case 'location':
            body = '📍 Location';
            break;
          case 'contacts':
            body = '👤 Contact card';
            break;
          default:
            body = 'New message';
        }
        if (body.length > 100) body = '${body.substring(0, 97)}…';
      }
    } catch (_) {}
    return body;
  }

  // ---------------------------------------------------------------------------
  // Call event routing (Phase 3)
  // ---------------------------------------------------------------------------

  static const _callEventNames = {
    'IncomingCall',
    'OutgoingCallInitiated',
    'CallAccepted',
    'CallTakenByOtherAgent',
    'CallEnded',
    'CallMissed',
    'CallStatus',
    'CallPermissionUpdated',
  };

  bool _isCallEvent(dynamic raw) {
    if (raw is! String) return false;
    final name = _normalizeEventName(raw);
    return _callEventNames.contains(name);
  }

  String _normalizeEventName(String raw) =>
      raw.startsWith('.') ? raw.substring(1) : raw;

  void _handleCallEvent(String event, Map<String, dynamic> payload) {
    print('📞 Reverb call event: $event');
    // Lazy import to avoid a hard dependency cycle. CallController is exposed
    // through a Riverpod provider that the orchestrator side already binds.
    try {
      final controller = _ref.read(callControllerProvider.notifier);
      controller.handleRemoteCallEvent(event, payload);
    } catch (e) {
      print('⚠️ Could not dispatch call event $event: $e');
    }
  }

}
