import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichat/core/constants/app_constants.dart';
import 'package:pichat/core/state/auth_state.dart';
import 'package:pichat/data/db/database_provider.dart';

import 'reverb_service.dart';

/// The realtime connection, created once for the life of the app.
///
/// This deliberately does NOT watch organizationProvider. It used to, and
/// because selecting an organization changes that provider, the service was
/// disposed and rebuilt a few milliseconds after start-up - orphaning the
/// websocket that had just connected and subscribed. The organization is set
/// imperatively through [ReverbService.startFor] instead, which reconnects only
/// when the organization or agent actually changes.
final reverbServiceProvider = Provider<ReverbService>((ref) {
  final db = ref.read(appDatabaseProvider);
  final orgId = ref.read(organizationProvider)?.id.toString();

  final service = ReverbService(
    host: AppConstants.wssUrl,
    // REVERB_APP_KEY. This is public by design - it is sent by every client
    // in the connection URL. The app secret must never ship in the app.
    appKey: 'nmrvhvajjcnesvezdkpd',
    useSecure: true,
    origin: AppConstants.wssOrigin,
    organizationId: orgId,
    db: db,
    ref: ref,
  );

  ref.onDispose(service.disconnect);

  return service;
});
