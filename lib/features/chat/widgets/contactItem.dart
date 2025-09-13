import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pichat/core/constants/app_constants.dart';
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
        // Less than 24h → show time
        return DateFormat.Hm().format(time);
      } else if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return DateFormat.E().format(time); // Mon, Tue...
      } else {
        return DateFormat('dd/MM/yyyy').format(time);
      }
    }

    return Column(
      children: [
        ListTile(
          leading: CircleAvatar(
            backgroundImage: contact.avatar != null
                ? NetworkImage("${AppConstants.baseUrl}${contact.avatar!}")
                : null,
            child: contact.avatar == null ? const Icon(Icons.person) : null,
          ),
          title: Text(contact.fullName ?? contact.phone),
          subtitle: lastChat == null || lastChat.deletedAt != null
              ? null
              : Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Outbound indicator for sent/delivered/read
              if (lastChat.userId != null)
                Padding(
                  padding: const EdgeInsets.only(right: 4.0),
                  child: Icon(
                    lastChat.isRead
                        ? Icons.done_all
                        : lastChat.status == 'delivered'
                        ? Icons.done_all
                        : Icons.done,
                    size: 16,
                    color: lastChat.isRead
                        ? Colors.blue
                        : lastChat.status == 'delivered'
                        ? Colors.grey
                        : Colors.grey,
                  ),
                ),
              // Message preview
              Expanded(
                child: Text(
                  _lastChatPreview(lastChat),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      color: Colors.grey[600], fontSize: 13),
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
                  formatLastChatTime(lastChat.createdAt),
                  style: TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
              if (contact.unreadCount > 0)
                Container(
                  margin: const EdgeInsets.only(top: 4),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.green,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${contact.unreadCount}',
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold),
                  ),
                ),
            ],
          ),
        ),
        // Bottom divider like WhatsApp
        const Divider(height: 0, indent: 72), // aligns with avatar
      ],
    );
  }

  String _lastChatPreview(Chat lastChat) {
    // Handle text, buttons, media, audio, etc.
    // Example for text and fallback icon for docs
    try {
      final meta = lastChat.metadata;
      final type = meta!['type'];
      switch (type) {
        case 'text':
          return meta['text']['body'] ?? '';
        case 'audio':
          return '🎵 Audio';
        case 'image':
          return '🖼️ Photo';
        case 'document':
          return '📄 Document';
        case 'video':
          return '🎬 Video';
        case 'sticker':
          return '😎 Sticker';
        default:
          return '📎 Attachment';
      }
    } catch (_) {
      return '';
    }
  }
}
