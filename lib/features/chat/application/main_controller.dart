import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:pichat/data/db/app_database.dart';
import 'package:pichat/data/db/database_provider.dart';
import 'package:pichat/data/models/chat_model.dart';
import 'package:pichat/data/repositories/label_repository.dart';
import 'package:pichat/data/models/contact_model.dart';
import 'package:pichat/data/repositories/chat_repository.dart';
import 'package:pichat/data/repositories/contact_repository.dart';


/// True while the contact list is being re-read from the server.
///
/// The list is offline-first, so a warm start shows the cached conversations
/// immediately and quietly replaces them when the fetch lands. Without a signal
/// that is indistinguishable from "this is current" — an agent could act on a
/// list that was minutes stale believing it was live.
final contactsRefreshingProvider = StateProvider<bool>((ref) => false);

final mainDataProvider = StateNotifierProvider<MainDataController, List<Contact>>((ref) {
  final contactRepo = ref.watch(contactRepositoryProvider);
  final chatRepo = ref.watch(chatRepositoryProvider);
  final db = ref.watch(appDatabaseProvider);
  return MainDataController(contactRepo, chatRepo, db, ref);
});

class MainDataController extends StateNotifier<List<Contact>> {
  final ContactRepository _contactRepo;
  final ChatRepository _chatRepo;
  final AppDatabase _db;

  /// Needed only to publish [contactsRefreshingProvider] so the list can show
  /// that it is re-reading rather than silently swapping stale rows.
  final Ref _ref;

  MainDataController(this._contactRepo, this._chatRepo, this._db, this._ref)
      : super([]) {
    _loadContacts();
  }

  static const _pageSize = 20;

  int _page = 1;
  bool _hasMore = true;
  bool _isLoadingMore = false;

  bool get hasMore => _hasMore;
  bool get isLoadingMore => _isLoadingMore;

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
    _ref.read(contactsRefreshingProvider.notifier).state = true;

    try {
      final apiContacts = await _contactRepo.getContacts(
        page: 1,
        perPage: _pageSize,
        forceRefresh: true,
      );

      // A refresh starts the list over, so paging restarts with it.
      _page = 1;
      _hasMore = apiContacts.length >= _pageSize;

      state = _sortedByRecency(apiContacts);
    } catch (e) {
      print('Error refreshing contacts: $e');
    } finally {
      _ref.read(contactsRefreshingProvider.notifier).state = false;
    }
  }

  /// Append the next page of conversations.
  ///
  /// The list was previously capped at whatever the first request returned:
  /// the repository accepted a page number but nothing ever asked for page two,
  /// and the screen had no scroll listener, so an agent could not reach any
  /// conversation past the first twenty.
  Future<void> loadMoreContacts() async {
    if (_isLoadingMore || !_hasMore) return;

    _isLoadingMore = true;

    try {
      // Page from the oldest conversation we hold rather than by offset.
      final oldest = state.isEmpty ? null : state.last;

      final next = await _contactRepo.getContacts(
        perPage: _pageSize,
        forceRefresh: true,
        before: oldest?.latestChatCreatedAt ?? oldest?.createdAt,
        beforeId: oldest?.id,
      );

      _page += 1;

      final seen = state.map((c) => c.id).toSet();
      final fresh = next.where((c) => !seen.contains(c.id)).toList();

      /*
       * Stop when a page brings nothing new, not just when it comes back empty.
       * This list is ordered by last activity and that order shifts constantly
       * as messages arrive, so offset paging can hand back a page of contacts
       * we already hold. Watching for an empty page alone let it walk through
       * page after page of duplicates on a single flick.
       */
      if (fresh.isEmpty) {
        _hasMore = false;

        return;
      }

      _hasMore = next.length >= _pageSize;

      state = _sortedByRecency([...state, ...fresh]);
    } catch (e) {
      print('Error loading more contacts: $e');
    } finally {
      _isLoadingMore = false;
    }
  }

  /// Newest conversation first.
  List<Contact> _sortedByRecency(List<Contact> contacts) {
    return List<Contact>.from(contacts)
      ..sort((a, b) {
        final aTime = a.latestChatCreatedAt ?? a.createdAt;
        final bTime = b.latestChatCreatedAt ?? b.createdAt;

        return bTime.compareTo(aTime);
      });
  }

  /// Apply an incoming message to the conversation list.
  ///
  /// A message from someone who is not in the loaded list used to be dropped
  /// here, so a brand new conversation stayed invisible until the agent pulled
  /// to refresh. The contact is now read from the local database - the realtime
  /// handler has already written it - and inserted at the top.
  Future<void> updateContactWithNewMessage(Chat chat) async {
    final List<Contact> updated = List.from(state);

    final index = updated.indexWhere((c) => c.id == chat.contactId);

    if (index == -1) {
      final stored = await _contactRepo.getContact(chat.contactId);

      if (stored != null) {
        addOrUpdateContact(stored.copyWith(lastChat: chat));
      }

      return;
    }

    final contact = updated[index];

    // Only apply a message that is genuinely newer than what we hold.
    if (contact.latestChatCreatedAt != null &&
        !chat.createdAt.isAfter(contact.latestChatCreatedAt!)) {
      return;
    }

    final isInbound = chat.type == 'inbound';
    final newContact = contact.copyWith(
      lastChatId: chat.id,
      lastChat: chat,
      latestChatCreatedAt: chat.createdAt,
      unreadCount: (contact.unreadCount ?? 0) + (chat.isRead ? 0 : 1),
      lastInboundChatAt: isInbound ? chat.createdAt : contact.lastInboundChatAt,
    );

    // Newest conversation first, the way every messaging app behaves.
    if (index != 0) {
      updated.removeAt(index);
      updated.insert(0, newContact);
    } else {
      updated[0] = newContact;
    }

    state = updated;
  }

  /// Apply a label change to the in-memory row.
  ///
  /// The list holds its own Contact copies, so a database write alone would not
  /// repaint the row until the next fetch.
  void applyLabels(int contactId, List<Label> labels) {
    final updated = List<Contact>.from(state);
    final index = updated.indexWhere((c) => c.id == contactId);

    if (index == -1) return;

    updated[index] = updated[index].copyWith(labels: labels);
    state = updated;
  }

  /// Reflect a call on the conversation, without waiting for a refresh.
  ///
  /// Call events arrive over Reverb while the list is on screen, so the row
  /// should change as the call does — ringing shows "Incoming call", and it
  /// becomes "Missed call" the moment nobody takes it. Written to the database
  /// as well so it survives leaving the screen.
  Future<void> applyCallActivity({
    required int contactId,
    required DateTime at,
    required String direction,
    required String status,
  }) async {
    await _db.setContactCallActivity(
      contactId: contactId,
      at: at,
      direction: direction,
      status: status,
    );

    final updated = List<Contact>.from(state);
    final index = updated.indexWhere((c) => c.id == contactId);

    if (index == -1) return;

    final patched = updated[index].copyWith(
      lastCallAt: at,
      lastCallDirection: direction,
      lastCallStatus: status,
      latestChatCreatedAt: at,
    );

    // A call is activity, so the conversation moves to the top the way a
    // message would.
    updated.removeAt(index);
    updated.insert(0, patched);

    state = updated;
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
