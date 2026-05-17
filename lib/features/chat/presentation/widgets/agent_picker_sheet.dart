import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichat/core/theme/app_colors.dart';
import 'package:pichat/core/theme/app_theme.dart';
import 'package:pichat/data/repositories/team_repository.dart';

/// Bottom sheet for selecting an agent to assign a chat to
class AgentPickerSheet extends ConsumerWidget {
  final String contactUuid;
  final Agent? currentAgent;
  final Function(Agent) onAgentSelected;

  const AgentPickerSheet({
    super.key,
    required this.contactUuid,
    this.currentAgent,
    required this.onAgentSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agentsAsync = ref.watch(agentsProvider);

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
              color: PiColors.of(context).divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.person_add, color: AppColors.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'agent_picker.title'.tr(),
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
          ),
          
          const Divider(),
          
          // Agent list
          agentsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (error, stack) => Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.error_outline, color: Colors.red[300], size: 48),
                  const SizedBox(height: 12),
                  Text(
                    'agent_picker.error.load_failed'.tr(),
                    style: TextStyle(color: PiColors.of(context).textSecondary),
                  ),
                  const SizedBox(height: 12),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(agentsProvider),
                    child: Text('common.retry'.tr()),
                  ),
                ],
              ),
            ),
            data: (agents) {
              if (agents.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    children: [
                      Icon(Icons.people_outline, color: PiColors.of(context).ink400, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        'agent_picker.empty.no_agents'.tr(),
                        style: TextStyle(color: PiColors.of(context).textSecondary),
                      ),
                    ],
                  ),
                );
              }
              
              return Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: agents.length,
                  itemBuilder: (context, index) {
                    final agent = agents[index];
                    final isCurrentAgent = currentAgent?.id == agent.id;
                    
                    return _AgentTile(
                      agent: agent,
                      isSelected: isCurrentAgent,
                      onTap: () {
                        onAgentSelected(agent);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              );
            },
          ),
          
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}

class _AgentTile extends StatelessWidget {
  final Agent agent;
  final bool isSelected;
  final VoidCallback onTap;

  const _AgentTile({
    required this.agent,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor: isSelected ? PiPalette.primary500 : PiColors.of(context).surface,
        backgroundImage: agent.avatar != null ? NetworkImage(agent.avatar!) : null,
        child: agent.avatar == null
            ? Text(
                _getInitials(agent.name),
                style: TextStyle(
                  color: isSelected ? PiPalette.white : PiColors.of(context).textSecondary,
                  fontWeight: FontWeight.bold,
                ),
              )
            : null,
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              agent.name.isNotEmpty ? agent.name : agent.email,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          if (isSelected)
            const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
        ],
      ),
      subtitle: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: _getRoleColor(agent.role).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              agent.role.toUpperCase(),
              style: TextStyle(
                fontSize: 10,
                color: _getRoleColor(agent.role),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'agent_picker.active_tickets'.tr(namedArgs: {'count': agent.activeTickets.toString()}),
            style: TextStyle(
              fontSize: 12,
              color: PiColors.of(context).textSecondary,
            ),
          ),
        ],
      ),
      trailing: isSelected
          ? null
          : Icon(Icons.chevron_right, color: PiColors.of(context).ink400),
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

  Color _getRoleColor(String role) {
    switch (role.toLowerCase()) {
      case 'admin':
        return Colors.purple;
      case 'manager':
        return Colors.blue;
      case 'agent':
        return Colors.green;
      default:
        return PiPalette.ink400;
    }
  }
}

/// Bottom sheet for changing ticket status
class TicketStatusSheet extends StatelessWidget {
  final String currentStatus;
  final Function(String) onStatusSelected;

  const TicketStatusSheet({
    super.key,
    required this.currentStatus,
    required this.onStatusSelected,
  });

  @override
  Widget build(BuildContext context) {
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
              color: PiColors.of(context).divider,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          
          // Title
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.flag, color: AppColors.primary),
                const SizedBox(width: 12),
                Text(
                  'ticket_status.title'.tr(),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Status options
          _StatusOption(
            status: 'open',
            label: 'ticket_status.open'.tr(),
            icon: Icons.inbox,
            color: Colors.green,
            isSelected: currentStatus == 'open',
            onTap: () {
              onStatusSelected('open');
              Navigator.pop(context);
            },
          ),
          _StatusOption(
            status: 'pending',
            label: 'ticket_status.pending'.tr(),
            icon: Icons.hourglass_empty,
            color: Colors.orange,
            isSelected: currentStatus == 'pending',
            onTap: () {
              onStatusSelected('pending');
              Navigator.pop(context);
            },
          ),
          _StatusOption(
            status: 'closed',
            label: 'ticket_status.closed'.tr(),
            icon: Icons.check_circle_outline,
            color: PiPalette.ink400,
            isSelected: currentStatus == 'closed',
            onTap: () {
              onStatusSelected('closed');
              Navigator.pop(context);
            },
          ),
          
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

class _StatusOption extends StatelessWidget {
  final String status;
  final String label;
  final IconData icon;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _StatusOption({
    required this.status,
    required this.label,
    required this.icon,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: color),
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: AppColors.primary)
          : null,
    );
  }
}
