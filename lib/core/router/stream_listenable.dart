// lib/core/router/stream_listenable.dart
import 'dart:async';
import 'package:flutter/foundation.dart';

/// Small utility that turns one or many Streams into a ChangeNotifier
/// you can pass to GoRouter.refreshListenable.
/// It listens to each stream and calls notifyListeners() on any event/error.
class StreamListenable extends ChangeNotifier {
  final List<StreamSubscription> _subs = [];

  StreamListenable(Iterable<Stream<dynamic>> streams) {
    for (final s in streams) {
      _subs.add(s.listen(
            (_) => notifyListeners(),
        onError: (_) => notifyListeners(),
      ));
    }
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _subs.clear();
    super.dispose();
  }
}
