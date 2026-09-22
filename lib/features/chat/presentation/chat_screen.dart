import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:pichat/data/db/app_database.dart';
import 'package:pichat/data/db/database_provider.dart';
import 'package:pichat/features/labels/presentation/assign_labels_sheet.dart';
import 'package:pichat/data/repositories/label_repository.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pichat/core/theme/app_colors.dart';
import 'package:pichat/core/theme/app_sizing.dart';
import 'package:pichat/core/theme/app_spacing.dart';
import 'package:pichat/data/models/contact_model.dart';
import 'package:pichat/core/services/notification_service.dart';
import 'package:pichat/features/chat/application/main_controller.dart';
import 'package:pichat/features/home/application/nav_retap.dart';
import 'package:pichat/features/chat/widgets/contactItem.dart';
import 'package:pichat/shared/widgets/pi_badge.dart';
import 'package:pichat/shared/widgets/pi_input.dart';

/// Search query provider for filtering contacts
final searchQueryProvider = StateProvider.autoDispose<String>((ref) => '');

/// Active filter provider
final activeFilterProvider = StateProvider.autoDispose<String?>((ref) => null);

/// Filtered contacts provider - combines search + filter
final filteredContactsProvider = Provider.autoDispose<List<Contact>>((ref) {
  final contacts = ref.watch(mainDataProvider);
  final query = ref.watch(searchQueryProvider).toLowerCase();
  final filter = ref.watch(activeFilterProvider);

  var filtered = contacts;

  // Apply search filter
  if (query.isNotEmpty) {
    filtered = filtered.where((c) {
      final name = (c.fullName ?? '').toLowerCase();
      final phone = c.phone.toLowerCase();
      // Get last message text from lastChat metadata
      String lastMessage = '';
      try {
        final meta = c.lastChat?.metadata;
        if (meta != null && meta['type'] == 'text') {
          lastMessage = (meta['text']?['body'] ?? '').toString().toLowerCase();
        }
      } catch (_) {}
      return name.contains(query) || phone.contains(query) || lastMessage.contains(query);
    }).toList();
  }

  // Apply status filter
  if (filter != null) {
    switch (filter) {
      case 'unread':
        filtered = filtered.where((c) => c.unreadCount > 0).toList();
        break;
      case 'open':
        filtered = filtered.where((c) => c.lastChat?.status == 'open').toList();
        break;
      case 'pending':
        filtered = filtered.where((c) => c.lastChat?.status == 'pending').toList();
        break;
      case 'closed':
        filtered = filtered.where((c) => c.lastChat?.status == 'closed').toList();
        break;
    }
  }

  return filtered;
});

class ChatListScreen extends ConsumerStatefulWidget {
  const ChatListScreen({super.key});

  @override
  ConsumerState<ChatListScreen> createState() => _ChatListScreenState();
}

