import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichat/core/state/auth_state.dart';
import 'package:pichat/data/db/app_database.dart';
import 'package:pichat/data/models/user_model.dart';

class UserNotifier extends StateNotifier<User?> {
  final AppDatabase db;
  UserNotifier(this.db) : super(null);

  Future<void> loadUser(int id) async {
    state = await db.getUserById(id);
  }

  Future<void> setUser(User user) async {
    state = user;
    await db.insertUser(user);
  }

  Future<void> clear() async {
    state = null;
  }
}
