// lib/screens/select_organization_screen.dart
import 'package:easy_localization/easy_localization.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichat/core/network/dio_provider.dart';
import 'package:pichat/core/router/app_router.dart';
import 'package:pichat/core/state/auth_state.dart';
import 'package:pichat/data/models/organization_model.dart';
import 'package:pichat/data/repositories/auth_repository.dart';

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
    // Notifiers are read before the first await: auto-selecting a single
    // organization below flips auth state and lets GoRouter deactivate this
    // screen, and a `ref.read` afterwards throws "Using ref when a widget is
    // about to or has been unmounted", killing the rest of this method.
    final dio = ref.read(dioProvider);
    final organizations = ref.read(organizationProvider.notifier);

    final Response<dynamic> response;

    try {
      response = await dio.get('/organizations');
    } catch (e) {
      // A revoked token lands here: signing in on another device evicts this
      // one, and the Dio interceptor logs us out on the 401. That redirect is
      // the correct outcome, so swallow the error rather than letting it
      // surface as an unhandled exception on the way to the login screen.
      debugPrint('[SelectOrg] could not load organizations: $e');

      if (mounted) setState(() => loading = false);

      return;
    }

    final fetched =
        List<Map<String, dynamic>>.from(response.data['organizations']);

    if (!mounted) return;

    // userIdProvider is populated by SplashScreen / login, which has not
    // necessarily finished when initState fires — so this one is read here
    // rather than hoisted. Caching to the local DB is best-effort; the picker
    // must still work without it.
    final userId = ref.read(userIdProvider);
    if (userId != null) {
      await organizations.insertOrganizations(
        fetched
            .map((org) => Organization.fromJson(
                org['organization'] as Map<String, dynamic>))
            .toList(),
        userId,
      );
    }

    if (!mounted) return;

    // Almost every agent belongs to exactly one organization, and asking them
    // to choose from a list of one is pure friction. The picker is still shown
    // to anyone who really does belong to several.
    if (fetched.length == 1) {
      await _select(Organization.fromJson(fetched.first['organization'] as Map<String, dynamic>));

      return;
    }

    setState(() {
      teams = fetched;
      loading = false;
    });
  }

  Future<void> _select(Organization org) async {
    // Same rule as fetchOrganizations: selecting an organization is exactly
    // what tears this screen down, so both providers are read up front.
    final authRepository = ref.read(authRepositoryProvider);
    final router = ref.read(appRouterProvider);

    await authRepository.selectOrganization(org);

    router.go('/home/chats');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('select_org.title'.tr())),
      body: loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: teams.length,
        itemBuilder: (context, index) {
          final org = Organization.fromJson(teams[index]['organization'] as Map<String, dynamic>);
          return ListTile(
            title: Text(org.name),
            onTap: () => _select(org),
          );
        },
      ),
    );
  }
}
