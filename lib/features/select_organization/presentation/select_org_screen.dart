// lib/screens/select_organization_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichat/core/network/dio_provider.dart';
import 'package:pichat/core/router/app_router.dart';
import 'package:pichat/data/repositories/auth_repository.dart';
import 'package:pichat/features/auth/application/auth_controller.dart';

class SelectOrganizationScreen extends ConsumerStatefulWidget {
  const SelectOrganizationScreen({super.key});

  @override
  ConsumerState<SelectOrganizationScreen> createState() => _SelectOrganizationScreenState();
}

class _SelectOrganizationScreenState extends ConsumerState<SelectOrganizationScreen> {
  List<Map<String, dynamic>> orgs = [];
  bool loading = true;

  @override
  void initState() {
    super.initState();
    fetchOrganizations();
  }

  Future<void> fetchOrganizations() async {
    final dio = ref.read(dioProvider);
    final response = await dio.get('/organizations');
    setState(() {
      orgs = List<Map<String, dynamic>>.from(response.data['organizations']);
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.read(appRouterProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Select Organization')),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: orgs.length,
        itemBuilder: (context, index) {
          final org = orgs[index];
          return ListTile(
            title: Text(org['organization']['name']),
            onTap: () async {
              await ref.read(authRepositoryProvider).selectOrganization(org['organization']['id'] as int);
              router.go('/home/chats');
            },
          );
        },
      ),
    );
  }
}
