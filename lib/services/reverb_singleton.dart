import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pichat/core/constants/app_constants.dart';
import 'package:pichat/data/db/database_provider.dart';

import 'reverb_service.dart';

final reverbServiceProvider = Provider<ReverbService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final orgId = "1"; // or fetch from auth/session provider

  return ReverbService(
    host: AppConstants.wssUrl,
    appKey: 'pi_9a885dd7c4f547c01',
    useSecure: true,
    organizationId: orgId,
    db: db,
    ref: ref,
  );
});
