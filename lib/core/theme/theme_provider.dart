import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage_x/flutter_secure_storage_x.dart';
import 'package:pichat/data/repositories/settings_repository.dart';

import 'app_theme.dart';

const _kThemeKey = 'app_theme_mode';

// ─── ThemeMode state ─────────────────────────────────────────────────────────

/// Persisted theme mode. Defaults to [ThemeMode.system] until a persisted
/// value is loaded, then switches to whatever the user last selected.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  static const _storage = FlutterSecureStorage();

  @override
  ThemeMode build() {
    // Read persisted value asynchronously; state starts as system.
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    final raw = await _storage.read(key: _kThemeKey);
    if (raw != null) {
      state = _parse(raw);
    }
  }

  Future<void> setMode(ThemeMode mode) async {
    state = mode;
    await _storage.write(key: _kThemeKey, value: mode.name);
  }

  /// Toggle between light ↔ dark (ignores system preference).
  Future<void> toggle() async {
    await setMode(state == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark);
  }

  ThemeMode _parse(String raw) {
    return ThemeMode.values.firstWhere(
      (m) => m.name == raw,
      orElse: () => ThemeMode.system,
    );
  }
}

final themeModeProvider = NotifierProvider<ThemeModeNotifier, ThemeMode>(
  ThemeModeNotifier.new,
);

// ─── Derived theme providers ──────────────────────────────────────────────────

/// Resolves the effective [ThemeMode] from both the local toggle and the
/// backend [AppSettings.theme] field (backend wins on first load if not yet
/// locally set).
final resolvedThemeModeProvider = Provider<ThemeMode>((ref) {
  final local = ref.watch(themeModeProvider);

  // If the user has explicitly picked a mode, trust it.
  if (local != ThemeMode.system) {
    return local;
  }

  // Fall back to backend settings.
  final settingsAsync = ref.watch(appSettingsProvider);
  return settingsAsync.maybeWhen(
    data: (s) {
      switch (s.theme) {
        case 'dark':
          return ThemeMode.dark;
        case 'light':
          return ThemeMode.light;
        default:
          return ThemeMode.system;
      }
    },
    orElse: () => ThemeMode.system,
  );
});

final lightThemeProvider = Provider<ThemeData>((_) => buildLightTheme());
final darkThemeProvider  = Provider<ThemeData>((_) => buildDarkTheme());
