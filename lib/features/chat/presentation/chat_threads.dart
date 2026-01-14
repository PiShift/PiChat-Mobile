import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pichat/core/theme/app_theme.dart';
import 'package:pichat/data/models/chat_model.dart';
import 'package:pichat/data/models/contact_model.dart';
import 'package:pichat/data/repositories/chat_repository.dart';
import 'package:pichat/features/chat/application/message_provider.dart';
import 'package:pichat/features/chat/widgets/chat_item.dart';
import 'package:scrollable_positioned_list/scrollable_positioned_list.dart';

class ChatThread extends ConsumerStatefulWidget {
  final Contact contact;
  const ChatThread({required this.contact, super.key});

  @override
  ConsumerState<ChatThread> createState() => _ChatThreadState();
}
class _ChatThreadState extends ConsumerState<ChatThread> {
  final ItemScrollController _itemScrollController = ItemScrollController();
  final ItemPositionsListener _itemPositionsListener = ItemPositionsListener.create();

  bool _hasScrolledToInitialPosition = false;
  bool _showScrollToBottom = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchNewMessages();
    });

    _itemPositionsListener.itemPositions.addListener(_visibleItemsListener);
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

    // Mark all visible messages as read
    final visibleMessages = messages
        .sublist(
      firstVisibleIndex.clamp(0, messages.length),
      (lastVisibleIndex + 1).clamp(0, messages.length),
    )
        .where((m) => !m.isRead)
        .toList();

    if (visibleMessages.isNotEmpty) {
      _markMessagesAsRead(visibleMessages);
    }

    // Show FAB if bottom not visible
    final lastIndex = messages.length - 1;
    final isAtBottom = positions.any((p) => p.index == lastIndex && p.itemTrailingEdge <= 1.0);
    if (!isAtBottom && !_showScrollToBottom) {
      setState(() => _showScrollToBottom = true);
    } else if (isAtBottom && _showScrollToBottom) {
      setState(() => _showScrollToBottom = false);
    }
  }

  void _markMessagesAsRead(List<Chat> msgs) async {
    final chatRepo = ref.read(chatRepositoryProvider);

    // Convert to ChatData but only update isRead
    final updates = msgs.map((msg) {
      return msg.copyWith(isRead: true); // Your Chat class should have copyWith
    }).toList();

    // await chatRepo.markMessagesAsRead(updates);
    // ref.invalidate(messagesProvider(widget.contact.id));
  }

  void _scrollToBottom() {
    final messages = ref.read(messagesProvider(widget.contact.id)).maybeWhen(
      data: (messages) => messages,
      orElse: () => [],
    );
    if (messages.isNotEmpty) {
      _itemScrollController.scrollTo(
        index: messages.length - 1,
        duration: const Duration(milliseconds: 300),
      );
    }
  }

  void _scrollToFirstUnread(List<Chat> messages) {
    if (_hasScrolledToInitialPosition) return;

    final firstUnreadIndex = messages.indexWhere((m) => !m.isRead);
    if (firstUnreadIndex != -1) {
      // Scroll to middle of viewport by using alignment 0.5
      _itemScrollController.scrollTo(
        index: firstUnreadIndex,
        duration: const Duration(milliseconds: 300),
        alignment: 0.5, // <-- middle of screen
      );
    } else {
      _scrollToBottom();
    }
    _hasScrolledToInitialPosition = true;
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesProvider(widget.contact.id));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(
            widget.contact.fullName ?? widget.contact.phone,
          style: TextStyle(
            color: AppColors.background
          ),
        ),
        leading: InkWell(
          onTap: () => context.pop(),
          child: Icon(Icons.arrow_back_ios_new, color: AppColors.background,),
        ),
      ),
      body: messagesAsync.when(
        data: (messages) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _scrollToFirstUnread(messages);
          });

          return Stack(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: RefreshIndicator(
                  onRefresh: _fetchNewMessages,
                  child: ScrollablePositionedList.builder(
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isUnread = !msg.isRead;
                      return ChatMessageItem(message: msg, isUnread: isUnread);
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
                              .where((m) => !m.isRead)
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
        error: (e, s) => Center(child: Text('Error loading messages: $e')),
      ),
    );
  }
}
