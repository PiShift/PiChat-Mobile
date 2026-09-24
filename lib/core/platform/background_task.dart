import 'dart:io';

import 'package:flutter/services.dart';

/// Asks the OS for time to finish work after the app leaves the foreground.
///
/// iOS suspends an app within seconds of it being backgrounded, which cut
/// uploads off mid-request: a voice note sent just before switching apps
/// never arrived. Wrapping a send in [run] asks for the extra time iOS grants
/// to finish a task (typically up to about 30 seconds). Android keeps the
/// process running, so there this is a pass-through.
class BackgroundTask {
  BackgroundTask._();

  static const _channel = MethodChannel('pichat/background_task');

  static Future<T> run<T>(Future<T> Function() work) async {
    if (!Platform.isIOS) return work();

    int? id;

    try {
      id = await _channel.invokeMethod<int>('begin');
    } catch (_) {
      // No time granted; do the work anyway.
    }

    try {
      return await work();
    } finally {
      if (id != null) {
        try {
          await _channel.invokeMethod('end', id);
        } catch (_) {}
      }
    }
  }
}
