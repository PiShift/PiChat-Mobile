import 'package:flutter_test/flutter_test.dart';
import 'package:pichat/data/models/chat_log_model.dart';
import 'package:pichat/data/models/chat_model.dart';
import 'package:pichat/data/models/contact_model.dart';
import 'package:pichat/features/chat/widgets/message_info_sheet.dart';

/// A message as `GET /contacts/{id}/messages` sends it, carrying both event
/// relations.
Map<String, dynamic> messageJson({
  List<Map<String, dynamic>> logs = const [],
  List<Map<String, dynamic>> readers = const [],
}) =>
    {
      'id': 812,
      'organization_id': 1,
      'uuid': 'chat-uuid',
      'contact_id': 5,
      'type': 'outbound',
      'metadata': '{"type":"text","text":{"body":"hello"}}',
      'status': 'read',
      'is_read': 0,
      'created_at': '2026-09-15 14:31:55',
      'logs': logs,
      'readers': readers,
    };

void main() {
  group('Chat.fromJson log relations', () {
    test('parses delivery receipts and agent reads into one list', () {
      final chat = Chat.fromJson(messageJson(
        logs: [
          {
            'id': 1,
            'chat_id': 812,
            'metadata': '{"status":"delivered","timestamp":"1789"}',
            'user_id': null,
            'created_at': '2026-09-15 14:31:58',
          },
        ],
        readers: [
          {
            'id': 2,
            'chat_id': 812,
            'metadata': '{"status":"agent_read"}',
            'user_id': 3,
            'created_at': '2026-09-15 14:32:01',
            'user': {
              'id': 3,
              'first_name': 'Bechir',
              'last_name': 'El Bechir',
              'full_name': 'Bechir El Bechir',
            },
          },
        ],
      ));

      expect(chat.logs, hasLength(2));

      final reads = chat.logs.where((l) => l.isAgentRead).toList();
      expect(reads, hasLength(1));
      expect(reads.single.userName, 'Bechir El Bechir');
      expect(reads.single.createdAt, DateTime(2026, 9, 15, 14, 32, 1));

      final delivery = chat.logs.where((l) => !l.isAgentRead).toList();
      expect(delivery, hasLength(1));
      expect(delivery.single.deliveryStatus, 'delivered');
    });

    test('a message with no relations has no logs', () {
      expect(Chat.fromJson(messageJson()).logs, isEmpty);
    });

    test('a malformed log is dropped without losing the message', () {
      final chat = Chat.fromJson(messageJson(
        logs: [
          {'id': 1, 'chat_id': 812, 'metadata': 'not json', 'created_at': null},
        ],
        readers: [
          {
            'id': 2,
            'chat_id': 812,
            'metadata': '{"status":"agent_read"}',
            'user_id': 3,
            'created_at': '2026-09-15 14:32:01',
            'user': {'id': 3, 'first_name': 'Bechir', 'last_name': ''},
          },
        ],
      ));

      expect(chat.logs, hasLength(2));
      // Unparseable metadata costs the status, not the row.
      expect(chat.logs.first.metadata, isNull);
      // Falls back to the name parts when full_name is absent.
      expect(chat.logs.last.userName, 'Bechir');
    });

    test('metadata survives a round trip through the database companion', () {
      final log = ChatLog.fromJson({
        'id': 2,
        'chat_id': 812,
        'metadata': '{"status":"agent_read"}',
        'user_id': 3,
        'created_at': '2026-09-15 14:32:01',
      });

      // toString() would write Dart's map notation, which does not read back.
      final stored = log.toCompanion().metadata.value;
      expect(ChatLog.fromJson({...log.toJson(), 'metadata': stored}).deliveryStatus,
          'agent_read');
    });
  });

  group('formatStamp', () {
    test('keeps seconds — the whole point of the log', () {
      expect(formatStamp(DateTime(2026, 9, 15, 14, 32, 7)), '15 Sep · 14:32:07');
    });

    test('tolerates a missing timestamp', () {
      expect(formatStamp(null), '—');
    });
  });

  group('Contact.copyWith', () {
    Contact contact() => Contact(
          id: 5,
          uuid: 'c',
          orgId: 1,
          phone: '+22200000000',
          formattedPhone: '+222 00 00 00 00',
          unreadCount: 0,
          unreadMessages: 0,
          createdAt: DateTime(2026, 9, 1),
          assignedAgentId: 3,
          assignedAgentName: 'Bechir',
          ticketStatus: 'open',
        );

    test('clearAssignment removes the agent, which `??` cannot express', () {
      final cleared = contact().copyWith(clearAssignment: true);

      expect(cleared.assignedAgentId, isNull);
      expect(cleared.assignedAgentName, isNull);
      expect(cleared.hasTicketData, isTrue);
    });

    test('without the flag the agent is carried through', () {
      final same = contact().copyWith(ticketStatus: 'closed');

      expect(same.assignedAgentName, 'Bechir');
      expect(same.ticketStatus, 'closed');
    });
  });
}
