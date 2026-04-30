import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:pichat/core/theme/app_theme.dart';
import 'package:pichat/data/models/contact_model.dart';
import 'package:pichat/features/chat/application/main_controller.dart';
import 'package:pichat/features/chat/widgets/contactItem.dart';

/// Search query provider for filtering contacts
final searchQueryProvider = StateProvider<String>((ref) => '');

/// Active filter provider
final activeFilterProvider = StateProvider<String?>((ref) => null);

/// Filtered contacts provider - combines search + filter
final filteredContactsProvider = Provider<List<Contact>>((ref) {
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

class _ChatListScreenState extends ConsumerState<ChatListScreen> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final contacts = ref.watch(filteredContactsProvider);
    final allContacts = ref.watch(mainDataProvider);
    final activeFilter = ref.watch(activeFilterProvider);
    final isLoading = allContacts.isEmpty;
    final unreadCount = allContacts.fold<int>(0, (sum, c) => sum + c.unreadCount);
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: _buildAppBar(context),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Padding(
            padding: EdgeInsets.fromLTRB(size.width * 0.04, 10, size.width * 0.04, 4),
            child: Text(
              'home.nav.chats'.tr(),
              style: TextStyle(
                fontSize: size.width * 0.052,
                fontWeight: FontWeight.bold,
                color: AppColors.textDark,
              ),
            ),
          ),

          // Search bar
          Padding(
            padding: EdgeInsets.symmetric(horizontal: size.width * 0.04),
            child: SizedBox(
              height: 36,
              child: TextField(
                controller: _searchController,
                onChanged: (v) => ref.read(searchQueryProvider.notifier).state = v,
                style: TextStyle(fontSize: size.width * 0.034),
                decoration: InputDecoration(
                  hintText: 'new_chat.search.hint'.tr(),
                  hintStyle: TextStyle(fontSize: size.width * 0.032, color: Colors.grey[500]),
                  prefixIcon: Icon(Icons.search, size: size.width * 0.043, color: Colors.grey[500]),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            ref.read(searchQueryProvider.notifier).state = '';
                          },
                          child: Icon(Icons.close, size: size.width * 0.038, color: Colors.grey[500]),
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: BorderSide(color: AppColors.primary.withOpacity(0.4), width: 1),
                  ),
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
          ),

          SizedBox(height: size.height * 0.008),

          // Filter chips
          SizedBox(
            height: 30,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: size.width * 0.04),
              children: [
                _FilterChip(label: 'All', value: null, active: activeFilter),
                SizedBox(width: size.width * 0.02),
                _FilterChip(
                  label: unreadCount > 0 ? 'Unread ($unreadCount)' : 'Unread',
                  value: 'unread',
                  active: activeFilter,
                ),
                SizedBox(width: size.width * 0.02),
                _FilterChip(label: 'Open', value: 'open', active: activeFilter),
                SizedBox(width: size.width * 0.02),
                _FilterChip(label: 'Pending', value: 'pending', active: activeFilter),
                SizedBox(width: size.width * 0.02),
                _FilterChip(label: 'Closed', value: 'closed', active: activeFilter),
              ],
            ),
          ),

          SizedBox(height: size.height * 0.006),

          // Contact list
          Expanded(
            child: isLoading
                ? const Center(child: CircularProgressIndicator())
                : contacts.isEmpty
                    ? _buildEmptyState()
                    : RefreshIndicator(
                        onRefresh: () async {
                          await ref.read(mainDataProvider.notifier).refreshContacts();
                        },
                        child: ListView.builder(
                          itemCount: contacts.length,
                          itemBuilder: (context, index) {
                            final contact = contacts[index];
                            return InkWell(
                              onTap: () => context.push('/home/chats/detail', extra: contact),
                              child: ContactItem(contact: contact),
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return AppBar(
      backgroundColor: AppColors.background,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      titleSpacing: 0,
      leading: PopupMenuButton<String>(
        icon: Icon(Icons.more_vert, size: size.width * 0.052, color: AppColors.textDark),
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
                Icon(Icons.done_all, size: size.width * 0.043, color: AppColors.textDark),
                SizedBox(width: size.width * 0.03),
                Text('Mark All as Read', style: TextStyle(fontSize: size.width * 0.034)),
              ],
            ),
          ),
        ],
      ),
      actions: [
        // New chat button
        IconButton(
          icon: Icon(Icons.edit_outlined, size: size.width * 0.052, color: AppColors.textDark),
          tooltip: 'New Chat',
          onPressed: () => context.push('/home/chats/new'),
          padding: EdgeInsets.zero,
        ),
        SizedBox(width: size.width * 0.015),
      ],
    );
  }

  Widget _buildEmptyState() {
    final query = ref.watch(searchQueryProvider);
    final filter = ref.watch(activeFilterProvider);
    if (query.isNotEmpty || filter != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off, size: 38, color: Colors.grey[400]),
            const SizedBox(height: 8),
            Text('No matching chats', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: () {
                _searchController.clear();
                ref.read(searchQueryProvider.notifier).state = '';
                ref.read(activeFilterProvider.notifier).state = null;
              },
              icon: const Icon(Icons.clear_all, size: 15),
              label: const Text('Clear filters', style: TextStyle(fontSize: 13)),
            ),
          ],
        ),
      );
    }
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.chat_bubble_outline, size: 38, color: Colors.grey[400]),
          const SizedBox(height: 8),
          Text('No conversations yet', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
        ],
      ),
    );
  }
}

class _FilterChip extends ConsumerWidget {
  final String label;
  final String? value;
  final String? active;

  const _FilterChip({required this.label, required this.value, required this.active});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isSelected = active == value;
    final size = MediaQuery.sizeOf(context);

    return GestureDetector(
      onTap: () => ref.read(activeFilterProvider.notifier).state = value,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: EdgeInsets.symmetric(horizontal: size.width * 0.028),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.greyBorder,
            width: 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: size.width * 0.029,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? Colors.white : AppColors.textDark,
          ),
        ),
      ),
    );
  }
}
