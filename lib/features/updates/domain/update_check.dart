const updateCheckInterval = Duration(hours: 12);

/// Startup checks run at most once per [updateCheckInterval] (spec-11). A clock moved backwards forces a check.
bool isUpdateCheckDue(DateTime? lastCheck, DateTime now) =>
    lastCheck == null || now.isBefore(lastCheck) || now.difference(lastCheck) >= updateCheckInterval;

class UpdateCheckNotConfiguredException implements Exception {
  final String key;

  const UpdateCheckNotConfiguredException(this.key);

  @override
  String toString() => '$key is not configured';
}

final class UpdateCheckState<T> {
  final T? latest;
  final bool checking;

  /// Only set for user-initiated checks; startup check failures are silent (spec-11 §11.2).
  final Object? error;

  const UpdateCheckState({this.latest, this.checking = false, this.error});
}

sealed class InstallState {
  const InstallState();
}

final class InstallIdle extends InstallState {
  const InstallIdle();
}

final class InstallInProgress extends InstallState {
  /// 0..1, or null when the size is unknown.
  final double? progress;

  const InstallInProgress([this.progress]);
}

final class InstallFailed extends InstallState {
  final Object error;

  const InstallFailed(this.error);
}
