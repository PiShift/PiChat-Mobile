// lib/features/calls/presentation/call_history_screen.dart
//
// Paginated list of past calls for the current organization. Pulled from
// `GET /api/v1/calls`.

import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/call_api.dart';
import '../data/call_models.dart';

final callHistoryProvider = FutureProvider.autoDispose<List<CallModel>>((ref) async {
  final api = ref.watch(callApiProvider);
  return api.fetchHistory(page: 1, perPage: 50);
});

class CallHistoryScreen extends ConsumerWidget {
  const CallHistoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(callHistoryProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Calls')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(callHistoryProvider),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            const SizedBox(height: 100),
            Center(child: Text('Failed to load calls: $e')),
          ]),
          data: (calls) {
            if (calls.isEmpty) {
              return ListView(children: const [
                SizedBox(height: 120),
                Center(child: Text('No calls yet.', style: TextStyle(color: Colors.grey))),
              ]);
            }
            return ListView.separated(
              itemCount: calls.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) => _CallTile(call: calls[i]),
            );
          },
        ),
      ),
    );
  }
}

class _CallTile extends StatelessWidget {
  const _CallTile({required this.call});

  final CallModel call;

  @override
  Widget build(BuildContext context) {
    final inbound = call.direction == 'inbound';
    final missed = call.status == 'missed' || call.status == 'rejected';

    return ListTile(
      leading: CircleAvatar(
        backgroundColor: missed ? Colors.red.shade50 : Colors.blue.shade50,
        child: Icon(
          inbound ? Icons.call_received : Icons.call_made,
          color: missed ? Colors.red : Colors.blue,
        ),
      ),
      title: Text(
        call.contactName?.isNotEmpty == true
            ? call.contactName!
            : (call.fromPhone ?? call.toPhone ?? 'Unknown'),
      ),
      subtitle: Text(_subtitle(call)),
      trailing: Text(
        call.createdAt != null ? DateFormat('MMM d, HH:mm').format(call.createdAt!) : '',
        style: const TextStyle(fontSize: 12, color: Colors.grey),
      ),
    );
  }

  String _subtitle(CallModel call) {
    final parts = <String>[];
    parts.add(call.status);
    if (call.durationSeconds != null && call.durationSeconds! > 0) {
      final m = call.durationSeconds! ~/ 60;
      final s = call.durationSeconds! % 60;
      parts.add('${m}m ${s}s');
    }
    return parts.join(' • ');
  }
}
