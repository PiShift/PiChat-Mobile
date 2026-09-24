import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';

/// What another app handed to PiChat through the system share sheet.
class SharedPayload {
  const SharedPayload({this.files = const [], this.text});

  /// Local copies of the shared files, made by the plugin.
  final List<SharedMediaFile> files;

  /// Shared text or link, sent as a message rather than a file.
  final String? text;

  bool get isEmpty => files.isEmpty && (text == null || text!.trim().isEmpty);
}

/// A share waiting for the agent to pick who it goes to.
final pendingShareProvider = StateProvider<SharedPayload?>((ref) => null);

/// Picks up shares from the OS — the one that launched the app, and any that
/// arrive while it is running — and parks them in [pendingShareProvider].
class ShareIntentService {
  ShareIntentService(this._ref);

  final Ref _ref;
  StreamSubscription<List<SharedMediaFile>>? _sub;

  Future<void> start() async {
    _sub ??= ReceiveSharingIntent.instance.getMediaStream().listen(
          _receive,
          onError: (_) {},
        );

    try {
      _receive(await ReceiveSharingIntent.instance.getInitialMedia());
    } catch (_) {}
  }

  void _receive(List<SharedMediaFile> items) {
    if (items.isEmpty) return;

    final files = <SharedMediaFile>[];
    final texts = <String>[];

    for (final item in items) {
      switch (item.type) {
        case SharedMediaType.text:
        case SharedMediaType.url:
          texts.add(item.path);
        default:
          files.add(item);
          // iOS carries the text typed in the share sheet alongside.
          final note = item.message;
          if (note != null && note.trim().isNotEmpty) texts.add(note);
      }
    }

    final payload = SharedPayload(
      files: files,
      text: texts.isEmpty ? null : texts.toSet().join('\n'),
    );

    if (payload.isEmpty) return;

    _ref.read(pendingShareProvider.notifier).state = payload;

    // Handled; otherwise the same share is delivered again on next launch.
    ReceiveSharingIntent.instance.reset();
  }

  void dispose() => _sub?.cancel();
}

final shareIntentServiceProvider = Provider<ShareIntentService>((ref) {
  final service = ShareIntentService(ref);
  ref.onDispose(service.dispose);
  return service;
});
