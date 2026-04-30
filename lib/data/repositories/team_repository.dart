import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichat/core/network/dio_provider.dart';

final teamRepositoryProvider = Provider<TeamRepository>((ref) {
  final dio = ref.watch(dioProvider);
  return TeamRepository(dio);
});

/// Model for Agent data
class Agent {
  final int id;
  final String name;
  final String firstName;
  final String lastName;
  final String email;
  final String? avatar;
  final String role;
  final int activeTickets;

  Agent({
    required this.id,
    required this.name,
    required this.firstName,
    required this.lastName,
    required this.email,
    this.avatar,
    required this.role,
    required this.activeTickets,
  });

  factory Agent.fromJson(Map<String, dynamic> json) {
    return Agent(
      id: json['id'] as int,
      name: json['name'] as String? ?? '',
      firstName: json['first_name'] as String? ?? '',
      lastName: json['last_name'] as String? ?? '',
      email: json['email'] as String? ?? '',
      avatar: json['avatar'] as String?,
      role: json['role'] as String? ?? 'agent',
      activeTickets: json['active_tickets'] as int? ?? 0,
    );
  }
}

/// Model for Ticket data
class Ticket {
  final int id;
  final String status;
  final Agent? assignedTo;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  Ticket({
    required this.id,
    required this.status,
    this.assignedTo,
    this.createdAt,
    this.updatedAt,
  });

  factory Ticket.fromJson(Map<String, dynamic> json) {
    return Ticket(
      id: json['id'] as int,
      status: json['status'] as String? ?? 'open',
      assignedTo: json['assigned_to'] != null
          ? Agent(
              id: json['assigned_to']['id'] as int,
              name: json['assigned_to']['name'] as String? ?? '',
              firstName: '',
              lastName: '',
              email: '',
              avatar: json['assigned_to']['avatar'] as String?,
              role: '',
              activeTickets: 0,
            )
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String)
          : null,
      updatedAt: json['updated_at'] != null
          ? DateTime.tryParse(json['updated_at'] as String)
          : null,
    );
  }
}

class TeamRepository {
  final Dio _dio;

  TeamRepository(this._dio);

  /// Get all agents in the organization
  Future<List<Agent>> getAgents() async {
    try {
      final response = await _dio.get('/team/agents');
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        final List<dynamic> agentsList = response.data['agents'] ?? [];
        return agentsList.map((json) => Agent.fromJson(json)).toList();
      }
      
      throw Exception('Failed to load agents');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to load agents');
    }
  }

  /// Get ticket details for a contact
  Future<Ticket?> getTicket(String contactUuid) async {
    try {
      final response = await _dio.get('/contacts/$contactUuid/ticket');
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        final ticketData = response.data['ticket'];
        if (ticketData == null) return null;
        return Ticket.fromJson(ticketData);
      }
      
      return null;
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to load ticket');
    }
  }

  /// Assign a contact's chat to an agent
  Future<Ticket> assignToAgent(String contactUuid, int agentId) async {
    try {
      final response = await _dio.post(
        '/contacts/$contactUuid/assign',
        data: <String, dynamic>{'agent_id': agentId},
      );
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        return Ticket.fromJson(response.data['ticket']);
      }
      
      throw Exception(response.data['message'] ?? 'Failed to assign agent');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to assign agent');
    }
  }

  /// Update ticket status (open, pending, closed)
  Future<Ticket> updateTicketStatus(String contactUuid, String status) async {
    try {
      final response = await _dio.patch(
        '/contacts/$contactUuid/ticket/status',
        data: <String, dynamic>{'status': status},
      );
      
      if (response.statusCode == 200 && response.data['success'] == true) {
        return Ticket.fromJson(response.data['ticket']);
      }
      
      throw Exception(response.data['message'] ?? 'Failed to update status');
    } on DioException catch (e) {
      throw Exception(e.response?.data?['message'] ?? 'Failed to update status');
    }
  }
}

/// Provider for agents list
final agentsProvider = FutureProvider<List<Agent>>((ref) async {
  final teamRepo = ref.watch(teamRepositoryProvider);
  return teamRepo.getAgents();
});

/// Provider for contact ticket
final contactTicketProvider = FutureProvider.family<Ticket?, String>((ref, contactUuid) async {
  final teamRepo = ref.watch(teamRepositoryProvider);
  return teamRepo.getTicket(contactUuid);
});
