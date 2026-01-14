import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage_x/flutter_secure_storage_x.dart';
import 'package:pichat/data/db/app_database.dart';
import 'package:pichat/data/models/chat_model.dart';
import 'package:pichat/features/chat/application/main_controller.dart';
import 'package:web_socket_channel/io.dart';
import 'package:web_socket_channel/status.dart' as status;
import 'package:http/http.dart' as http;

class ReverbService {
  final String host;
  final String appKey;
  final bool useSecure;
  IOWebSocketChannel? _channel;
  bool _connected = false;
  int _reconnectAttempts = 0;
  String? organizationId;
  late AppDatabase _db;
  final Ref _ref;

  ReverbService({
    required this.host,
    required this.appKey,
    this.useSecure = true,
    required this.organizationId,
    required AppDatabase db,
    required Ref ref,
  }) : _db = db,
        _ref = ref;

  void init({required String orgId, required AppDatabase database}) {
    organizationId = orgId;
    _db = database;
  }

  void connect() async {
    if (_connected) return;
    if (organizationId == null) {
      print("❌ Cannot connect: orgId is null");
      return;
    }

    final scheme = useSecure ? 'wss' : 'ws';
    final uri = Uri.parse('$scheme://$host/app/$appKey');
    final AppDatabase _db;
    print('Reverb connecting to $uri');

    // Dispose old channel if any
    try {
      await _channel?.sink.close();
    } catch (_) {}
    _channel = null;

    try {
      _channel = IOWebSocketChannel.connect(uri);

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
          } else if (data['event'] == 'pusher:pong') {
            print("📩 Reverb Got pong");
          } else if (data['event'] == 'NewChatEvent') {
            final payload = json.decode(data['data']);

            final chatList = payload['chat'] as List;
            final chat = Chat.fromJson(chatList.first['value']);

            print("✅ New chat received: $chat");
            _handleIncomingChat(chat);
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
    // Save to DB
    await _db.into(_db.chats).insertOnConflictUpdate(chat.toCompanion());

    // Update contact lastChat info if needed
    final contact = await (_db.select(_db.contacts)
      ..where((c) => c.id.equals(chat.contactId)))
        .getSingleOrNull();

    if (contact != null) {
      final updated = contact.copyWith(
        lastChatId: Value(chat.id),
        latestChatCreatedAt: Value(chat.createdAt),
        unreadCount: (contact.unreadCount ?? 0) + (chat.isRead ? 0 : 1),
      );
      await _db.into(_db.contacts).insertOnConflictUpdate(updated.toCompanion(true));
    }

    // Optionally trigger state refresh
    // _ref.read(mainDataProvider.notifier).refreshContacts();
    final controller = _ref.read(mainDataProvider.notifier);
    controller.updateContactWithNewMessage(chat);

  }

}
