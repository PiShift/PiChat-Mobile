import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pichat/features/home/application/nav_retap.dart';

void main() {
  late ProviderContainer container;

  setUp(() => container = ProviderContainer());
  tearDown(() => container.dispose());

  test('starts on no tab', () {
    expect(container.read(navRetapProvider).tab, -1);
  });

  test('two taps on the same tab are two distinct events', () {
    final seen = <NavRetap>[];
    container.listen(navRetapProvider, (_, next) => seen.add(next),
        fireImmediately: false);

    final notifier = container.read(navRetapProvider.notifier);
    notifier.bump(0);
    notifier.bump(0);

    // The tab alone never changes between consecutive re-taps, so without the
    // tick the second tap would be swallowed as "same value".
    expect(seen.map((e) => e.tab), [0, 0]);
    expect(seen.map((e) => e.tick), [1, 2]);
  });

  test('carries the tab that was re-tapped', () {
    container.read(navRetapProvider.notifier).bump(3);

    expect(container.read(navRetapProvider).tab, 3);
  });
}
