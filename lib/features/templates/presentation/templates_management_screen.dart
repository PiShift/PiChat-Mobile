import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pichat/core/utils/text_direction.dart';
import 'package:pichat/core/theme/app_sizing.dart';
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
                return _EmptyState(
                  icon: LucideIcons.fileText,
                  title: 'templates.empty.no_templates'.tr(),
                  // Templates are authored and approved on Meta's side, so an
                  // agent finding none here has nothing to fix in the app.
                  detail: 'Approved templates from your WhatsApp Business '
                      'account appear here.',
                );
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

/// One template in the management list.
///
/// Rebuilt as a card because the previous row was a 3px colour bar next to raw
/// `TextStyle` sized in fractions of the screen — so it neither matched the
/// app's typography nor held together at different text scales. The variables a
/// template needs are surfaced here too: whether a template is usable at a
/// glance depends on what it will ask you to fill in.
class _TemplateListItem extends StatelessWidget {
  final Template template;
  const _TemplateListItem({required this.template});

  @override
  Widget build(BuildContext context) {
    final colors = PiColors.of(context);
    final categoryColor = _categoryColor(template.category);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  template.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: Sz.sp(context, 15),
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              _Pill(
                label: template.status.toUpperCase(),
                color: _statusColor(template.status),
              ),
            ],
          ),
          if (template.preview.trim().isNotEmpty) ...[
            const SizedBox(height: 7),
            // The preview carries the customer's language, so it is laid out in
            // that language's direction rather than the app's.
            Directionality(
              textDirection: directionOf(template.preview),
              child: Text(
                template.preview,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: Sz.sp(context, 13),
                  height: 1.4,
                  color: colors.textSecondary,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              _Pill(label: template.category.toUpperCase(), color: categoryColor),
              const SizedBox(width: 6),
              _Pill(label: template.language.toUpperCase(), color: colors.textSecondary),
              const Spacer(),
              if (template.variables.isNotEmpty)
                Row(
                  children: [
                    Icon(LucideIcons.pencil, size: 11, color: colors.textSecondary),
                    const SizedBox(width: 4),
                    Text(
                      template.variables.length == 1
                          ? '1 field'
                          : '${template.variables.length} fields',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: Sz.sp(context, 11),
                        color: colors.textSecondary,
                      ),
                    ),
                  ],
                ),
            ],
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

/// Small tinted label used for status, category and language.
class _Pill extends StatelessWidget {
  const _Pill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: GoogleFonts.plusJakartaSans(
          fontSize: Sz.sp(context, 10),
          fontWeight: FontWeight.w700,
          color: color,
          height: 1.2,
        ),
      ),
    );
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
                    return _EmptyState(
                      icon: LucideIcons.zap,
                      title: 'quick_replies.empty.no_replies'.tr(),
                      detail: 'Save the answers you send most often, then type '
                          '/ in any chat to drop one in.',
                    );
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

/// One canned reply.
///
/// The shortcut leads, because that is what an agent types: `/hello` in the
/// composer is the fast path, and the list should teach that shape rather than
/// bury it. Destructive and edit actions sit at the end, sized as real touch
/// targets — they were previously zero-padding icons a few pixels across.
class _CannedReplyItem extends StatelessWidget {
  final CannedReplyData reply;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CannedReplyItem({
    required this.reply,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final colors = PiColors.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.divider),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: PiPalette.primary500.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    '/${reply.shortcut}',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: Sz.sp(context, 12),
                      fontWeight: FontWeight.w700,
                      color: PiPalette.primary500,
                      height: 1.2,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                // Canned replies are written in the customer's language, so
                // Arabic content lays out right-to-left here as it will in the
                // conversation.
                Directionality(
                  textDirection: directionOf(reply.content),
                  child: Text(
                    reply.content,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: Sz.sp(context, 13.5),
                      height: 1.4,
                      color: colors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit',
            icon: Icon(LucideIcons.pencil, size: 17, color: colors.textSecondary),
            onPressed: onEdit,
          ),
          IconButton(
            tooltip: 'Delete',
            icon: Icon(LucideIcons.trash2, size: 17, color: PiPalette.error500),
            onPressed: onDelete,
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

/// Shown when a list has nothing in it.
///
/// A bare line of grey text left an agent unsure whether the screen had failed,
/// was still loading, or genuinely had nothing — so each state says what
/// belongs here and, where there is one, the action that fills it.
class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final colors = PiColors.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: colors.surfaceRaised,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 24, color: colors.textSecondary),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: Sz.sp(context, 15),
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              detail,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: Sz.sp(context, 13),
                height: 1.45,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
