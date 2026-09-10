import 'package:flutter_test/flutter_test.dart';
import 'package:pichat/features/chat/application/local_media_manager.dart';

void main() {
  test('a recording under chat_media is stored relative', () {
    const abs = '/var/mobile/Containers/Data/Application/AAA-111/Documents'
        '/chat_media/42/audio/voice_1700000000000.ogg';

    expect(
      LocalMediaManager.storedPath(abs),
      'chat_media/42/audio/voice_1700000000000.ogg',
    );
  });

  test('a path outside our tree is left alone', () {
    const abs = '/var/mobile/Containers/Data/Application/AAA-111/tmp/img.jpg';

    expect(LocalMediaManager.storedPath(abs), abs);
  });

  test('the stored form survives the container UUID changing', () {
    const before = '/Containers/Data/Application/AAA-111/Documents'
        '/chat_media/42/audio/voice_1.ogg';

    // What the old build wrote: a temp path with no marker to re-anchor by.
    const legacy = '/Containers/Data/Application/AAA-111/tmp/voice_1.m4a';

    expect(LocalMediaManager.storedPath(before).startsWith('/'), isFalse);
    expect(LocalMediaManager.storedPath(legacy).startsWith('/'), isTrue);
  });
}
