import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:pichat/data/models/group_model.dart';
import 'package:pichat/data/repositories/group_repository.dart';

// List of all groups
final groupsProvider = FutureProvider<List<WhatsappGroup>>((ref) async {
  return ref.watch(groupRepositoryProvider).getGroups();
});

// Single group detail
final groupDetailProvider = FutureProvider.family<WhatsappGroup, String>((ref, uuid) async {
  return ref.watch(groupRepositoryProvider).getGroup(uuid);
});

// Join requests for a group
final joinRequestsProvider = FutureProvider.family<List<Map<String, dynamic>>, String>((ref, uuid) async {
  return ref.watch(groupRepositoryProvider).getJoinRequests(uuid);
});

// Invite link — fetched on demand via a StateNotifier
class InviteLinkState {
  final AsyncValue<String?> link;
  const InviteLinkState({this.link = const AsyncData(null)});
}

class InviteLinkNotifier extends StateNotifier<InviteLinkState> {
  final GroupRepository _repo;
  final String _uuid;

  InviteLinkNotifier(this._repo, this._uuid) : super(const InviteLinkState());

  Future<void> fetch() async {
    state = const InviteLinkState(link: AsyncLoading());
    state = InviteLinkState(link: await AsyncValue.guard(() => _repo.getInviteLink(_uuid)));
  }

  Future<void> reset() async {
    state = const InviteLinkState(link: AsyncLoading());
    state = InviteLinkState(link: await AsyncValue.guard(() => _repo.resetInviteLink(_uuid)));
  }
}

final inviteLinkProvider = StateNotifierProvider.family<InviteLinkNotifier, InviteLinkState, String>((ref, uuid) {
  return InviteLinkNotifier(ref.watch(groupRepositoryProvider), uuid);
});
