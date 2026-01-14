import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pichat/data/models/chat_model.dart';
import 'package:pichat/features/chat/widgets/image_preview.dart';

import 'audio_preview.dart';
import 'document_preview.dart';

class ChatMessageItem extends StatelessWidget {
  final Chat message;
  final bool isUnread;
  static const double mediaMaxWidth = 240.0;
  static const double mediaMaxHeight = 280.0;

  const ChatMessageItem({required this.message, this.isUnread = false, super.key});

  Map<String, dynamic> get metadata {
    try {
      return message.metadata != null ? message.metadata! : {};
    } catch (e) {
      return {};
    }
  }

  Widget _buildMediaPreview(BuildContext context, String mediaType) {
    if (message.media == null) return const SizedBox.shrink();
    final mediaId = message.media!.id ?? message.id;

    switch (mediaType) {
      case 'image':
        return ImagePreview(media: message.media!, mediaId: mediaId.toString());
      case 'audio':
        return AudioPreview(media: message.media!, mediaId: mediaId.toString());
      case 'pdf':
      case 'doc':
      case 'docx':
      default:
        return DocumentPreview(
          media: message.media!,
          mediaId: mediaId.toString(),
          mediaType: mediaType,
          contactId: message.contactId.toString()
        );
    }
  }

  void _showFullScreenMedia(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            iconTheme: const IconThemeData(color: Colors.white),
          ),
          body: Center(
            child: InteractiveViewer(
              child: Image.network(
                message.media!.path ?? '',
                fit: BoxFit.contain,
              ),
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
      // Handle URL button - implement URL launching
        break;
      case 'phone':
      // Handle phone button - implement phone dialing
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
      // Handle reply button - implement reply functionality
        break;
      default:
      // Default action or log unknown button type
        print('Unknown button type: $type');
    }
  }

  @override
  Widget build(BuildContext context) {
    final isInbound = message.type == 'inbound';
    final type = metadata['type'] ?? 'text';
    final header = metadata['header']?['text'];
    final body = metadata['text']?['body'];
    final buttons = metadata['buttons'] ?? [];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      alignment: isInbound ? Alignment.centerLeft : Alignment.centerRight,
      child: Column(
        crossAxisAlignment: isInbound ? CrossAxisAlignment.start : CrossAxisAlignment.end,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: mediaMaxWidth),
            child: Container(
              decoration: BoxDecoration(
                color: isInbound ? Colors.white : Colors.lightBlue[100],
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: isInbound ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                children: [
                  if (message.media != null) _buildMediaPreview(context, type),
                  if (header != null || body != null)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        crossAxisAlignment: isInbound ? CrossAxisAlignment.start : CrossAxisAlignment.end,
                        children: [
                          if (header != null)
                            Text(header, style: const TextStyle(fontWeight: FontWeight.bold)),
                          if (body != null) Text(body),
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
                              (i) => ElevatedButton(
                            onPressed: () => handleButton(context, buttons[i]),
                            child: Text(buttons[i]['text'] ?? 'Button'),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (isUnread)
            Padding(
              padding: const EdgeInsets.only(top: 2, left: 8, right: 8),
              child: Text(
                'New',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.red[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
