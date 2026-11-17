import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Which single-finger drags pan the zoomed content; the rest stay with the scrollable inside.
enum ReaderPanAxis {
  /// Long strip: the list scrolls vertically, so only horizontal drags pan.
  horizontal,

  /// Paged: the pager is locked while zoomed, so drags pan in any direction.
  free,
}

/// Pinch / double-tap / ctrl+wheel / trackpad-pinch zoom with panning over the whole reader viewport (spec-07).
/// The content keeps covering the viewport (no zooming out below 1). Taps are reported in viewport coordinates
/// for tap zones.
///
/// Gestures never compete with the scrollable inside for the same movement: pinches are tracked from raw pointers
/// (outside the gesture arena) and reported through [onPinchChanged], so the view stops scrolling meanwhile;
/// single-finger panning exists only while zoomed, along [panAxis].
class ReaderZoom extends StatefulWidget {
  static const maxScale = 4.0;
  static const doubleTapScale = 2.5;

  final Widget child;
  final ReaderPanAxis panAxis;
  final void Function(Offset position, Size size)? onTap;
  final ValueChanged<bool>? onZoomChanged;
  final ValueChanged<bool>? onPinchChanged;

  const ReaderZoom({
    super.key,
    required this.child,
    required this.panAxis,
    this.onTap,
    this.onZoomChanged,
    this.onPinchChanged,
  });

  @override
  State<ReaderZoom> createState() => ReaderZoomState();
}

