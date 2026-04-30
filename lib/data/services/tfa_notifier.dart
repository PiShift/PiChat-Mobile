import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

class TfaNotifier extends StateNotifier<String?> {
  TfaNotifier(): super(null);

  void setToken(String? v) {
    // debugPrint('TfaNotifier.setToken: $v');
    state = v;
  }
}