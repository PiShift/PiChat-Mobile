import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pichat/core/theme/app_colors.dart';
import 'package:pichat/core/theme/app_theme.dart';
import 'package:pichat/data/models/group_model.dart';
import 'package:pichat/data/repositories/group_repository.dart';
import 'package:pichat/features/groups/application/group_providers.dart';

class GroupsScreen extends ConsumerStatefulWidget {
  const GroupsScreen({super.key});

  @override
  ConsumerState<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends ConsumerState<GroupsScreen> {
  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final groupsAsync = ref.watch(groupsProvider);

    return Scaffold(
      backgroundColor: PiColors.of(context).background,
      appBar: AppBar(
        backgroundColor: PiColors.of(context).background,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        title: Text(
          'Groups',
          style: TextStyle(
            fontSize: size.width * 0.045,
            fontWeight: FontWeight.bold,
            color: PiColors.of(context).textPrimary,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: PiPalette.primary500),
            onPressed: () => _showCreateGroupSheet(context),
            tooltip: 'Create Group',
          ),
        ],
      ),
      body: groupsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: PiPalette.primary500)),
        error: (e, _) => Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline, size: 48, color: PiColors.of(context).error),
              const SizedBox(height: 12),
              Text('Failed to load groups', style: TextStyle(color: PiColors.of(context).textSecondary)),
              TextButton(
                onPressed: () => ref.invalidate(groupsProvider),
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
        data: (groups) {
          if (groups.isEmpty) {
            return _buildEmptyState(size);
          }
          return RefreshIndicator(
            color: PiPalette.primary500,
            onRefresh: () async => ref.invalidate(groupsProvider),
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: groups.length,
              separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
              itemBuilder: (context, index) => _GroupTile(group: groups[index]),
            ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(Size size) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.group_outlined, size: size.width * 0.15, color: PiColors.of(context).ink400),
          SizedBox(height: size.height * 0.02),
          Text(
            'No groups yet',
            style: TextStyle(fontSize: size.width * 0.045, fontWeight: FontWeight.bold, color: PiColors.of(context).textPrimary),
          ),
          SizedBox(height: size.height * 0.008),
          Text(
            'Create a WhatsApp group to get started.',
            style: TextStyle(fontSize: size.width * 0.033, color: PiColors.of(context).textSecondary),
          ),
          SizedBox(height: size.height * 0.03),
          ElevatedButton.icon(
            onPressed: () => _showCreateGroupSheet(context),
            icon: const Icon(Icons.add),
            label: const Text('Create Group'),
            style: ElevatedButton.styleFrom(backgroundColor: PiPalette.primary500, foregroundColor: PiPalette.white),
          ),
        ],
      ),
    );
  }

  void _showCreateGroupSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: PiColors.of(context).surfaceRaised,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => _CreateGroupSheet(onCreated: () {
        ref.invalidate(groupsProvider);
      }),
    );
  }
}

// ---------------------------------------------------------------------------
// Group Tile
// ---------------------------------------------------------------------------

class _GroupTile extends StatelessWidget {
  const _GroupTile({required this.group});
  final WhatsappGroup group;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: PiPalette.primary500.withOpacity(0.12),
        child: Text(
          group.subject.isNotEmpty ? group.subject[0].toUpperCase() : 'G',
          style: const TextStyle(color: PiPalette.primary500, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(group.subject, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        '${group.participantCount} participants • ${group.status}',
        style: TextStyle(fontSize: 12, color: PiColors.of(context).textSecondary),
      ),
      trailing: group.isSuspended
          ? Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: PiPalette.warning500.withOpacity(0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text('Suspended', style: TextStyle(fontSize: 10, color: PiPalette.warning500)),
            )
          : Icon(Icons.chevron_right, color: PiColors.of(context).ink400),
      onTap: () => context.push('/home/groups/detail', extra: group),
    );
  }
}

// ---------------------------------------------------------------------------
// Create Group Bottom Sheet
// ---------------------------------------------------------------------------

class _CreateGroupSheet extends ConsumerStatefulWidget {
  const _CreateGroupSheet({required this.onCreated});
  final VoidCallback onCreated;

  @override
  ConsumerState<_CreateGroupSheet> createState() => _CreateGroupSheetState();
}

class _CreateGroupSheetState extends ConsumerState<_CreateGroupSheet> {
  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _joinApprovalMode = 'auto_approve';
  bool _isLoading = false;

  @override
  void dispose() {
    _subjectController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    try {
      await ref.read(groupRepositoryProvider).createGroup(
            subject: _subjectController.text.trim(),
            description: _descriptionController.text.trim().isEmpty ? null : _descriptionController.text.trim(),
            joinApprovalMode: _joinApprovalMode,
          );
      widget.onCreated();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to create group: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Handle
            Center(
              child: Container(width: 40, height: 4, decoration: BoxDecoration(color: PiColors.of(context).divider, borderRadius: BorderRadius.circular(2))),
            ),
            const SizedBox(height: 16),
            const Text('Create WhatsApp Group', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('Groups are invite-only. An invite link will be delivered via webhook after creation.', style: TextStyle(fontSize: 12, color: PiColors.of(context).textSecondary)),
            const SizedBox(height: 16),

            // Subject
            TextFormField(
              controller: _subjectController,
              maxLength: 128,
              decoration: const InputDecoration(labelText: 'Group Subject *', border: OutlineInputBorder(), counterText: ''),
              validator: (v) => (v == null || v.trim().isEmpty) ? 'Subject is required' : null,
            ),
            const SizedBox(height: 12),

            // Description
            TextFormField(
              controller: _descriptionController,
              maxLength: 2048,
              maxLines: 2,
              decoration: const InputDecoration(labelText: 'Description (optional)', border: OutlineInputBorder(), counterText: ''),
            ),
            const SizedBox(height: 12),

            // Join Approval Mode
            DropdownButtonFormField<String>(
              value: _joinApprovalMode,
              decoration: const InputDecoration(labelText: 'Join Approval', border: OutlineInputBorder()),
              items: const [
                DropdownMenuItem(value: 'auto_approve', child: Text('Auto-approve (anyone with link)')),
                DropdownMenuItem(value: 'approval_required', child: Text('Approval required')),
              ],
              onChanged: (v) => setState(() => _joinApprovalMode = v ?? 'auto_approve'),
            ),
            const SizedBox(height: 20),

            ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              style: ElevatedButton.styleFrom(
                backgroundColor: PiPalette.primary500,
                foregroundColor: PiPalette.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: _isLoading
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Create Group', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
