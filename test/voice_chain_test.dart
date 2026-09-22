import 'package:flutter_test/flutter_test.dart';
import 'package:pichat/data/models/chat_media_model.dart';
import 'package:pichat/data/models/chat_model.dart';
import 'package:pichat/features/chat/application/voice_chain.dart';

int _id = 0;

Chat message({ChatMedia? media, Map<String, dynamic>? metadata}) {
  _id++;

  return Chat(
    id: _id,
    orgId: 1,
    uuid: 'u$_id',
    contactId: 7,
    type: 'inbound',
    metadata: metadata,
    media: media,
    status: 'sent',
    isRead: true,
    createdAt: DateTime(2026, 9, 11).add(Duration(minutes: _id)),
  );
}

ChatMedia _media(int id, String type, {String? path}) => ChatMedia(
      id: id,
      type: type,
      path: path,
      createdAt: DateTime(2026, 9, 11),
    );

/// A recorded voice note: WhatsApp's own flag, on an ogg container.
Chat voice(int id) => message(
      media: _media(id, 'audio/ogg'),
      metadata: {
        'type': 'audio',
        'audio': {'voice': true},
      },
    );

/// An attached audio file — audio, but not a voice note.
Chat audioFile(int id) => message(
      media: _media(id, 'audio/mpeg', path: 'song.mp3'),
      metadata: {'type': 'audio', 'audio': {}},
    );

Chat text() => message(metadata: {'type': 'text'});

void main() {
  setUp(() => _id = 0);

  test('a run of three notes links straight through', () {
    final links = voiceLinksFrom([voice(1), voice(2), voice(3)]);

    expect(links['1'], '2');
    expect(links['2'], '3');
    expect(links['3'], isNull, reason: 'the run ends in silence');
  });

  test('a message between two notes breaks the run', () {
    final links = voiceLinksFrom([voice(1), text(), voice(2)]);

    expect(links['1'], isNull);
    expect(links, isEmpty);
  });

  test('runs on either side of a message stay separate', () {
    final links =
        voiceLinksFrom([voice(1), voice(2), text(), voice(3), voice(4)]);

    expect(links['1'], '2');
    expect(links['2'], isNull, reason: 'must not jump the text message');
    expect(links['3'], '4');
  });

  test('an attached audio file is not part of a run', () {
    final links = voiceLinksFrom([voice(1), audioFile(2), voice(3)]);

    expect(links, isEmpty);
  });

  test('a lone note links to nothing', () {
    expect(voiceLinksFrom([text(), voice(1), text()]), isEmpty);
  });

  test('an .ogg with no voice flag still counts, for older rows', () {
    final links = voiceLinksFrom([
      message(media: _media(1, 'audio/ogg')),
      message(media: _media(2, 'audio/ogg')),
    ]);

    expect(links['1'], '2');
  });

  group('auto-play requests', () {
    late VoiceChainNotifier chain;

    setUp(() => chain = VoiceChainNotifier());

    test('a request is consumed once, so a pause does not restart it', () {
      chain.requestAutoPlay('b');
      expect(chain.state.autoPlay, 'b');

      chain.consume('b');
      expect(chain.state.autoPlay, isNull);
    });

    test('one bubble cannot consume another bubble request', () {
      chain.requestAutoPlay('b');
      chain.consume('a');

      expect(chain.state.autoPlay, 'b');
    });
  });
}
