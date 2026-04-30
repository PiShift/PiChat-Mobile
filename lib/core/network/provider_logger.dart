// lib/debug/provider_logger.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final class ProviderLogger extends ProviderObserver {
  @override
  void didUpdateProvider(ProviderObserverContext context, Object? previousValue, Object? newValue) {
    final name = context.provider.name ?? context.provider.runtimeType.toString();
    debugPrint('PROVIDER CHANGE -> $name : $previousValue -> $newValue');
  }

  @override
  void didAddProvider(ProviderObserverContext context, Object? value) {
    final name = context.provider.name ?? context.provider.runtimeType.toString();
    debugPrint('PROVIDER ADDED -> $name : $value');
  }

  @override
  void didDisposeProvider(ProviderObserverContext context) {
    final name = context.provider.name ?? context.provider.runtimeType.toString();
    debugPrint('PROVIDER DISPOSED -> $name');
  }
}
