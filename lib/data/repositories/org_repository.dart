import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichat/core/network/dio_provider.dart';
import 'package:pichat/data/db/app_database.dart';
import 'package:pichat/data/db/database_provider.dart';
import 'package:pichat/data/models/organization_model.dart';

final organizationRepositoryProvider = Provider<OrganizationRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final db = ref.watch(appDatabaseProvider);
  return OrganizationRepository(dio, db, ref);
});

class OrganizationRepository {
  final Dio _dio;
  final AppDatabase _db;
  final Ref _ref;

  OrganizationRepository(this._dio, this._db, this._ref);

  Future<List<Organization>> getOrganizations({bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await _db.select(_db.organizations).get();
      if (cached.isNotEmpty) {
        return cached.map((row) => Organization.fromDb(row)).toList();
      }
    }

    final response = await _dio.get('/organizations');
    final data = response.data['data'] as List;
    final orgs = data.map((json) => Organization.fromJson(json)).toList();

    await _db.batch((batch) {
      batch.insertAllOnConflictUpdate(
        _db.organizations,
        orgs.map((o) => o.toCompanion()).toList(),
      );
    });

    return orgs;
  }

  Future<Organization?> getOrganization(int id, {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await (_db.select(_db.organizations)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
      if (cached != null) return Organization.fromDb(cached);
    }

    final response = await _dio.get('/organizations/$id');
    final org = Organization.fromJson(response.data['data']);

    await _db.into(_db.organizations).insertOnConflictUpdate(org.toCompanion());
    return org;
  }
}
