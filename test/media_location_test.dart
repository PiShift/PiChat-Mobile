import 'package:flutter_test/flutter_test.dart';
import 'package:pichat/data/models/chat_media_model.dart';

Map<String, dynamic> payload({
  required String location,
  required String path,
}) =>
    {
      'id': 1,
      'meta_id': 'wamid.abc',
      'name': 'voice.ogg',
      'path': path,
      'location': location,
      'type': 'audio/ogg',
      'created_at': '2026-09-10T10:00:00.000Z',
    };

void main() {
  test('outbound media the server calls "local" is treated as remote', () {
    // What the server sends for anything we uploaded: its own disk is "local".
    final media = ChatMedia.fromJson(payload(
      location: 'local',
      path: 'https://pichat.mr/media/public/uploads/media/sent/1/voice.ogg',
    ));

    expect(media.location, isNot('local'),
        reason: 'an https path is not a file on this phone');
  });

  test('s3-hosted media stays remote', () {
    final media = ChatMedia.fromJson(payload(
      location: 'amazon',
      path: 'https://bucket.s3.amazonaws.com/voice.ogg',
    ));

    expect(media.location, isNot('local'));
  });

  test('a real on-device path is still local', () {
    // What updateMediaPath writes after this device downloads a file.
    final media = ChatMedia.fromJson(payload(
      location: 'local',
      path: 'chat_media/7/audio/123.ogg',
    ));

    expect(media.location, 'local');
  });

  test('the url is preserved so it can still be downloaded', () {
    const url = 'https://pichat.mr/media/public/uploads/media/sent/1/voice.ogg';

    expect(ChatMedia.fromJson(payload(location: 'local', path: url)).path, url);
  });
}
