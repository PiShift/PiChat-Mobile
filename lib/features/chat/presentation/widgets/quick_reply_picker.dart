import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichat/core/theme/app_theme.dart';
import 'package:pichat/data/repositories/canned_reply_repository.dart';

/// Bottom sheet for selecting a quick reply (canned response)
class QuickReplyPicker extends ConsumerStatefulWidget {
  final Function(CannedReply) onReplySelected;
  final String? initialSearch;

  const QuickReplyPicker({
    super.key,
    required this.onReplySelected,
    this.initialSearch,
  });

  @override
  ConsumerState<QuickReplyPicker> createState() => _QuickReplyPickerState();
}

class _QuickReplyPickerState extends ConsumerState<QuickReplyPicker> {
  late TextEditingController _searchController;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: widget.initialSearch ?? '');
    _searchQuery = widget.initialSearch ?? '';
    // Always load fresh replies when the picker opens so newly created
    // replies (added via the Templates management screen) are visible.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.invalidate(cannedRepliesProvider);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final repliesAsync = _searchQuery.isEmpty
        ? ref.watch(cannedRepliesProvider)
        : ref.watch(filteredCannedRepliesProvider(_searchQuery));

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
          Container(
            margin: const EdgeInsets.symmetric(vertical: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Title and search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.flash_on, color: AppColors.primary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'quick_replies.title'.tr(),
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                // Search field
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'quick_replies.search.hint'.tr(),
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 20),
                            onPressed: () {
                              _searchController.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (value) {
                    setState(() => _searchQuery = value);
                  },
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          const Divider(height: 1),
          
          // Replies list
          Flexible(
            child: repliesAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (error, stack) => Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[300], size: 48),
                    const SizedBox(height: 12),
                    Text(
                      'quick_replies.error.load_failed'.tr(),
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(cannedRepliesProvider),
                      child: Text('common.retry'.tr()),
                    ),
                  ],
                ),
              ),
              data: (replies) {
                if (replies.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.message_outlined, color: Colors.grey[400], size: 48),
                        const SizedBox(height: 12),
                        Text(
                          _searchQuery.isEmpty
                              ? 'quick_replies.empty.no_replies'.tr()
                              : 'quick_replies.empty.no_matches'.tr(),
                          style: TextStyle(color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  );
                }
                
                return ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: replies.length,
                  separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
                  itemBuilder: (context, index) {
                    final reply = replies[index];
                    return _QuickReplyTile(
                      reply: reply,
                      onTap: () {
                        widget.onReplySelected(reply);
                        Navigator.pop(context);
                      },
                    );
                  },
                );
              },
            ),
          ),
          
          // Tip at bottom
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.grey[50],
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.info_outline, size: 14, color: Colors.grey[500]),
                const SizedBox(width: 8),
                Text(
                  'quick_replies.tip'.tr(),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[500],
                  ),
                ),
              ],
            ),
          ),
          
          SizedBox(height: MediaQuery.of(context).padding.bottom),
        ],
      ),
    );
  }
}

class _QuickReplyTile extends StatelessWidget {
  final CannedReply reply;
  final VoidCallback onTap;

  const _QuickReplyTile({
    required this.reply,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
        color: _getTypeColor(reply.type).withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(
          _getTypeIcon(reply.type),
          color: _getTypeColor(reply.type),
          size: 22,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              reply.shortcut,
              style: const TextStyle(fontWeight: FontWeight.w500),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              reply.shortcut,
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.primary,
                fontWeight: FontWeight.bold,
                fontFamily: 'monospace',
              ),
            ),
          ),
        ],
      ),
      subtitle: Text(
        reply.content,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.grey[600],
          fontSize: 13,
        ),
      ),
      trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
    );
  }

  IconData _getTypeIcon(String type) {
    switch (type) {
      case 'image':
        return Icons.image;
      case 'audio':
        return Icons.audiotrack;
      case 'document':
        return Icons.description;
      default:
        return Icons.message;
    }
  }

  Color _getTypeColor(String type) {
    switch (type) {
      case 'image':
        return Colors.purple;
      case 'audio':
        return Colors.orange;
      case 'document':
        return Colors.blue;
      default:
        return AppColors.primary;
    }
  }
}

/// Inline suggestion widget that appears above the text field
class QuickReplySuggestions extends ConsumerWidget {
  final String searchText;
  final Function(CannedReply) onReplySelected;

  const QuickReplySuggestions({
    super.key,
    required this.searchText,
    required this.onReplySelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Only show if text starts with "/"
    if (!searchText.startsWith('/') || searchText.length < 2) {
      return const SizedBox.shrink();
    }

    final repliesAsync = ref.watch(filteredCannedRepliesProvider(searchText));

    return repliesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (replies) {
        if (replies.isEmpty) return const SizedBox.shrink();
        
        // Show max 3 suggestions
        final suggestions = replies.take(3).toList();
        
        return Container(
          margin: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 8,
                offset: const Offset(0, -2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: suggestions.map((reply) => InkWell(
              onTap: () => onReplySelected(reply),
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        reply.shortcut,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                          fontFamily: 'monospace',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        reply.content,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey[700],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            )).toList(),
          ),
        );
      },
    );
  }
}
