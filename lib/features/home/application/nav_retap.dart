import 'package:flutter_riverpod/flutter_riverpod.dart';

/// A tap on a bottom-nav item whose tab is already showing.
///
/// Navigating again would be a no-op, so the shell publishes the tap here and
/// the screen decides what "you are already here" should mean — for the chat
/// list, scrolling back to the top.
///
/// [tick] exists because the tab index alone does not change between two
/// consecutive taps on the same item, and `ref.listen` only fires on a new
/// value.
typedef NavRetap = ({int tab, int tick});

class NavRetapNotifier extends Notifier<NavRetap> {
  @override
  NavRetap build() => (tab: -1, tick: 0);

  void bump(int tab) => state = (tab: tab, tick: state.tick + 1);
}

final navRetapProvider =
    NotifierProvider<NavRetapNotifier, NavRetap>(NavRetapNotifier.new);
