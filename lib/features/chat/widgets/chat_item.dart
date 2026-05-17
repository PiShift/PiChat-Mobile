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
import 'package:pichat/data/models/chat_media_model.dart';
import 'package:pichat/data/repositories/chat_repository.dart';
import 'package:pichat/data/repositories/contact_repository.dart';
import 'package:pichat/features/chat/application/main_controller.dart';
import 'package:pichat/features/chat/widgets/image_preview.dart';

import 'audio_preview.dart';
import 'document_preview.dart';
import 'package:pichat/core/theme/app_colors.dart';
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

  Widget _buildMediaPreview(BuildContext context, String mediaType) {
    final localPath = metadata['_localFilePath'] as String?;

    switch (mediaType) {
      case 'image':
        // Always prefer local file — for pending/sent outbound or downloaded inbound
        if (localPath != null) {
          return GestureDetector(
            onTap: () => _showLocalFullScreen(context, localPath),
            child: Image.file(
              File(localPath),
              width: double.infinity,
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

      case 'pdf':
      case 'doc':
      case 'docx':
      case 'document':
      default:
        // Pending/failed: show file name placeholder
        if (localPath != null && message.media == null) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(LucideIcons.fileText, size: 32, color: PiColors.of(context).textSecondary),
                const SizedBox(width: 8),
                Flexible(
                  child: Text(
                    localPath.split('/').last,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: Sz.sp(context, 13),
                      color: PiColors.of(context).textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          );
        }
        if (message.media == null) return const SizedBox.shrink();
        return DocumentPreview(
          media: message.media!,
          mediaId: message.media!.id.toString(),
          metaId: message.media!.metaId,
          mediaType: mediaType,
          contactId: message.contactId.toString(),
        );
    }
  }

  Widget _buildMediaErrorBox(BuildContext context) {
    return Container(
      width: double.infinity,
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

  /// Overlays a semi-transparent layer with an error icon + retry button
  /// over the message bubble for outbound failed messages. Pending uses a
  /// subtle clock indicator in the footer instead so the user still sees
  /// the actual content (image / audio player / text).
  Widget _buildStatusOverlay(BuildContext context, WidgetRef ref) {
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
  Widget _buildStatusTick(BuildContext context) {
    if (message.type != 'outbound') return const SizedBox.shrink();
    if (isFailed) return const SizedBox.shrink();
    if (isPending) {
      return Icon(LucideIcons.clock, size: 11, color: PiColors.of(context).textSecondary);
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
    final chatRepo = ref.read(chatRepositoryProvider);
    final org = ref.read(organizationProvider);
    final orgId = org?.id ?? 0;
    final localPath = metadata['_localFilePath'] as String?;
    final type = metadata['type'] ?? 'text';
    final mediaMime = message.media?.type ?? '';
    final isMediaMessage = localPath != null ||
        message.mediaId != null ||
        mediaMime.startsWith('audio/') ||
        mediaMime.startsWith('image/') ||
        mediaMime.startsWith('video/') ||
        ['image', 'audio', 'video', 'document'].contains(type);

    if (isMediaMessage) {
      if (localPath == null || !File(localPath).existsSync()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('chat.media.retry_unavailable'.tr()),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
      final file = File(localPath);
      unawaited(chatRepo.sendMediaMessage(
        contactUuid,
        file,
        caption: metadata[type]?['caption'] as String?,
        contactId: message.contactId,
        orgId: orgId,
        tempId: message.id, // reuse the same temp row
      ));
    } else {
      // Text retry
      final body = metadata['text']?['body'] as String? ?? '';
      if (body.trim().isEmpty) return;
      unawaited(chatRepo.sendTextMessage(
        contactUuid,
        body,
        contactId: message.contactId,
        orgId: orgId,
        tempId: message.id,
      ));
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

    final footer = _buildFooter(context);

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
              GestureDetector(
                // Long-press any sent or delivered message that has a wamId
                // to react to it. Pending/failed outbound bubbles have no
                // wamId yet so they're naturally excluded.
                onLongPress: message.wamId != null
                    ? () => _showReactionPicker(context, ref, bubbleKey)
                    : null,
                child: ConstrainedBox(
                  key: bubbleKey,
                constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                child: Container(
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    color: isInbound
                        ? PiColors.of(context).bubbleReceived
                        : PiColors.of(context).bubbleSent,
                    border: Border.all(
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
                    boxShadow: [
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
                      if (type != 'unsupported' && hasMedia) _buildMediaPreview(context, type),
                      if (type != 'unsupported' && isLocation) _buildLocationPreview(context),
                      if (type != 'unsupported' && isContacts) _buildContactsPreview(context, ref),
                      if (header != null || mainText != null)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 6, 8, 4),
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
                                Text(
                                  mainText,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: Sz.sp(context, 14),
                                    color: PiColors.of(context).textPrimary,
                                    height: 1.4,
                                  ),
                                  textAlign: TextAlign.start,
                                ),
                            ],
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
                      // Footer (time + tick) sits on its own row at the
                      // bottom-end of the bubble (right in LTR, left in RTL).
                      Padding(
                        padding: const EdgeInsetsDirectional.fromSTEB(8, 0, 8, 4),
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
              // Status overlay (spinner / error+retry) for outbound pending/failed
              if (!isInbound) _buildStatusOverlay(context, ref),
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
  Widget _buildFooter(BuildContext context) {
    final isInbound = message.type == 'inbound';
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          _formatTime(message.createdAt),
          style: GoogleFonts.plusJakartaSans(
            fontSize: Sz.sp(context, 10),
            color: PiColors.of(context).textSecondary,
          ),
        ),
        if (!isInbound)
          Padding(
            padding: const EdgeInsets.only(left: 3),
            child: _buildStatusTick(context),
          ),
      ],
    );
  }

  /// WhatsApp-style reaction picker. Shows a floating pill positioned just
  /// above the long-pressed bubble with 6 quick emojis + a `+` button that
  /// opens a full emoji sheet. The whole UI is rendered through an Overlay
  /// (no modal bottom sheet) so it stays visually attached to the bubble.
  Future<void> _showReactionPicker(
    BuildContext context,
    WidgetRef ref,
    GlobalKey bubbleKey,
  ) async {
    HapticFeedback.selectionClick();

    final overlay = Overlay.of(context, rootOverlay: true);
    final renderBox = bubbleKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final bubblePos = renderBox.localToGlobal(Offset.zero);
    final bubbleSize = renderBox.size;
    final screen = MediaQuery.of(context).size;

    // Pill width is ~ 6 * 44 + plus btn + padding ≈ 320. Clamp inside screen.
    const pillWidth = 320.0;
    const pillHeight = 56.0;
    double left = bubblePos.dx + (bubbleSize.width / 2) - (pillWidth / 2);
    left = left.clamp(8.0, screen.width - pillWidth - 8.0);

    // Prefer placing the pill above the bubble; fall back to below if there
    // isn't enough headroom (e.g. message at top of viewport).
    double top = bubblePos.dy - pillHeight - 8;
    if (top < MediaQuery.of(context).padding.top + 8) {
      top = bubblePos.dy + bubbleSize.height + 8;
    }

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
          Positioned(
            left: left,
            top: top,
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
