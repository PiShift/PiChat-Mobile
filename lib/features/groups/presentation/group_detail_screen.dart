import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichat/core/theme/app_colors.dart';
import 'package:pichat/core/theme/app_theme.dart';
import 'package:pichat/data/models/group_model.dart';
import 'package:pichat/data/repositories/group_repository.dart';
import 'package:pichat/features/groups/application/group_providers.dart';

class GroupDetailScreen extends ConsumerStatefulWidget {
  const GroupDetailScreen({super.key, required this.group});
  final WhatsappGroup group;

  @override
  ConsumerState<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends ConsumerState<GroupDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late WhatsappGroup _group;

  @override
  void initState() {
    super.initState();
    _group = widget.group;
    _tabController = TabController(length: _group.needsApproval ? 3 : 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_group.subject, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.textDark)),
            Text(
              '${_group.participantCount} participants',
              style: TextStyle(fontSize: 12, color: PiColors.of(context).textSecondary),
            ),
          ],
        ),
        actions: [
          if (_group.isSuspended)
            Container(
              margin: const EdgeInsets.only(right: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.orange[100], borderRadius: BorderRadius.circular(6)),
              child: const Text('Suspended', style: TextStyle(color: Colors.orange, fontSize: 12)),
            ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: AppColors.textDark),
            onSelected: (value) {
              if (value == 'delete') _confirmDelete(context);
            },
            itemBuilder: (_) => [
              const PopupMenuItem(value: 'delete', child: Text('Delete Group', style: TextStyle(color: Colors.red))),
            ],
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          labelColor: AppColors.primary,
          unselectedLabelColor: PiColors.of(context).textSecondary,
          indicatorColor: AppColors.primary,
          tabs: [
            const Tab(text: 'Participants'),
            const Tab(text: 'Invite Link'),
            if (_group.needsApproval) const Tab(text: 'Requests'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _ParticipantsTab(group: _group, onParticipantRemoved: _onParticipantRemoved),
          _InviteLinkTab(group: _group),
          if (_group.needsApproval) _JoinRequestsTab(group: _group, onChanged: _refreshGroup),
        ],
      ),
    );
  }

  void _onParticipantRemoved(String waId) {
    setState(() {
      final updatedParticipants = _group.participants
          .map((p) => p.waId == waId ? WhatsappGroupParticipant(id: p.id, waId: p.waId, name: p.name, status: 'removed', joinedAt: p.joinedAt) : p)
          .toList();
      _group = _group.copyWith(
        participants: updatedParticipants,
        participantCount: updatedParticipants.where((p) => p.status == 'active').length,
      );
    });
  }

  Future<void> _refreshGroup() async {
    try {
      final updated = await ref.read(groupRepositoryProvider).getGroup(_group.uuid);
      setState(() => _group = updated);
    } catch (_) {}
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Group'),
        content: const Text('This will permanently delete the WhatsApp group. This action cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(groupRepositoryProvider).deleteGroup(_group.uuid);
                ref.invalidate(groupsProvider);
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to delete: $e')));
                }
              }
            },
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Participants Tab
// ---------------------------------------------------------------------------

class _ParticipantsTab extends ConsumerWidget {
  const _ParticipantsTab({required this.group, required this.onParticipantRemoved});
  final WhatsappGroup group;
  final void Function(String waId) onParticipantRemoved;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = group.participants.where((p) => p.status == 'active').toList();
    final others = group.participants.where((p) => p.status != 'active').toList();
    final all = [...active, ...others];

    if (all.isEmpty) {
      return Center(child: Text('No participants yet.', style: TextStyle(color: PiColors.of(context).textSecondary)));
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: all.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        final p = all[index];
        return ListTile(
          leading: CircleAvatar(
            backgroundColor: _statusColor(p.status).withOpacity(0.15),
            child: Text(
              (p.name ?? p.waId).isNotEmpty ? (p.name ?? p.waId)[0].toUpperCase() : '?',
              style: TextStyle(color: _statusColor(p.status), fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(p.name ?? p.waId, style: const TextStyle(fontWeight: FontWeight.w500)),
          subtitle: p.name != null ? Text(p.waId, style: TextStyle(fontSize: 12, color: PiColors.of(context).textSecondary)) : null,
          trailing: p.status == 'active'
              ? TextButton(
                  onPressed: () => _confirmRemove(context, ref, p.waId),
                  child: const Text('Remove', style: TextStyle(color: Colors.red, fontSize: 12)),
                )
              : Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: _statusColor(p.status).withOpacity(0.12),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(p.status, style: TextStyle(fontSize: 10, color: _statusColor(p.status))),
                ),
        );
      },
    );
  }

