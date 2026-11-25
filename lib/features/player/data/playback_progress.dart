/// Position that playback itself has reached, to tell a real end of file from a failed stream.
///
/// With mpv's `keep-open`, a stream that hits EOF before showing any frame is seeked to its last frame: the
/// position jumps to the duration right before `eof-reached`, which looks like a finished file. Unrequested
/// forward jumps are therefore not counted as reached; jumps landing near a requested seek (or start) are.
final class PlaybackProgress {
  static const _maxStep = Duration(seconds: 5);
  // hr-seek=no lands on a keyframe, possibly well before the requested position.
  static const _seekTolerance = Duration(seconds: 15);
  static const endTolerance = Duration(seconds: 5);

  Duration _last = Duration.zero;
  Duration _reached = Duration.zero;
  Duration? _seekTarget;

  Duration get reached => _reached;

  /// A new file opened at [start].
  void reset(Duration start) {
    _last = Duration.zero;
    _reached = Duration.zero;
    _seekTarget = start > Duration.zero ? start : null;
  }

  void seekTo(Duration target) => _seekTarget = target;

  void position(Duration value) {
    final step = value - _last;
    _last = value;
    final target = _seekTarget;
    if (target != null && (value - target).abs() <= _seekTolerance) {
      _seekTarget = null;
    } else if (step > _maxStep) {
      return;
    }
    _reached = value;
  }

  /// Playback got to the end of a file of [duration]; never true while the duration is unknown.
  bool reachedEnd(Duration duration) => duration > Duration.zero && duration - _reached <= endTolerance;
}
