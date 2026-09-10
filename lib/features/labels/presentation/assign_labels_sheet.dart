import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pichat/core/theme/app_colors.dart';
import 'package:pichat/data/repositories/label_repository.dart';

/// Picks the labels on one conversation.
///
/// Selection is applied in one call when the sheet is confirmed, not per tap:
/// the server replaces the whole set, so a dropped request cannot leave the
/// conversation half-labelled. Creating a label from here is deliberate too —
/// the moment an agent realises they need one is while they are looking at the
/// conversation that needs it, not later in a settings screen.
class AssignLabelsSheet extends ConsumerStatefulWidget {
  const AssignLabelsSheet({
    required this.contactUuid,
    required this.current,
    super.key,
  });

  final String contactUuid;
  final List<Label> current;

  @override
  ConsumerState<AssignLabelsSheet> createState() => _AssignLabelsSheetState();
}

class _AssignLabelsSheetState extends ConsumerState<AssignLabelsSheet> {
  late Set<String> _selected = widget.current.map((l) => l.uuid).toSet();
  final _searchController = TextEditingController();
  String _query = '';
  bool _saving = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;

    setState(() => _saving = true);

    try {
      final labels = await ref
          .read(labelRepositoryProvider)
          .syncForContact(widget.contactUuid, _selected.toList());

      // Counts change when a label gains or loses a conversation.
      ref.invalidate(labelsProvider);

      if (mounted) Navigator.of(context).pop(labels);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save labels: $e')),
        );
      }
    }
  }

  Future<void> _createFromQuery() async {
    final name = _searchController.text.trim();

    if (name.isEmpty) return;

    try {
      final label = await ref.read(labelRepositoryProvider).create(name: name);

      ref.invalidate(labelsProvider);

      if (!mounted) return;

      setState(() {
        _selected.add(label.uuid);
        _searchController.clear();
        _query = '';
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not create label: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = PiColors.of(context);
    final async = ref.watch(labelsProvider);

    return Container(
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 10),
          Container(
            width: 36,
            height: 4,
            decoration: BoxDecoration(
              color: colors.divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              children: [
                Icon(LucideIcons.tag, size: 18, color: PiPalette.primary500),
                const SizedBox(width: 8),
                Text(
                  'Labels',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: colors.textPrimary,
                  ),
                ),
                const Spacer(),
                TextButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 15,
                          height: 15,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(
                          'Done',
                          style: GoogleFonts.plusJakartaSans(
                            fontWeight: FontWeight.w700,
                            color: PiPalette.primary500,
                          ),
                        ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _searchController,
              onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
              style: GoogleFonts.plusJakartaSans(fontSize: 14),
              decoration: InputDecoration(
                hintText: 'Search or create a label…',
                prefixIcon: const Icon(LucideIcons.search, size: 18),
                filled: true,
                fillColor: colors.surfaceRaised,
                contentPadding: const EdgeInsets.symmetric(vertical: 4),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Flexible(
            child: async.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(28),
                child: CircularProgressIndicator(),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: Text('Could not load labels: $e'),
              ),
              data: (labels) {
                final filtered = _query.isEmpty
                    ? labels
                    : labels
                        .where((l) => l.name.toLowerCase().contains(_query))
                        .toList();

                // Offer to create only when the search matches nothing exactly,
                // so an agent cannot quietly make a duplicate.
                final exactExists = labels
                    .any((l) => l.name.toLowerCase() == _query);
                final canCreate = _query.isNotEmpty && !exactExists;

                return ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  children: [
                    if (canCreate)
                      _CreateRow(
                        name: _searchController.text.trim(),
                        onTap: _createFromQuery,
                      ),
                    for (final label in filtered)
                      _LabelRow(
                        label: label,
                        selected: _selected.contains(label.uuid),
                        onTap: () => setState(() {
                          if (!_selected.remove(label.uuid)) {
                            _selected.add(label.uuid);
                          }
                        }),
                      ),
                    if (filtered.isEmpty && !canCreate)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        child: Center(
                          child: Text(
                            'No labels yet. Type a name to create one.',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 13,
                              color: colors.textSecondary,
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _LabelRow extends StatelessWidget {
  const _LabelRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Label label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colors = PiColors.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: label.displayColor,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: colors.textPrimary,
                ),
              ),
            ),
            if (label.contactsCount > 0)
              Padding(
                padding: const EdgeInsets.only(right: 10),
                child: Text(
                  '${label.contactsCount}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12,
                    color: colors.textSecondary,
                  ),
                ),
              ),
            Icon(
              selected ? LucideIcons.squareCheck : LucideIcons.square,
              size: 19,
              color: selected ? PiPalette.primary500 : colors.divider,
            ),
          ],
        ),
      ),
    );
  }
}

class _CreateRow extends StatelessWidget {
  const _CreateRow({required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 4),
        child: Row(
          children: [
            Icon(LucideIcons.plus, size: 17, color: PiPalette.primary500),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Create "$name"',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: PiPalette.primary500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