class ReaderZoomState extends State<ReaderZoom> with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(vsync: this, duration: const Duration(milliseconds: 200))
    ..addListener(_onAnimation);

  double _scale = 1;
  Offset _offset = Offset.zero;
  Size _size = Size.zero;

  /// Touch pointers down, in viewport coordinates.
  final _touches = <int, Offset>{};

  /// Pinch (or trackpad pinch) in progress: the scale and content point under the focal point at its start.
  ({double span, double scale, Offset scene})? _pinch;
  ({double scale, Offset scene})? _trackpad;
  Offset? _doubleTapAt;
  ({double scale, Offset offset})? _from;
  ({double scale, Offset offset})? _to;

  bool get zoomed => _scale > 1.001;

  double get scale => _scale;

  Offset get offset => _offset;

  @override
  void dispose() {
    _animation.dispose();
    super.dispose();
  }

  void reset() {
    _animation.stop();
    _set(1, Offset.zero);
  }

  /// Scales around [focal] (viewport coordinates) keeping the content under it in place.
  void zoomAt(Offset focal, double scale) {
    _animation.stop();
    final target = _target(focal, scale);
    _set(target.scale, target.offset);
  }

  void panBy(Offset delta) {
    _animation.stop();
    _set(_scale, _offset + delta);
  }

  /// Ctrl + mouse wheel.
  void zoomByWheel(PointerScrollEvent event) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null) return;
    zoomAt(box.globalToLocal(event.position), _scale * math.exp(-event.scrollDelta.dy / 200));
  }

  Offset _scene(Offset focal) => (focal - _offset) / _scale;

  ({double scale, Offset offset}) _target(Offset focal, double scale) {
    final clamped = scale.clamp(1.0, ReaderZoom.maxScale);
    return (scale: clamped, offset: focal - _scene(focal) * clamped);
  }

  void _set(double scale, Offset offset) {
    final s = scale.clamp(1.0, ReaderZoom.maxScale);
    final clamped = Offset(
      offset.dx.clamp(math.min(0.0, _size.width * (1 - s)), 0.0),
      offset.dy.clamp(math.min(0.0, _size.height * (1 - s)), 0.0),
    );
    if (s == _scale && clamped == _offset) return;
    final wasZoomed = zoomed;
    setState(() {
      _scale = s;
      _offset = clamped;
    });
    if (wasZoomed != zoomed) widget.onZoomChanged?.call(zoomed);
  }

  void _animateTo(double scale, Offset offset) {
    _from = (scale: _scale, offset: _offset);
    _to = (scale: scale, offset: offset);
    _animation.forward(from: 0);
  }

  void _onAnimation() {
    final from = _from, to = _to;
    if (from == null || to == null) return;
    final t = Curves.easeOutCubic.transform(_animation.value);
    _set(from.scale + (to.scale - from.scale) * t, Offset.lerp(from.offset, to.offset, t)!);
  }

  void _onDoubleTap() {
    final at = _doubleTapAt ?? _size.center(Offset.zero);
    if (zoomed) {
      _animateTo(1, Offset.zero);
    } else {
      final target = _target(at, ReaderZoom.doubleTapScale);
      _animateTo(target.scale, target.offset);
    }
  }

  // Pinch from raw touch pointers: the first two fingers down.

  (Offset, double) get _focalAndSpan {
    final [a, b, ...] = _touches.values.toList();
    return ((a + b) / 2, (a - b).distance);
  }

  void _onPointerDown(PointerDownEvent event) {
    if (event.kind != PointerDeviceKind.touch && event.kind != PointerDeviceKind.stylus) return;
    _touches[event.pointer] = event.localPosition;
    if (_touches.length == 2) _startPinch();
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (!_touches.containsKey(event.pointer)) return;
    _touches[event.pointer] = event.localPosition;
    final pinch = _pinch;
    if (pinch == null) return;
    final (focal, span) = _focalAndSpan;
    final scale = (pinch.scale * span / pinch.span).clamp(1.0, ReaderZoom.maxScale);
    _set(scale, focal - pinch.scene * scale);
  }

  void _onPointerEnd(PointerEvent event) {
    if (_touches.remove(event.pointer) == null || _pinch == null) return;
    if (_touches.length >= 2) {
      _startPinch(); // A third finger lifted: continue with the remaining two.
    } else {
      _pinch = null;
      widget.onPinchChanged?.call(false);
    }
  }

  void _startPinch() {
    _animation.stop();
    final (focal, span) = _focalAndSpan;
    final started = _pinch == null;
    _pinch = (span: math.max(span, 1), scale: _scale, scene: _scene(focal));
    if (started) widget.onPinchChanged?.call(true);
  }

  void _onPanZoomStart(PointerPanZoomStartEvent event) {
    _animation.stop();
    _trackpad = (scale: _scale, scene: _scene(event.localPosition));
  }

  /// Trackpad pinch; two-finger scrolling (scale 1) is left to the scrollable and the drag recognizers.
  void _onPanZoomUpdate(PointerPanZoomUpdateEvent event) {
    final trackpad = _trackpad;
    if (trackpad == null || event.scale == 1) return;
    final scale = (trackpad.scale * event.scale).clamp(1.0, ReaderZoom.maxScale);
    _set(scale, event.localPosition - trackpad.scene * scale);
  }

  void _onPan(Offset delta) {
    if (_pinch == null) panBy(delta);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _size = constraints.biggest;
      final pan = zoomed ? widget.panAxis : null;
      return Listener(
        onPointerDown: _onPointerDown,
        onPointerMove: _onPointerMove,
        onPointerUp: _onPointerEnd,
        onPointerCancel: _onPointerEnd,
        onPointerPanZoomStart: _onPanZoomStart,
        onPointerPanZoomUpdate: _onPanZoomUpdate,
        onPointerPanZoomEnd: (_) => _trackpad = null,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: widget.onTap == null ? null : (details) => widget.onTap!(details.localPosition, _size),
          onDoubleTapDown: (details) => _doubleTapAt = details.localPosition,
          onDoubleTap: _onDoubleTap,
          onPanUpdate: pan == ReaderPanAxis.free ? (details) => _onPan(details.delta) : null,
          onHorizontalDragUpdate: pan == ReaderPanAxis.horizontal
              ? (details) => _onPan(Offset(details.delta.dx, 0))
              : null,
          child: ClipRect(
            child: Transform(
              transform: Matrix4.identity()
                ..translateByDouble(_offset.dx, _offset.dy, 0, 1)
                ..scaleByDouble(_scale, _scale, 1, 1),
              child: widget.child,
            ),
          ),
        ),
      );
    },
  );
}

/// Takes mouse-wheel events over [child] before the scrollable inside it when [resolve] returns a handler
/// (zoom with ctrl, pan while zoomed, page turns in paged modes).
///
/// The listener is a transparent layer above [child], not inside it: a scrollable ignores pointers on its content
/// while it animates, so a listener inside would miss events and the scrollable would take them instead (scrolling
/// off a page turn, then snapping back). Being hit first, the layer wins the pointer signal resolver; it does not
/// take part in gestures.
class ReaderWheelListener extends StatelessWidget {
  final void Function(PointerScrollEvent event)? Function(PointerScrollEvent event) resolve;
  final Widget child;

  const ReaderWheelListener({super.key, required this.resolve, required this.child});

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      child,
      Positioned.fill(
        child: Listener(
          behavior: HitTestBehavior.translucent,
          onPointerSignal: (event) {
            if (event is! PointerScrollEvent) return;
            final handler = resolve(event);
            if (handler == null) return;
            GestureBinding.instance.pointerSignalResolver.register(event, (e) => handler(e as PointerScrollEvent));
          },
        ),
      ),
    ],
  );
}
