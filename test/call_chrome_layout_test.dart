import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pichat/features/calls/widgets/call_chrome.dart';

/// Stands in for the app below the strip. It records the State instance so a
/// test can tell "rebuilt" apart from "thrown away and built again" — the
/// latter is what discarded the router's state and bounced the agent back to
/// the chat list.
class _App extends StatefulWidget {
  const _App();

  @override
  State<_App> createState() => _AppState();
}

class _AppState extends State<_App> {
  @override
  Widget build(BuildContext context) => const SizedBox(width: 10, height: 10);
}

Widget host({Widget? callStrip, Widget? voiceStrip}) => Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(padding: EdgeInsets.only(top: 44)),
        child: CallChromeLayout(
          callStrip: callStrip,
          voiceStrip: voiceStrip,
          child: const _App(),
        ),
      ),
    );

void main() {
  testWidgets('showing a strip does not rebuild the app below it',
      (tester) async {
    await tester.pumpWidget(host());

    final before = tester.state<_AppState>(find.byType(_App));

    // A voice note starts playing outside its conversation.
    await tester.pumpWidget(host(voiceStrip: const Text('voice')));

    expect(
      identical(tester.state<_AppState>(find.byType(_App)), before),
      isTrue,
      reason: 'the app must keep its state when a strip appears',
    );

    // And a call arrives on top of it.
    await tester.pumpWidget(
      host(callStrip: const Text('call'), voiceStrip: const Text('voice')),
    );

    expect(identical(tester.state<_AppState>(find.byType(_App)), before), isTrue);

    // Everything goes away again.
    await tester.pumpWidget(host());

    expect(identical(tester.state<_AppState>(find.byType(_App)), before), isTrue,
        reason: 'nor when every strip is dismissed');
  });

  testWidgets('the status bar inset is removed only while a strip shows',
      (tester) async {
    await tester.pumpWidget(host());

    expect(
      MediaQuery.of(tester.element(find.byType(_App))).padding.top,
      44,
      reason: 'with no strip the screen keeps its own inset',
    );

    await tester.pumpWidget(host(voiceStrip: const Text('voice')));

    expect(
      MediaQuery.of(tester.element(find.byType(_App))).padding.top,
      0,
      reason: 'the strip has already taken it; keeping it doubles the gap',
    );
  });

  testWidgets('an empty slot takes no space', (tester) async {
    await tester.pumpWidget(host());

    expect(tester.getTopLeft(find.byType(_App)).dy, 0);
  });
}
