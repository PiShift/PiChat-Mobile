import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichat/core/network/dio_provider.dart';
import 'package:pichat/data/db/app_database.dart';
import 'package:pichat/data/db/database_provider.dart';
import 'package:pichat/data/models/user_model.dart';

final userRepositoryProvider = Provider<UserRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final db = ref.watch(appDatabaseProvider);
  return UserRepository(dio, db, ref);
});

class UserRepository {
  final Dio _dio;
  final AppDatabase _db;
  final Ref _ref;

  UserRepository(this._dio, this._db, this._ref);

  Future<User?> getUser(int id, {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await (_db.select(_db.users)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
      if (cached != null) return User.fromDb(cached);
    }

    final response = await _dio.get('/users/$id');
    final user = User.fromJson(response.data['data']);

    await _db.into(_db.users).insertOnConflictUpdate(user.toCompanion());
    return user;
  }

  Future<void> updateUser(User user) async {
    await _dio.put('/users/${user.id}', data: user.toJson());
    await _db.into(_db.users).insertOnConflictUpdate(user.toCompanion());
  }
}
