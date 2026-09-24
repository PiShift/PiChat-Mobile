import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pichat/core/state/auth_state.dart';
import 'package:pichat/data/models/chat_model.dart';
import 'package:pichat/features/chat/application/local_media_manager.dart';
import 'package:pichat/features/chat/widgets/video_preview.dart';
import 'package:pichat/data/models/chat_media_model.dart';
import 'package:pichat/data/repositories/chat_repository.dart';
import 'package:pichat/data/repositories/contact_repository.dart';
import 'package:pichat/features/chat/application/main_controller.dart';
import 'package:pichat/features/chat/widgets/image_preview.dart';
import 'package:pichat/features/chat/widgets/message_info_sheet.dart';
import 'package:pichat/features/chat/widgets/upload_status_button.dart';

import 'audio_preview.dart';
import 'document_preview.dart';
import 'package:pichat/core/theme/app_colors.dart';
import 'package:pichat/core/utils/text_direction.dart';
import 'package:pichat/core/utils/whatsapp_text.dart';
import 'package:pichat/core/theme/app_radius.dart';
import 'package:pichat/core/theme/app_sizing.dart';
import 'package:url_launcher/url_launcher.dart';

class ChatMessageItem extends ConsumerWidget {
  final Chat message;
  final bool isUnread;
  final String contactUuid;
  /// Reactions to overlay on this bubble. Each entry corresponds to one
  /// reactor (the contact and/or the current user). Empty list = none.
  final List<ChatReactionInfo> reactions;
  static const double mediaMaxWidth = 240.0;
  static const double mediaMaxHeight = 280.0;

  const ChatMessageItem({
    required this.message,
    required this.contactUuid,
    this.isUnread = false,
    this.reactions = const [],
    super.key,
  });

  Map<String, dynamic> get metadata {
    try {
      return message.metadata != null ? message.metadata! : {};
    } catch (e) {
      return {};
    }
  }

  bool get isPending => message.status == 'pending';
  bool get isFailed => message.status == 'failed';

  Widget _buildMediaPreview(
      BuildContext context, WidgetRef ref, String mediaType) {
    final localPath =
        LocalMediaManager.resolve(metadata['_localFilePath'] as String?);

    switch (mediaType) {
      case 'image':
        // Always prefer local file — for pending/sent outbound or downloaded inbound
        if (localPath != null) {
          return GestureDetector(
            onTap: () => _showLocalFullScreen(context, localPath),
            child: Image.file(
              File(localPath),
              width: mediaMaxWidth,
              height: mediaMaxHeight,
              fit: BoxFit.cover,
              errorBuilder: (ctx, __, ___) => _buildMediaErrorBox(ctx),
            ),
          );
        }
        if (message.media != null) {
          return ImagePreview(
            media: message.media!,
            mediaId: message.media!.id.toString(),
            contactId: message.contactId.toString(),
            metaId: message.media!.metaId,
          );
        }
        return const SizedBox.shrink();

      case 'sticker':
        // Meta sends stickers as WebP with no filename, so the backend stores
        // the name as "N/A". Without a branch here they fell through to the
        // generic document row and rendered as a file card titled "N/A" with
        // nothing to show. A sticker is an image - send it down the image
        // pipeline, uncropped and sticker-sized.
        if (message.media == null && localPath == null) {
          return const SizedBox.shrink();
        }

        return ImagePreview(
          media: message.media ??
              ChatMedia(
                id: -message.id,
                path: localPath,
                location: 'local',
                type: 'image/webp',
              ),
          mediaId: message.media?.id.toString() ?? 'local-${message.id}',
          contactId: message.contactId.toString(),
          metaId: message.media?.metaId,
          localFilePath: localPath,
          isSticker: true,
        );

      case 'audio':
        // While the voice note is still uploading the server media row
        // doesn't exist yet, but we have the locally recorded file. Render
        // the audio player against the local file so the user sees the
        // proper voice-note bubble immediately and can even replay it.
        if (message.media == null) {
          if (localPath != null) {
            return AudioPreview(
              media: ChatMedia(
                id: -message.id, // synthetic, stable per temp row
                path: localPath,
                location: 'local',
                type: 'audio/mp4',
              ),
              mediaId: 'local-${message.id}',
              contactId: message.contactId.toString(),
              localFilePath: localPath,
              transport: _uploadControl(context, ref, size: 36, onMedia: false),
            );
          }
          return const SizedBox.shrink();
        }
        return AudioPreview(
          media: message.media!,
          mediaId: message.media!.id.toString(),
          contactId: message.contactId.toString(),
          metaId: message.media!.metaId,
          localFilePath: localPath,
        );

      case 'video':
        // Videos used to fall through to the generic document row below, so a
        // clip arrived as a file name with no poster frame and no way to play
        // it in place.
        if (message.media == null && localPath == null) {
          return const SizedBox.shrink();
        }

        return VideoPreview(
          media: message.media ??
              ChatMedia(
                id: -message.id,
                path: localPath,
                location: 'local',
                type: 'video/mp4',
              ),
          mediaId: message.media?.id.toString() ?? 'local-${message.id}',
          contactId: message.contactId.toString(),
          metaId: message.media?.metaId,
          localFilePath: localPath,
        );

      case 'pdf':
      case 'doc':
      case 'docx':
      case 'document':
      default:
        // Pending/failed: the same card a sent document gets, read from the
        // local file, so the bubble does not change shape once it is sent.
        if (localPath != null && message.media == null) {
          final name = localPath.split('/').last;
          int? bytes;
          try {
            bytes = File(localPath).lengthSync();
          } catch (_) {}

          return DocumentPreview(
            media: ChatMedia(
              id: -message.id,
              name: name,
              path: localPath,
              location: 'local',
              size: bytes?.toString(),
            ),
            mediaId: 'local-${message.id}',
            mediaType: name.contains('.') ? name.split('.').last : mediaType,
            contactId: message.contactId.toString(),
            uploadControl: _uploadControl(context, ref, size: 44, onMedia: false),
          );
        }
        if (message.media == null) return const SizedBox.shrink();
        final sentFromHere = localPath != null && File(localPath).existsSync();
        return DocumentPreview(
          // A document sent from this phone is already here: preview it from
          // the local copy rather than offering to download it again.
          media: sentFromHere
              ? ChatMedia(
                  id: message.media!.id,
                  mediaId: message.media!.mediaId,
                  metaId: message.media!.metaId,
                  name: message.media!.name,
                  path: localPath,
                  metaUrl: message.media!.metaUrl,
                  location: 'local',
                  type: message.media!.type,
                  size: message.media!.size,
                  createdAt: message.media!.createdAt,
                )
              : message.media!,
          mediaId: message.media!.id.toString(),
          metaId: message.media!.metaId,
          mediaType: mediaType,
          contactId: message.contactId.toString(),
        );
    }
  }

