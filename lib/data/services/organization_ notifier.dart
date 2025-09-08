import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichat/data/db/app_database.dart';
import 'package:pichat/data/models/organization_model.dart';

class OrganizationNotifier extends StateNotifier<Organization?> {
  final AppDatabase db;
  OrganizationNotifier(this.db) : super(null);

  Future<void> setOrganization(Organization org, int userId) async {
    state = org;
    await db.insertOrganization(org);
    await db.insertUserOrganization(userId: userId, orgId: org.id);
  }

  Future<void> loadOrganization(int orgId) async {
    final org = await db.getOrganizationById(orgId);
    state = org;
  }

  // instert all organizations
  Future<void> insertOrganizations(List<Organization> orgs, int? userId) async {
    for (var org in orgs) {
      await db.insertOrganization(org);
      await db.insertUserOrganization(userId: userId!, orgId: org.id);
    }
  }

  Future<void> clear() async {
    state = null;
  }
}
