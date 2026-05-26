import 'package:flutter_secure_storage_x/flutter_secure_storage_x.dart';

/// A single notification sound option available in the in-app picker.
///
/// [assetPath]    — Flutter asset used for in-app preview via just_audio.
///                  These files live in assets/sounds/.
/// [iosSoundFile] — Filename (with extension) of the .caf file that must be
///                  added to ios/Runner/ in Xcode so iOS can play it when
///                  a notification arrives in the background / killed state.
///                  null means "use the system default notification sound".
class PiChatNotificationSound {
  final String id;
  final String label;
  final String? assetPath;
  final String? iosSoundFile;

  const PiChatNotificationSound({
    required this.id,
    required this.label,
    this.assetPath,
    this.iosSoundFile,
  });

  bool get isDefault => id == 'default';
}

class NotificationSoundService {
  static const _storage = FlutterSecureStorage();
  static const _storageKey = 'pichat_notification_sound';

  /// The full list of sounds shown in the picker.
  ///
  /// To add more sounds:
  ///   1. Drop the .caf file into ios/Runner/ (add via Xcode so it is in the bundle).
  ///   2. Drop the same file (or an .mp3 preview copy) into assets/sounds/.
  ///   3. Add an entry here.
  static const List<PiChatNotificationSound> sounds = [
    PiChatNotificationSound(
      id: 'default',
      label: 'Default',
    ),
    PiChatNotificationSound(
      id: 'note',
      label: 'Note',
      assetPath: 'assets/sounds/note.caf',
      iosSoundFile: 'note.caf',
    ),
    PiChatNotificationSound(
      id: 'chime',
      label: 'Chime',
      assetPath: 'assets/sounds/chime.caf',
      iosSoundFile: 'chime.caf',
    ),
    PiChatNotificationSound(
      id: 'ping',
      label: 'Ping',
      assetPath: 'assets/sounds/ping.caf',
      iosSoundFile: 'ping.caf',
    ),
    PiChatNotificationSound(
      id: 'pop',
      label: 'Pop',
      assetPath: 'assets/sounds/pop.caf',
      iosSoundFile: 'pop.caf',
    ),
    PiChatNotificationSound(
      id: 'alert',
      label: 'Alert',
      assetPath: 'assets/sounds/alert.caf',
      iosSoundFile: 'alert.caf',
    ),
  ];

  Future<String> getSelectedId() async {
    return await _storage.read(key: _storageKey) ?? 'default';
  }

  Future<void> setSelectedId(String id) async {
    await _storage.write(key: _storageKey, value: id);
  }

  PiChatNotificationSound findById(String id) {
    return sounds.firstWhere(
      (s) => s.id == id,
      orElse: () => sounds.first,
    );
  }
}
