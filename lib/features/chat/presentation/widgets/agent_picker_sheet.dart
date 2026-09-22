import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichat/core/theme/app_colors.dart';
import 'package:pichat/core/theme/app_theme.dart';
import 'package:pichat/data/repositories/team_repository.dart';
import 'package:pichat/features/chat/data/pibot_api.dart';

/// Bottom sheet for choosing who owns a conversation.
///
/// The AI assistant and the agents are one decision, not two, so they share a
/// single list separated by a divider: picking an agent hands the conversation
/// to a human, picking the assistant hands it back to the bot. They used to be
/// a buried menu item and an unrelated toggle in the status strip.
class AgentPickerSheet extends ConsumerWidget {
  final String contactUuid;
  final Agent? currentAgent;
  final Function(Agent) onAgentSelected;

  /// AI state for this conversation. The assistant section is hidden when the
  /// organization has no assistant configured.
  final PibotState? pibot;

  /// Hand the conversation back to the assistant.
  final VoidCallback? onAiSelected;

  const AgentPickerSheet({
    super.key,
    required this.contactUuid,
    this.currentAgent,
    required this.onAgentSelected,
    this.pibot,
    this.onAiSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final agentsAsync = ref.watch(agentsProvider);
    final bot = pibot;
    final showAi = bot != null && bot.orgEnabled && onAiSelected != null;

    // Material, not a decorated Container: the tiles below paint their
    // background and ink on the nearest Material ancestor, so a coloured box
    // between them and it would hide every splash.
    return Material(
      color: PiColors.of(context).surfaceRaised,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
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

          if (showAi) ...[
            _SectionHeading(label: 'agent_picker.section.ai'.tr()),
            _AiTile(
              state: bot,
              // The assistant owns the conversation exactly when no agent does.
              isSelected: currentAgent == null,
              onTap: () {
                onAiSelected!();
                Navigator.pop(context);
              },
            ),
            const Divider(height: 1),
          ],

          _SectionHeading(label: 'agent_picker.section.agents'.tr()),

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

/// Small heading separating the assistant from the agents.
class _SectionHeading extends StatelessWidget {
  const _SectionHeading({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(
          label.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.6,
            color: PiColors.of(context).textSecondary,
          ),
        ),
      ),
    );
  }
}

/// The assistant, listed alongside the agents it can hand work back to.
class _AiTile extends StatelessWidget {
  const _AiTile({
    required this.state,
    required this.isSelected,
    required this.onTap,
  });

  final PibotState state;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        backgroundColor:
            isSelected ? PiPalette.primary500 : PiColors.of(context).surface,
        child: Icon(
          LucideIcons.sparkles,
          size: 18,
          color: isSelected ? PiPalette.white : PiColors.of(context).textSecondary,
        ),
      ),
      title: Row(
        children: [
          Expanded(
            child: Text(
              state.botName ?? 'agent_picker.ai.default_name'.tr(),
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
          if (isSelected)
            const Icon(Icons.check_circle, color: AppColors.primary, size: 20),
        ],
      ),
      subtitle: Text(
        state.label,
        style: TextStyle(
          fontSize: 12,
          color: PiColors.of(context).textSecondary,
        ),
      ),
      trailing: isSelected
          ? null
          : Icon(Icons.chevron_right, color: PiColors.of(context).ink400),
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
    return Material(
      color: Colors.white,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      clipBehavior: Clip.antiAlias,
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
