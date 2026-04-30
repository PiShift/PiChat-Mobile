import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichat/core/theme/app_theme.dart';
import 'package:pichat/data/models/contact_model.dart';
import 'package:pichat/data/repositories/contact_repository.dart';
import 'package:pichat/data/repositories/team_repository.dart';
import 'package:pichat/features/chat/presentation/widgets/agent_picker_sheet.dart';

/// Screen to view and edit contact details
class ContactDetailsScreen extends ConsumerStatefulWidget {
  final Contact contact;

  const ContactDetailsScreen({super.key, required this.contact});

  @override
  ConsumerState<ContactDetailsScreen> createState() => _ContactDetailsScreenState();
}

class _ContactDetailsScreenState extends ConsumerState<ContactDetailsScreen> {
  bool _isEditing = false;
  late TextEditingController _firstNameController;
  late TextEditingController _lastNameController;

  @override
  void initState() {
    super.initState();
    _firstNameController = TextEditingController(text: widget.contact.firstName);
    _lastNameController = TextEditingController(text: widget.contact.lastName);
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ticketAsync = ref.watch(contactTicketProvider(widget.contact.uuid));

    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(
          _isEditing ? 'contact_details.title_editing'.tr() : 'contact_details.title'.tr(),
          style: const TextStyle(color: Colors.white),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit, color: Colors.white),
              onPressed: () => setState(() => _isEditing = true),
            )
          else
            IconButton(
              icon: const Icon(Icons.check, color: Colors.white),
              onPressed: _saveContact,
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Avatar and name
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    backgroundImage: widget.contact.avatar != null
                        ? NetworkImage(widget.contact.avatar!)
                        : null,
                    child: widget.contact.avatar == null
                        ? Text(
                            _getInitials(widget.contact.fullName ?? widget.contact.phone),
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(height: 16),
                  if (!_isEditing)
                    Text(
                      widget.contact.fullName ?? widget.contact.phone,
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  const SizedBox(height: 4),
                  Text(
                    widget.contact.phone,
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 32),

            // Contact info card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'contact_details.section.information'.tr(),
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    
                    if (_isEditing) ...[
                      TextField(
                        controller: _firstNameController,
                        decoration: InputDecoration(
                          labelText: 'contact_details.field.first_name'.tr(),
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _lastNameController,
                        decoration: InputDecoration(
                          labelText: 'contact_details.field.last_name'.tr(),
                          prefixIcon: const Icon(Icons.person_outline),
                        ),
                      ),
                    ] else ...[
                      _InfoRow(
                        icon: Icons.person_outline,
                        label: 'contact_details.field.first_name'.tr(),
                        value: widget.contact.firstName ?? '-',
                      ),
                      _InfoRow(
                        icon: Icons.person_outline,
                        label: 'contact_details.field.last_name'.tr(),
                        value: widget.contact.lastName ?? '-',
                      ),
                      _InfoRow(
                        icon: Icons.phone_outlined,
                        label: 'contact_details.field.phone'.tr(),
                        value: widget.contact.phone,
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Ticket status card
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'contact_details.section.ticket_status'.tr(),
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        ticketAsync.when(
                          loading: () => const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          error: (_, __) => const Icon(Icons.error_outline, color: Colors.red),
                          data: (ticket) => _StatusBadge(status: ticket?.status ?? 'open'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    ticketAsync.when(
                      loading: () => const SizedBox.shrink(),
                      error: (_, __) => Text('contact_details.error.load_ticket'.tr()),
                      data: (ticket) => Column(
                        children: [
                          _InfoRow(
                            icon: Icons.flag_outlined,
                            label: 'contact_details.field.status'.tr(),
                            value: (ticket?.status ?? 'open').toUpperCase(),
                          ),
                          _InfoRow(
                            icon: Icons.person_outline,
                            label: 'contact_details.field.assigned_to'.tr(),
                            value: ticket?.assignedTo?.name ?? 'contact_details.value.unassigned'.tr(),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showAssignAgent(),
                            icon: const Icon(Icons.person_add),
                            label: Text('contact_details.action.assign'.tr()),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _showStatusPicker(),
                            icon: const Icon(Icons.flag),
                            label: Text('contact_details.action.change_status'.tr()),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Quick actions
            Card(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.message, color: AppColors.primary),
                    title: Text('contact_details.action.send_message'.tr()),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pop(context), // Go back to chat
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.photo_library, color: AppColors.primary),
                    title: Text('contact_details.action.view_media'.tr()),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      // Navigate to media gallery
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: Icon(Icons.block, color: Colors.red[400]),
                    title: Text('contact_details.action.block_contact'.tr(), style: TextStyle(color: Colors.red[400])),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      // Show block confirmation
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name[0].toUpperCase();
  }

  Future<void> _saveContact() async {
    setState(() => _isEditing = false);
    try {
      final repo = ref.read(contactRepositoryProvider);
      await repo.updateContact(
        uuid: widget.contact.uuid,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('contact_details.snackbar.contact_saved'.tr()), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('contact_details.snackbar.failed_to_save'.tr(namedArgs: {'error': e.toString()})), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _showAssignAgent() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        maxChildSize: 0.8,
        minChildSize: 0.3,
        builder: (_, scrollController) => AgentPickerSheet(
          contactUuid: widget.contact.uuid,
          onAgentSelected: (agent) async {
            try {
              final teamRepo = ref.read(teamRepositoryProvider);
              await teamRepo.assignToAgent(widget.contact.uuid, agent.id);
              ref.invalidate(contactTicketProvider(widget.contact.uuid));
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('chat.snackbar.assigned_to'.tr(namedArgs: {'name': agent.name})), backgroundColor: Colors.green),
                );
              }
            } catch (e) {
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('contact_details.snackbar.failed'.tr(namedArgs: {'error': e.toString()})), backgroundColor: Colors.red),
                );
              }
            }
          },
        ),
      ),
    );
  }

  void _showStatusPicker() {
    final ticketAsync = ref.read(contactTicketProvider(widget.contact.uuid));
    final currentStatus = ticketAsync.hasValue ? ticketAsync.value?.status ?? 'open' : 'open';

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => TicketStatusSheet(
        currentStatus: currentStatus,
        onStatusSelected: (status) async {
          try {
            final teamRepo = ref.read(teamRepositoryProvider);
            await teamRepo.updateTicketStatus(widget.contact.uuid, status);
            ref.invalidate(contactTicketProvider(widget.contact.uuid));
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('chat.snackbar.status_changed'.tr(namedArgs: {'status': status})), backgroundColor: Colors.green),
              );
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('contact_details.snackbar.failed'.tr(namedArgs: {'error': e.toString()})), backgroundColor: Colors.red),
              );
            }
          }
        },
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[500])),
              Text(value, style: const TextStyle(fontSize: 14)),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final String status;

  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _getStatusColor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }
}
