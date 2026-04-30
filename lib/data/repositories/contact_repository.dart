import 'package:dio/dio.dart';
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichat/core/network/dio_provider.dart';
import 'package:pichat/data/db/app_database.dart';
import 'package:pichat/data/db/database_provider.dart';
import 'package:pichat/data/models/chat_model.dart';
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
      final cached = await (_db.select(_db.contacts)
            ..orderBy([
              (t) => OrderingTerm(
                    expression: t.latestChatCreatedAt,
                    mode: OrderingMode.desc,
                  )
            ]))
          .get();
      if (cached.isNotEmpty) {
        // Load lastChat for each contact from the local chats table
        final contacts = await Future.wait(cached.map((row) async {
          final contact = Contact.fromDb(row);
          if (row.lastChatId != null) {
            final chatRow = await (_db.select(_db.chats)
                  ..where((c) => c.id.equals(row.lastChatId!)))
                .getSingleOrNull();
            if (chatRow != null) {
              return contact.copyWith(lastChat: Chat.fromDb(chatRow));
            }
          }
          return contact;
        }));
        return contacts;
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

  /// Search contacts locally (from cache) by phone or name
  Future<List<Contact>> searchContacts(String query) async {
    final cached = await _db.select(_db.contacts).get();
    final lower = query.toLowerCase();
    return cached
        .where((row) =>
            (row.phone.contains(lower)) ||
            (row.fullName?.toLowerCase().contains(lower) ?? false) ||
            (row.firstName?.toLowerCase().contains(lower) ?? false) ||
            (row.lastName?.toLowerCase().contains(lower) ?? false))
        .map((row) => Contact.fromDb(row))
        .toList();
  }

  /// Create a new contact via the API
  Future<Contact> createContact({
    required String phone,
    String? firstName,
    String? lastName,
  }) async {
    final response = await _dio.post('/contacts/create', data: {
      'phone': phone,
      if (firstName != null && firstName.isNotEmpty) 'first_name': firstName,
      if (lastName != null && lastName.isNotEmpty) 'last_name': lastName,
    });

    final data = response.data;
    // API returns { success, contact } or { success, message, contact } on 409
    final contactJson = data['contact'] as Map<String, dynamic>;
    return Contact.fromJson(contactJson);
  }

  /// Look up a contact by phone number on the server. Returns `null` when
  /// the number isn't in the org's address book yet (HTTP 404). Other
  /// errors propagate.
  Future<Contact?> findContactByPhone(String phone) async {
    // Send the number as-is — the backend uses PhoneService::getE164Format
    // to normalize, so stripping the '+' here would break matching of
    // contacts that were saved as '+22236973666'.
    try {
      final response = await _dio.get(
        '/contacts/find',
        queryParameters: {'phone': phone.trim()},
      );
      final json = response.data['contact'] as Map<String, dynamic>?;
      if (json == null) return null;
      final contact = Contact.fromJson(json);
      await _db.into(_db.contacts).insertOnConflictUpdate(contact.toCompanion());
      return contact;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Find an existing contact for [phone] (checking the local cache first,
  /// then the server) and only create a new one if neither has it. The
  /// returned contact is always persisted in the local DB so the chat
  /// thread can be opened immediately.
  Future<Contact> findOrCreateByPhone({
    required String phone,
    String? firstName,
    String? lastName,
  }) async {
    final trimmed = phone.trim();
    // Local cache lookup is digit-tolerant: contacts may be stored either
    // as '+22236973666' or '22236973666' depending on origin, so we
    // compare on the digits-only form.
    final digits = trimmed.replaceAll(RegExp(r'[^0-9]'), '');

    // 1. Local cache first — by far the most common case.
    final localRows = await _db.select(_db.contacts).get();
    for (final row in localRows) {
      final rowDigits = row.phone.replaceAll(RegExp(r'[^0-9]'), '');
      if (rowDigits == digits) return Contact.fromDb(row);
    }

    // 2. Ask the server (handles the case where another agent created the
    //    contact and we just haven't synced yet).
    final remote = await findContactByPhone(trimmed);
    if (remote != null) return remote;

    // 3. Genuinely new — create it. Send the original (with '+' if any)
    //    so the backend can E.164-normalize it.
    return createContact(
      phone: trimmed,
      firstName: firstName,
      lastName: lastName,
    );
  }

  /// Update an existing contact
  Future<Contact> updateContact({
    required String uuid,
    String? firstName,
    String? lastName,
  }) async {
    final response = await _dio.put('/contacts/$uuid', data: {
      if (firstName != null) 'first_name': firstName,
      if (lastName != null) 'last_name': lastName,
    });

    final contactJson = response.data['contact'] as Map<String, dynamic>;
    final contact = Contact.fromJson(contactJson);
    await _db.into(_db.contacts).insertOnConflictUpdate(contact.toCompanion());
    return contact;
  }
}
