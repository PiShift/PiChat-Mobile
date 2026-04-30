import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pichat/core/constants/app_constants.dart';
import 'package:pichat/core/theme/app_theme.dart';
import 'package:pichat/data/models/chat_model.dart';
import 'package:pichat/data/models/contact_model.dart';

class ContactItem extends StatelessWidget {
  final Contact contact;
  const ContactItem({super.key, required this.contact});

  @override
  Widget build(BuildContext context) {
    final lastChat = contact.lastChat;

    String formatLastChatTime(DateTime? time) {
      if (time == null) return '';
      final now = DateTime.now();
      final difference = now.difference(time);

      if (difference.inDays == 0) {
        return DateFormat.Hm('en').format(time);
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return DateFormat.E('en').format(time);
      } else {
        return DateFormat('dd/MM', 'en').format(time);
      }
    }

    String initials(String name) {
      final parts = name.trim().split(' ');
      if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
      return name.isNotEmpty ? name[0].toUpperCase() : '?';
    }

    final name = contact.fullName ?? contact.phone;
    final statusColor = _statusColor(lastChat?.status);

    return Column(
      children: [
        ListTile(
          leading: Stack(
            clipBehavior: Clip.none,
            children: [
              CircleAvatar(
                backgroundColor: AppColors.primary.withOpacity(0.15),
                backgroundImage: contact.avatar != null
                    ? NetworkImage("${AppConstants.baseUrl}${contact.avatar!}")
                    : null,
                child: contact.avatar == null
                    ? Text(
                        initials(name),
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      )
                    : null,
              ),
              // Status dot
              if (lastChat?.status != null)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 11,
                    height: 11,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
          title: Text(
            name,
            style: TextStyle(
              fontWeight: contact.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
            ),
          ),
          subtitle: lastChat == null || lastChat.deletedAt != null
              ? null
              : Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    if (lastChat.type == 'outbound')
                      Padding(
                        padding: const EdgeInsets.only(right: 4.0),
                        child: _StatusTick(status: lastChat.status),
                      ),
                    Expanded(
                      child: _LastMessagePreview(
                        lastChat: lastChat,
                        unread: contact.unreadCount > 0,
                      ),
                    ),
                  ],
                ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (lastChat != null)
                Text(
                  formatLastChatTime(contact.latestChatCreatedAt ?? lastChat.createdAt),
                  style: TextStyle(
                    color: contact.unreadCount > 0 ? AppColors.primary : Colors.grey[500],
                    fontSize: 11,
                    fontWeight: contact.unreadCount > 0 ? FontWeight.bold : FontWeight.normal,
                  ),
                ),
              if (contact.unreadCount > 0)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    contact.unreadCount > 99 ? '99+' : '${contact.unreadCount}',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 0, indent: 72),
      ],
    );
  }

  Color _statusColor(String? status) {
    switch (status) {
      case 'open':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.transparent;
    }
  }
}

class _LastMessagePreview extends StatelessWidget {
  final Chat lastChat;
  final bool unread;

  const _LastMessagePreview({required this.lastChat, required this.unread});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final textColor = unread ? Colors.black87 : Colors.grey[600];
    final fontWeight = unread ? FontWeight.w500 : FontWeight.normal;
    final fontSize = size.width * 0.032;

    try {
      final meta = lastChat.metadata;
      final type = meta?['type'];

      if (type == 'text') {
        final body = meta?['text']?['body'] ?? '';
        return Text(
          body,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(color: textColor, fontSize: fontSize, fontWeight: fontWeight),
        );
      }

      final (icon, label) = _iconAndLabel(type);
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: size.width * 0.036, color: Colors.grey[500]),
          SizedBox(width: size.width * 0.012),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: textColor, fontSize: fontSize, fontWeight: fontWeight),
          ),
        ],
      );
    } catch (_) {
      return const SizedBox.shrink();
    }
  }

  (IconData, String) _iconAndLabel(String? type) {
    switch (type) {
      case 'audio':
        return (Icons.mic_rounded, 'Voice message');
      case 'image':
        return (Icons.image_outlined, 'Photo');
      case 'document':
        return (Icons.insert_drive_file_outlined, 'Document');
      case 'video':
        return (Icons.videocam_outlined, 'Video');
      case 'sticker':
        return (Icons.emoji_emotions_outlined, 'Sticker');
      default:
        return (Icons.attach_file, 'Attachment');
    }
  }
}

/// Mirrors the in-bubble status tick logic so the contacts list shows the
/// same delivery/read state for the last outbound message:
///   pending  -> clock
///   failed   -> red error
///   sent     -> single grey check
///   delivered-> double grey check
///   read     -> double blue check
class _StatusTick extends StatelessWidget {
  final String? status;
  const _StatusTick({required this.status});

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case 'pending':
        return const Icon(Icons.access_time, size: 14, color: Colors.grey);
      case 'failed':
        return const Icon(Icons.error_outline, size: 14, color: Colors.redAccent);
      case 'read':
        return const Icon(Icons.done_all, size: 14, color: Colors.blue);
      case 'delivered':
        return const Icon(Icons.done_all, size: 14, color: Colors.grey);
      case 'sent':
      default:
        return const Icon(Icons.done, size: 14, color: Colors.grey);
    }
  }
}
