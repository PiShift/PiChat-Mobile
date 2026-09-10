import 'package:pichat/features/calls/data/call_models.dart';

/// A run of consecutive calls collapsed into one history row.
///
/// WhatsApp folds together calls that are consecutive AND share the contact AND
/// share the type — seven unanswered attempts read as one row saying "(7)"
/// rather than seven identical lines. A different type, a different contact, or
/// a different day all break the run, which is why the same number can appear
/// twice in a day: once as "(2) Incoming" and again as "Missed".
class CallGroup {
  CallGroup(this.calls);

  /// Newest first, matching the list order.
  final List<CallModel> calls;

  CallModel get latest => calls.first;

  int get count => calls.length;

  CallKind get kind => latest.kind;

  String get title =>
      latest.contactName?.isNotEmpty == true
          ? latest.contactName!
          : (latest.isInbound ? latest.fromPhone : latest.toPhone) ?? 'Unknown';

  /// Only meaningful for a single call; a run of attempts has no one duration.
  int? get durationSeconds => count == 1 ? latest.durationSeconds : null;
}

extension on CallModel {
  bool get isInbound => direction == 'inbound';
}

/// Collapses a time-ordered list of calls into history rows.
///
/// [calls] must be newest-first, which is how the API returns them. The walk is
/// linear: a call joins the previous group when the contact, the type and the
/// calendar day all match, and starts a new one otherwise.
List<CallGroup> groupCalls(List<CallModel> calls) {
  final groups = <CallGroup>[];

  for (final call in calls) {
    final current = groups.isEmpty ? null : groups.last;

    if (current != null && _belongsTogether(current.latest, call)) {
      current.calls.add(call);
      continue;
    }

    groups.add(CallGroup([call]));
  }

  return groups;
}

bool _belongsTogether(CallModel a, CallModel b) {
  if (a.kind != b.kind) return false;

  // Contact id where both have one, otherwise the raw number — an unknown
  // caller still groups with themselves.
  final sameParty = (a.contactId != null && a.contactId == b.contactId) ||
      (a.contactId == null &&
          b.contactId == null &&
          _party(a) != null &&
          _party(a) == _party(b));

  if (!sameParty) return false;

  return _sameDay(a.createdAt, b.createdAt);
}

String? _party(CallModel call) =>
    call.direction == 'inbound' ? call.fromPhone : call.toPhone;

bool _sameDay(DateTime? a, DateTime? b) {
  if (a == null || b == null) return false;

  final x = a.toLocal();
  final y = b.toLocal();

  return x.year == y.year && x.month == y.month && x.day == y.day;
}
