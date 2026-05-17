import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichat/core/theme/app_colors.dart';
import 'package:pichat/core/theme/app_theme.dart';
import 'package:pichat/data/repositories/template_repository.dart';

// ──────────────────────────────────────────────
// Canned Reply providers
// ──────────────────────────────────────────────

final cannedRepliesProvider = FutureProvider<List<CannedReplyData>>((ref) async {
  final repo = ref.watch(templateRepositoryProvider);
  return repo.getCannedReplies();
});

// ──────────────────────────────────────────────
// Template Management Screen
// ──────────────────────────────────────────────

class TemplatesManagementScreen extends ConsumerStatefulWidget {
  const TemplatesManagementScreen({super.key});

  @override
  ConsumerState<TemplatesManagementScreen> createState() => _TemplatesManagementScreenState();
}

class _TemplatesManagementScreenState extends ConsumerState<TemplatesManagementScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  int _currentTab = 0;
  final _cannedRepliesTabKey = GlobalKey<_CannedRepliesTabState>();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() => _currentTab = _tabController.index);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);

    return Scaffold(
      backgroundColor: PiColors.of(context).background,
      appBar: AppBar(
        backgroundColor: PiColors.of(context).background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'templates.title'.tr(),
          style: TextStyle(
            fontSize: size.width * 0.045,
            fontWeight: FontWeight.bold,
            color: PiColors.of(context).textPrimary,
          ),
        ),
        actions: [
          if (_currentTab == 1)
            IconButton(
              icon: Icon(Icons.add, size: size.width * 0.055, color: PiColors.of(context).textPrimary),
              onPressed: () => _cannedRepliesTabKey.currentState?.openAddDialog(),
              tooltip: 'New Reply',
            ),
          SizedBox(width: size.width * 0.01),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: PiPalette.primary500,
          unselectedLabelColor: PiColors.of(context).textSecondary,
          indicatorColor: PiPalette.primary500,
          indicatorWeight: 2,
          labelStyle: TextStyle(fontSize: size.width * 0.033, fontWeight: FontWeight.w600),
          tabs: const [
            Tab(text: 'Templates'),
            Tab(text: 'Canned Replies'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const _TemplatesTab(),
          _CannedRepliesTab(key: _cannedRepliesTabKey),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────
// Templates Tab
// ──────────────────────────────────────────────

class _TemplatesTab extends ConsumerStatefulWidget {
  const _TemplatesTab();
  
  @override
  ConsumerState<_TemplatesTab> createState() => _TemplatesTabState();
}

class _TemplatesTabState extends ConsumerState<_TemplatesTab> {
  String _search = '';
  String? _category;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final templatesAsync = ref.watch(templatesProvider);
    final size = MediaQuery.sizeOf(context);

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(size.width * 0.04, 10, size.width * 0.04, 6),
          child: SizedBox(
            height: 36,
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _search = v.toLowerCase()),
              style: TextStyle(fontSize: size.width * 0.034),
              decoration: InputDecoration(
                hintText: 'templates.search.hint'.tr(),
                hintStyle: TextStyle(fontSize: size.width * 0.032, color: PiColors.of(context).textSecondary),
                prefixIcon: Icon(Icons.search, size: size.width * 0.043, color: PiColors.of(context).textSecondary),
                filled: true,
                fillColor: PiColors.of(context).surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                isDense: true,
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),

        // Category filter chips
        SizedBox(
          height: 30,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: size.width * 0.04),
            children: ['All', 'MARKETING', 'UTILITY', 'AUTHENTICATION'].map((cat) {
              final val = cat == 'All' ? null : cat;
              final selected = _category == val;
              return Padding(
                padding: EdgeInsets.only(right: size.width * 0.02),
                child: GestureDetector(
                  onTap: () => setState(() => _category = val),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    padding: EdgeInsets.symmetric(horizontal: size.width * 0.028, vertical: 3),
                    decoration: BoxDecoration(
                      color: selected ? PiPalette.primary500 : PiColors.of(context).surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: selected ? PiPalette.primary500 : PiColors.of(context).divider),
                    ),
                    child: Text(
                      cat == 'All' ? 'templates.category.all'.tr() : cat.toLowerCase().capitalizeFirst(),
                      style: TextStyle(
                        fontSize: size.width * 0.029,
                        color: selected ? PiPalette.white : PiColors.of(context).textPrimary,
                        fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),

        SizedBox(height: size.height * 0.006),

        Expanded(
          child: templatesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('templates.error.load_failed'.tr(), style: TextStyle(color: PiColors.of(context).textSecondary))),
            data: (templates) {
              final filtered = templates.where((t) {
                final matchSearch = _search.isEmpty ||
                    t.name.toLowerCase().contains(_search) ||
                    t.preview.toLowerCase().contains(_search);
                final matchCat = _category == null || t.category.toUpperCase() == _category;
                return matchSearch && matchCat;
              }).toList();

              if (filtered.isEmpty) {
                return Center(child: Text('templates.empty.no_templates'.tr(), style: TextStyle(color: PiColors.of(context).textSecondary, fontSize: 13)));
              }

              return ListView.separated(
                padding: EdgeInsets.symmetric(horizontal: size.width * 0.04, vertical: 6),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final t = filtered[index];
                  return _TemplateListItem(template: t);
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TemplateListItem extends StatelessWidget {
  final Template template;
  const _TemplateListItem({required this.template});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final categoryColor = _categoryColor(template.category);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: size.height * 0.008),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 3,
            height: size.height * 0.07,
            decoration: BoxDecoration(
              color: categoryColor,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(width: size.width * 0.03),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        template.name,
                        style: TextStyle(fontSize: size.width * 0.035, fontWeight: FontWeight.w600, color: PiColors.of(context).textPrimary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: size.width * 0.02, vertical: 2),
                      decoration: BoxDecoration(
                        color: _statusColor(template.status).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        template.status.toUpperCase(),
                        style: TextStyle(fontSize: size.width * 0.025, color: _statusColor(template.status), fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: size.height * 0.003),
                Text(
                  template.preview,
                  style: TextStyle(fontSize: size.width * 0.031, color: PiColors.of(context).textSecondary),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: size.height * 0.003),
                Text(
                  '${template.category} · ${template.language.toUpperCase()}',
                  style: TextStyle(fontSize: size.width * 0.028, color: PiColors.of(context).ink400),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Color _categoryColor(String cat) {
    switch (cat.toUpperCase()) {
      case 'MARKETING': return PiPalette.warning500;
      case 'UTILITY': return PiPalette.info500;
      case 'AUTHENTICATION': return PiPalette.success500;
      default: return PiPalette.ink400;
    }
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved': return PiPalette.success500;
      case 'rejected': return PiPalette.error500;
      case 'pending': return PiPalette.warning500;
      default: return PiPalette.ink400;
    }
  }
}

// ──────────────────────────────────────────────
// Canned Replies Tab
// ──────────────────────────────────────────────

class _CannedRepliesTab extends ConsumerStatefulWidget {
  const _CannedRepliesTab({super.key});

  @override
  ConsumerState<_CannedRepliesTab> createState() => _CannedRepliesTabState();
}

class _CannedRepliesTabState extends ConsumerState<_CannedRepliesTab> {
  String _search = '';
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void openAddDialog() => _showEditDialog(context);

  @override
  Widget build(BuildContext context) {
    final repliesAsync = ref.watch(cannedRepliesProvider);
    final size = MediaQuery.sizeOf(context);

    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(size.width * 0.04, 10, size.width * 0.04, 6),
              child: SizedBox(
                height: 36,
                child: TextField(
                  controller: _searchController,
                  onChanged: (v) => setState(() => _search = v.toLowerCase()),
                  style: TextStyle(fontSize: size.width * 0.034),
                  decoration: InputDecoration(
                    hintText: 'quick_replies.search.hint'.tr(),
                    hintStyle: TextStyle(fontSize: size.width * 0.032, color: PiColors.of(context).textSecondary),
                    prefixIcon: Icon(Icons.search, size: size.width * 0.043, color: PiColors.of(context).textSecondary),
                    filled: true,
                    fillColor: PiColors.of(context).surface,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),

            Expanded(
              child: repliesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.reply_all, size: 36, color: PiColors.of(context).ink400),
                      SizedBox(height: size.height * 0.012),
                      Text('quick_replies.error.load_failed'.tr(), style: TextStyle(color: PiColors.of(context).textSecondary, fontSize: 13)),
                      SizedBox(height: size.height * 0.012),
                      TextButton(onPressed: () => ref.invalidate(cannedRepliesProvider), child: const Text('Retry')),
                    ],
                  ),
                ),
                data: (replies) {
                  final filtered = _search.isEmpty
                      ? replies
                      : replies.where((r) {
                          final q = _search;
                          return r.shortcut.toLowerCase().contains(q) ||
                              r.content.toLowerCase().contains(q);
                        }).toList();

                  if (filtered.isEmpty) {
                    return Center(child: Text('quick_replies.empty.no_replies'.tr(), style: TextStyle(color: PiColors.of(context).textSecondary, fontSize: 13)));
                  }

                  return ListView.separated(
                    padding: EdgeInsets.fromLTRB(size.width * 0.04, 6, size.width * 0.04, size.height * 0.04),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final r = filtered[index];
                      return _CannedReplyItem(
                        reply: r,
                        onEdit: () => _showEditDialog(context, r),
                        onDelete: () => _confirmDelete(context, r),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
  }

  void _showEditDialog(BuildContext context, [CannedReplyData? existing]) {
    final shortcutCtrl = TextEditingController(text: existing?.shortcut ?? '');
    final messageCtrl = TextEditingController(text: existing?.content ?? '');
    final size = MediaQuery.sizeOf(context);
    bool saving = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setInnerState) => AlertDialog(
          title: Text(existing == null ? 'New Canned Reply' : 'Edit Canned Reply', style: TextStyle(fontSize: size.width * 0.04)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: shortcutCtrl,
                decoration: InputDecoration(
                  labelText: 'Shortcut (e.g. hello)',
                  labelStyle: TextStyle(fontSize: size.width * 0.033),
                  prefixText: '/ ',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                style: TextStyle(fontSize: size.width * 0.034),
              ),
              SizedBox(height: size.height * 0.012),
              TextField(
                controller: messageCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: 'Message',
                  labelStyle: TextStyle(fontSize: size.width * 0.033),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                style: TextStyle(fontSize: size.width * 0.034),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: saving ? null : () => Navigator.pop(ctx), child: const Text('Cancel')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: PiPalette.primary500),
              onPressed: saving
                  ? null
                  : () async {
                      final shortcut = shortcutCtrl.text.trim();
                      final message = messageCtrl.text.trim();
                      if (shortcut.isEmpty || message.isEmpty) return;
                      setInnerState(() => saving = true);
                      try {
                        final repo = ref.read(templateRepositoryProvider);
                        if (existing == null) {
                          await repo.storeCannedReply(shortcut: shortcut, content: message);
                        } else {
                          await repo.updateCannedReply(uuid: existing.uuid, shortcut: shortcut, content: message);
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        ref.invalidate(cannedRepliesProvider);
                      } catch (e) {
                        setInnerState(() => saving = false);
                        if (ctx.mounted) {
                          ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: PiPalette.error500));
                        }
                      }
                    },
              child: saving
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: PiPalette.white))
                  : Text(existing == null ? 'Create' : 'Save', style: const TextStyle(color: PiPalette.white)),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context, CannedReplyData reply) {
    final size = MediaQuery.sizeOf(context);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete Canned Reply', style: TextStyle(fontSize: size.width * 0.04)),
        content: Text('Delete "${reply.shortcut}" ?', style: TextStyle(fontSize: size.width * 0.034)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: PiPalette.error500),
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final repo = ref.read(templateRepositoryProvider);
                await repo.deleteCannedReply(reply.uuid);
                ref.invalidate(cannedRepliesProvider);
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: PiPalette.error500));
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: PiPalette.white)),
          ),
        ],
      ),
    );
  }
}

class _CannedReplyItem extends StatelessWidget {
  final CannedReplyData reply;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CannedReplyItem({required this.reply, required this.onEdit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Padding(
      padding: EdgeInsets.symmetric(vertical: size.height * 0.007),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: size.width * 0.025, vertical: 3),
            decoration: BoxDecoration(
              color: PiPalette.primary500.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(
              reply.shortcut,
              style: TextStyle(fontSize: size.width * 0.03, color: PiPalette.primary500, fontWeight: FontWeight.w600),
            ),
          ),
          SizedBox(width: size.width * 0.03),
          Expanded(
            child: Text(
              reply.content,
              style: TextStyle(fontSize: size.width * 0.032, color: PiColors.of(context).textSecondary),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined, size: size.width * 0.043, color: PiColors.of(context).textSecondary),
            onPressed: onEdit,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          SizedBox(width: size.width * 0.02),
          IconButton(
            icon: Icon(Icons.delete_outline, size: size.width * 0.043, color: PiColors.of(context).error),
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
        ],
      ),
    );
  }
}

extension _StringExt on String {
  String capitalizeFirst() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1).toLowerCase()}';
  }
}
