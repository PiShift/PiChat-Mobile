import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichat/core/network/dio_provider.dart';
import 'package:pichat/data/db/app_database.dart';
import 'package:pichat/data/db/database_provider.dart';
import 'package:pichat/data/models/contact_model.dart';
import 'package:pichat/data/models/user_model.dart';
import 'package:dio/dio.dart';

final contactRepositoryProvider = Provider<ContactRepository>((ref) {
  final dio = ref.watch(dioProvider);
  final db = ref.watch(appDatabaseProvider);
  return ContactRepository(dio, db, ref);
});

class ContactRepository {
  final Dio _dio;
  final AppDatabase _db;
  final Ref _ref;

  ContactRepository(this._dio, this._db, this._ref);

  Future<List<Contact>> getContacts({
    int page = 1,
    int perPage = 20,
    String? search,
    bool forceRefresh = false,
  }) async {
    if (!forceRefresh && page == 1) {
      final cached = await _db.select(_db.contacts).get();
      if (cached.isNotEmpty) {
        return cached.map((row) => Contact.fromDb(row)).toList();
      }
    }

    final response = await _dio.get('/contacts', queryParameters: {
      'page': page,
      'per_page': perPage,
      if (search != null) 'search': search,
    });

    final data = response.data['data'] as List;
    final contacts = data.map((json) => Contact.fromJson(json)).toList();

    if (page == 1) {
      await _db.batch((batch) {
        batch.insertAllOnConflictUpdate(
          _db.contacts,
          contacts.map((c) => c.toCompanion()).toList(),
        );
      });
    }

    return contacts;
  }

  Future<Contact?> getContact(int id, {bool forceRefresh = false}) async {
    if (!forceRefresh) {
      final cached = await (_db.select(_db.contacts)..where((tbl) => tbl.id.equals(id))).getSingleOrNull();
      if (cached != null) return Contact.fromDb(cached);
    }

    final response = await _dio.get('/contacts/$id');
    final contact = Contact.fromJson(response.data['data']);

    await _db.into(_db.contacts).insertOnConflictUpdate(contact.toCompanion());
    return contact;
  }
}
