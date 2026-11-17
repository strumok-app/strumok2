import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Pinch / double-tap / ctrl+wheel zoom with panning over the whole reader viewport (spec-07). The content keeps
/// covering the viewport (no zooming out below 1). Taps are reported in viewport coordinates for tap zones.
class ReaderZoom extends StatefulWidget {
  static const maxScale = 4.0;
  static const doubleTapScale = 2.5;

  final Widget child;
  final void Function(Offset position, Size size)? onTap;
  final ValueChanged<bool>? onZoomChanged;

  const ReaderZoom({super.key, required this.child, this.onTap, this.onZoomChanged});

  static ReaderZoomState? maybeOf(BuildContext context) => context.findAncestorStateOfType<ReaderZoomState>();

  @override
  State<ReaderZoom> createState() => ReaderZoomState();
}

class ReaderZoomState extends State<ReaderZoom> with SingleTickerProviderStateMixin {
  late final _animation = AnimationController(vsync: this, duration: const Duration(milliseconds: 200))
    ..addListener(_onAnimation);

  double _scale = 1;
  Offset _offset = Offset.zero;
  Size _size = Size.zero;

  double _gestureScale = 1;
  Offset _gestureScene = Offset.zero;
  Offset? _doubleTapAt;
  ({double scale, Offset offset})? _from;
  ({double scale, Offset offset})? _to;

  bool get zoomed => _scale > 1.001;

  double get scale => _scale;

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

  ({double scale, Offset offset}) _target(Offset focal, double scale) {
    final clamped = scale.clamp(1.0, ReaderZoom.maxScale);
    final scene = (focal - _offset) / _scale;
    return (scale: clamped, offset: focal - scene * clamped);
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

  void _onScaleStart(ScaleStartDetails details) {
    _animation.stop();
    _gestureScale = _scale;
    _gestureScene = (details.localFocalPoint - _offset) / _scale;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    final scale = (_gestureScale * details.scale).clamp(1.0, ReaderZoom.maxScale);
    _set(scale, details.localFocalPoint - _gestureScene * scale);
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

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      _size = constraints.biggest;
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapUp: widget.onTap == null ? null : (details) => widget.onTap!(details.localPosition, _size),
        onDoubleTapDown: (details) => _doubleTapAt = details.localPosition,
        onDoubleTap: _onDoubleTap,
        onScaleStart: _onScaleStart,
        onScaleUpdate: _onScaleUpdate,
        child: ClipRect(
          child: Transform(
            transform: Matrix4.identity()
              ..translateByDouble(_offset.dx, _offset.dy, 0, 1)
              ..scaleByDouble(_scale, _scale, 1, 1),
            child: widget.child,
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
