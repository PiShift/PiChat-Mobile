import 'dart:io';

import 'package:audio_session/audio_session.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pichat/core/services/notification_sound_service.dart';
import 'package:pichat/core/theme/app_colors.dart';
import 'package:pichat/core/theme/app_theme.dart';

/// WhatsApp-style notification sound picker.
/// Shows all available sounds, previews them on tap, and persists the choice.
/// [onSoundSelected] is called with the chosen [PiChatNotificationSound] after
/// saving so the caller can sync the preference to the backend.
class NotificationSoundPickerSheet extends StatefulWidget {
  final void Function(PiChatNotificationSound)? onSoundSelected;

  const NotificationSoundPickerSheet({super.key, this.onSoundSelected});

  @override
  State<NotificationSoundPickerSheet> createState() => _NotificationSoundPickerSheetState();
}

class _NotificationSoundPickerSheetState extends State<NotificationSoundPickerSheet> {
  static const _soundPreviewChannel = MethodChannel('com.pishift.pichat/sound_preview');

  final _soundService = NotificationSoundService();
  final _player = AudioPlayer();

  String _selectedId = 'default';
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadCurrent();
  }

  Future<void> _loadCurrent() async {
    final id = await _soundService.getSelectedId();
    if (mounted) setState(() { _selectedId = id; _loading = false; });
  }

  Future<void> _select(PiChatNotificationSound sound) async {
    setState(() => _selectedId = sound.id);
    await _soundService.setSelectedId(sound.id);
    widget.onSoundSelected?.call(sound);
    await _preview(sound);
  }

  Future<void> _preview(PiChatNotificationSound sound) async {
    if (sound.assetPath == null) return;
    try {
      if (Platform.isIOS) {
        // AudioServicesPlaySystemSound bypasses AVAudioSession entirely, so it
        // works even when the VoIP stack holds exclusive audio hardware access.
        //
        // Flutter assets live inside App.framework in release builds, which
        // Bundle.main cannot resolve from native code. Instead, Dart reads the
        // asset from the Flutter bundle (which always works) and writes it to a
        // temp file whose concrete path we then hand off to native.
        final bytes = await rootBundle.load(sound.assetPath!);
        final tmp = await getTemporaryDirectory();
        final file = File('${tmp.path}/${sound.id}.caf');
        await file.writeAsBytes(bytes.buffer.asUint8List(), flush: true);
        await _soundPreviewChannel.invokeMethod<void>('playSound', {
          'filePath': file.path,
        });
        return;
      }

      // Android: use just_audio with the Flutter asset.
      final session = await AudioSession.instance;
      await session.configure(const AudioSessionConfiguration(
        androidAudioAttributes: AndroidAudioAttributes(
          contentType: AndroidAudioContentType.sonification,
          usage: AndroidAudioUsage.notificationRingtone,
        ),
        androidAudioFocusGainType: AndroidAudioFocusGainType.gainTransientMayDuck,
      ));
      try {
        await session.setActive(true);
      } catch (_) {}
      await _player.stop();
      await _player.setAudioSource(AudioSource.asset(sound.assetPath!));
      await _player.play();
    } catch (e) {
      debugPrint('[SoundPicker] preview error: $e');
    }
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: EdgeInsets.only(top: size.height * 0.012),
            width: size.width * 0.1,
            height: 4,
            decoration: BoxDecoration(
              color: PiColors.of(context).divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Title
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: size.width * 0.04,
              vertical: size.height * 0.014,
            ),
            child: Row(
              children: [
                Text(
                  'settings.notifications.change_sound_title'.tr(),
                  style: TextStyle(
                    fontSize: size.width * 0.04,
                    fontWeight: FontWeight.w600,
                    color: PiColors.of(context).textPrimary,
                  ),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: PiColors.of(context).divider),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            )
          else
            for (final sound in NotificationSoundService.sounds)
              ListTile(
                leading: Icon(
                  sound.isDefault ? Icons.notifications_outlined : Icons.music_note_outlined,
                  size: size.width * 0.05,
                  color: _selectedId == sound.id
                      ? PiPalette.primary500
                      : PiColors.of(context).ink400,
                ),
                title: Text(
                  sound.label,
                  style: TextStyle(
                    fontSize: size.width * 0.034,
                    color: _selectedId == sound.id
                        ? PiPalette.primary500
                        : PiColors.of(context).textPrimary,
                    fontWeight: _selectedId == sound.id
                        ? FontWeight.w600
                        : FontWeight.normal,
                  ),
                ),
                trailing: _selectedId == sound.id
                    ? Icon(Icons.check, color: PiPalette.primary500, size: size.width * 0.045)
                    : null,
                dense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: size.width * 0.04),
                onTap: () => _select(sound),
              ),
          SizedBox(height: size.height * 0.02),
        ],
      ),
    );
  }
}
