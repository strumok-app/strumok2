import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

extension CacheForRef on Ref {
  /// Keeps an auto-dispose provider alive for [duration] after its last listener is gone.
  void cacheFor(Duration duration) {
    final link = keepAlive();
    Timer? timer;
    onCancel(() => timer = Timer(duration, link.close));
    onResume(() => timer?.cancel());
    onDispose(() => timer?.cancel());
  }
}
