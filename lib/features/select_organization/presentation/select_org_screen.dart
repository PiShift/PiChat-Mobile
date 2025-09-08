// lib/screens/select_organization_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichat/core/network/dio_provider.dart';
import 'package:pichat/core/router/app_router.dart';
import 'package:pichat/core/state/auth_state.dart';
import 'package:pichat/data/models/organization_model.dart';
import 'package:pichat/data/repositories/auth_repository.dart';
import 'package:pichat/features/auth/application/auth_controller.dart';

class SelectOrganizationScreen extends ConsumerStatefulWidget {
  const SelectOrganizationScreen({super.key});

  @override
  ConsumerState<SelectOrganizationScreen> createState() => _SelectOrganizationScreenState();
}

class _SelectOrganizationScreenState extends ConsumerState<SelectOrganizationScreen> {
  List<Map<String, dynamic>> teams = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchOrganizations();
  }

  Future<void> fetchOrganizations() async {
    final dio = ref.read(dioProvider);
    final userId = ref.read(userIdProvider);
    final response = await dio.get('/organizations');
    setState(() {
      teams = List<Map<String, dynamic>>.from(response.data['organizations']);
      loading = false;
    });
    await ref.read(organizationProvider.notifier).insertOrganizations(
      teams.map((org) => Organization.fromJson(org['organization'] as Map<String, dynamic>)).toList(),
      userId!,
    );
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.read(appRouterProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Select Organization')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: teams.length,
        itemBuilder: (context, index) {
          final org = Organization.fromJson(teams[index]['organization'] as Map<String, dynamic>);
          return ListTile(
            title: Text(org.name),
            onTap: () async {
              await ref.read(authRepositoryProvider).selectOrganization(org);
              router.go('/home/chats');
            },
          );
        },
      ),
    );
  }
}
