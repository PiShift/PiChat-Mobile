import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
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

  /// Refresh contacts from API
  /// The API now returns contacts with last_message embedded, so NO need to loop!
  Future<void> refreshContacts() async {
    try {
      final apiContacts = await _contactRepo.getContacts(forceRefresh: true);
      
      // Sort by latest message descending so newest conversations appear first
      final sorted = List<Contact>.from(apiContacts)
        ..sort((a, b) {
          final aTime = a.latestChatCreatedAt ?? a.createdAt;
          final bTime = b.latestChatCreatedAt ?? b.createdAt;
          return bTime.compareTo(aTime);
        });

      state = sorted;
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

  /// Update a contact's unread count (called when messages are marked as read)
  void updateContactUnreadCount(int contactId, int newUnreadCount) {
    final List<Contact> updated = List.from(state);
    final index = updated.indexWhere((c) => c.id == contactId);
    
    if (index != -1) {
      final contact = updated[index];
      updated[index] = contact.copyWith(unreadCount: newUnreadCount);
      state = updated;
    }
  }

  /// Decrease unread count by the number of messages marked as read
  void decreaseUnreadCount(int contactId, int count) {
    final List<Contact> updated = List.from(state);
    final index = updated.indexWhere((c) => c.id == contactId);
    
    if (index != -1) {
      final contact = updated[index];
      final newCount = ((contact.unreadCount ?? 0) - count).clamp(0, 999999);
      updated[index] = contact.copyWith(unreadCount: newCount);
      state = updated;
    }
  }

  /// Add a new contact or update an existing one in the list
  void addOrUpdateContact(Contact contact) {
    final List<Contact> updated = List.from(state);
    final index = updated.indexWhere((c) => c.id == contact.id);
    if (index != -1) {
      updated[index] = contact;
    } else {
      updated.insert(0, contact);
    }
    state = updated;
  }

  /// Mark all contacts' unread counts as 0 in the local state
  Future<void> markAllAsRead() async {
    state = state.map((c) => c.copyWith(unreadCount: 0)).toList();
  }

}
