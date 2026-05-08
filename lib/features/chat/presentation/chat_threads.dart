import 'dart:async';
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:pichat/core/state/auth_state.dart';
import 'package:pichat/core/theme/app_theme.dart';
import 'package:pichat/data/models/chat_model.dart';
import 'package:pichat/data/models/contact_model.dart';
import 'package:pichat/data/repositories/chat_repository.dart';
import 'package:pichat/data/repositories/team_repository.dart';
import 'package:pichat/features/chat/application/main_controller.dart';
import 'package:pichat/features/chat/application/message_provider.dart';
import 'package:pichat/features/chat/presentation/media_gallery_screen.dart';
import 'package:pichat/features/chat/presentation/media_preview_screen.dart';
import 'package:pichat/features/chat/presentation/widgets/agent_picker_sheet.dart';
import 'package:pichat/features/chat/presentation/widgets/quick_reply_picker.dart';
import 'package:pichat/features/contacts/presentation/contact_details_screen.dart';
import 'package:pichat/features/templates/presentation/template_picker_screen.dart';
import 'package:pichat/features/chat/widgets/chat_item.dart';
import 'package:pichat/features/chat/widgets/share_contact_sheet.dart';
import 'package:pichat/features/chat/widgets/share_location_sheet.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class ChatThread extends ConsumerStatefulWidget {
  final Contact contact;
  const ChatThread({required this.contact, super.key});

  @override
  ConsumerState<ChatThread> createState() => _ChatThreadState();
}
class _ChatThreadState extends ConsumerState<ChatThread>
    with WidgetsBindingObserver {
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();

  bool _hasScrolledToInitialPosition = false;
  bool _showScrollToBottom = false;
  bool _showAttachmentPanel = false;
  bool _showEmojiPanel = false;
  bool _isAtBottom = true;
  int _lastRenderedCount = 0;

  // ── Voice recording state ────────────────────────────────────────────
  /// Whether the input field currently has any text. Drives the swap
  /// between the mic button (idle/empty) and the send button (typing).
  bool _hasText = false;
  /// True while audio is actively being captured by the microphone.
  bool _isRecording = false;
  /// Path to the freshly recorded audio file once the user stops the
  /// recording. Non-null means we're in "review before send" mode.
  String? _recordedAudioPath;
  /// Final length of the recording, captured at stop time.
  Duration _recordedDuration = Duration.zero;
  /// Live elapsed time while [_isRecording] is true.
  Duration _recordElapsed = Duration.zero;
  Timer? _recordTicker;
  final AudioRecorder _audioRecorder = AudioRecorder();
  final AudioPlayer _previewPlayer = AudioPlayer();
  bool _previewIsPlaying = false;
  StreamSubscription<PlayerState>? _previewStateSub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchNewMessages();
    });

    _itemPositionsListener.itemPositions.addListener(_visibleItemsListener);

    _messageController.addListener(_onTextChanged);

    _previewStateSub = _previewPlayer.playerStateStream.listen((s) {
      final playing = s.playing && s.processingState != ProcessingState.completed;
      if (playing != _previewIsPlaying && mounted) {
        setState(() => _previewIsPlaying = playing);
      }
      if (s.processingState == ProcessingState.completed) {
        _previewPlayer.seek(Duration.zero);
        _previewPlayer.pause();
      }
    });

    _messageFocusNode.addListener(() {
      if (_messageFocusNode.hasFocus && mounted) {
        setState(() {
          _showAttachmentPanel = false;
          _showEmojiPanel = false;
        });
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _messageController.removeListener(_onTextChanged);
    _messageController.dispose();
    _messageFocusNode.dispose();
    _recordTicker?.cancel();
    _audioRecorder.dispose();
    _previewStateSub?.cancel();
    _previewPlayer.dispose();
    if (_recordedAudioPath != null) {
      // best-effort cleanup of the temp recording if the user navigates away
      // without sending it.
      final f = File(_recordedAudioPath!);
      if (f.existsSync()) {
        try { f.deleteSync(); } catch (_) {}
      }
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-fetch messages missed while the app was in the background
      _fetchNewMessages();
    }
  }

  void _onTextChanged() {
    final h = _messageController.text.trim().isNotEmpty;
    if (h != _hasText && mounted) {
      setState(() => _hasText = h);
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;

    _messageController.clear();

    final chatRepo = ref.read(chatRepositoryProvider);
    final orgId = ref.read(organizationProvider)?.id ?? 0;

    try {
      await chatRepo.sendTextMessage(
        widget.contact.uuid,
        text,
        contactId: widget.contact.id,
        orgId: orgId,
      );
    } on MessageWindowExpiredException {
      // 24h window expired — optimistic row already deleted by repository.
      // Show the expired banner so the user knows to send a template instead.
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('chat.banner.24h_expired'.tr()),
            backgroundColor: Colors.orange,
            action: SnackBarAction(
              label: 'chat.banner.send_template_button'.tr(),
              textColor: Colors.white,
              onPressed: _showTemplatePicker,
            ),
          ),
        );
      }
    } catch (_) {
      // Other errors are shown via the retry button on the failed message.
    }

    // Sending always pulls the viewport to the latest message, even if the
    // user was scrolled up reading older history.
    _isAtBottom = true;
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  /// Handle menu action selection
  void _handleMenuAction(String action) {
    switch (action) {
      case 'contact':
        _showContactDetails();
        break;
      case 'template':
        _showTemplatePicker();
        break;
      case 'assign':
        _showAgentPicker();
        break;
      case 'status':
        _showStatusPicker();
        break;
      case 'close':
        _closeTicket();
        break;
    }
  }

  /// Show contact details screen
  void _showContactDetails() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ContactDetailsScreen(contact: widget.contact),
      ),
    );
  }

  /// Show template picker for 24h window expired contacts
  void _showTemplatePicker() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TemplatePickerScreen(
          contactUuid: widget.contact.uuid,
          contactName: widget.contact.fullName ?? widget.contact.phone,
          onTemplateSent: () {
            // Refresh messages after template sent
            ref.invalidate(messagesProvider(widget.contact.id));
            Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
          },
        ),
      ),
    );
  }

  /// Show agent picker bottom sheet
  void _showAgentPicker() async {
    // First get current ticket to know current agent
    final teamRepo = ref.read(teamRepositoryProvider);
    Ticket? currentTicket;
    
    try {
      currentTicket = await teamRepo.getTicket(widget.contact.uuid);
    } catch (_) {}
    
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.8,
        minChildSize: 0.3,
        builder: (_, scrollController) => AgentPickerSheet(
          contactUuid: widget.contact.uuid,
          currentAgent: currentTicket?.assignedTo,
          onAgentSelected: (agent) async {
            try {
              await teamRepo.assignToAgent(widget.contact.uuid, agent.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('chat.snackbar.assigned_to'.tr(namedArgs: {'name': agent.name})),
                    backgroundColor: Colors.green,
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('chat.snackbar.failed_to_assign'.tr(namedArgs: {'error': e.toString()})),
                    backgroundColor: AppColors.error,
                  ),
                );
              }
            }
          },
        ),
      ),
    );
  }

  /// Show status picker bottom sheet
  void _showStatusPicker() async {
    final teamRepo = ref.read(teamRepositoryProvider);
    Ticket? currentTicket;
    
    try {
      currentTicket = await teamRepo.getTicket(widget.contact.uuid);
    } catch (_) {}
    
    if (!mounted) return;
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TicketStatusSheet(
        currentStatus: currentTicket?.status ?? 'open',
        onStatusSelected: (status) async {
          try {
            await teamRepo.updateTicketStatus(widget.contact.uuid, status);
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('chat.snackbar.status_changed'.tr(namedArgs: {'status': status})),
                  backgroundColor: Colors.green,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('chat.snackbar.failed_to_update_status'.tr(namedArgs: {'error': e.toString()})),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          }
        },
      ),
    );
  }

  /// Close the ticket
  void _closeTicket() async {
    final teamRepo = ref.read(teamRepositoryProvider);
    
    try {
      await teamRepo.updateTicketStatus(widget.contact.uuid, 'closed');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('chat.snackbar.ticket_closed'.tr()),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('chat.snackbar.failed_to_close_ticket'.tr(namedArgs: {'error': e.toString()})),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _fetchNewMessages() async {
    final chatRepo = ref.read(chatRepositoryProvider);
    final lastId = widget.contact.lastChatId;
    await chatRepo.getMessages(widget.contact.id, afterId: lastId, forceRefresh: true);
  }

  void _visibleItemsListener() {
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;

    final messages = ref.read(messagesProvider(widget.contact.id)).maybeWhen(
      data: (List<Chat> m) => m,
      orElse: () => <Chat>[],
    );
    if (messages.isEmpty) return;

    // Determine visible indices roughly in the middle of the viewport
    final firstVisibleIndex = positions.map((p) => p.index).reduce((a, b) => a < b ? a : b);
    final lastVisibleIndex = positions.map((p) => p.index).reduce((a, b) => a > b ? a : b);

    // Mark all visible *inbound* messages as read. Outbound messages live
    // with is_read=false until the recipient reads them; if we included them
    // here we'd both fire spurious read-receipt API calls and decrement the
    // contact's unread count for our own sent messages.
    final visibleMessages = messages
        .sublist(
      firstVisibleIndex.clamp(0, messages.length),
      (lastVisibleIndex + 1).clamp(0, messages.length),
    )
        .where((m) => m.type == 'inbound' && !m.isRead)
        .toList();

    if (visibleMessages.isNotEmpty) {
      _markMessagesAsRead(visibleMessages);
    }

    // Show FAB only when the user has scrolled at least ~3 items away from the bottom.
    // This prevents the button from popping up after just a tiny scroll.
    final lastIndex = messages.length - 1;
    final maxVisibleIndex = positions.map((p) => p.index).reduce((a, b) => a > b ? a : b);
    final isNearBottom = lastIndex - maxVisibleIndex < 3;
    _isAtBottom = isNearBottom;
    if (!isNearBottom && !_showScrollToBottom) {
      setState(() => _showScrollToBottom = true);
    } else if (isNearBottom && _showScrollToBottom) {
      setState(() => _showScrollToBottom = false);
    }
  }

  void _markMessagesAsRead(List<Chat> msgs) async {
    final chatRepo = ref.read(chatRepositoryProvider);

    // Convert to ChatData but only update isRead
    final updates = msgs.map((msg) {
      return msg.copyWith(isRead: true); // Your Chat class should have copyWith
    }).toList();

    await chatRepo.markMessagesAsRead(updates);

    // Update the contact's unread count in the contacts list
    ref.read(mainDataProvider.notifier).decreaseUnreadCount(
      widget.contact.id,
      msgs.length,
    );
  }

  void _scrollToBottom() {
    final messages = ref.read(messagesProvider(widget.contact.id)).maybeWhen(
      data: (messages) => messages.where(_hasRenderableContent).toList(),
      orElse: () => <Chat>[],
    );
    if (messages.isNotEmpty && _itemScrollController.isAttached) {
      _itemScrollController.scrollTo(
        index: messages.length - 1,
        duration: const Duration(milliseconds: 300),
      );
    }
  }

  /// Jump to the bottom without animation — used right after sending so the
  /// user immediately sees their own message even if they were scrolled up.
  // ignore: unused_element
  void _jumpToBottom() {
    final messages = ref.read(messagesProvider(widget.contact.id)).maybeWhen(
      data: (messages) => messages.where(_hasRenderableContent).toList(),
      orElse: () => <Chat>[],
    );
    if (messages.isNotEmpty && _itemScrollController.isAttached) {
      _itemScrollController.jumpTo(index: messages.length - 1);
    }
  }
  void _scrollToFirstUnread(List<Chat> messages) {
    if (_hasScrolledToInitialPosition) return;

    // Initial position is already set via initialScrollIndex — just mark done.
    _hasScrolledToInitialPosition = true;
  }

  /// True when a message has at least one renderable piece of content
  /// (text body, media, header, or interactive buttons). Used to hide
  /// blank bubbles that come from partial/system payloads.
  bool _hasRenderableContent(Chat msg) {
    if (msg.media != null) return true;
    final meta = msg.metadata;
    if (meta == null) return false;
    // Reactions are overlaid on their referenced bubble — they should never
    // appear as standalone bubbles in the message list.
    if ((meta['type'] as String?) == 'reaction') return false;
    if ((meta['_localFilePath'] as String?)?.isNotEmpty == true) return true;
    final type = meta['type'] as String? ?? 'text';
    // Location/contacts payloads are always renderable.
    if (type == 'location' || type == 'contacts') return true;
    final textNode = meta['text'];
    final body = textNode is Map ? textNode['body'] as String? : null;
    if (body != null && body.trim().isNotEmpty) return true;
    final typeNode = meta[type];
    final caption = typeNode is Map ? typeNode['caption'] as String? : null;
    if (caption != null && caption.trim().isNotEmpty) return true;
    final headerNode = meta['header'];
    final header = headerNode is Map ? headerNode['text'] as String? : null;
    if (header != null && header.trim().isNotEmpty) return true;
    final buttons = meta['buttons'];
    if (buttons is List && buttons.isNotEmpty) return true;
    return false;
  }

  /// Walk through every message and build a `wam_id -> [reactions]` lookup
  /// so each rendered bubble can show the reactions it has received as a
  /// small overlay. WhatsApp keeps **one** reaction per participant, so we
  /// dedupe by sender direction (inbound = the contact, outbound = us) and
  /// the latest emoji from a given side wins. An empty emoji clears that
  /// side's reaction.
  Map<String, List<_ReactionInfo>> _collectReactions(List<Chat> all) {
    // Iterate in chronological order so later entries overwrite earlier.
    final ordered = [...all]
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    // wamId -> {fromMe -> emoji}
    final perTarget = <String, Map<bool, String>>{};
    for (final m in ordered) {
      final meta = m.metadata;
      if (meta == null) continue;
      if ((meta['type'] as String?) != 'reaction') continue;
      final r = (meta['reaction'] as Map?) ?? const {};
      final targetWamId = r['message_id'] as String?;
      if (targetWamId == null) continue;
      final emoji = (r['emoji'] as String?) ?? '';
      final fromMe = m.type == 'outbound';
      final bucket = perTarget.putIfAbsent(targetWamId, () => {});
      if (emoji.isEmpty) {
        bucket.remove(fromMe);
      } else {
        bucket[fromMe] = emoji;
      }
    }
    return {
      for (final entry in perTarget.entries)
        if (entry.value.isNotEmpty)
          entry.key: [
            // Contact's reaction first (left-most), then ours.
            if (entry.value[false] != null)
              _ReactionInfo(emoji: entry.value[false]!, fromMe: false),
            if (entry.value[true] != null)
              _ReactionInfo(emoji: entry.value[true]!, fromMe: true),
          ],
    };
  }

  /// Compute the index to open at: first unread, or last message.
  int _initialIndex(List<Chat> messages) {
    if (messages.isEmpty) return 0;
    final firstUnread = messages.indexWhere((m) => m.type == 'inbound' && !m.isRead);
    return firstUnread != -1 ? firstUnread : messages.length - 1;
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesProvider(widget.contact.id));

    // Auto-scroll to bottom whenever the conversation grows AND the user is
    // already pinned at the bottom. This keeps the latest message visible
    // for both messages we send and incoming Reverb pushes, without yanking
    // the viewport away from someone who is reading older history.
    ref.listen<AsyncValue<List<Chat>>>(messagesProvider(widget.contact.id),
        (prev, next) {
      next.whenData((all) {
        final visible = all.where(_hasRenderableContent).length;
        if (visible > _lastRenderedCount && _isAtBottom) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _scrollToBottom();
          });
        }
        _lastRenderedCount = visible;
      });
    });

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.black12,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new, size: 20, color: Colors.grey[800]),
          onPressed: () => context.pop(),
        ),
        titleSpacing: 0,
        title: GestureDetector(
          onTap: _showContactDetails,
          behavior: HitTestBehavior.opaque,
          child: Row(
            children: [
              // Avatar
              CircleAvatar(
                radius: 18,
                backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                child: Text(
                  (widget.contact.fullName ?? widget.contact.phone)
                      .substring(0, 1)
                      .toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              // Name + phone
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      widget.contact.fullName ?? widget.contact.phone,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Colors.grey[900],
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (widget.contact.fullName != null)
                      Text(
                        widget.contact.phone,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey[500],
                          height: 1.2,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'Call',
            icon: Icon(Icons.call, color: Colors.grey[800]),
            onPressed: () {
              context.push('/call/outbound', extra: {
                'uuid': widget.contact.uuid,
                'name': widget.contact.fullName ?? widget.contact.phone,
                'phone': widget.contact.phone,
              });
            },
          ),
          // Actions menu — media gallery moved inside
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: Colors.grey[800]),
            onSelected: (value) {
              if (value == 'media') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => MediaGalleryScreen(
                      contactUuid: widget.contact.uuid,
                      contactName: widget.contact.fullName ?? widget.contact.phone,
                    ),
                  ),
                );
              } else {
                _handleMenuAction(value);
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'contact',
                child: Row(children: [
                  const Icon(Icons.person_outline, size: 20),
                  const SizedBox(width: 12),
                  Text('chat.menu.contact_details'.tr()),
                ]),
              ),
              PopupMenuItem(
                value: 'media',
                child: Row(children: [
                  const Icon(Icons.photo_library_outlined, size: 20),
                  const SizedBox(width: 12),
                  Text('chat.tooltip.media_gallery'.tr()),
                ]),
              ),
              PopupMenuItem(
                value: 'template',
                child: Row(children: [
                  const Icon(Icons.description_outlined, size: 20),
                  const SizedBox(width: 12),
                  Text('chat.menu.send_template'.tr()),
                ]),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'assign',
                child: Row(children: [
                  const Icon(Icons.person_add_outlined, size: 20),
                  const SizedBox(width: 12),
                  Text('chat.menu.assign_to_agent'.tr()),
                ]),
              ),
              PopupMenuItem(
                value: 'status',
                child: Row(children: [
                  const Icon(Icons.flag_outlined, size: 20),
                  const SizedBox(width: 12),
                  Text('chat.menu.change_status'.tr()),
                ]),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                value: 'close',
                child: Row(children: [
                  const Icon(Icons.check_circle_outline, size: 20, color: Colors.green),
                  const SizedBox(width: 12),
                  Text('chat.menu.close_ticket'.tr(), style: const TextStyle(color: Colors.green)),
                ]),
              ),
            ],
          ),
        ],
      ),
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          FocusScope.of(context).unfocus();
          setState(() {
            _showAttachmentPanel = false;
            _showEmojiPanel = false;
          });
        },
        child: Column(
        children: [
          // Messages list (expanded to fill available space)
          Expanded(
            child: messagesAsync.when(
              data: (allMessages) {
                // Drop empty bubbles: no text, no caption, no media, no header,
                // no buttons. These can come from system events or partial
                // template payloads and just render as a blank box.
                final messages = allMessages.where(_hasRenderableContent).toList();
                final reactionsByWamId = _collectReactions(allMessages);
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  _scrollToFirstUnread(messages);
                });

                // Compute initial position once — used by ScrollablePositionedList
                // to render directly at the right spot with no visible scroll.
                final startIndex = _hasScrolledToInitialPosition
                    ? null
                    : _initialIndex(messages);
                final isAtBottom = startIndex == null ||
                    startIndex == messages.length - 1;

                return Stack(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: RefreshIndicator(
                        onRefresh: _fetchNewMessages,
                        child: ScrollablePositionedList.builder(
                          itemCount: messages.length,
                          initialScrollIndex: startIndex ?? (messages.isEmpty ? 0 : messages.length - 1),
                          initialAlignment: isAtBottom ? 0.0 : 0.3,
                          itemBuilder: (context, index) {
                            final msg = messages[index];
                            final isUnread = msg.type == 'inbound' && !msg.isRead;
                            final reactions = msg.wamId != null
                                ? reactionsByWamId[msg.wamId!]
                                : null;
                            return ChatMessageItem(
                              message: msg,
                              contactUuid: widget.contact.uuid,
                              isUnread: isUnread,
                              reactions: reactions
                                      ?.map((r) => ChatReactionInfo(
                                            emoji: r.emoji,
                                            fromMe: r.fromMe,
                                          ))
                                      .toList() ??
                                  const [],
                            );
                          },
                          itemScrollController: _itemScrollController,
                          itemPositionsListener: _itemPositionsListener,
                        ),
                      ),
                    ),
                    if (_showScrollToBottom)
                      Positioned(
                        bottom: 20,
                        right: 20,
                        child: Stack(
                          clipBehavior: Clip.none,
                          children: [
                            FloatingActionButton(
                              onPressed: _scrollToBottom,
                              backgroundColor: AppColors.primary,
                              mini: true,
                              shape: const CircleBorder(),
                              child: const Icon(Icons.keyboard_arrow_down_outlined, color: Colors.white,),
                            ),
                            // Unread badge
                            Builder(
                              builder: (context) {
                                final unreadCount = messagesAsync.value!
                                    .where((m) => m.type == 'inbound' && !m.isRead)
                                    .length;
                                if (unreadCount == 0) return const SizedBox.shrink();
                                return Positioned(
                                  right: -4,
                                  top: -4,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: AppColors.secondary,
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: const BoxConstraints(
                                      minWidth: 20,
                                      minHeight: 20,
                                    ),
                                    child: Center(
                                      child: Text(
                                        '$unreadCount',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                  ],
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, s) => Center(child: Text('chat.error.loading_messages'.tr(namedArgs: {'error': e.toString()}))),
            ),
          ),

          // Message input field at bottom
          _buildMessageInput(),
        ],
        ),
      ),
    );
  }

  /// Show quick reply picker
  void _showQuickReplyPicker({String? initialSearch}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        minChildSize: 0.4,
        builder: (_, scrollController) => QuickReplyPicker(
          initialSearch: initialSearch,
          onReplySelected: (reply) {
            // Insert the reply text into the message field
            _messageController.text = reply.content;
            _messageController.selection = TextSelection.fromPosition(
              TextPosition(offset: reply.content.length),
            );
            _messageFocusNode.requestFocus();
          },
        ),
      ),
    );
  }

  /// Returns true if the contact messaged us within the last 24 hours
  bool _isWithin24HourWindow() {
    final lastInbound = widget.contact.lastInboundChatAt;
    if (lastInbound == null) return false;
    return DateTime.now().difference(lastInbound).inHours < 24;
  }

  /// Banner shown when the 24-hour window has expired
  Widget _build24HourExpiredBanner() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        border: Border(top: BorderSide(color: Colors.orange.shade200)),
      ),
      child: SafeArea(
        child: Row(
          children: [
            Icon(Icons.timer_off_outlined, color: Colors.orange.shade700, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'chat.banner.24h_expired'.tr(),
                style: TextStyle(color: Colors.orange.shade800, fontSize: 13),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: _showTemplatePicker,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange.shade700,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                textStyle: const TextStyle(fontSize: 13),
              ),
              child: Text('chat.banner.send_template_button'.tr()),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleEmojiPanel() {
    if (_showEmojiPanel) {
      setState(() => _showEmojiPanel = false);
      _messageFocusNode.requestFocus();
    } else {
      _messageFocusNode.unfocus();
      setState(() {
        _showEmojiPanel = true;
        _showAttachmentPanel = false;
      });
    }
  }

  void _toggleAttachmentPanel() {
    if (_showAttachmentPanel) {
      setState(() => _showAttachmentPanel = false);
    } else {
      _messageFocusNode.unfocus();
      setState(() {
        _showAttachmentPanel = true;
        _showEmojiPanel = false;
      });
    }
  }

  void _closePanel() {
    setState(() {
      _showAttachmentPanel = false;
      _showEmojiPanel = false;
    });
  }

  // ── Voice recording ──────────────────────────────────────────────────────
  String _formatRecDuration(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  Future<void> _startRecording() async {
    // Drop any open panel and dismiss the keyboard so the recording row gets
    // the user's full attention.
    _closePanel();
    _messageFocusNode.unfocus();

    if (!await _audioRecorder.hasPermission()) {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Microphone permission denied')),
          );
        }
        return;
      }
    }

    final dir = await getTemporaryDirectory();
    // WhatsApp Cloud API only renders an audio upload as a *voice note*
    // (mic icon, transcription, auto-play) when it's encoded as OPUS in an
    // OGG container. Plain AAC/M4A clips arrive as basic audio files.
    // Falling back to AAC keeps recording working on the (rare) device that
    // can't encode opus directly.
    final supportsOpus = await _audioRecorder.isEncoderSupported(AudioEncoder.opus);
    final encoder = supportsOpus ? AudioEncoder.opus : AudioEncoder.aacLc;
    final ext = supportsOpus ? 'ogg' : 'm4a';
    final path =
        '${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.$ext';

    await _audioRecorder.start(
      RecordConfig(
        encoder: encoder,
        bitRate: 64000,
        sampleRate: supportsOpus ? 16000 : 44100,
        numChannels: 1,
      ),
      path: path,
    );

    final start = DateTime.now();
    _recordTicker?.cancel();
    _recordTicker = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      setState(() => _recordElapsed = DateTime.now().difference(start));
    });

    if (!mounted) return;
    setState(() {
      _isRecording = true;
      _recordedAudioPath = null;
      _recordedDuration = Duration.zero;
      _recordElapsed = Duration.zero;
    });
  }

  Future<void> _cancelRecording() async {
    _recordTicker?.cancel();
    final path = await _audioRecorder.stop();
    if (path != null) {
      final f = File(path);
      if (await f.exists()) {
        try { await f.delete(); } catch (_) {}
      }
    }
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _recordedAudioPath = null;
      _recordElapsed = Duration.zero;
      _recordedDuration = Duration.zero;
    });
  }

  Future<void> _stopRecordingForReview() async {
    _recordTicker?.cancel();
    final captured = _recordElapsed;
    final path = await _audioRecorder.stop();
    if (path == null) {
      if (mounted) setState(() => _isRecording = false);
      return;
    }
    // Anything below ~0.7s is almost certainly an accidental tap — drop it.
    if (captured.inMilliseconds < 700) {
      try { await File(path).delete(); } catch (_) {}
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _recordedAudioPath = null;
        _recordElapsed = Duration.zero;
      });
      return;
    }
    try {
      await _previewPlayer.setFilePath(path);
    } catch (_) {}
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _recordedAudioPath = path;
      _recordedDuration = captured;
    });
  }

  Future<void> _deleteRecording() async {
    await _previewPlayer.stop();
    final path = _recordedAudioPath;
    if (path != null) {
      final f = File(path);
      if (await f.exists()) {
        try { await f.delete(); } catch (_) {}
      }
    }
    if (!mounted) return;
    setState(() {
      _recordedAudioPath = null;
      _recordedDuration = Duration.zero;
      _previewIsPlaying = false;
    });
  }

  Future<void> _togglePreviewPlayback() async {
    if (_previewIsPlaying) {
      await _previewPlayer.pause();
    } else {
      await _previewPlayer.play();
    }
  }

  Future<void> _sendRecording() async {
    final path = _recordedAudioPath;
    if (path == null) return;
    await _previewPlayer.stop();
    final file = File(path);
    setState(() {
      _recordedAudioPath = null;
      _recordedDuration = Duration.zero;
      _previewIsPlaying = false;
    });
    await _sendMediaFile(file, isVoice: true);
  }

  // ── Input row builders ───────────────────────────────────────────────────
  Widget _buildIdleInputRow(bool panelOpen) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // LEFT: + (opens attachment panel) or keyboard (closes panel)
        _IconTapTarget(
          onTap: _showAttachmentPanel ? _closePanel : _toggleAttachmentPanel,
          tooltip: panelOpen ? null : 'chat.attachment.sheet_title'.tr(),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: Icon(
              panelOpen ? Icons.keyboard_alt_outlined : Icons.add,
              key: ValueKey(panelOpen),
              size: 24,
              color: Colors.grey[700],
            ),
          ),
        ),
        // CENTER: text field with sticker icon inside (right)
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 110, minHeight: 38),
            child: Container(
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _messageController,
                      focusNode: _messageFocusNode,
                      maxLines: 4,
                      minLines: 1,
                      textCapitalization: TextCapitalization.sentences,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textDark,
                      ),
                      decoration: InputDecoration(
                        hintText: 'chat.input.hint'.tr(),
                        hintStyle: TextStyle(
                          color: Colors.grey[500],
                          fontSize: 13,
                        ),
                        border: InputBorder.none,
                        isCollapsed: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                      ),
                      onChanged: (text) {
                        if (text.trim() == '/') {
                          _showQuickReplyPicker(initialSearch: '');
                        }
                      },
                      onSubmitted: (_) => _sendMessage(),
                    ),
                  ),
                  GestureDetector(
                    onTap: _toggleEmojiPanel,
                    behavior: HitTestBehavior.opaque,
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 180),
                          child: Icon(
                            _showEmojiPanel
                                ? Icons.keyboard_alt_outlined
                                : Icons.emoji_emotions_outlined,
                            key: ValueKey(_showEmojiPanel),
                            size: 22,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 4),
        // Camera + mic shortcuts — always visible when no text. They share
        // the same flat styling so the mic feels like a sibling shortcut
        // rather than the primary "send" affordance.
        if (!_hasText) ...[
          _IconTapTarget(
            onTap: () { _closePanel(); _pickImage(ImageSource.camera); },
            child: Icon(
              Icons.camera_alt_outlined,
              size: 22,
              color: Colors.grey[700],
            ),
          ),
          _IconTapTarget(
            onTap: _startRecording,
            child: Icon(
              Icons.mic_none_rounded,
              size: 22,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(width: 4),
        ] else ...[
          // When typing, show the orange send button on the right.
          const SizedBox(width: 4),
          GestureDetector(
            onTap: _sendMessage,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 180),
              transitionBuilder: (c, a) =>
                  ScaleTransition(scale: a, child: c),
              child: Container(
                key: const ValueKey('send'),
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 18,
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildRecordingRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // LEFT: trash to abort
        _IconTapTarget(
          onTap: _cancelRecording,
          child: Icon(Icons.delete_outline,
              size: 22, color: Colors.red[600]),
        ),
        // CENTER: pulsing red dot + elapsed timer in a pill
        Expanded(
          child: Container(
            height: 38,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                _PulsingRedDot(),
                const SizedBox(width: 10),
                Text(
                  _formatRecDuration(_recordElapsed),
                  style: const TextStyle(
                    fontSize: 14,
                    fontFeatures: [FontFeature.tabularFigures()],
                    color: AppColors.textDark,
                  ),
                ),
                const Spacer(),
                Text(
                  'Recording…',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // RIGHT: stop = move to review
        GestureDetector(
          onTap: _stopRecordingForReview,
          child: Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.stop_rounded,
                color: Colors.white, size: 20),
          ),
        ),
      ],
    );
  }

  Widget _buildAudioReviewRow() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // LEFT: discard
        _IconTapTarget(
          onTap: _deleteRecording,
          child:
              Icon(Icons.delete_outline, size: 22, color: Colors.red[600]),
        ),
        // CENTER: play/pause + position text inside the same pill as input
        Expanded(
          child: Container(
            height: 38,
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.only(left: 4, right: 14),
            child: Row(
              children: [
                IconButton(
                  onPressed: _togglePreviewPlayback,
                  iconSize: 22,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                      minWidth: 32, minHeight: 32),
                  icon: Icon(
                    _previewIsPlaying
                        ? Icons.pause_circle_filled
                        : Icons.play_circle_fill,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.mic, size: 14, color: Colors.black54),
                const SizedBox(width: 4),
                Expanded(
                  child: StreamBuilder<Duration>(
                    stream: _previewPlayer.positionStream,
                    builder: (context, snap) {
                      final pos = snap.data ?? Duration.zero;
                      final total = _recordedDuration == Duration.zero
                          ? (_previewPlayer.duration ?? Duration.zero)
                          : _recordedDuration;
                      final shown = _previewIsPlaying ? pos : total;
                      return Text(
                        _formatRecDuration(shown),
                        style: const TextStyle(
                          fontSize: 12,
                          fontFeatures: [FontFeature.tabularFigures()],
                          color: AppColors.textDark,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        // RIGHT: send recording
        GestureDetector(
          onTap: _sendRecording,
          child: Container(
            width: 38,
            height: 38,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.send_rounded,
                color: Colors.white, size: 18),
          ),
        ),
      ],
    );
  }

  /// Build the message input widget — WhatsApp style
  Widget _buildMessageInput() {
    if (!_isWithin24HourWindow()) {
      return _build24HourExpiredBanner();
    }

    final size = MediaQuery.sizeOf(context);
    final panelOpen = _showAttachmentPanel || _showEmojiPanel;

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 8, offset: const Offset(0, -1)),
        ],
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Input row ──
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 6,
              ),
              child: _isRecording
                  ? _buildRecordingRow()
                  : _recordedAudioPath != null
                      ? _buildAudioReviewRow()
                      : _buildIdleInputRow(panelOpen),
            ),

            // ── Bottom panel (attachment grid or emoji grid) ──
            AnimatedSize(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              child: _showAttachmentPanel
                  ? _buildAttachmentPanel(size)
                  : _showEmojiPanel
                      ? _buildEmojiPanel(size)
                      : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentPanel(Size size) {
    // 4-column grid, 2 rows — each option has a colored circle + label
    final actions = [
      (Icons.photo_library_rounded,   'chat.attachment.gallery'.tr(),  const Color(0xFF1A73E8), () { _closePanel(); _pickImage(ImageSource.gallery); }),
      (Icons.camera_alt_rounded,      'chat.attachment.camera'.tr(),   const Color(0xFF202124), () { _closePanel(); _pickImage(ImageSource.camera); }),
      (Icons.location_on_rounded,     'Location',                       const Color(0xFF34A853), () { _closePanel(); _shareLocation(); }),
      (Icons.person_rounded,          'Contact',                        const Color(0xFF9AA0A6), () { _closePanel(); _shareContact(); }),
      (Icons.insert_drive_file_rounded,'chat.attachment.document'.tr(), const Color(0xFF1A73E8), () { _closePanel(); _pickDocument(); }),
      (Icons.flash_on_rounded,        'Quick Reply',                    const Color(0xFFF9AB00), () { _closePanel(); _showQuickReplyPicker(); }),
    ];

    final circleSize = size.width * 0.155;
    final iconSize   = size.width * 0.065;

    return Container(
      width: double.infinity,
      color: const Color(0xFFF0EBE1), // WhatsApp's warm cream background
      padding: EdgeInsets.fromLTRB(
        size.width * 0.04,
        size.height * 0.025,
        size.width * 0.04,
        size.height * 0.02,
      ),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 4,
        mainAxisSpacing: size.height * 0.024,
        crossAxisSpacing: size.width * 0.02,
        childAspectRatio: 0.85,
        children: actions.map((a) {
          return GestureDetector(
            onTap: a.$4,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: circleSize,
                  height: circleSize,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.08),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Icon(a.$1, size: iconSize, color: a.$3),
                ),
                SizedBox(height: size.height * 0.008),
                Text(
                  a.$2,
                  style: TextStyle(
                    fontSize: size.width * 0.029,
                    color: Colors.grey[700],
                    fontWeight: FontWeight.w500,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildEmojiPanel(Size size) {
    const emojis = [
      '😀','😃','😄','😁','😆','😅','🤣','😂','🙂','🙃','😉','😊','😇','🥰','😍','🤩',
      '😘','😗','😚','😙','😋','😛','😜','🤪','😝','🤑','🤗','🤭','🤔','😐','😑','😶',
      '😏','😒','🙄','😬','😔','😪','😴','😷','🤒','🤕','🤢','🤮','🥵','🥶','😵','🤯',
      '🥳','😎','🤓','😕','😟','🙁','☹️','😮','😲','😳','🥺','😦','😧','😨','😢','😭',
      '😱','😖','😣','😞','😩','😫','😤','😡','😠','🤬','😈','👿','💀','💩','🤡','👻',
      '❤️','🧡','💛','💚','💙','💜','🖤','🤍','💔','❣️','💕','💞','💓','💗','💖','💘',
      '👋','✋','👌','✌️','🤞','👍','👎','✊','👏','🙌','🙏','🤝','💪','🦾','🖐️','☝️',
      '🎉','🎊','🎈','🎁','🏆','🥇','⭐','🌟','✨','🔥','💥','❄️','🌈','☀️','🌙','⚡',
    ];

    return Container(
      height: size.height * 0.28,
      color: Colors.white,
      child: GridView.builder(
        padding: EdgeInsets.all(size.width * 0.02),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 8,
          crossAxisSpacing: size.width * 0.005,
          mainAxisSpacing: size.width * 0.005,
        ),
        itemCount: emojis.length,
        itemBuilder: (_, i) => GestureDetector(
          onTap: () {
            final sel = _messageController.selection;
            final text = _messageController.text;
            final start = sel.start < 0 ? text.length : sel.start;
            final end = sel.end < 0 ? text.length : sel.end;
            final newText = text.replaceRange(start, end, emojis[i]);
            _messageController.value = TextEditingValue(
              text: newText,
              selection: TextSelection.collapsed(offset: start + emojis[i].length),
            );
          },
          child: Center(
            child: Text(emojis[i], style: TextStyle(fontSize: size.width * 0.062)),
          ),
        ),
      ),
    );
  }

  /// Pick image from gallery or camera — shows preview before sending
  Future<void> _pickImage(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final pickedFile = await picker.pickImage(
        source: source,
        imageQuality: 80,
        maxWidth: 1920,
        maxHeight: 1920,
      );

      if (pickedFile != null && mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MediaPreviewScreen(
              file: File(pickedFile.path),
              isImage: true,
              onSend: (file, caption) => _sendMediaFile(file, caption: caption),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('chat.snackbar.error_picking_image'.tr(namedArgs: {'error': e.toString()})), backgroundColor: AppColors.error),
        );
      }
    }
  }

  /// Pick document file — shows preview before sending
  Future<void> _pickDocument() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
      );

      if (result != null && result.files.single.path != null && mounted) {
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => MediaPreviewScreen(
              file: File(result.files.single.path!),
              isImage: false,
              onSend: (file, caption) => _sendMediaFile(file, caption: caption),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('chat.snackbar.error_picking_file'.tr(namedArgs: {'error': e.toString()})), backgroundColor: AppColors.error),
        );
      }
    }
  }

  /// Send a media file with optional caption — optimistic insert handles UX
  Future<void> _sendMediaFile(File file, {String? caption, bool isVoice = false}) async {
    final chatRepo = ref.read(chatRepositoryProvider);
    final orgId = ref.read(organizationProvider)?.id ?? 0;

    unawaited(chatRepo.sendMediaMessage(
      widget.contact.uuid,
      file,
      caption: caption,
      contactId: widget.contact.id,
      orgId: orgId,
      isVoice: isVoice,
    ));

    _isAtBottom = true;
    Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
  }

  /// Open the location-sharing sheet and dispatch the result.
  Future<void> _shareLocation() async {
    final result = await showShareLocationSheet(context);
    if (result == null) return;

    final chatRepo = ref.read(chatRepositoryProvider);
    final orgId = ref.read(organizationProvider)?.id ?? 0;

    try {
      await chatRepo.sendLocation(
        widget.contact.uuid,
        latitude: result.latitude,
        longitude: result.longitude,
        name: result.name,
        address: result.address,
        contactId: widget.contact.id,
        orgId: orgId,
      );
      _isAtBottom = true;
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to send location: $e')),
      );
    }
  }

  /// Open the contact-picker sheet (device address book) and forward the
  /// selection to Meta as a contact card. Address book details we don't
  /// have (org, urls, etc.) are simply left out of the payload — Meta
  /// accepts a minimal `name + phones[]` shape.
  Future<void> _shareContact() async {
    final picked = await showShareContactSheet(context);
    if (picked == null) return;

    final first = (picked.firstName ?? '').trim();
    final last = (picked.lastName ?? '').trim();
    final fullName = [first, last].where((s) => s.isNotEmpty).join(' ');
    final formattedName = fullName.isEmpty ? picked.displayName : fullName;

    final card = <String, dynamic>{
      'name': {
        'formatted_name': formattedName.isEmpty
            ? picked.phones.first.phone
            : formattedName,
        if (first.isNotEmpty) 'first_name': first,
        if (last.isNotEmpty) 'last_name': last,
      },
      'phones': [
        for (final p in picked.phones)
          {
            'phone': p.phone,
            'type': p.type,
          },
      ],
    };

    final chatRepo = ref.read(chatRepositoryProvider);
    final orgId = ref.read(organizationProvider)?.id ?? 0;

    try {
      await chatRepo.sendContactCards(
        widget.contact.uuid,
        [card],
        contactId: widget.contact.id,
        orgId: orgId,
      );
      _isAtBottom = true;
      Future.delayed(const Duration(milliseconds: 100), _scrollToBottom);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to share contact: $e')),
      );
    }
  }
}

/// Latest reaction visible on a chat bubble.
class _ReactionInfo {
  const _ReactionInfo({required this.emoji, required this.fromMe});
  final String emoji;
  final bool fromMe;
}

/// A flat 44\u00d744 tap target that wraps an icon. Matches Material's minimum
/// touch-target guideline so the inline input-bar shortcuts (+, sticker,
/// camera, mic, trash) are easy to hit even though the rendered icon stays
/// at 22\u201324dp.
class _IconTapTarget extends StatelessWidget {
  final VoidCallback onTap;
  final Widget child;
  final String? tooltip;

  const _IconTapTarget({
    required this.onTap,
    required this.child,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final button = Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(child: child),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

/// A small red dot that pulses opacity to signal an active recording.
class _PulsingRedDot extends StatefulWidget {
  @override
  State<_PulsingRedDot> createState() => _PulsingRedDotState();
}

class _PulsingRedDotState extends State<_PulsingRedDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0.35, end: 1.0).animate(_ctrl),
      child: Container(
        width: 10,
        height: 10,
        decoration: const BoxDecoration(
          color: Colors.red,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
