import 'package:dio/dio.dart';
import 'package:flutter_riverpod/legacy.dart';

/// Sends that are in flight right now, keyed by the optimistic row's id.
///
/// The value is upload progress from 0 to 1, or null until the first progress
/// event (and for sends with no body worth measuring, like text). A row that
/// is `pending` in the database but missing here is not being sent by anyone:
/// the app was suspended or killed mid-send, and the outbox picks it up.
class UploadRegistry extends StateNotifier<Map<int, double?>> {
  UploadRegistry() : super(const {});

  final Map<int, CancelToken> _tokens = {};

  bool isInFlight(int localId) => state.containsKey(localId);

  /// Register a send and hand back the token that cancels it.
  CancelToken begin(int localId) {
    final token = CancelToken();

    _tokens[localId] = token;
    state = {...state, localId: null};

    return token;
  }

  void progress(int localId, int sent, int total) {
    if (!state.containsKey(localId) || total <= 0) return;

    state = {...state, localId: (sent / total).clamp(0.0, 1.0)};
  }

  void end(int localId) {
    _tokens.remove(localId);

    if (!state.containsKey(localId)) return;

    state = {...state}..remove(localId);
  }

  /// Stop a send. The repository sees the cancellation and marks the row
  /// failed, which turns its bubble into a retry button.
  void cancel(int localId) {
    _tokens[localId]?.cancel('cancelled by agent');
  }
}

final uploadRegistryProvider =
    StateNotifierProvider<UploadRegistry, Map<int, double?>>(
  (ref) => UploadRegistry(),
);
