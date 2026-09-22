import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pichat/features/chat/widgets/voice_mini_player.dart';

/// Mounts the bar the way the app does: above the Navigator, so there is no
/// [Overlay] anywhere above it. Anything that needs one — an IconButton
/// tooltip, for instance — asserts here rather than on a device.
Widget noOverlay(Widget child) => Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: Theme(data: ThemeData.light(), child: child),
      ),
    );

void main() {
  testWidgets('renders with no Overlay ancestor', (tester) async {
    await tester.pumpWidget(noOverlay(
      VoiceMiniPlayerBar(
        title: 'Bechir El Bechir',
        position: const Duration(seconds: 12),
        total: const Duration(seconds: 48),
        playing: true,
        onToggle: () {},
        onClose: () {},
      ),
    ));

    expect(tester.takeException(), isNull);
    expect(find.text('Bechir El Bechir'), findsOneWidget);
    expect(find.text('00:12 / 00:48'), findsOneWidget);
  });

  testWidgets('does not overflow on a narrow screen with a long name',
      (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(noOverlay(
      VoiceMiniPlayerBar(
        title: 'A contact with an extremely long display name that must clip',
        position: Duration.zero,
        total: const Duration(minutes: 3),
        playing: false,
        onToggle: () {},
        onClose: () {},
      ),
    ));

    expect(tester.takeException(), isNull);
  });

  testWidgets('controls fire', (tester) async {
    var toggled = 0;
    var closed = 0;

    await tester.pumpWidget(noOverlay(
      VoiceMiniPlayerBar(
        title: 'Voice message',
        position: Duration.zero,
        total: const Duration(seconds: 10),
        playing: true,
        onToggle: () => toggled++,
        onClose: () => closed++,
      ),
    ));

    await tester.tap(find.bySemanticsLabel('Pause'));
    await tester.tap(find.bySemanticsLabel('Close player'));

    expect(toggled, 1);
    expect(closed, 1);
  });

  testWidgets('an unknown duration still renders', (tester) async {
    await tester.pumpWidget(noOverlay(
      VoiceMiniPlayerBar(
        title: 'Voice message',
        position: const Duration(seconds: 3),
        total: null,
        playing: true,
        onToggle: () {},
        onClose: () {},
      ),
    ));

    expect(tester.takeException(), isNull);
    expect(find.text('00:03'), findsOneWidget);
  });
}