  Color _statusColor(String status) {
    return switch (status) {
      'active' => Colors.green,
      'pending' => Colors.orange,
      _ => PiPalette.ink400,
    };
  }

  void _confirmRemove(BuildContext context, WidgetRef ref, String waId) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove Participant'),
        content: const Text('Are you sure you want to remove this participant from the group?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              try {
                await ref.read(groupRepositoryProvider).removeParticipant(group.uuid, waId);
                onParticipantRemoved(waId);
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to remove: $e')));
                }
              }
            },
            child: const Text('Remove', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Invite Link Tab
// ---------------------------------------------------------------------------

class _InviteLinkTab extends ConsumerWidget {
  const _InviteLinkTab({required this.group});
  final WhatsappGroup group;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final linkState = ref.watch(inviteLinkProvider(group.uuid));
    final notifier = ref.read(inviteLinkProvider(group.uuid).notifier);

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text('Invite Link', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 8),
          Text(
            'Share this link so people can join the group.',
            style: TextStyle(color: PiColors.of(context).textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 20),

          linkState.link.when(
            data: (link) {
              if (link == null) {
                return ElevatedButton.icon(
                  onPressed: () => notifier.fetch(),
                  icon: const Icon(Icons.link),
                  label: const Text('Get Invite Link'),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(color: PiColors.of(context).surface, borderRadius: BorderRadius.circular(8)),
                    child: Row(
                      children: [
                        Expanded(child: Text(link, style: const TextStyle(fontSize: 13), overflow: TextOverflow.ellipsis)),
                        IconButton(
                          icon: const Icon(Icons.copy, size: 18, color: AppColors.primary),
                          onPressed: () {
                            Clipboard.setData(ClipboardData(text: link));
                            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Link copied!'), duration: Duration(seconds: 2)));
                          },
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: () => _confirmReset(context, notifier),
                    icon: const Icon(Icons.refresh, color: Colors.red),
                    label: const Text('Reset Link', style: TextStyle(color: Colors.red)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.red)),
                  ),
                ],
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
            error: (e, _) => Column(
              children: [
                Text('Error: $e', style: const TextStyle(color: Colors.red)),
                TextButton(onPressed: () => notifier.fetch(), child: const Text('Retry')),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _confirmReset(BuildContext context, InviteLinkNotifier notifier) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reset Invite Link'),
        content: const Text('The current invite link will be revoked and a new one will be generated.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              notifier.reset();
            },
            child: const Text('Reset', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Join Requests Tab
// ---------------------------------------------------------------------------

class _JoinRequestsTab extends ConsumerWidget {
  const _JoinRequestsTab({required this.group, required this.onChanged});
  final WhatsappGroup group;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final requestsAsync = ref.watch(joinRequestsProvider(group.uuid));

    return requestsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator(color: AppColors.primary)),
      error: (e, _) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Error: $e', style: const TextStyle(color: Colors.red)),
            TextButton(onPressed: () => ref.invalidate(joinRequestsProvider(group.uuid)), child: const Text('Retry')),
          ],
        ),
      ),
      data: (requests) {
        if (requests.isEmpty) {
          return Center(child: Text('No pending join requests.', style: TextStyle(color: PiColors.of(context).textSecondary)));
        }
        return ListView.separated(
          padding: const EdgeInsets.symmetric(vertical: 8),
          itemCount: requests.length,
          separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
          itemBuilder: (context, index) {
            final req = requests[index];
            final requestId = req['join_request_id'] as String? ?? '';
            final waId = req['wa_id'] as String? ?? '';
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: Colors.orange[100],
                child: Text(waId.isNotEmpty ? waId[0] : '?', style: const TextStyle(color: Colors.orange)),
              ),
              title: Text(waId),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () => _approve(context, ref, requestId),
                    child: const Text('Approve', style: TextStyle(color: Colors.green)),
                  ),
                  TextButton(
                    onPressed: () => _reject(context, ref, requestId),
                    child: const Text('Reject', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _approve(BuildContext context, WidgetRef ref, String requestId) async {
    try {
      await ref.read(groupRepositoryProvider).approveJoinRequest(group.uuid, requestId);
      ref.invalidate(joinRequestsProvider(group.uuid));
      onChanged();
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _reject(BuildContext context, WidgetRef ref, String requestId) async {
    try {
      await ref.read(groupRepositoryProvider).rejectJoinRequest(group.uuid, requestId);
      ref.invalidate(joinRequestsProvider(group.uuid));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }
}
