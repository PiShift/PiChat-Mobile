import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pichat/data/models/chat_media_model.dart';
import 'package:pichat/features/chat/application/media_providers.dart';
import 'package:pichat/features/chat/widgets/image_preview.dart';

/// A sticker as it arrives from Meta: nothing on disk, no servable URL, just
/// a meta_url to fetch it with.
ChatMedia undownloaded() => ChatMedia(
      id: 99,
      metaId: 'meta-media-id',
      name: 'N/A',
      path: null,
      metaUrl: 'https://lookaside.fbsbx.com/whatsapp/sticker',
      location: 'meta',
      type: 'image/webp',
    );

Widget host({required bool isSticker}) => ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: ImagePreview(
            media: undownloaded(),
            mediaId: 'auto-1',
            contactId: '7',
            metaId: 'meta-media-id',
            isSticker: isSticker,
          ),
        ),
      ),
    );

void main() {
  // Each test builds its own ProviderContainer, so each one constructs an
  // AppDatabase. That is a test-harness artifact, not the app's behaviour.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  group('state', () {
    test('a retry clears the error from the previous attempt', () {
      // `error: null` could not clear the field, so a failed download kept
      // showing its old error underneath every retry.
      final failed = MediaPlaybackState(error: 'boom');

      expect(failed.copyWith(clearError: true).error, isNull);
      expect(failed.copyWith(isDownloading: true).error, 'boom',
          reason: 'an unrelated update must not drop the error');
    });

    test('autoAttempted survives an unrelated update', () {
      final attempted = MediaPlaybackState(autoAttempted: true);

      expect(attempted.copyWith(isDownloading: true).autoAttempted, isTrue);
    });
  });

  group('sticker bubble', () {
    testWidgets('fetches itself with no user tap', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: ImagePreview(
              media: undownloaded(),
              mediaId: 'auto-1',
              contactId: '7',
              isSticker: true,
            ),
          ),
        ),
      ));
      await tester.pump();

      expect(container.read(mediaPlaybackProvider('auto-1')).autoAttempted,
          isTrue,
          reason: 'the sticker should request itself after the first frame');
    });

    testWidgets('a photo still waits to be asked', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          home: Scaffold(
            body: ImagePreview(
              media: undownloaded(),
              mediaId: 'photo-1',
              contactId: '7',
            ),
          ),
        ),
      ));
      await tester.pump();

      expect(container.read(mediaPlaybackProvider('photo-1')).autoAttempted,
          isFalse,
          reason: 'auto-fetching every photo would spend the user\'s data');
      expect(find.byIcon(LucideIcons.download), findsOneWidget);
    });

    testWidgets('shows a retry button once the fetch has failed',
        (tester) async {
      // No organization is selected in the test container, so the download
      // fails the way a real one would with no access token.
      await tester.pumpWidget(host(isSticker: true));

      // First frame: fetching, so no button yet.
      expect(find.byIcon(LucideIcons.download), findsNothing);
      expect(find.byIcon(LucideIcons.refreshCw), findsNothing);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      await tester.pump();
      await tester.pump();

      expect(find.byIcon(LucideIcons.refreshCw), findsOneWidget,
          reason: 'a failed sticker needs a way back');
    });

    testWidgets('does not re-request itself on every rebuild', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Every real fetch flips isDownloading on once, so counting that edge
      // counts attempts. Asserting on the flag's value instead would pass
      // either way: it is back to false by the time the rebuilds are done.
      var attempts = 0;
      container.listen(mediaPlaybackProvider('loop-1'), (prev, next) {
        if (next.isDownloading && !(prev?.isDownloading ?? false)) attempts++;
      });

      Widget build() => UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: ImagePreview(
                  media: undownloaded(),
                  mediaId: 'loop-1',
                  contactId: '7',
                  isSticker: true,
                ),
              ),
            ),
          );

      await tester.pumpWidget(build());
      await tester.pump();
      await tester.pump();

      expect(container.read(mediaPlaybackProvider('loop-1')).error, isNotNull,
          reason: 'the first attempt should have run and failed');
      expect(attempts, 1);

      // Rebuild the way scrolling a thread past the sticker would.
      for (var i = 0; i < 5; i++) {
        await tester.pumpWidget(build());
        await tester.pump();
      }

      expect(attempts, 1,
          reason: 'a failed sticker must not re-request on every rebuild');
    });
  });
}
