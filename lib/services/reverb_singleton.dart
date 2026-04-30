import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichat/core/constants/app_constants.dart';
import 'package:pichat/core/state/auth_state.dart';
import 'package:pichat/data/db/database_provider.dart';

import 'reverb_service.dart';

final reverbServiceProvider = Provider<ReverbService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final org = ref.watch(organizationProvider);
  final orgId = org?.id.toString();

  return ReverbService(
    host: AppConstants.wssUrl,
    appKey: 'kmdqYl4DVjIv6kBPtlJ9',
    useSecure: true,
    origin: AppConstants.wssOrigin,
    organizationId: orgId,
    db: db,
    ref: ref,
  );
});
