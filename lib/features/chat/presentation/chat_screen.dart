import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pichat/core/theme/app_colors.dart';
import 'package:pichat/core/theme/app_sizing.dart';
import 'package:pichat/core/theme/app_spacing.dart';
import 'package:pichat/data/models/contact_model.dart';
import 'package:pichat/features/chat/application/main_controller.dart';
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
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-sync contacts + latest messages after returning from background
      ref.read(mainDataProvider.notifier).refreshContacts();
    }
  }

  @override
  Widget build(BuildContext context) {
    final contacts = ref.watch(filteredContactsProvider);
    final allContacts = ref.watch(mainDataProvider);
    final activeFilter = ref.watch(activeFilterProvider);
    final isLoading = allContacts.isEmpty;
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
                          child: ListView.builder(
                            itemCount: contacts.length,
                            itemBuilder: (context, index) {
                              final contact = contacts[index];
                              return GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () => context.push('/home/chats/detail', extra: contact),
                                child: ContactItem(contact: contact),
                              );
                            },
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
