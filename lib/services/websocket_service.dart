import 'dart:developer';
import 'package:pusher_client_socket/pusher_client_socket.dart';

class ReverbService {
  late final PusherClient pusherClient;

  ReverbService();

  Future<void> init(String organizationId, String authToken) async {
    final options = PusherOptions(
      key: 'pi_9a885dd7c4f547c01',
      host: 'wss://wavely.pishift.co',
      wssPort: 443,
      encrypted: true, // wss
      authOptions: PusherAuthOptions(
        'https://wavely.pishift.co/broadcasting/auth',
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $authToken',
        },
      ),
      autoConnect: false,
    );

    pusherClient = PusherClient(options: options);

    // Debugging connection states
    pusherClient.onConnectionStateChange((state) {
      print("🔌 Reverb connection state: $state");
    });

    pusherClient.onConnectionError((error) {
      print("❌ Reverb connection error - $error");
    });

    pusherClient.onError((error) {
      print("⚠️ Reverb error - $error");
    });

    pusherClient.onDisconnected((data) {
      print("🔌 Reverb disconnected - $data");
    });

    // Connect and subscribe
    pusherClient.connect();

    final channelName = 'chats.ch$organizationId';
    final channel = pusherClient.subscribe(channelName);

    channel.bind('NewChatEvent', (event) {
      print("Reverb $organizationId");
      print("📩 Reverb received on $channelName: ${event.data}");
      // TODO: handle event.data (same as Vue updateSidePanel)
    });
  }
}
