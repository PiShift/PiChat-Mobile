import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pichat/core/theme/app_colors.dart';
import 'package:pichat/core/theme/app_sizing.dart';
import 'package:pichat/data/repositories/label_repository.dart';

/// Manage the organization's labels.
///
/// Every agent shares one set, so a change here is a change for the team. That
/// is why deleting asks first and says how many conversations it will affect —
/// removing a label nobody else expected to lose is not recoverable from a
/// phone.
class LabelsScreen extends ConsumerWidget {
  const LabelsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = PiColors.of(context);
    final async = ref.watch(labelsProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(LucideIcons.arrowLeft, size: 22),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Labels',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
        actions: [
          IconButton(
            tooltip: 'New label',
            icon: const Icon(LucideIcons.plus, size: 22),
            onPressed: () => _edit(context, ref, null),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(labelsProvider),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            const SizedBox(height: 100),
            Center(child: Text('Could not load labels: $e')),
          ]),
          data: (labels) {
            if (labels.isEmpty) {
              return ListView(children: [
                const SizedBox(height: 100),
                _Empty(onCreate: () => _edit(context, ref, null)),
              ]);
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: labels.length,
              itemBuilder: (_, i) => _LabelTile(
                label: labels[i],
                onEdit: () => _edit(context, ref, labels[i]),
                onDelete: () => _confirmDelete(context, ref, labels[i]),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _edit(BuildContext context, WidgetRef ref, Label? existing) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _LabelEditor(existing: existing),
    );

    if (saved == true) ref.invalidate(labelsProvider);
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Label label,
  ) async {
    final count = label.contactsCount;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${label.name}"?'),
        // Naming the blast radius: this label belongs to the whole team, and
        // the agent deleting it may not be the one who relies on it.
        content: Text(
          count == 0
              ? 'This label is not used by any conversation.'
              : 'It will be removed from $count conversation'
                  '${count == 1 ? '' : 's'} for every agent.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text('Delete', style: TextStyle(color: PiPalette.error500)),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await ref.read(labelRepositoryProvider).delete(label.uuid);
      ref.invalidate(labelsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not delete: $e')),
        );
      }
    }
  }
}

class _LabelTile extends StatelessWidget {
  const _LabelTile({
    required this.label,
    required this.onEdit,
    required this.onDelete,
  });

  final Label label;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colors = PiColors.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: colors.surfaceRaised,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colors.divider),
      ),
      child: Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: label.displayColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: Sz.sp(context, 14.5),
                    fontWeight: FontWeight.w600,
                    color: colors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  label.contactsCount == 1
                      ? '1 conversation'
                      : '${label.contactsCount} conversations',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: Sz.sp(context, 11.5),
                    color: colors.textSecondary,
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

/// Create or rename a label, and pick its colour.
class _LabelEditor extends ConsumerStatefulWidget {
  const _LabelEditor({this.existing});

  final Label? existing;

  @override
  ConsumerState<_LabelEditor> createState() => _LabelEditorState();
}

class _LabelEditorState extends ConsumerState<_LabelEditor> {
  late final TextEditingController _name =
      TextEditingController(text: widget.existing?.name ?? '');
  late String _color = widget.existing?.color ?? _palette.first;
  bool _saving = false;

  /// A fixed palette rather than a colour wheel: labels are scanned at a
  /// glance in a list, so they need to stay distinguishable from one another —
  /// which free choice quickly ruins.
  static const _palette = <String>[
    '#FF7300',
    '#3B82F6',
    '#22C55E',
    '#F59E0B',
    '#EF4444',
    '#8E5AF7',
    '#00A3A3',
    '#EC4899',
  ];

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();

    if (name.isEmpty || _saving) return;

    setState(() => _saving = true);

    try {
      final repo = ref.read(labelRepositoryProvider);

      if (widget.existing == null) {
        await repo.create(name: name, color: _color);
      } else {
        await repo.update(widget.existing!.uuid, name: name, color: _color);
      }

      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = PiColors.of(context);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        decoration: BoxDecoration(
          color: colors.background,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.existing == null ? 'New label' : 'Edit label',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              style: GoogleFonts.plusJakartaSans(fontSize: 15),
              decoration: InputDecoration(
                labelText: 'Name',
                filled: true,
                fillColor: colors.surfaceRaised,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 18),
            Text(
              'Colour',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final hex in _palette)
                  GestureDetector(
                    onTap: () => setState(() => _color = hex),
                    child: Container(
                      width: 34,
                      height: 34,
                      decoration: BoxDecoration(
                        color: Label(uuid: '', name: '', color: hex).displayColor,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: _color == hex
                              ? colors.textPrimary
                              : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: PiPalette.primary500,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        'Save',
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onCreate});

  final VoidCallback onCreate;

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
              child: Icon(LucideIcons.tag, size: 24, color: colors.textSecondary),
            ),
            const SizedBox(height: 14),
            Text(
              'No labels yet',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Label conversations to find them again — by stage, priority, '
              'or anything your team works by.',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13,
                height: 1.45,
                color: colors.textSecondary,
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(LucideIcons.plus, size: 17),
              label: const Text('Create a label'),
              style: FilledButton.styleFrom(
                backgroundColor: PiPalette.primary500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