  Widget _buildMediaErrorBox(BuildContext context) {
    return Container(
      // A finite width so the bubble's IntrinsicWidth can measure it.
      width: mediaMaxWidth,
      height: mediaMaxHeight,
      color: PiColors.of(context).surface,
      child: Center(child: Icon(Icons.broken_image, size: 48, color: PiColors.of(context).ink400)),
    );
  }

  /// Render a tappable static map preview for a `location` message.
  /// Uses OpenStreetMap's static-tile-free service to keep things
  /// dependency-free; tapping the bubble opens the user's preferred maps app.
  Widget _buildLocationPreview(BuildContext context) {
    final loc = (metadata['location'] as Map?) ?? const {};
    final lat = double.tryParse('${loc['latitude']}');
    final lng = double.tryParse('${loc['longitude']}');
    if (lat == null || lng == null) return const SizedBox.shrink();
    final name = loc['name'] as String?;
    final address = loc['address'] as String?;

    return GestureDetector(
      onTap: () async {
        final uri = Uri.parse(
          'https://www.google.com/maps/search/?api=1&query=$lat,$lng',
        );
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } catch (_) {}
      },
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            child: Container(
              width: mediaMaxWidth,
              height: 140,
              color: const Color(0xFFE5E3DF),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Icon(Icons.map_rounded,
                      size: 64, color: Color(0xFFB0B0B0)),
                  Positioned.fill(
                    child: Center(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.location_on,
                                color: Colors.white, size: 14),
                            SizedBox(width: 4),
                            Text(
                              'Open in Maps',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (name != null || address != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 6, 8, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (name != null)
                    Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  if (address != null)
                    Text(
                      address,
                      style: TextStyle(color: PiColors.of(context).textSecondary, fontSize: 12),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  /// Render shared contact card(s). Each card shows the formatted name and
  /// the first phone number if present.
  Widget _buildContactsPreview(BuildContext context, WidgetRef ref) {
    final raw = metadata['contacts'];
    final contacts = (raw is List) ? raw : const [];
    if (contacts.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: contacts.map<Widget>((c) {
        final map = (c as Map?) ?? const {};
        final nameMap = (map['name'] as Map?) ?? const {};
        final formatted =
            (nameMap['formatted_name'] as String?)?.trim().isNotEmpty == true
                ? nameMap['formatted_name'] as String
                : ([nameMap['first_name'], nameMap['last_name']]
                    .whereType<String>()
                    .where((s) => s.trim().isNotEmpty)
                    .join(' '));
        final phones = (map['phones'] as List?) ?? const [];
        String? firstPhone;
        if (phones.isNotEmpty) {
          final first = phones.first;
          if (first is Map) {
            firstPhone = first['phone'] as String?;
          }
        }
        return Container(
          width: mediaMaxWidth,
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: PiColors.of(context).surface,
                      child: Text(
                        formatted.isNotEmpty
                            ? formatted[0].toUpperCase()
                            : '?',
                        style: GoogleFonts.plusJakartaSans(
                            color: PiColors.of(context).textSecondary,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            formatted.isEmpty ? 'Contact' : formatted,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style:
                                const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          if (firstPhone != null)
                            Text(
                              firstPhone,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                  color: PiColors.of(context).textSecondary, fontSize: 12),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (firstPhone != null) ...[
                const SizedBox(height: 8),
                const Divider(height: 1),
                Row(
                  children: [
                    Expanded(
                      child: _ContactActionButton(
                        icon: LucideIcons.messageCircle,
                        label: 'Message',
                        color: PiPalette.success500,
                        onTap: () => _openChatWithContact(
                          context,
                          ref,
                          phone: firstPhone!,
                          formattedName: formatted,
                          firstName: nameMap['first_name'] as String?,
                          lastName: nameMap['last_name'] as String?,
                        ),
                      ),
                    ),
                    Container(
                        width: 1, height: 28, color: PiColors.of(context).divider),
                    Expanded(
                      child: _ContactActionButton(
                        icon: LucideIcons.phone,
                        label: 'Call',
                        color: PiPalette.success500,
                        onTap: () async {
                          final uri = Uri.parse('tel:$firstPhone');
                          try {
                            await launchUrl(uri);
                          } catch (_) {}
                        },
                      ),
                    ),
                    Container(
                        width: 1, height: 28, color: PiColors.of(context).divider),
                    Expanded(
                      child: _ContactActionButton(
                        icon: LucideIcons.copy,
                        label: 'Copy',
                        color: PiPalette.ink500,
                        onTap: () async {
                          await Clipboard.setData(
                              ClipboardData(text: firstPhone!));
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Phone number copied'),
                                duration: Duration(seconds: 1),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      }).toList(),
    );
  }

  Future<void> _openChatWithContact(
    BuildContext context,
    WidgetRef ref, {
    required String phone,
    required String formattedName,
    String? firstName,
    String? lastName,
  }) async {
    String? fn = firstName?.trim();
    String? ln = lastName?.trim();
    if ((fn == null || fn.isEmpty) && (ln == null || ln.isEmpty)) {
      final parts = formattedName.trim().split(RegExp(r'\s+'));
      if (parts.isNotEmpty && parts.first.isNotEmpty) fn = parts.first;
      if (parts.length > 1) ln = parts.sublist(1).join(' ');
    }
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);

    // Lightweight blocking spinner so the user knows something's
    // happening while we hit the find/create endpoints.
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const Center(
        child: CircularProgressIndicator(strokeWidth: 2.5),
      ),
    );

    try {
      final repo = ref.read(contactRepositoryProvider);
      final contact = await repo.findOrCreateByPhone(
        phone: phone,
        firstName: (fn != null && fn.isNotEmpty) ? fn : null,
        lastName: (ln != null && ln.isNotEmpty) ? ln : null,
      );
      ref.read(mainDataProvider.notifier).addOrUpdateContact(contact);
      // Pop the spinner before navigating so it doesn't sit on top of
      // the new screen.
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      router.push('/home/chats/detail', extra: contact);
    } catch (e) {
      if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Could not open chat: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showLocalFullScreen(BuildContext context, String localPath) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.file(File(localPath), fit: BoxFit.contain),
            ),
          ),
        ),
      ),
    );
  }

  String _formatFileSize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  void handleButton(BuildContext context, Map<String, dynamic> button) {
    final type = button['type']?.toString().toLowerCase();
    final payload = button['payload'];

    switch (type) {
      case 'url':
        break;
      case 'phone':
        break;
      case 'copy':
        if (payload != null) {
          Clipboard.setData(ClipboardData(text: payload.toString()));
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Text copied to clipboard')),
          );
        }
        break;
      case 'reply':
        break;
      default:
        break;
    }
  }

  /// Whether this outgoing message is a file upload, as opposed to text,
  /// a location or a contact card.
  bool _isUpload(String type) =>
      message.id < 0 &&
      metadata['_localFilePath'] != null &&
      const {'image', 'video', 'audio', 'document', 'sticker'}.contains(type);

  /// The progress / cancel / resend control for an upload, or null when the
  /// message is not an upload in progress or failed.
  Widget? _uploadControl(
    BuildContext context,
    WidgetRef ref, {
    double size = 48,
    bool onMedia = true,
  }) {
    if (!isPending && !isFailed) return null;

    return UploadStatusButton(
      localId: message.id,
      failed: isFailed,
      size: size,
      onMedia: onMedia,
      onCancel: () => ref.read(chatRepositoryProvider).cancelSend(message.id),
      onRetry: () => _retry(context, ref),
    );
  }

  /// Outgoing message that is still sending or failed.
  ///
  /// Uploads get the WhatsApp control centred on the media: a progress ring
  /// with ✕ to stop it, then an upload arrow to send it again. A voice note
  /// carries it in place of its play button instead (see the audio case in
  /// the media preview). Text, locations and contact cards keep the error
  /// scrim with a Retry pill once they fail.
  Widget _buildStatusOverlay(BuildContext context, WidgetRef ref, String type) {
    if (_isUpload(type)) {
      // Voice notes and documents carry the control inside their own card.
      if (type == 'audio' || type == 'document') return const SizedBox.shrink();

      final control = _uploadControl(context, ref);
      if (control == null) return const SizedBox.shrink();

      return Positioned.fill(child: Center(child: control));
    }

    if (!isFailed) return const SizedBox.shrink();

    return Positioned.fill(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          color: Colors.black38,
          child: Center(
            child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error_outline, color: Colors.redAccent, size: 28),
                      const SizedBox(height: 4),
                      GestureDetector(
                        onTap: () => _retry(context, ref),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            'common.retry'.tr(),
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.black87,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  /// Status tick row shown below outbound messages that have been delivered.
  Widget _buildStatusTick(BuildContext context, {bool onDark = false}) {
    if (message.type != 'outbound') return const SizedBox.shrink();
    if (isFailed) return const SizedBox.shrink();
    if (isPending) {
      return Icon(
        LucideIcons.clock,
        size: 11,
        color: onDark ? PiPalette.white : PiColors.of(context).textSecondary,
      );
    }

    IconData icon;
    Color color;

    switch (message.status) {
      case 'read':
        icon = LucideIcons.checkCheck;
        color = PiColors.of(context).info500;
        break;
      case 'delivered':
        icon = LucideIcons.checkCheck;
        color = PiColors.of(context).ink400;
        break;
      default:
        icon = LucideIcons.check;
        color = PiColors.of(context).ink400;
    }

    // Read receipts keep their blue on a scrim; the rest go white so they stay
    // legible over a photo or a video frame.
    if (onDark && message.status != 'read') {
      color = PiPalette.white;
    }

    return Icon(icon, size: 13, color: color);
  }

  /// Local-time HH:MM (24h) for the message bubble.
  String _formatTime(DateTime dt) {
    final local = dt.toLocal();
    final h = local.hour.toString().padLeft(2, '0');
    final m = local.minute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  Future<void> _retry(BuildContext context, WidgetRef ref) async {
    final sent = await ref
        .read(chatRepositoryProvider)
        .resend(message, contactUuid: contactUuid);

    // Only a media message can be left with nothing to resend: its local
    // file is gone.
    if (!sent && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('chat.media.retry_unavailable'.tr()),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isInbound = message.type == 'inbound';
    var type = metadata['type'] ?? 'text';
    // Backend mis-classifies .m4a/.aac (audio inside an MP4 container) as
    // "video" because PHP's mime sniffer reports them as video/mp4. When
    // the actual media row's mime starts with audio/, render the audio
    // player even if the metadata says otherwise.
    final mediaMime = message.media?.type ?? '';
    if (mediaMime.startsWith('audio/')) {
      type = 'audio';
    }
    final header = metadata['header']?['text'];
    // Text body for text messages
    final body = metadata['text']?['body'] as String?;
    // Caption for media messages (stored under metadata[type]['caption']).
    // Some types (e.g. `contacts`) have a List under `metadata[type]` so we
    // must guard with `is Map` before reading `caption`.
    final typeNode = metadata[type];
    final caption = typeNode is Map ? typeNode['caption'] as String? : null;
    final buttons = metadata['buttons'] ?? [];

    final hasMedia = message.media != null || metadata['_localFilePath'] != null;
    final isLocation = type == 'location';
    final isContacts = type == 'contacts';
    // Text to show below media (caption) or as standalone message (body)
    final displayText = hasMedia ? caption : body;
    final standaloneBody = (!hasMedia && body != null && displayText == null) ? body : null;
    final mainText = displayText?.isNotEmpty == true ? displayText : standaloneBody;

    /*
     * A bubble carrying nothing but text sizes itself to that text instead of
     * stretching to the 75% maximum, so "Ok" no longer occupies the same width
     * as a paragraph. Media, location, contact cards and button bubbles keep
     * the full width, which is what their fixed-size previews want.
     */
    /*
     * A media bubble with no caption puts its timestamp over the media rather
     * than on a strip beneath it. The strip read as a stray white band under
     * the video and PDF cards.
     */
    // Only visual media floats its timestamp. A document card has its own white
    // information row, and a floating pill just landed on top of it.
    const floatingTypes = {'image', 'video', 'sticker'};

    // A sticker is transparent art rather than a photo, so WhatsApp shows it
    // on the page itself. Keeping the bubble filled every cut-out area with
    // the bubble colour and boxed the artwork in with a border.
    final isStickerBubble = type == 'sticker' && hasMedia;

    final isBareMedia = type != 'unsupported' &&
        (floatingTypes.contains(type) || isLocation) &&
        (hasMedia || isLocation) &&
        header == null &&
        (displayText?.isEmpty ?? true) &&
        (standaloneBody?.isEmpty ?? true) &&
        (buttons as List).isEmpty;

    final isTextOnly = type != 'unsupported' &&
        !hasMedia &&
        !isLocation &&
        !isContacts &&
        (buttons as List).isEmpty &&
        mainText != null;

    final footer = _buildFooter(context);

    // Only a plain text bubble offers Copy.
    final copyText = isTextOnly && mainText.trim().isNotEmpty ? mainText : null;

    // Anchor key for the floating reaction picker so it can be positioned
    // directly above the long-pressed bubble (WhatsApp-style).
    final bubbleKey = GlobalKey();

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      // Use directional alignment so the bubble flips correctly in RTL.
      alignment: isInbound
          ? AlignmentDirectional.centerStart
          : AlignmentDirectional.centerEnd,
      child: Column(
        crossAxisAlignment: isInbound ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              _SwipeForInfo(
                // An optimistic bubble has no server row yet, so there is
                // nothing to show a log for.
                onTriggered: message.id > 0
                    ? () => MessageInfoSheet.show(context, message)
                    : null,
                child: GestureDetector(
                // Long-press opens reactions above the bubble (only once it
                // has a wamId — pending and failed ones cannot be reacted
                // to) and the message's actions below it.
                onLongPress: message.wamId != null || copyText != null
                    ? () => _showMessageMenu(
                          context,
                          ref,
                          bubbleKey,
                          copyText: copyText,
                        )
                    : null,
                child: ConstrainedBox(
                  key: bubbleKey,
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: isStickerBubble
                        ? Colors.transparent
                        : isInbound
                            ? PiColors.of(context).bubbleReceived
                            : PiColors.of(context).bubbleSent,
                    border: isStickerBubble
                        ? null
                        : Border.all(
                            color: isInbound
                                ? PiColors.of(context).bubbleReceivedBorder
                                : PiColors.of(context).bubbleSentBorder,
                            width: 1,
                          ),
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(PiRadius.xl),
                      topRight: const Radius.circular(PiRadius.xl),
                      bottomLeft: Radius.circular(
                          isInbound ? PiRadius.xs : PiRadius.xl),
                      bottomRight: Radius.circular(
                          isInbound ? PiRadius.xl : PiRadius.xs),
                    ),
                    boxShadow: isStickerBubble
                        ? null
                        : [
                            BoxShadow(
                              color: PiPalette.ink900.withOpacity(0.06),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                  ),
                  child: Column(
                    // Text content always reads from start (left in LTR, right
                    // in RTL). The footer row pins itself to end below.
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (type == 'unsupported')
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.block, size: 14, color: PiColors.of(context).textSecondary),
                              const SizedBox(width: 4),
                              Text(
                                'Message type not supported',
                                style: TextStyle(fontSize: 13, color: PiColors.of(context).textSecondary, fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                        ),
                      if (type != 'unsupported' && hasMedia) _buildMediaPreview(context, ref, type),
                      if (type != 'unsupported' && isLocation) _buildLocationPreview(context),
                      if (type != 'unsupported' && isContacts) _buildContactsPreview(context, ref),
                      if (isTextOnly)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 6, 10, 5),
                          /*
                           * Wrap shrink-wraps to its widest run, so the bubble
                           * follows the text. It also puts the timestamp on the
                           * same line when there is room and drops it to its own
                           * line when there is not - the behaviour WhatsApp has.
                           *
                           * Deliberately not IntrinsicWidth: measuring intrinsics
                           * inside ScrollablePositionedList collapsed every
                           * bubble to nothing.
                           */
                          // Lay the text out in its own direction. The bubble
                          // itself stays on the sender's side — that is decided
                          // by inbound/outbound, not by the language — so the
                          // Directionality is scoped to the content only.
                          child: Directionality(
                            textDirection: directionOf(mainText),
                            child: Wrap(
                            alignment: WrapAlignment.end,
                            crossAxisAlignment: WrapCrossAlignment.end,
                            spacing: 8,
                            runSpacing: 2,
                            children: [
                              if (header != null)
                                Text(
                                  header,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: Sz.sp(context, 14),
                                    fontWeight: FontWeight.w700,
                                    color: PiColors.of(context).textPrimary,
                                  ),
                                ),
                              Text.rich(
                                TextSpan(
                                  children: WhatsappText.spans(
                                    mainText,
                                    base: GoogleFonts.plusJakartaSans(
                                      fontSize: Sz.sp(context, 14),
                                      color: PiColors.of(context).textPrimary,
                                      height: 1.4,
                                    ),
                                    linkColor: PiPalette.primary500,
                                  ),
                                ),
                                textAlign: TextAlign.start,
                              ),
                              footer,
                            ],
                          ),
                          ),
                        ),
                      if (!isTextOnly && (header != null || mainText != null))
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
                          // Captions and long-form bodies follow the language
                          // of the text, same as the text-only bubble above.
                          child: Directionality(
                            textDirection: directionOf(mainText ?? header),
                            child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (header != null)
                                Text(
                                  header,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: Sz.sp(context, 14),
                                    fontWeight: FontWeight.w700,
                                    color: PiColors.of(context).textPrimary,
                                  ),
                                  textAlign: TextAlign.start,
                                ),
                              if (mainText != null)
                                Text.rich(
                                  TextSpan(
                                    children: WhatsappText.spans(
                                      mainText,
                                      base: GoogleFonts.plusJakartaSans(
                                        fontSize: Sz.sp(context, 14),
                                        color: PiColors.of(context).textPrimary,
                                        height: 1.4,
                                      ),
                                      linkColor: PiPalette.primary500,
                                    ),
                                  ),
                                  textAlign: TextAlign.start,
                                ),
                            ],
                          ),
                          ),
                        ),
                      if (buttons.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.all(8),
                          child: Wrap(
                            spacing: 4,
                            children: List.generate(
                              buttons.length,
                              (i) => GestureDetector(
                                onTap: () => handleButton(context, buttons[i]),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: PiColors.of(context).primary500,
                                    borderRadius: BorderRadius.circular(PiRadius.full),
                                  ),
                                  child: Text(
                                    buttons[i]['text'] ?? 'Button',
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: Sz.sp(context, 13),
                                      fontWeight: FontWeight.w600,
                                      color: PiPalette.white,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      // Footer (time + tick) on its own row at the bottom-end
                      // of the bubble. Text-only bubbles carry it inline in the
                      // Wrap above instead.
                      if (!isTextOnly && !isBareMedia)
                        Padding(
                          padding:
                              const EdgeInsetsDirectional.fromSTEB(8, 0, 8, 4),
                          child: Align(
                            alignment: AlignmentDirectional.centerEnd,
                            child: footer,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              ),
              ),
              // Timestamp floated over the media, on a scrim so it stays
              // readable against a bright frame or a white page.
              if (isBareMedia)
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: PiPalette.ink900.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: _buildFooter(context, onDark: true),
                  ),
                ),
              // Status overlay (spinner / error+retry) for outbound pending/failed
              if (!isInbound) _buildStatusOverlay(context, ref, type),
              // Floating reaction pill — overlaps the bubble's bottom edge
              // on the outward side (left for inbound, right for outbound),
              // matching WhatsApp. Holds every reactor's emoji side-by-side.
              if (reactions.isNotEmpty)
                Positioned(
                  bottom: -16,
                  left: isInbound ? 8 : null,
                  right: isInbound ? null : 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: PiColors.of(context).surfaceRaised,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: PiPalette.ink900.withOpacity(0.12),
                          blurRadius: 4,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final r in reactions)
                          Padding(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 1),
                            child: Text(
                              r.emoji,
                              style: const TextStyle(fontSize: 14),
                            ),
                          ),
                        if (reactions.length > 1) ...[
                          const SizedBox(width: 2),
                          Text(
                            '${reactions.length}',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11,
                              color: PiColors.of(context).textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
            ],
          ),
          // Extra spacing so the reaction pill doesn't visually collide with
          // the next bubble.
          if (reactions.isNotEmpty) const SizedBox(height: 14),
          if (isUnread)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 8, right: 8),
              child: Text(
                'New',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: Sz.sp(context, 11),
                  color: PiColors.of(context).error,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// Time + status tick. Sits inside the bubble, bottom-right, in normal
  /// (non-overlapping) flow — so it never covers text, captions, or media.
  /// [onDark] renders the time and tick in white, for the badge that floats
  /// over media. The colour has to be set here rather than inherited: the Text
  /// below names its own colour, which silently won over any DefaultTextStyle
  /// wrapped around it and left the time invisible on the scrim.
  Widget _buildFooter(BuildContext context, {bool onDark = false}) {
    final isInbound = message.type == 'inbound';
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Mark replies the AI assistant sent. Without it an agent reading back
        // through a thread cannot tell which outbound messages they are
        // accountable for and which the bot wrote on their behalf.
        if (message.isPibot) ...[
          Icon(
            LucideIcons.sparkles,
            size: Sz.sp(context, 10),
            color:
                onDark ? PiPalette.white : PiColors.of(context).textSecondary,
          ),
          const SizedBox(width: 3),
        ],
        Text(
          _formatTime(message.createdAt),
          style: GoogleFonts.plusJakartaSans(
            fontSize: Sz.sp(context, 10),
            color: onDark ? PiPalette.white : PiColors.of(context).textSecondary,
          ),
        ),
        if (!isInbound)
          Padding(
            padding: const EdgeInsets.only(left: 3),
            child: _buildStatusTick(context, onDark: onDark),
          ),
      ],
    );
  }

  /// WhatsApp-style long-press menu, drawn in an Overlay so it stays
  /// attached to the bubble: a reaction pill above it (6 quick emojis and a
  /// `+` for the full sheet) and the message's actions below it.
  Future<void> _showMessageMenu(
    BuildContext context,
    WidgetRef ref,
    GlobalKey bubbleKey, {
    String? copyText,
  }) async {
    HapticFeedback.selectionClick();

    final overlay = Overlay.of(context, rootOverlay: true);
    final renderBox = bubbleKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final bubblePos = renderBox.localToGlobal(Offset.zero);
    final bubbleSize = renderBox.size;
    final screen = MediaQuery.of(context).size;
    final safe = MediaQuery.of(context).padding;
    final isInbound = message.type == 'inbound';

    final canReact = message.wamId != null;
    final actions = <_MessageAction>[
      if (copyText != null)
        _MessageAction(
          icon: LucideIcons.copy,
          label: 'chat.actions.copy'.tr(),
          onTap: () async {
            await Clipboard.setData(ClipboardData(text: copyText));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('chat.actions.copied'.tr()),
                behavior: SnackBarBehavior.floating,
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),
    ];

    if (!canReact && actions.isEmpty) return;

    // Pill width is ~ 6 * 44 + plus btn + padding ≈ 320. Clamp inside screen.
    const pillWidth = 320.0;
    const pillHeight = 56.0;
    const actionsHeight = 48.0;
    const gap = 8.0;

    double pillLeft = bubblePos.dx + (bubbleSize.width / 2) - (pillWidth / 2);
    pillLeft = pillLeft.clamp(8.0, screen.width - pillWidth - 8.0);

    // Prefer the pill above the bubble; fall back to below if there isn't
    // enough headroom (e.g. message at top of viewport).
    double pillTop = bubblePos.dy - pillHeight - gap;
    final pillBelow = pillTop < safe.top + gap;
    if (pillBelow) pillTop = bubblePos.dy + bubbleSize.height + gap;

    // Actions go under the bubble, or under the pill when that took the spot.
    // A bubble near the bottom edge pulls them back up on screen.
    double actionsTop = canReact && pillBelow
        ? pillTop + pillHeight + gap
        : bubblePos.dy + bubbleSize.height + gap;
    final maxActionsTop = screen.height - safe.bottom - actionsHeight - gap;
    if (actionsTop > maxActionsTop) actionsTop = maxActionsTop;

    // Lined up with the bubble's outer edge, like the bubble itself.
    final actionsLeft = isInbound ? bubblePos.dx.clamp(8.0, screen.width) : null;
    final actionsRight = isInbound
        ? null
        : (screen.width - bubblePos.dx - bubbleSize.width).clamp(8.0, screen.width);

    final completer = Completer<String?>();
    late OverlayEntry entry;

    void close([String? value]) {
      if (entry.mounted) entry.remove();
      if (!completer.isCompleted) completer.complete(value);
    }

    entry = OverlayEntry(
      builder: (_) => Stack(
        children: [
          // Tap outside to dismiss without picking.
          Positioned.fill(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => close(null),
            ),
          ),
          if (canReact)
            Positioned(
              left: pillLeft,
              top: pillTop,
              width: pillWidth,
              child: _ReactionPill(
                onPick: (emoji) => close(emoji),
                onMore: () async {
                  close(null);
                  final picked = await _showFullEmojiSheet(context);
                  if (picked != null && picked.isNotEmpty) {
                    await _dispatchReaction(context, ref, picked);
                  }
                },
              ),
            ),
          if (actions.isNotEmpty)
            Positioned(
              left: actionsLeft,
              right: actionsRight,
              top: actionsTop,
              child: _MessageActionBar(
                actions: actions,
                onSelected: (action) {
                  close(null);
                  action.onTap();
                },
              ),
            ),
        ],
      ),
    );
    overlay.insert(entry);

    final picked = await completer.future;
    if (picked == null) return;
    if (!context.mounted) return;
    await _dispatchReaction(context, ref, picked);
  }

  Future<void> _dispatchReaction(
    BuildContext context,
    WidgetRef ref,
    String emoji,
  ) async {
    final wamId = message.wamId;
    if (wamId == null) return;

    final orgId = ref.read(organizationProvider)?.id ?? message.orgId;
    final chatRepo = ref.read(chatRepositoryProvider);

    try {
      await chatRepo.sendReaction(
        contactUuid,
        wamId: wamId,
        emoji: emoji,
        contactId: message.contactId,
        orgId: orgId,
      );
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send reaction: $e')),
      );
    }
  }

  /// Full-screen emoji sheet for picking any emoji when the user taps `+`
  /// on the quick reaction pill.
  Future<String?> _showFullEmojiSheet(BuildContext context) {
    const allEmojis = [
      '😀','😃','😄','😁','😆','😅','🤣','😂','🙂','🙃','😉','😊','😇','🥰','😍','🤩',
      '😘','😗','😚','😙','🥲','😋','😛','😜','🤪','😝','🤑','🤗','🤭','🤫','🤔','🤐',
      '🤨','😐','😑','😶','😏','😒','🙄','😬','🤥','😌','😔','😪','🤤','😴','😷','🤒',
      '🤕','🤢','🤮','🤧','🥵','🥶','🥴','😵','🤯','🤠','🥳','🥸','😎','🤓','🧐','😕',
      '😟','🙁','☹️','😮','😯','😲','😳','🥺','😦','😧','😨','😰','😥','😢','😭','😱',
      '😖','😣','😞','😓','😩','😫','🥱','😤','😡','😠','🤬','😈','👿','💀','💩','🤡',
      '👍','👎','👌','✌️','🤞','🤟','🤘','🤙','👈','👉','👆','👇','☝️','✋','🤚','🖐️',
      '🖖','👋','🤝','🙏','💪','❤️','🧡','💛','💚','💙','💜','🖤','🤍','🤎','💔','❣️',
      '🔥','✨','🎉','🎊','💯','✅','❌','⭐','🌟','💫','💥','💢','💦','💨','🕊️','🦋',
    ];
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: PiColors.of(context).surfaceRaised,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(PiRadius.lg)),
      ),
      builder: (_) => SafeArea(
        child: SizedBox(
          height: 360,
          child: GridView.builder(
            padding: const EdgeInsets.all(12),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 8,
              mainAxisSpacing: 4,
              crossAxisSpacing: 4,
            ),
            itemCount: allEmojis.length,
            itemBuilder: (ctx, i) => GestureDetector(
              onTap: () => Navigator.of(ctx).pop(allEmojis[i]),
              child: Center(
                child: Text(allEmojis[i], style: const TextStyle(fontSize: 26)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// One reaction overlaid on a chat bubble.
class ChatReactionInfo {
  const ChatReactionInfo({required this.emoji, required this.fromMe});
  final String emoji;
  final bool fromMe;
}

/// Compact action button used inside the shared-contact bubble
/// (Message / Call / Copy).
class _ContactActionButton extends StatelessWidget {
  const _ContactActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Floating quick-reaction pill: 6 suggested emojis + a `+` button.
/// One entry in the long-press action bar. Delete, reply and forward slot in
/// here as they become possible.
class _MessageAction {
  const _MessageAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _MessageActionBar extends StatelessWidget {
  const _MessageActionBar({required this.actions, required this.onSelected});

  final List<_MessageAction> actions;
  final ValueChanged<_MessageAction> onSelected;

  @override
  Widget build(BuildContext context) {
    final colors = PiColors.of(context);

    return Align(
      alignment: AlignmentDirectional.centerStart,
      widthFactor: 1,
      child: Container(
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 4),
        decoration: BoxDecoration(
          color: colors.surfaceRaised,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: PiPalette.ink900.withValues(alpha: 0.18),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final action in actions)
              GestureDetector(
                onTap: () => onSelected(action),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(action.icon, size: 18, color: colors.textPrimary),
                      const SizedBox(width: 8),
                      Text(
                        action.label,
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: Sz.sp(context, 14),
                          fontWeight: FontWeight.w600,
                          color: colors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ReactionPill extends StatelessWidget {
  const _ReactionPill({required this.onPick, required this.onMore});
  final ValueChanged<String> onPick;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    const quick = ['❤️', '👍', '😂', '😮', '😢', '🙏'];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: PiColors.of(context).surfaceRaised,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: PiPalette.ink900.withOpacity(0.18),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          for (final e in quick)
            GestureDetector(
              onTap: () => onPick(e),
              behavior: HitTestBehavior.opaque,
              child: Padding(
                padding: const EdgeInsets.all(6),
                child: Text(e, style: const TextStyle(fontSize: 24)),
              ),
            ),
          GestureDetector(
            onTap: onMore,
            behavior: HitTestBehavior.opaque,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: PiColors.of(context).surface,
                shape: BoxShape.circle,
              ),
              child: Icon(LucideIcons.plus, size: 22, color: PiColors.of(context).textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

/// Drag a bubble sideways to open its message info.
///
/// Matches how WhatsApp surfaces the same thing, and keeps the bubble's
/// long-press free for reactions. The drag is deliberately handled here rather
/// than on the message row so the vertical list keeps ownership of vertical
/// gestures; horizontal drags inside a bubble (the audio scrubber) belong to
/// their own inner detector, which wins the arena as the deeper competitor.
class _SwipeForInfo extends StatefulWidget {
  const _SwipeForInfo({required this.child, this.onTriggered});

  final Widget child;

  /// Null disables the gesture entirely — nothing to show info for.
  final VoidCallback? onTriggered;

  @override
  State<_SwipeForInfo> createState() => _SwipeForInfoState();
}

class _SwipeForInfoState extends State<_SwipeForInfo> {
  static const _triggerAt = 40.0;
  static const _maxPull = 64.0;

  double _offset = 0;

  void _update(DragUpdateDetails details) {
    setState(() {
      _offset = (_offset + details.delta.dx).clamp(-_maxPull, _maxPull);
    });
  }

  void _end(DragEndDetails _) {
    final triggered = _offset.abs() >= _triggerAt;

    setState(() => _offset = 0);

    if (triggered) widget.onTriggered?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.onTriggered == null) return widget.child;

    return GestureDetector(
      onHorizontalDragUpdate: _update,
      onHorizontalDragEnd: _end,
      onHorizontalDragCancel: () => setState(() => _offset = 0),
      child: AnimatedContainer(
        duration: _offset == 0
            ? const Duration(milliseconds: 180)
            : Duration.zero,
        curve: Curves.easeOut,
        transform: Matrix4.translationValues(_offset, 0, 0),
        child: widget.child,
      ),
    );
  }
}
