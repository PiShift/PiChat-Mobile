// lib/features/calls/presentation/call_history_screen.dart
//
// Organization-wide call history, grouped the way WhatsApp groups it.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pichat/data/db/app_database.dart';
import 'package:pichat/data/db/database_provider.dart';
import 'package:pichat/data/models/contact_model.dart';
import 'package:pichat/core/theme/app_colors.dart';
import 'package:pichat/core/utils/chat_date.dart';
import 'package:pichat/features/calls/application/call_history_grouping.dart';

import '../data/call_api.dart';
import '../data/call_models.dart';

/// Every call in the organization, newest first.
///
/// Deliberately not filtered to the reading agent: this is a shared inbox, and
/// "who called us and did anyone pick up" is a question about the team, not
/// about one person. Each row names the agent who took it.
final callHistoryProvider =
    FutureProvider.autoDispose<List<CallModel>>((ref) async {
  final api = ref.watch(callApiProvider);

  return api.fetchHistory(page: 1, perPage: 50);
});

class CallHistoryScreen extends ConsumerWidget {
  const CallHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = PiColors.of(context);
    final async = ref.watch(callHistoryProvider);

    return Scaffold(
      backgroundColor: colors.background,
      appBar: AppBar(
        backgroundColor: colors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Calls',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: colors.textPrimary,
          ),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(callHistoryProvider),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            const SizedBox(height: 100),
            Center(child: Text('Could not load calls: $e')),
          ]),
          data: (calls) {
            if (calls.isEmpty) {
              return ListView(children: [
                const SizedBox(height: 120),
                Center(
                  child: Text(
                    'No calls yet.',
                    style: GoogleFonts.plusJakartaSans(
                      color: colors.textSecondary,
                    ),
                  ),
                ),
              ]);
            }

            final groups = groupCalls(calls);

            return ListView.separated(
              itemCount: groups.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, indent: 64, color: colors.divider),
              itemBuilder: (_, i) => _CallGroupTile(group: groups[i]),
            );
          },
        ),
      ),
    );
  }
}

class _CallGroupTile extends ConsumerWidget {
  const _CallGroupTile({required this.group});

  final CallGroup group;

  /// Opens the conversation this call belongs to.
  ///
  /// The chat route takes a Contact rather than an id, so the row resolves it
  /// from the local database. If the contact has not been synced yet there is
  /// nothing sensible to open, so the tap is simply inert.
  Future<void> _openConversation(BuildContext context, WidgetRef ref) async {
    final contactId = group.latest.contactId;

    if (contactId == null) return;

    final db = ref.read(appDatabaseProvider);
    final row = await (db.select(db.contacts)
          ..where((t) => t.id.equals(contactId)))
        .getSingleOrNull();

    if (row == null || !context.mounted) return;

    context.push('/home/chats/detail', extra: Contact.fromDb(row));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = PiColors.of(context);
    final missed = group.kind == CallKind.missed;

    // Missed is the only state that colours the row: it is the only one that
    // needs somebody to act.
    final accent = missed ? PiPalette.error500 : colors.textSecondary;

    final icon = switch (group.kind) {
      CallKind.missed => LucideIcons.phoneMissed,
      CallKind.incoming => LucideIcons.phoneIncoming,
      CallKind.outgoing => LucideIcons.phoneOutgoing,
    };

    final label = switch (group.kind) {
      CallKind.missed => 'Missed',
      CallKind.incoming => 'Incoming',
      CallKind.outgoing => 'Outgoing',
    };

    final latest = group.latest;

    return InkWell(
      // Opening the conversation rather than dialling: the agent almost always
      // wants the context before calling back, and the thread has a call button
      // of its own.
      onTap: latest.contactId == null
          ? null
          : () => _openConversation(context, ref),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 20,
              backgroundColor: colors.surfaceRaised,
              child: Icon(LucideIcons.user, size: 19, color: colors.textSecondary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          group.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: missed ? accent : colors.textPrimary,
                          ),
                        ),
                      ),
                      // The run length, WhatsApp-style: seven attempts read as
                      // one row saying (7) rather than seven identical lines.
                      if (group.count > 1) ...[
                        const SizedBox(width: 5),
                        Text(
                          '(${group.count})',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: missed ? accent : colors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Icon(icon, size: 13, color: accent),
                      const SizedBox(width: 5),
                      Flexible(
                        child: Text(
                          _subtitle(label),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12.5,
                            color: colors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              latest.createdAt == null ? '' : chatDateLabel(latest.createdAt!),
              style: GoogleFonts.plusJakartaSans(
                fontSize: 12,
                color: colors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "Incoming · 3:07 · Bechir" — duration only when the row is a single call,
  /// since a run of attempts has no one duration, and the agent only when
  /// somebody actually took it.
  String _subtitle(String label) {
    final parts = <String>[label];

    final seconds = group.durationSeconds;

    if (seconds != null && seconds > 0) {
      final minutes = seconds ~/ 60;
      final remainder = (seconds % 60).toString().padLeft(2, '0');
      parts.add('$minutes:$remainder');
    }

    final agent = group.latest.agentName;

    if (agent != null && agent.isNotEmpty) parts.add(agent);

    return parts.join('  ·  ');
  }
}
