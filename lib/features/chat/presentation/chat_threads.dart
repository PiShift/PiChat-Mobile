import 'dart:async';
import 'dart:ui' show ImageFilter;
import 'dart:io';

import 'package:easy_localization/easy_localization.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:pichat/core/state/auth_state.dart';
import 'package:pichat/core/theme/app_colors.dart';
import 'package:pichat/core/theme/app_radius.dart';
import 'package:pichat/core/theme/app_sizing.dart';
import 'package:pichat/core/theme/app_spacing.dart';
import 'package:pichat/core/utils/chat_date.dart';
import 'package:pichat/features/chat/widgets/chat_date_chip.dart';
import 'package:pichat/data/models/chat_model.dart';
import 'package:pichat/features/chat/widgets/conversation_status_bar.dart';
import 'package:pichat/features/chat/widgets/timeline_event_item.dart';
import 'package:pichat/data/models/timeline_event_model.dart';
import 'package:pichat/data/models/contact_model.dart';
import 'package:pichat/data/repositories/chat_repository.dart';
import 'package:pichat/data/repositories/team_repository.dart';
import 'package:pichat/data/db/app_database.dart';
import 'package:pichat/data/db/database_provider.dart';
import 'package:drift/drift.dart' show OrderingTerm, OrderingMode;
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
  final ItemPositionsListener _itemPositionsListener =
      ItemPositionsListener.create();
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _messageFocusNode = FocusNode();

  bool _showScrollToBottom = false;
  bool _showAttachmentPanel = false;
  bool _showEmojiPanel = false;
  bool _isAtBottom = true;

  /// Index the thread should open at, decided once from the first real batch of
  /// messages: the first unread message, or the newest one when all are read.
  int? _initialScrollTarget;

  /// Id of the newest message we have rendered. Used to tell an appended
  /// message apart from older history arriving at the top - the latter must
  /// never move the viewport.
  int? _newestMessageId;
  bool _initialPositionApplied = false;

  /// Messages that arrived while the reader was scrolled away from the bottom.
  /// Shown as a count on the jump-to-bottom button and cleared when they get
  /// there.
  int _pendingNewMessages = 0;

  /// Messages this screen has already marked read, so repeated scroll frames
  /// do not re-write the same rows.
  final Set<int> _seenMessageIds = <int>{};

  /// Captured in initState: dispose() runs after `ref` stops being usable.
  late final ChatRepository _chatRepoForDispose;
  late final MainDataController _listNotifierForDispose;
  bool _isInitialLoading = true;

  /// Day shown by the chip pinned at the top of the thread.
  String? _stickyDateLabel;

  // Cached notifier so dispose() can safely clear without accessing ref.
  late StateController<int?> _activeContactNotifier;

  // ── Older-message pagination state ───────────────────────────────────
  bool _isLoadingOlder = false;
  bool _hasMoreOlderMessages = true;

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

    // Cache the notifier before any async work so dispose() can access it
    // safely even after the widget is deactivated (ref is no longer usable).
    _activeContactNotifier = ref.read(activeContactIdProvider.notifier);
    _chatRepoForDispose = ref.read(chatRepositoryProvider);
    _listNotifierForDispose = ref.read(mainDataProvider.notifier);

    // Tell the rest of the app which contact is currently open so
    // ReverbService can suppress in-app banners for this conversation.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _activeContactNotifier.state = widget.contact.id;
      _fetchNewMessages();
    });

    _itemPositionsListener.itemPositions.addListener(_visibleItemsListener);

    _messageController.addListener(_onTextChanged);

    _previewStateSub = _previewPlayer.playerStateStream.listen((s) {
      final playing =
          s.playing && s.processingState != ProcessingState.completed;
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
    /*
     * Leaving a conversation means it has been read. Marking only what scrolled
     * past the viewport left the reader with unread markers on messages they
     * had already moved beyond, so anything still queued is flushed and the
     * rest of the conversation is closed out in the same batch.
     */
    _markWholeConversationRead();

    // Clear the active contact so banners resume for future incoming messages.
    // Use the cached notifier — ref is unsafe after the widget is deactivated.
    _activeContactNotifier.state = null;
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
        try {
          f.deleteSync();
        } catch (_) {}
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
            backgroundColor: PiPalette.warning500,
            action: SnackBarAction(
              label: 'chat.banner.send_template_button'.tr(),
              textColor: PiPalette.white,
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

              // Reflect the new owner locally so the header and the chat list
              // update immediately instead of waiting for the next full
              // contacts refresh.
              await ref.read(appDatabaseProvider).setContactAssignment(
                    contactId: widget.contact.id,
                    agentId: agent.id,
                    agentName: agent.name,
                  );

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('chat.snackbar.assigned_to'
                        .tr(namedArgs: {'name': agent.name})),
                    backgroundColor: PiPalette.success500,
                  ),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('chat.snackbar.failed_to_assign'
                        .tr(namedArgs: {'error': e.toString()})),
                    backgroundColor: PiPalette.error500,
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
                  content: Text('chat.snackbar.status_changed'
                      .tr(namedArgs: {'status': status})),
                  backgroundColor: PiPalette.success500,
                ),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('chat.snackbar.failed_to_update_status'
                      .tr(namedArgs: {'error': e.toString()})),
                  backgroundColor: PiPalette.error500,
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
            backgroundColor: PiPalette.success500,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('chat.snackbar.failed_to_close_ticket'
                .tr(namedArgs: {'error': e.toString()})),
            backgroundColor: PiPalette.error500,
          ),
        );
      }
    }
  }

  Future<void> _fetchNewMessages() async {
    final chatRepo = ref.read(chatRepositoryProvider);

    // Deliberately NOT an `afterId` sync.
    //
    // `afterId` was the highest local message id, which cannot heal a gap in
    // the middle of a thread: if Reverb delivered the newest messages live
    // while an earlier stretch was missed (the app was closed, or a broadcast
    // was dropped), then "give me everything after the newest id I hold"
    // returns nothing and the hole stays forever — pull-to-refresh included.
    //
    // Re-reading the newest page instead costs the same single request and is
    // an idempotent upsert, so any gap inside that window fills itself. Older
    // gaps are handled by the scroll-up loader, which pages by `beforeId`.
    try {
      await chatRepo.getMessages(
        widget.contact.id,
        forceRefresh: true,
      );
    } finally {
      if (mounted && _isInitialLoading) {
        setState(() => _isInitialLoading = false);
      }
    }
  }

  /// Load messages older than the oldest locally stored message (scroll-up pagination).
  Future<void> _loadOlderMessages() async {
    if (_isLoadingOlder || !_hasMoreOlderMessages) return;
    setState(() => _isLoadingOlder = true);

    final db = ref.read(appDatabaseProvider);
    final chatRepo = ref.read(chatRepositoryProvider);

    // Find the oldest message currently in the local DB for this contact.
    final oldestLocalRow = await (db.select(db.chats)
          ..where((t) => t.contactId.equals(widget.contact.id))
          ..orderBy(
              [(t) => OrderingTerm(expression: t.id, mode: OrderingMode.asc)])
          ..limit(1))
        .getSingleOrNull();

    // Remember where the reader is so the same message can be put back under
    // their eye after older history is inserted above it.
    final anchor = _itemPositionsListener.itemPositions.value.isEmpty
        ? null
        : _itemPositionsListener.itemPositions.value.reduce(
            (a, b) => a.index < b.index ? a : b,
          );

    try {
      await chatRepo.getMessages(
        widget.contact.id,
        beforeId: oldestLocalRow?.id,
        forceRefresh: true,
      );

      // Did history actually get longer? Counting the returned rows was
      // unreliable: the endpoint returns timeline entries, and tickets and
      // notes among them made a full page look short, which permanently
      // stopped paging after the first fetch.
      final oldestNow = await (db.select(db.chats)
            ..where((t) => t.contactId.equals(widget.contact.id))
            ..orderBy([
              (t) => OrderingTerm(expression: t.id, mode: OrderingMode.asc),
            ])
            ..limit(1))
          .getSingleOrNull();

      final grew = oldestNow != null && oldestNow.id != oldestLocalRow?.id;

      if (!mounted) return;

      setState(() {
        _hasMoreOlderMessages = grew;
        _isLoadingOlder = false;
      });

      // Hold the reader's place: inserting above them would otherwise shift
      // everything down by however many messages just arrived.
      if (grew && anchor != null) {
        final inserted = await _countMessagesBefore(db, oldestLocalRow?.id);

        if (inserted > 0 && _itemScrollController.isAttached) {
          _itemScrollController.jumpTo(
            index: anchor.index + inserted,
            alignment: anchor.itemLeadingEdge,
          );
        }
      }
    } catch (_) {
      if (mounted) setState(() => _isLoadingOlder = false);
    }
  }

  /// How many messages now sit before [beforeId] - i.e. how many were just
  /// inserted above what the reader was looking at.
  Future<int> _countMessagesBefore(AppDatabase db, int? beforeId) async {
    if (beforeId == null) return 0;

    // Filtered in Dart rather than SQL to stay with the query style used
    // elsewhere in this file and avoid pulling drift's expression operators in.
    final rows = await (db.select(db.chats)
          ..where((t) => t.contactId.equals(widget.contact.id)))
        .get();

    return rows.where((r) => r.deletedAt == null && r.id < beforeId).length;
  }

  void _visibleItemsListener() {
    final positions = _itemPositionsListener.itemPositions.value;
    if (positions.isEmpty) return;

    // Must apply the same _hasRenderableContent filter used by ScrollablePositionedList
    // so that position indices (0..N-1 of filtered items) map to the correct messages.
    final messages = ref.read(messagesProvider(widget.contact.id)).maybeWhen(
          data: (List<Chat> m) => m.where(_hasRenderableContent).toList(),
          orElse: () => <Chat>[],
        );
    if (messages.isEmpty) return;

    // Determine visible indices roughly in the middle of the viewport
    final firstVisibleIndex =
        positions.map((p) => p.index).reduce((a, b) => a < b ? a : b);

    // Load older messages when the user scrolls to the top (index 0 = loader item, index 1 = oldest message).
    if (firstVisibleIndex <= 1 && !_isInitialLoading) {
      _loadOlderMessages();
    }

    // The day the pinned chip should show: whichever message is nearest the
    // top edge without being scrolled past it. Using the topmost *visible*
    // message rather than the first index means the chip changes exactly as a
    // day group crosses the top, the way the inline separator would if it
    // could stay put.
    final onScreen = positions
        .where((p) => p.index >= 1 && p.index <= messages.length)
        .toList();

    if (onScreen.isNotEmpty) {
      final topMost = onScreen.reduce(
        (a, b) => a.itemLeadingEdge <= b.itemLeadingEdge ? a : b,
      );

      final messageIndex = topMost.index - 1;
      final message = messages[messageIndex];
      final label = chatDateLabel(message.createdAt);

      // Suppress the pin while the real separator is still on screen. The
      // pinned chip only stands in for a separator that has scrolled past the
      // top edge; showing both puts two identical chips a few pixels apart.
      final previous =
          messageIndex == 0 ? null : messages[messageIndex - 1].createdAt;
      final separatorStillVisible =
          isNewDay(previous, message.createdAt) && topMost.itemLeadingEdge >= 0;

      final next = separatorStillVisible ? null : label;

      if (next != _stickyDateLabel && mounted) {
        setState(() => _stickyDateLabel = next);
      }
    }

    /*
     * Read state and "am I at the bottom" both work off the items' real edges
     * rather than their indices. itemLeadingEdge/itemTrailingEdge are fractions
     * of the viewport - 0 is its top, 1 its bottom - so a message only counts
     * as seen once its top has actually come into view, not merely because it
     * appears in the reported position list while peeking in at the edge.
     */
    bool isMeaningfullyVisible(ItemPosition p) => p.itemLeadingEdge < 0.85;

    // Mark seen *inbound* messages as read. Outbound messages live with
    // is_read=false until the recipient reads them; including them here would
    // fire spurious read receipts and decrement our own unread count.
    // Index 0 is the top loader, so message i sits at index i + 1.
    final seen = <Chat>[];

    for (final position in positions) {
      if (position.index == 0 || !isMeaningfullyVisible(position)) continue;

      final messageIndex = position.index - 1;

      if (messageIndex < 0 || messageIndex >= messages.length) continue;

      final msg = messages[messageIndex];

      if (msg.type == 'inbound' && !msg.isRead) {
        seen.add(msg);
      }
    }

    if (seen.isNotEmpty) {
      _markMessagesAsRead(seen);
    }

    /*
     * At the bottom means the newest message is fully on screen. The old test
     * allowed three items of slack, so a message landing one or two rows below
     * the fold still counted as "at the bottom": the jump-to-bottom button
     * never appeared and the counter never moved - exactly the case of an agent
     * sitting on the newest message when another one arrives.
     */
    final lastItemIndex = messages.length;
    ItemPosition? lastPosition;

    for (final position in positions) {
      if (position.index == lastItemIndex) {
        lastPosition = position;
        break;
      }
    }

    final isAtBottom =
        lastPosition != null && lastPosition.itemTrailingEdge <= 1.02;

    _isAtBottom = isAtBottom;

    if (!isAtBottom && !_showScrollToBottom) {
      setState(() => _showScrollToBottom = true);
    } else if (isAtBottom && (_showScrollToBottom || _pendingNewMessages > 0)) {
      // The newest message is fully visible, so it has been seen.
      setState(() {
        _showScrollToBottom = false;
        _pendingNewMessages = 0;
      });
    }
  }

  /// Queue messages the reader has now seen.
  ///
  /// Marking happens in two speeds on purpose. Locally it is immediate, so the
  /// unread markers clear under the reader's thumb as they scroll. The write
  /// itself is batched: this used to fire a request on every scroll tick that
  /// revealed an unread message, which on a thread with dozens of them meant a
  /// burst of calls over mobile data.
  void _markMessagesAsRead(List<Chat> msgs) {
    // Only the ones this screen has not already handled - the positions
    // listener fires on every scroll frame and would otherwise re-write the
    // same rows over and over.
    final fresh = msgs.where((m) => _seenMessageIds.add(m.id)).toList();

    if (fresh.isEmpty) return;

    /*
     * Written straight through, so unread markers clear under the reader's
     * thumb as they scroll. The repository already holds the network side back
     * and sends these in batches, so being immediate here costs nothing extra
     * on the wire.
     */
    ref.read(chatRepositoryProvider).markMessagesAsRead(
          fresh.map((msg) => msg.copyWith(isRead: true)).toList(),
        );

    ref.read(mainDataProvider.notifier).decreaseUnreadCount(
          widget.contact.id,
          fresh.length,
        );
  }

  /// Close out the conversation as the reader leaves.
  ///
  /// Deliberately does not touch `ref`: this runs from dispose(), by which time
  /// the widget's ref is no longer usable, so it works off the references
  /// captured in initState.
  void _markWholeConversationRead() {
    final contactId = widget.contact.id;
    final chatRepo = _chatRepoForDispose;
    final listNotifier = _listNotifierForDispose;

    Future(() async {
      try {
        await chatRepo.markConversationRead(contactId);
        listNotifier.updateContactUnreadCount(contactId, 0);
      } catch (e) {
        // Nothing to show the user - they have already left the screen.
        print('Could not finish marking the conversation read: $e');
      }
    });
  }

  void _scrollToBottom() {
    final messages = ref.read(messagesProvider(widget.contact.id)).maybeWhen(
          data: (messages) => messages.where(_hasRenderableContent).toList(),
          orElse: () => <Chat>[],
        );
    if (messages.isNotEmpty && _itemScrollController.isAttached) {
      /*
       * Aligning the footer sentinel's leading edge to the bottom of the
       * viewport leaves the last real message resting exactly on that edge.
       *
       * Aligning the message itself cannot work: alignment 0 put its leading
       * edge at the top, so the list slid there and settled back - a visible
       * jump - while alignment 1 pushed the message itself off the bottom.
       *
       * jumpTo rather than scrollTo: animated scrolling here uses spring
       * physics that overshoot and bounce.
       */
      _itemScrollController.jumpTo(
        index: messages.length + 1,
        alignment: 1.0,
      );
    }
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
    // Unsupported message types (WhatsApp error 131051, stickers, polls, etc.)
    // should still render as a placeholder so the chat thread isn't blank.
    if (type == 'unsupported') return true;
    if (meta['errors'] is List && (meta['errors'] as List).isNotEmpty)
      return true;
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
  /// Buckets events by the index of the message they follow.
  ///
  /// Key -1 holds everything older than the first message, so a call or an
  /// assignment on a conversation whose messages have not loaded yet still
  /// appears rather than being dropped. Both lists arrive oldest-first, so this
  /// is a single walk rather than a search per event.
  Map<int, List<TimelineEvent>> _groupEventsByAnchor(
    List<Chat> messages,
    List<TimelineEvent> events,
  ) {
    if (events.isEmpty) return const {};

    final grouped = <int, List<TimelineEvent>>{};
    var messageIndex = 0;

    for (final event in events) {
      // Advance past every message older than this event.
      while (messageIndex < messages.length &&
          !messages[messageIndex].createdAt.isAfter(event.createdAt)) {
        messageIndex++;
      }

      grouped.putIfAbsent(messageIndex - 1, () => []).add(event);
    }

    return grouped;
  }

  int _initialIndex(List<Chat> messages) {
    if (messages.isEmpty) return 0;
    final firstUnread =
        messages.indexWhere((m) => m.type == 'inbound' && !m.isRead);
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
        final visible = all.where(_hasRenderableContent).toList();
        final newestId = visible.isEmpty ? null : visible.last.id;

        /*
         * The first batch of messages needs no scrolling at all: the list mounts
         * directly at its initialScrollIndex. Treating that first arrival as
         * "the conversation grew" is what made the thread visibly fly to the
         * bottom and settle back every time it was opened - _isAtBottom starts
         * true and _lastRenderedCount starts at zero, so any first emission
         * looked like growth while pinned to the bottom.
         */
        if (!_initialPositionApplied) {
          _initialPositionApplied = true;
          _newestMessageId = newestId;

          return;
        }

        // Only something arriving at the end should pull the view down. Older
        // history paged in at the top grows the list too, and used to yank the
        // reader away from what they were reading.
        final appended = newestId != null && newestId != _newestMessageId;

        _newestMessageId = newestId;

        if (!appended) return;

        /*
         * An arriving message is never allowed to move the viewport. Someone
         * reading back through the history must stay exactly where they are,
         * which is what WhatsApp does: the message is appended quietly and the
         * jump-to-bottom button carries a count until the reader goes to it.
         *
         * The one exception is a message we sent ourselves - the composer just
         * cleared, so the sender expects to see it land.
         */
        final newest = visible.last;

        if (newest.type == 'outbound') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _scrollToBottom();
          });

          return;
        }

        /*
         * Counted unconditionally, not gated on _isAtBottom. That flag still
         * describes the layout from *before* this message existed, and a
         * message arriving while the reader sits at the bottom lands below the
         * fold - so the first one was never counted and only the second showed
         * up as "1".
         *
         * The positions listener resets this to zero the moment the newest
         * message is genuinely fully visible, so a message that does land in
         * view corrects itself on the next frame rather than needing to be
         * predicted here.
         */
        setState(() => _pendingNewMessages += 1);
      });
    });

    return Scaffold(
      backgroundColor: PiColors.of(context).background,
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
            _buildChatAppBar(context),
            ConversationStatusBar(contact: widget.contact),
            Divider(
                height: 1, thickness: 1, color: PiColors.of(context).divider),
            // Messages list (expanded to fill available space)
            Expanded(
              child: messagesAsync.when(
                data: (allMessages) {
                  // Drop empty bubbles: no text, no caption, no media, no header,
                  // no buttons. These can come from system events or partial
                  // template payloads and just render as a blank box.
                  final messages =
                      allMessages.where(_hasRenderableContent).toList();

                  // Calls, ticket changes and notes. Anchored to the message
                  // each one follows rather than given list slots of their own,
                  // so scroll positioning stays indexed on messages.
                  final events = ref
                      .watch(timelineEventsProvider(widget.contact.id))
                      .maybeWhen(
                        data: (rows) => rows,
                        orElse: () => const <TimelineEvent>[],
                      );
                  final eventsByAnchor = _groupEventsByAnchor(messages, events);

                  // Show a spinner while the first API fetch is in flight.
                  // Drift immediately emits [] from an empty table, so the
                  // provider reaches data([]) before any messages are loaded —
                  // without this guard the user sees a white screen instead of
                  // a loading indicator.
                  if (_isInitialLoading && messages.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  // Drift already has messages — initial load is done.
                  // Use a postFrameCallback to avoid calling setState during build.
                  if (_isInitialLoading && messages.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _isInitialLoading = false);
                    });
                  }

                  // All messages were filtered out (e.g. unsupported type, system
                  // events). Show a placeholder rather than a blank white screen.
                  if (messages.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(LucideIcons.messageCircle,
                              size: 48, color: PiColors.of(context).ink400),
                          const SizedBox(height: 12),
                          Text(
                            'No messages yet',
                            style: TextStyle(
                                color: PiColors.of(context).textSecondary,
                                fontSize: 15),
                          ),
                        ],
                      ),
                    );
                  }

                  final reactionsByWamId = _collectReactions(allMessages);

                  /*
                 * Decide where the thread opens exactly once, from the first
                 * real batch of messages, and remember it. Recomputing this on
                 * every rebuild meant the target moved as messages streamed in.
                 *
                 * The list renders straight at this index, so there is no
                 * scroll to watch - the reader lands on their first unread
                 * message, or at the newest one when everything is read.
                 */
                  if (_initialScrollTarget == null) {
                    _initialScrollTarget = _initialIndex(messages);

                    // Opening part-way up the thread means we are not pinned to
                    // the bottom, so later arrivals must not drag the view down.
                    _isAtBottom = _initialScrollTarget == messages.length - 1;
                  }

                  final startIndex =
                      _initialScrollTarget!.clamp(0, messages.length - 1);
                  final isAtBottom = startIndex == messages.length - 1;

                  return Stack(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: RefreshIndicator(
                          onRefresh: _fetchNewMessages,
                          child: ScrollablePositionedList.builder(
                            // index 0 is the top loader; index messages.length + 1
                            // is a footer sentinel used purely as a scroll target.
                            itemCount: messages.length + 2,
                            // +1 for the loader at index 0. When opening on an
                            // unread message, leave it just below the top edge so
                            // the messages above it read as already-seen context.
                            initialScrollIndex: startIndex + 1,
                            initialAlignment: isAtBottom ? 0.0 : 0.12,
                            physics: const ClampingScrollPhysics(),
                            itemBuilder: (context, index) {
                              /*
                               * A sentinel below the last message. Aligning to
                               * it is what lets the jump-to-bottom land with the
                               * last message fully on screen: alignment
                               * positions an item's *leading* edge, so no
                               * alignment of the message itself can rest its
                               * bottom on the viewport bottom - putting the
                               * footer's leading edge there does exactly that.
                               */
                              if (index == messages.length + 1) {
                                return const SizedBox(height: 2);
                              }

                              // Index 0 is the top loader.
                              if (index == 0) {
                                return _isLoadingOlder
                                    ? const Padding(
                                        padding:
                                            EdgeInsets.symmetric(vertical: 16),
                                        child: Center(
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2)),
                                      )
                                    : const SizedBox.shrink();
                              }
                              final messageIndex = index - 1;
                              final msg = messages[messageIndex];
                              final isUnread =
                                  msg.type == 'inbound' && !msg.isRead;
                              final reactions = msg.wamId != null
                                  ? reactionsByWamId[msg.wamId!]
                                  : null;

                              final bubble = ChatMessageItem(
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

                              // -1 carries anything that happened before the
                              // first message, so an assignment or a call on a
                              // brand-new conversation is not swallowed.
                              final leading = messageIndex == 0
                                  ? (eventsByAnchor[-1] ?? const [])
                                  : const <TimelineEvent>[];
                              final trailing =
                                  eventsByAnchor[messageIndex] ?? const [];

                              // Day separator above the first message of each
                              // day. The pinned chip at the top of the list
                              // shows the same label for whichever day is
                              // currently under it.
                              final previous = messageIndex == 0
                                  ? null
                                  : messages[messageIndex - 1].createdAt;
                              final startsDay =
                                  isNewDay(previous, msg.createdAt);

                              if (leading.isEmpty &&
                                  trailing.isEmpty &&
                                  !startsDay) {
                                return bubble;
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  if (startsDay)
                                    ChatDateSeparator(
                                      label: chatDateLabel(msg.createdAt),
                                    ),
                                  for (final e in leading)
                                    TimelineEventItem(event: e),
                                  bubble,
                                  for (final e in trailing)
                                    TimelineEventItem(event: e),
                                ],
                              );
                            },
                            itemScrollController: _itemScrollController,
                            itemPositionsListener: _itemPositionsListener,
                          ),
                        ),
                      ),
                      // Pinned day chip. Sits above the list so the day group
                      // currently under the top edge stays named even after its
                      // inline separator has scrolled away — the separator and
                      // this chip are the same widget, so the handover is
                      // invisible.
                      if (_stickyDateLabel != null)
                        Positioned(
                          top: 6,
                          left: 0,
                          right: 0,
                          child: IgnorePointer(
                            child: Center(
                              child: ChatDateChip(
                                label: _stickyDateLabel!,
                                elevated: true,
                              ),
                            ),
                          ),
                        ),
                      if (_showScrollToBottom || _pendingNewMessages > 0)
                        Positioned(
                          bottom: 20,
                          right: 20,
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              GestureDetector(
                                onTap: () {
                                  setState(() => _pendingNewMessages = 0);
                                  _scrollToBottom();
                                },
                                child: Container(
                                  width: 40,
                                  height: 40,
                                  decoration: const BoxDecoration(
                                    color: PiPalette.primary500,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(LucideIcons.chevronDown,
                                      size: 22, color: PiPalette.white),
                                ),
                              ),
                              // How many arrived while the reader was away
                              // from the bottom. Previously this counted every
                              // unread message in the conversation, so opening
                              // a thread with sixty unread showed "60" and the
                              // number never meant anything useful.
                              Builder(
                                builder: (context) {
                                  final unreadCount = _pendingNewMessages;
                                  if (unreadCount == 0) {
                                    return const SizedBox.shrink();
                                  }
                                  return Positioned(
                                    right: -4,
                                    top: -4,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: PiPalette.ink900,
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
                                            color: PiPalette.white,
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
                error: (e, s) => Center(
                    child: Text('chat.error.loading_messages'
                        .tr(namedArgs: {'error': e.toString()}))),
              ),
            ),

            // Message input field at bottom
            _buildMessageInput(),
          ],
        ),
      ),
    );
  }

  Widget _buildChatAppBar(BuildContext context) {
    final colors = PiColors.of(context);
    /*
     * The colour is painted outside the SafeArea so it continues behind the
     * status bar. Previously the inset showed the scaffold background while the
     * bar below it was surfaceRaised, leaving a visible seam along the top edge.
     */
    return Container(
      color: colors.surfaceRaised,
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: [
              // Back button
              GestureDetector(
                onTap: () {
                  if (context.canPop()) {
                    context.pop();
                  } else {
                    context.go('/home/chats');
                  }
                },
                behavior: HitTestBehavior.opaque,
                child: const SizedBox(
                  width: 48,
                  height: 56,
                  child: Center(
                    child: Icon(LucideIcons.arrowLeft, size: 22),
                  ),
                ),
              ),
              // Avatar + name (tappable → contact details)
              Expanded(
                child: GestureDetector(
                  onTap: _showContactDetails,
                  behavior: HitTestBehavior.opaque,
                  child: Row(
                    children: [
                      _buildHeaderAvatar(),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              widget.contact.fullName ?? widget.contact.phone,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: Sz.sp(context, 15),
                                fontWeight: FontWeight.w600,
                                color: colors.textPrimary,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (widget.contact.fullName != null)
                              Text(
                                widget.contact.phone,
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: Sz.sp(context, 12),
                                  color: colors.textSecondary,
                                  height: 1.2,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Call button
              GestureDetector(
                onTap: () {
                  context.push('/call/outbound', extra: {
                    'uuid': widget.contact.uuid,
                    'name': widget.contact.fullName ?? widget.contact.phone,
                    'phone': widget.contact.phone,
                  });
                },
                behavior: HitTestBehavior.opaque,
                child: SizedBox(
                  width: 44,
                  height: 56,
                  child: Center(
                    child: Icon(LucideIcons.phone,
                        size: 20, color: colors.textPrimary),
                  ),
                ),
              ),
              // Overflow menu
              PopupMenuButton<String>(
                icon: Icon(LucideIcons.ellipsisVertical,
                    size: 20, color: colors.textPrimary),
                onSelected: (value) {
                  if (value == 'media') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => MediaGalleryScreen(
                          contactUuid: widget.contact.uuid,
                          contactName:
                              widget.contact.fullName ?? widget.contact.phone,
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
                      Icon(LucideIcons.user,
                          size: 18, color: PiColors.of(context).textSecondary),
                      const SizedBox(width: 12),
                      Text('chat.menu.contact_details'.tr()),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'media',
                    child: Row(children: [
                      Icon(LucideIcons.image,
                          size: 18, color: PiColors.of(context).textSecondary),
                      const SizedBox(width: 12),
                      Text('chat.tooltip.media_gallery'.tr()),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'template',
                    child: Row(children: [
                      Icon(LucideIcons.fileText,
                          size: 18, color: PiColors.of(context).textSecondary),
                      const SizedBox(width: 12),
                      Text('chat.menu.send_template'.tr()),
                    ]),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'assign',
                    child: Row(children: [
                      Icon(LucideIcons.userPlus,
                          size: 18, color: PiColors.of(context).textSecondary),
                      const SizedBox(width: 12),
                      Text('chat.menu.assign_to_agent'.tr()),
                    ]),
                  ),
                  PopupMenuItem(
                    value: 'status',
                    child: Row(children: [
                      Icon(LucideIcons.flag,
                          size: 18, color: PiColors.of(context).textSecondary),
                      const SizedBox(width: 12),
                      Text('chat.menu.change_status'.tr()),
                    ]),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'close',
                    child: Row(children: [
                      Icon(LucideIcons.circleCheck,
                          size: 18, color: PiPalette.success500),
                      const SizedBox(width: 12),
                      Text('chat.menu.close_ticket'.tr(),
                          style: TextStyle(color: PiPalette.success500)),
                    ]),
                  ),
                ],
              ),
              const SizedBox(width: 4),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderAvatar() {
    final avatarUrl = widget.contact.avatar;
    return SizedBox(
      width: 36,
      height: 36,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: PiColors.of(context).surface,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child:
                const Icon(LucideIcons.user, size: 18, color: PiPalette.ink400),
          ),
          if (avatarUrl != null)
            ClipOval(
              child: CachedNetworkImage(
                imageUrl: avatarUrl,
                width: 36,
                height: 36,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            ),
        ],
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

  /// Returns true if the contact messaged us within the last 24 hours.
  ///
  /// `widget.contact.lastInboundChatAt` may be stale (e.g. loaded from local DB
  /// which doesn't persist this field). We prefer the live in-memory copy from
  /// `mainDataProvider`, which is updated by ReverbService whenever a new
  /// inbound message arrives.
  bool _isWithin24HourWindow() {
    // Prefer the live contact from the in-memory list.
    final contacts = ref.read(mainDataProvider);
    final liveContact = contacts.firstWhere(
      (c) => c.id == widget.contact.id,
      orElse: () => widget.contact,
    );

    final lastInbound =
        liveContact.lastInboundChatAt ?? widget.contact.lastInboundChatAt;
    if (lastInbound == null) return false;
    return DateTime.now().difference(lastInbound).inHours < 24;
  }

  /// Banner shown when the 24-hour window has expired
  Widget _build24HourExpiredBanner() {
    final colors = PiColors.of(context);

    /*
     * A floating capsule rather than a full-width bar. The old banner sat
     * edge-to-edge where the composer belongs and claimed a large block of the
     * thread; this reads as a temporary state over the conversation, which is
     * what it is.
     */
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          PiSpacing.space12,
          PiSpacing.space8,
          PiSpacing.space12,
          PiSpacing.space12,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: BackdropFilter(
            // Frosted, so the messages behind it stay faintly visible instead
            // of the banner reading as another opaque panel.
            filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                PiSpacing.space12,
                PiSpacing.space8,
                PiSpacing.space8,
                PiSpacing.space8,
              ),
              decoration: BoxDecoration(
                color: colors.surfaceRaised.withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: colors.divider.withValues(alpha: 0.6)),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.10),
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      color: PiPalette.warning500.withValues(alpha: 0.14),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      LucideIcons.clock,
                      color: PiPalette.warning500,
                      size: 14,
                    ),
                  ),
                  const SizedBox(width: PiSpacing.space8),
                  Expanded(
                    child: Text(
                      'chat.banner.24h_expired'.tr(),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: Sz.sp(context, 12.5),
                        height: 1.25,
                        color: colors.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: PiSpacing.space8),
                  GestureDetector(
                    onTap: _showTemplatePicker,
                    behavior: HitTestBehavior.opaque,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: PiSpacing.space12,
                        vertical: 7,
                      ),
                      decoration: BoxDecoration(
                        color: PiPalette.primary500,
                        borderRadius: PiRadius.brFull,
                      ),
                      child: Text(
                        'chat.banner.send_template_button'.tr(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: Sz.sp(context, 12.5),
                          fontWeight: FontWeight.w600,
                          color: PiPalette.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
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
    final supportsOpus =
        await _audioRecorder.isEncoderSupported(AudioEncoder.opus);
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
        try {
          await f.delete();
        } catch (_) {}
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
      try {
        await File(path).delete();
      } catch (_) {}
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
        try {
          await f.delete();
        } catch (_) {}
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
              panelOpen ? LucideIcons.chevronDown : LucideIcons.plus,
              key: ValueKey(panelOpen),
              size: 22,
              color: PiColors.of(context).textSecondary,
            ),
          ),
        ),
        // CENTER: text field with sticker icon inside (right)
        Expanded(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxHeight: 110, minHeight: 38),
            child: Container(
              decoration: BoxDecoration(
                color: PiColors.of(context).background,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: PiColors.of(context).divider,
                  width: 1.5,
                ),
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
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: Sz.sp(context, 14),
                        color: PiColors.of(context).textPrimary,
                      ),
                      decoration: InputDecoration(
                        hintText: 'chat.input.hint'.tr(),
                        hintStyle: GoogleFonts.plusJakartaSans(
                          color: PiColors.of(context).textSecondary,
                          fontSize: Sz.sp(context, 13),
                        ),
                        filled: true,
                        fillColor: Colors.transparent,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
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
                                ? LucideIcons.chevronDown
                                : LucideIcons.smile,
                            key: ValueKey(_showEmojiPanel),
                            size: 20,
                            color: PiColors.of(context).textSecondary,
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
            onTap: () {
              _closePanel();
              _pickImage(ImageSource.camera);
            },
            child: Icon(
              LucideIcons.camera,
              size: 22,
              color: PiColors.of(context).textSecondary,
            ),
          ),
          _IconTapTarget(
            onTap: _startRecording,
            child: Icon(
              LucideIcons.mic,
              size: 22,
              color: PiColors.of(context).textSecondary,
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
              transitionBuilder: (c, a) => ScaleTransition(scale: a, child: c),
              child: Container(
                key: const ValueKey('send'),
                width: 38,
                height: 38,
                decoration: const BoxDecoration(
                  color: PiPalette.primary500,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  LucideIcons.send,
                  color: PiPalette.white,
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
          child: Icon(LucideIcons.trash2,
              size: 22, color: PiColors.of(context).error),
        ),
        // CENTER: pulsing red dot + elapsed timer in a pill
        Expanded(
          child: Container(
            height: 38,
            decoration: BoxDecoration(
              color: PiColors.of(context).surface,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              children: [
                _PulsingRedDot(),
                const SizedBox(width: 10),
                Text(
                  _formatRecDuration(_recordElapsed),
                  style: TextStyle(
                    fontSize: 14,
                    fontFeatures: [FontFeature.tabularFigures()],
                    color: PiColors.of(context).textPrimary,
                  ),
                ),
                const Spacer(),
                Text(
                  'Recording…',
                  style: TextStyle(
                    fontSize: 12,
                    color: PiColors.of(context).textSecondary,
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
              color: PiPalette.primary500,
              shape: BoxShape.circle,
            ),
            child: const Icon(LucideIcons.square,
                color: PiPalette.white, size: 18),
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
          child: Icon(LucideIcons.trash2,
              size: 22, color: PiColors.of(context).error),
        ),
        // CENTER: play/pause + position text inside the same pill as input
        Expanded(
          child: Container(
            height: 38,
            decoration: BoxDecoration(
              color: PiColors.of(context).surface,
              borderRadius: BorderRadius.circular(20),
            ),
            padding: const EdgeInsets.only(left: 4, right: 14),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _togglePreviewPlayback,
                  behavior: HitTestBehavior.opaque,
                  child: SizedBox(
                    width: 32,
                    height: 32,
                    child: Center(
                      child: Icon(
                        _previewIsPlaying
                            ? LucideIcons.circlePause
                            : LucideIcons.circlePlay,
                        size: 24,
                        color: PiPalette.primary500,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(LucideIcons.mic,
                    size: 14, color: PiColors.of(context).textSecondary),
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
                        style: TextStyle(
                          fontSize: 12,
                          fontFeatures: [FontFeature.tabularFigures()],
                          color: PiColors.of(context).textPrimary,
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
              color: PiPalette.primary500,
              shape: BoxShape.circle,
            ),
            child:
                const Icon(LucideIcons.send, color: PiPalette.white, size: 18),
          ),
        ),
      ],
    );
  }

  /// Build the message input widget — WhatsApp style
  Widget _buildMessageInput() {
    // Watch mainDataProvider so this rebuilds when contacts refresh from API
    // (which populates lastInboundChatAt that isn't stored in the local DB).
    ref.watch(mainDataProvider.select(
      (contacts) => contacts
          .firstWhere((c) => c.id == widget.contact.id,
              orElse: () => widget.contact)
          .lastInboundChatAt,
    ));

    if (!_isWithin24HourWindow()) {
      return _build24HourExpiredBanner();
    }

    final size = MediaQuery.sizeOf(context);
    final panelOpen = _showAttachmentPanel || _showEmojiPanel;

    return Container(
      decoration: BoxDecoration(
        color: PiColors.of(context).surfaceRaised,
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, -1)),
        ],
      ),
      child: SafeArea(
        top: false,
        bottom: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Input row ──
            Padding(
              padding: EdgeInsets.only(
                left: 8,
                right: 8,
                top: 6,
                bottom: panelOpen
                    ? 6
                    : 6 + MediaQuery.viewPaddingOf(context).bottom,
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
      (
        LucideIcons.image,
        'chat.attachment.gallery'.tr(),
        const Color(0xFF1A73E8),
        () {
          _closePanel();
          _pickImage(ImageSource.gallery);
        }
      ),
      (
        LucideIcons.camera,
        'chat.attachment.camera'.tr(),
        const Color(0xFF202124),
        () {
          _closePanel();
          _pickImage(ImageSource.camera);
        }
      ),
      (
        LucideIcons.mapPin,
        'Location',
        const Color(0xFF34A853),
        () {
          _closePanel();
          _shareLocation();
        }
      ),
      (
        LucideIcons.user,
        'Contact',
        const Color(0xFF9AA0A6),
        () {
          _closePanel();
          _shareContact();
        }
      ),
      (
        LucideIcons.fileText,
        'chat.attachment.document'.tr(),
        const Color(0xFF1A73E8),
        () {
          _closePanel();
          _pickDocument();
        }
      ),
      (
        LucideIcons.zap,
        'Quick Reply',
        const Color(0xFFF9AB00),
        () {
          _closePanel();
          _showQuickReplyPicker();
        }
      ),
    ];

    final circleSize = size.width * 0.155;
    final iconSize = size.width * 0.065;

    return Container(
      width: double.infinity,
      color: PiColors.of(context).surface,
      padding: EdgeInsets.fromLTRB(
        size.width * 0.04,
        12,
        size.width * 0.04,
        12 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: GridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: 4,
        mainAxisSpacing: size.width * 0.04,
        crossAxisSpacing: size.width * 0.02,
        childAspectRatio: 1.0,
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
                    color: PiColors.of(context).surfaceRaised,
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
                    color: PiColors.of(context).textSecondary,
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
      '😀',
      '😃',
      '😄',
      '😁',
      '😆',
      '😅',
      '🤣',
      '😂',
      '🙂',
      '🙃',
      '😉',
      '😊',
      '😇',
      '🥰',
      '😍',
      '🤩',
      '😘',
      '😗',
      '😚',
      '😙',
      '😋',
      '😛',
      '😜',
      '🤪',
      '😝',
      '🤑',
      '🤗',
      '🤭',
      '🤔',
      '😐',
      '😑',
      '😶',
      '😏',
      '😒',
      '🙄',
      '😬',
      '😔',
      '😪',
      '😴',
      '😷',
      '🤒',
      '🤕',
      '🤢',
      '🤮',
      '🥵',
      '🥶',
      '😵',
      '🤯',
      '🥳',
      '😎',
      '🤓',
      '😕',
      '😟',
      '🙁',
      '☹️',
      '😮',
      '😲',
      '😳',
      '🥺',
      '😦',
      '😧',
      '😨',
      '😢',
      '😭',
      '😱',
      '😖',
      '😣',
      '😞',
      '😩',
      '😫',
      '😤',
      '😡',
      '😠',
      '🤬',
      '😈',
      '👿',
      '💀',
      '💩',
      '🤡',
      '👻',
      '❤️',
      '🧡',
      '💛',
      '💚',
      '💙',
      '💜',
      '🖤',
      '🤍',
      '💔',
      '❣️',
      '💕',
      '💞',
      '💓',
      '💗',
      '💖',
      '💘',
      '👋',
      '✋',
      '👌',
      '✌️',
      '🤞',
      '👍',
      '👎',
      '✊',
      '👏',
      '🙌',
      '🙏',
      '🤝',
      '💪',
      '🦾',
      '🖐️',
      '☝️',
      '🎉',
      '🎊',
      '🎈',
      '🎁',
      '🏆',
      '🥇',
      '⭐',
      '🌟',
      '✨',
      '🔥',
      '💥',
      '❄️',
      '🌈',
      '☀️',
      '🌙',
      '⚡',
    ];

    return Container(
      height: size.height * 0.28 + MediaQuery.viewPaddingOf(context).bottom,
      color: PiColors.of(context).surfaceRaised,
      child: GridView.builder(
        padding: EdgeInsets.fromLTRB(
            size.width * 0.02,
            size.width * 0.02,
            size.width * 0.02,
            size.width * 0.02 + MediaQuery.viewPaddingOf(context).bottom),
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
              selection:
                  TextSelection.collapsed(offset: start + emojis[i].length),
            );
          },
          child: Center(
            child:
                Text(emojis[i], style: TextStyle(fontSize: size.width * 0.062)),
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
          SnackBar(
              content: Text('chat.snackbar.error_picking_image'
                  .tr(namedArgs: {'error': e.toString()})),
              backgroundColor: PiPalette.error500),
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
          SnackBar(
              content: Text('chat.snackbar.error_picking_file'
                  .tr(namedArgs: {'error': e.toString()})),
              backgroundColor: PiPalette.error500),
        );
      }
    }
  }

  /// Send a media file with optional caption — optimistic insert handles UX
  Future<void> _sendMediaFile(File file,
      {String? caption, bool isVoice = false}) async {
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
        'formatted_name':
            formattedName.isEmpty ? picked.phones.first.phone : formattedName,
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
    final button = GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: SizedBox(
        width: 44,
        height: 44,
        child: Center(child: child),
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
          color: PiPalette.error500,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
