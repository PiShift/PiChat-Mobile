import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pichat/core/theme/app_colors.dart';
import 'package:pichat/features/chat/application/upload_progress.dart';

/// The WhatsApp-style control on an outgoing media message.
///
/// While sending it is a progress ring with an ✕ that stops the upload. Once
/// stopped or failed it becomes an upload arrow that sends it again.
class UploadStatusButton extends ConsumerWidget {
  const UploadStatusButton({
    super.key,
    required this.localId,
    required this.failed,
    required this.onCancel,
    required this.onRetry,
    this.size = 48,
    this.onMedia = true,
  });

  /// The optimistic row's id.
  final int localId;
  final bool failed;
  final VoidCallback onCancel;
  final VoidCallback onRetry;
  final double size;

  /// Drawn over a photo or video (dark scrim) rather than inside a bubble.
  final bool onMedia;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress =
        ref.watch(uploadRegistryProvider.select((m) => m[localId]));

    final background = onMedia
        ? PiPalette.ink900.withValues(alpha: 0.55)
        : PiPalette.primary500;
    const foreground = PiPalette.white;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: failed ? onRetry : onCancel,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(color: background, shape: BoxShape.circle),
        child: failed
            ? Icon(LucideIcons.upload, color: foreground, size: size * 0.45)
            : Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: size - 6,
                    height: size - 6,
                    child: CircularProgressIndicator(
                      // Spins before the first progress event, and again
                      // once the bytes are all out: the server is still
                      // passing the file to Meta, and a full ring standing
                      // still looked like a stuck upload.
                      value: progress == null || progress == 0 || progress >= 1
                          ? null
                          : progress,
                      strokeWidth: 2.5,
                      color: foreground,
                      backgroundColor: foreground.withValues(alpha: 0.25),
                    ),
                  ),
                  Icon(LucideIcons.x, color: foreground, size: size * 0.38),
                ],
              ),
      ),
    );
  }
}