class _ChatListScreenState extends ConsumerState<ChatListScreen>
    with WidgetsBindingObserver {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Clear stale notifications left from when the app was in the background.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => NotificationService().clearAll(),
    );
  }

  final ScrollController _listScrollController = ScrollController();

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _listScrollController.dispose();
    super.dispose();
  }

  /// Pull in the next page as the agent nears the end of the list. Searching
  /// filters what is already loaded, so paging is paused while a query is
  /// active rather than appending rows the filter would hide.
  void _onListScroll() {
    if (ref.read(searchQueryProvider).isNotEmpty) return;

    final position = _listScrollController.position;

    if (position.pixels >= position.maxScrollExtent - 400) {
      ref.read(mainDataProvider.notifier).loadMoreContacts();
    }
  }

  /// Bring the agent back to the newest conversations.
  void _scrollToTop() {
    if (!_listScrollController.hasClients) return;

    _listScrollController.animateTo(
      0,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-sync contacts + latest messages after returning from background.
      ref.read(mainDataProvider.notifier).refreshContacts();
      // Clear notification center and reset app icon badge.
      NotificationService().clearAll();
    }
  }

  /// Label a conversation straight from the list.
  ///
  /// Writes the result locally on return so the row repaints at once rather
  /// than waiting for the next contacts fetch.
  Future<void> _showLabelPicker(Contact contact) async {
    HapticFeedback.selectionClick();

    final result = await showModalBottomSheet<List<Label>>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AssignLabelsSheet(
        contactUuid: contact.uuid,
        current: contact.labels,
      ),
    );

    if (result == null || !mounted) return;

    await ref
        .read(appDatabaseProvider)
        .setContactLabels(contactId: contact.id, labels: result);

    // The in-memory list holds its own copy of the contact.
    ref.read(mainDataProvider.notifier).applyLabels(contact.id, result);
  }

  @override
  Widget build(BuildContext context) {
    // Tapping the chats icon while already on the chats tab scrolls back to
    // the top, the way the home button does elsewhere.
    ref.listen<NavRetap>(navRetapProvider, (_, retap) {
      if (retap.tab == 0) _scrollToTop();
    });

    final contacts = ref.watch(filteredContactsProvider);
    final allContacts = ref.watch(mainDataProvider);
    final activeFilter = ref.watch(activeFilterProvider);
    final isLoading = allContacts.isEmpty;
    final isRefreshing = ref.watch(contactsRefreshingProvider);
    final listNotifier = ref.read(mainDataProvider.notifier);
    final showLoadMoreFooter = listNotifier.hasMore &&
        ref.watch(searchQueryProvider).isEmpty;
    final unreadCount = allContacts.fold<int>(0, (sum, c) => sum + c.unreadCount);

    return Scaffold(
      backgroundColor: PiColors.of(context).background,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────────
            _buildHeader(context),
            const SizedBox(height: PiSpacing.space8),

            // ── Search ───────────────────────────────────────────────────────
            PiSearchInput(
              controller: _searchController,
              hint: 'new_chat.search.hint'.tr(),
              onChanged: (v) => ref.read(searchQueryProvider.notifier).state = v,
              onClear: () => ref.read(searchQueryProvider.notifier).state = '',
            ),
            const SizedBox(height: PiSpacing.space8),

            // ── Filter chips ─────────────────────────────────────────────────
            _buildFilterRow(context, activeFilter, unreadCount),
            const SizedBox(height: PiSpacing.space8),

            // Says the list is being re-read. It is offline-first, so a warm
            // start shows cached conversations at once and replaces them when
            // the fetch lands — without this an agent cannot tell a stale list
            // from a current one, and may act on rows that are minutes old.
            SizedBox(
              height: 2,
              child: isRefreshing
                  ? LinearProgressIndicator(
                      minHeight: 2,
                      backgroundColor: Colors.transparent,
                      color: PiPalette.primary500,
                    )
                  : null,
            ),

            // ── Contact list ─────────────────────────────────────────────────
            Expanded(
              child: isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: PiPalette.primary500,
                        strokeWidth: 2,
                      ),
                    )
                  : contacts.isEmpty
                      ? _buildEmptyState(context)
                      : RefreshIndicator(
                          color: PiPalette.primary500,
                          onRefresh: () async {
                            await ref.read(mainDataProvider.notifier).refreshContacts();
                          },
                          child: NotificationListener<ScrollNotification>(
                            onNotification: (_) {
                              _onListScroll();

                              return false;
                            },
                            child: ListView.builder(
                              controller: _listScrollController,
                              itemCount: contacts.length + (showLoadMoreFooter ? 1 : 0),
                              itemBuilder: (context, index) {
                                if (index >= contacts.length) {
                                  return const Padding(
                                    padding: EdgeInsets.symmetric(vertical: 20),
                                    child: Center(
                                      child: SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      ),
                                    ),
                                  );
                                }

                                final contact = contacts[index];

                                return GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () => context.push('/home/chats/detail', extra: contact),
                                  // Long-press to label, the gesture WhatsApp
                                  // teaches ("tap and hold on any contact to
                                  // label it"). Labelling is triage done while
                                  // scanning the list — making an agent open
                                  // each conversation first defeats it.
                                  onLongPress: () => _showLabelPicker(contact),
                                  child: ContactItem(contact: contact),
                                );
                              },
                            ),
                          ),
                        ),
            ),
          ],
        ),
      ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        PiSpacing.space16,
        PiSpacing.space12,
        PiSpacing.space4,
        0,
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'home.nav.chats'.tr(),
              style: GoogleFonts.plusJakartaSans(
                fontSize: Sz.sp(context, 20),
                fontWeight: FontWeight.w700,
                color: PiColors.of(context).textPrimary,
                height: 26 / 20,
              ),
            ),
          ),
          // New chat
          _HeaderIconButton(
            icon: LucideIcons.squarePen,
            tooltip: 'New Chat',
            onTap: () => context.push('/home/chats/new'),
          ),
          // More options
          PopupMenuButton<String>(
            tooltip: 'More options',
            offset: const Offset(0, 40),
            onSelected: (value) async {
              if (value == 'mark_all_read') {
                await ref.read(mainDataProvider.notifier).markAllAsRead();
              }
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'mark_all_read',
                child: Row(
                  children: [
                    const Icon(LucideIcons.checkCheck, size: 16, color: PiPalette.ink600),
                    const SizedBox(width: PiSpacing.space8),
                    Text(
                      'Mark All as Read',
                      style: GoogleFonts.plusJakartaSans(fontSize: 14),
                    ),
                  ],
                ),
              ),
            ],
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: Icon(
                LucideIcons.ellipsisVertical,
                size: Sz.sp(context, 22),
                color: PiColors.of(context).textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow(BuildContext context, String? activeFilter, int unreadCount) {
    return SizedBox(
      height: 32,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: PiSpacing.space16),
        children: [
          PiFilterChip(
            label: 'All',
            isActive: activeFilter == null,
            onTap: () => ref.read(activeFilterProvider.notifier).state = null,
          ),
          const SizedBox(width: PiSpacing.space8),
          PiFilterChip(
            label: unreadCount > 0 ? 'Unread ($unreadCount)' : 'Unread',
            isActive: activeFilter == 'unread',
            onTap: () => ref.read(activeFilterProvider.notifier).state = 'unread',
          ),
          const SizedBox(width: PiSpacing.space8),
          PiFilterChip(
            label: 'Open',
            isActive: activeFilter == 'open',
            onTap: () => ref.read(activeFilterProvider.notifier).state = 'open',
          ),
          const SizedBox(width: PiSpacing.space8),
          PiFilterChip(
            label: 'Pending',
            isActive: activeFilter == 'pending',
            onTap: () => ref.read(activeFilterProvider.notifier).state = 'pending',
          ),
          const SizedBox(width: PiSpacing.space8),
          PiFilterChip(
            label: 'Closed',
            isActive: activeFilter == 'closed',
            onTap: () => ref.read(activeFilterProvider.notifier).state = 'closed',
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final query = ref.watch(searchQueryProvider);
    final filter = ref.watch(activeFilterProvider);

    if (query.isNotEmpty || filter != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.search, size: 40, color: PiPalette.ink300),
            const SizedBox(height: PiSpacing.space8),
            Text(
              'No matching chats',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 14,
                color: PiColors.of(context).textSecondary,
              ),
            ),
            const SizedBox(height: PiSpacing.space4),
            GestureDetector(
              onTap: () {
                _searchController.clear();
                ref.read(searchQueryProvider.notifier).state = '';
                ref.read(activeFilterProvider.notifier).state = null;
              },
              child: Text(
                'Clear filters',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: PiPalette.primary500,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(LucideIcons.messageCircle, size: 40, color: PiPalette.ink300),
          const SizedBox(height: PiSpacing.space8),
          Text(
            'No conversations yet',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              color: PiColors.of(context).textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Header icon button ───────────────────────────────────────────────────────

class _HeaderIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  const _HeaderIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(
            icon,
            size: Sz.sp(context, 22),
            color: PiColors.of(context).textPrimary,
          ),
        ),
      ),
    );
  }
}
