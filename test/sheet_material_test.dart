import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pichat/data/models/chat_log_model.dart';
import 'package:pichat/data/models/chat_model.dart';
import 'package:pichat/features/chat/widgets/message_info_sheet.dart';

/// The sheets are full of ListTiles, which paint their background and ink onto
/// the nearest Material ancestor. A coloured Container between the two hides
/// every splash, and Flutter reports it as
/// "ListTile background color or ink splashes may be invisible."
///
/// That is an assertion, not an exception, so it only ever shows up at runtime
/// in debug — which is exactly the kind of thing worth pinning down in a test.
Widget host(Widget child) => MaterialApp(
      home: Scaffold(body: child),
    );

/// easy_localization is not initialised under test, so `.tr()` renders the key
/// verbatim. Asserting on the key keeps these checks real rather than
/// vacuously passing on copy that was never looked up.
const nobodyOpened = 'message_info.nobody_opened';
const deliveryHeading = 'MESSAGE_INFO.DELIVERY';

Chat message({List<ChatLog> logs = const []}) => Chat(
      id: 812,
      orgId: 1,
      uuid: 'chat-uuid',
      contactId: 5,
      type: 'outbound',
      metadata: const {
        'type': 'text',
        'text': {'body': 'hello'},
      },
      status: 'read',
      isRead: false,
      createdAt: DateTime(2026, 9, 15, 14, 31, 55),
      logs: logs,
    );

ChatLog read(String name, DateTime at) => ChatLog(
      id: 2,
      chatId: 812,
      userId: 3,
      userName: name,
      metadata: const {'status': 'agent_read'},
      createdAt: at,
    );

ChatLog delivery(String status, DateTime at) => ChatLog(
      id: 1,
      chatId: 812,
      metadata: {'status': status},
      createdAt: at,
    );

void main() {
  testWidgets('the info sheet raises no ink/material assertion', (tester) async {
    await tester.pumpWidget(host(MessageInfoSheet(
      message: message(logs: [
        read('Bechir El Bechir', DateTime(2026, 9, 15, 14, 32, 1)),
        delivery('delivered', DateTime(2026, 9, 15, 14, 31, 58)),
      ]),
    )));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Bechir El Bechir'), findsOneWidget);
    // Second precision is the whole point of the screen.
    expect(find.text('15 Sep · 14:32:01'), findsOneWidget);
    // Outbound: the delivery section is present here, which is what makes the
    // `findsNothing` on the inbound case below mean something.
    expect(find.text(deliveryHeading), findsOneWidget);
  });

  testWidgets('with nobody having opened it, it says so', (tester) async {
    await tester.pumpWidget(host(MessageInfoSheet(message: message())));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text(nobodyOpened), findsOneWidget);
  });

  testWidgets('an inbound message shows no delivery section', (tester) async {
    await tester.pumpWidget(host(MessageInfoSheet(
      message: Chat(
        id: 813,
        orgId: 1,
        uuid: 'u',
        contactId: 5,
        type: 'inbound',
        metadata: const {'type': 'text'},
        status: 'delivered',
        isRead: true,
        createdAt: DateTime(2026, 9, 15, 14, 0, 0),
        logs: [read('Fatim', DateTime(2026, 9, 15, 14, 0, 9))],
      ),
    )));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    // Nobody "opens" a message the customer sent us on the customer's behalf.
    expect(find.text(deliveryHeading), findsNothing);
    expect(find.text('Fatim'), findsOneWidget);
  });
}
