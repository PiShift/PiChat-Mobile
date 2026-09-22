import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pichat/data/models/chat_media_model.dart';
import 'package:pichat/data/models/chat_model.dart';
import 'package:pichat/features/chat/widgets/chat_item.dart';
import 'package:pichat/features/chat/widgets/document_preview.dart';
import 'package:pichat/features/chat/widgets/image_preview.dart';

/// Meta sends no filename for a sticker, so the backend writes the media row's
/// name as the literal "N/A" (only documents get a real filename). The bubble
/// had no `sticker` branch, so it fell through to the generic document card and
/// rendered as a file row titled "N/A" with no artwork at all.
Chat sticker() => Chat(
      id: 41,
      orgId: 1,
      uuid: 'sticker-uuid',
      contactId: 7,
      type: 'inbound',
      metadata: const {
        'type': 'sticker',
        'sticker': {'id': 'meta-media-id', 'mime_type': 'image/webp'},
      },
      status: 'delivered',
      isRead: true,
      createdAt: DateTime(2026, 9, 20, 11, 4),
      media: ChatMedia(
        id: 99,
        metaId: 'meta-media-id',
        // Exactly what ProcessWhatsappMessageEvent stores for a sticker.
        name: 'N/A',
        path: null,
        metaUrl: 'https://lookaside.fbsbx.com/whatsapp/sticker',
        location: 'meta',
        type: 'image/webp',
      ),
    );

Widget host(Chat message) => ProviderScope(
      child: MaterialApp(
        home: Scaffold(
          body: ChatMessageItem(message: message, contactUuid: 'contact-uuid'),
        ),
      ),
    );

void main() {
  testWidgets('a sticker renders as an image, not an "N/A" document card',
      (tester) async {
    await tester.pumpWidget(host(sticker()));

    expect(find.byType(ImagePreview), findsOneWidget,
        reason: 'a sticker is an image and belongs in the image pipeline');
    expect(find.byType(DocumentPreview), findsNothing,
        reason: 'the document card is what produced the "N/A" bubble');
    expect(find.text('N/A'), findsNothing);
  });

  testWidgets('the sticker keeps its own proportions and stays sticker-sized',
      (tester) async {
    await tester.pumpWidget(host(sticker()));

    final preview = tester.widget<ImagePreview>(find.byType(ImagePreview));

    expect(preview.isSticker, isTrue,
        reason: 'cover-cropping a sticker to the photo frame cuts its edges off');
  });

  testWidgets('a sticker sits on the page rather than in a bubble',
      (tester) async {
    await tester.pumpWidget(host(sticker()));

    // The bubble chrome is the one clipped Container wrapping the media.
    final decorated = tester
        .widgetList<Container>(find.ancestor(
          of: find.byType(ImagePreview),
          matching: find.byType(Container),
        ))
        .where((c) => c.decoration is BoxDecoration)
        .map((c) => c.decoration! as BoxDecoration);

    expect(decorated, isNotEmpty, reason: 'the bubble container should be found');

    for (final d in decorated) {
      expect(d.color, anyOf(isNull, Colors.transparent),
          reason: 'a transparent sticker would fill with the bubble colour');
      expect(d.border, isNull, reason: 'a border boxes the artwork in');
    }
  });
}
