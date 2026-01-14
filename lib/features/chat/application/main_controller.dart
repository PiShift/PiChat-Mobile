import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichat/data/db/app_database.dart';
import 'package:pichat/data/db/database_provider.dart';
import 'package:pichat/data/models/chat_model.dart';
import 'package:pichat/data/models/contact_model.dart';
import 'package:pichat/data/repositories/chat_repository.dart';
import 'package:pichat/data/repositories/contact_repository.dart';


final mainDataProvider = StateNotifierProvider<MainDataController, List<Contact>>((ref) {
  final contactRepo = ref.watch(contactRepositoryProvider);
  final chatRepo = ref.watch(chatRepositoryProvider);
  final db = ref.watch(appDatabaseProvider);
  return MainDataController(contactRepo, chatRepo, db);
});

class MainDataController extends StateNotifier<List<Contact>> {
  final ContactRepository _contactRepo;
  final ChatRepository _chatRepo;
  final AppDatabase _db;

  MainDataController(this._contactRepo, this._chatRepo, this._db) : super([]) {
    _loadContacts();
  }

  Future<void> _loadContacts() async {
    // 1️⃣ Load **cached contacts immediately** → UI shows instantly
    final cachedContacts = await _contactRepo.getContacts(forceRefresh: false);
    state = cachedContacts;

    // 2️⃣ Background refresh from API (does not block UI)
    refreshContacts();
  }

  Future<void> refreshContacts() async {
    try {
      final apiContacts = await _contactRepo.getContacts(forceRefresh: true);

      // Update state immediately after API data
      state = apiContacts;

      // For each contact, load messages **from DB first** (instant)
      for (var contact in apiContacts) {
        final lastId = contact.lastChat!.id;
        final newMessages = await _chatRepo.getMessages(contact.id, afterId: lastId, forceRefresh: true);

        if (newMessages.isNotEmpty) {
          contact.lastChatId = newMessages.last.id;
          contact.latestChatCreatedAt = newMessages.last.createdAt;
          await _db.into(_db.contacts).insertOnConflictUpdate(contact.toCompanion());
        }
      }

      // Then fetch **fresh messages** from API in background
      for (var contact in apiContacts) {
        final freshMessages = await _chatRepo.getMessages(contact.id, forceRefresh: true);

        // freshMessages are saved to DB by repository
        // UI can re-read from DB or listen to state changes
      }
    } catch (e) {
      print('Error refreshing contacts: $e');
    }
  }

  void updateContactWithNewMessage(Chat chat) {
    final List<Contact> updated = List.from(state);

    final index = updated.indexWhere((c) => c.id == chat.contactId);
    if (index != -1) {
      final contact = updated[index];

      // Only update if the new message is newer
      if (contact.latestChatCreatedAt == null ||
          chat.createdAt.isAfter(contact.latestChatCreatedAt!)) {
        final newContact = contact.copyWith(
          lastChatId: chat.id,
          lastChat: chat,
          latestChatCreatedAt: chat.createdAt,
          unreadCount: (contact.unreadCount ?? 0) + (chat.isRead ? 0 : 1),
        );

        // Move to top only if not already at top
        if (index != 0) {
          updated.removeAt(index);
          updated.insert(0, newContact);
        } else {
          updated[0] = newContact;
        }

        state = updated;
      }
    }
  }


}
