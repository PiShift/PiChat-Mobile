import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichat/core/state/auth_state.dart';
import 'package:pichat/data/db/app_database.dart';
import 'package:pichat/data/db/database_provider.dart';
import 'package:pichat/data/models/chat_model.dart';
import 'package:pichat/data/repositories/chat_repository.dart';
import 'package:pichat/features/chat/application/upload_progress.dart';

/// Sends again the messages that were left half-sent.
///
/// A send in progress when the app was suspended or killed left its row
/// `pending`, and nothing ever picked it up again: the bubble showed a clock
/// forever and never offered a retry. Swept on start-up and whenever the app
/// comes back to the front. Resending is safe because every attempt carries
/// the row's client id, so the server returns a message it already sent
/// instead of sending it twice.
class OutboxService {
  OutboxService(this._ref);

  final Ref _ref;

  /// Attempts made per row during this run, so a message the server keeps
  /// refusing ends up failed (with a retry button) instead of looping.
  final Map<int, int> _attempts = {};

  static const _maxAttempts = 3;

  bool _sweeping = false;

  Future<void> sweep() async {
    if (_sweeping) return;
    if (_ref.read(authTokenProvider) == null) return;

    final orgId = _ref.read(organizationProvider)?.id;
    if (orgId == null) return;

    _sweeping = true;

    try {
      final db = _ref.read(appDatabaseProvider);
      final registry = _ref.read(uploadRegistryProvider.notifier);
      final repo = _ref.read(chatRepositoryProvider);

      final rows = await (db.select(db.chats)
            ..where((t) =>
                t.id.isSmallerThanValue(0) &
                t.status.equals('pending') &
                t.type.equals('outbound') &
                t.orgId.equals(orgId)))
          .get();

      for (final data in rows) {
        // Still being sent by this run of the app.
        if (registry.isInFlight(data.id)) continue;

        final row = Chat.fromDb(data);
        final kind = row.metadata?['type'];

        // Reactions are small and replaced by the next one; not worth
        // resending out of order.
        if (kind == 'reaction') {
          await db.updateChatStatus(row.id, 'failed');
          continue;
        }

        final attempts = (_attempts[row.id] ?? 0) + 1;
        _attempts[row.id] = attempts;

        final contact = await (db.select(db.contacts)
              ..where((c) => c.id.equals(row.contactId)))
            .getSingleOrNull();

        final sent = attempts <= _maxAttempts &&
            contact != null &&
            await repo.resend(row, contactUuid: contact.uuid);

        if (!sent) await db.updateChatStatus(row.id, 'failed');
      }
    } catch (_) {
      // A failed sweep is retried on the next resume.
    } finally {
      _sweeping = false;
    }
  }
}

final outboxServiceProvider = Provider<OutboxService>((ref) => OutboxService(ref));
