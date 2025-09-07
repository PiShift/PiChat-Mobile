// lib/debug/provider_logger.dart
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ProviderLogger extends ProviderObserver {
  @override
  void didUpdateProvider(ProviderBase provider, Object? previousValue, Object? newValue, ProviderContainer container) {
    final name = provider.name ?? provider.runtimeType.toString();
    debugPrint('PROVIDER CHANGE -> $name : $previousValue -> $newValue');
  }

  @override
  void didAddProvider(ProviderBase provider, Object? value, ProviderContainer container) {
    final name = provider.name ?? provider.runtimeType.toString();
    debugPrint('PROVIDER ADDED -> $name : $value');
  }

  @override
  void didDisposeProvider(ProviderBase provider, ProviderContainer container) {
    final name = provider.name ?? provider.runtimeType.toString();
    debugPrint('PROVIDER DISPOSED -> $name');
  }
}
