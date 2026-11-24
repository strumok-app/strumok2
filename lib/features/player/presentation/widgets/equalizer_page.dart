import 'dart:async';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization.dart';
import '../../../../core/platform/device_class.dart';
import '../../domain/equalizer.dart';
import '../player_controller.dart';
import '../player_settings.dart';

/// Equalizer page of the player settings (spec-06 §6.5): presets, a graphic equalizer (preamp + 10 bands) and the
/// loudness switches.
class EqualizerPage extends ConsumerWidget {
  const EqualizerPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final settings = ref.watch(playerSettingsProvider);
    final deviceClass = ref.watch(deviceClassProvider);
    final controller = ref.read(playerControllerProvider.notifier);
    final preset = settings.equalizerPreset;
    final tv = deviceClass == DeviceClass.tv;
    return ListView(
      children: [
        _PresetRow(current: preset, onSelected: (preset) => unawaited(controller.setEqualizer(preset.gains))),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: EqualizerGraph(
            gains: settings.equalizer,
            onChanged: (gains) => unawaited(controller.setEqualizer(gains)),
            adjustOnSelect: tv,
            haptics: deviceClass == DeviceClass.phone || deviceClass == DeviceClass.tablet,
            autofocus: preset == null,
          ),
        ),
        if (tv)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              l10n.playerEqualizerTvHint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
            ),
          ),
        const SizedBox(height: 8),
        SwitchListTile(
          key: const ValueKey('equalizer-volume-normalization'),
          title: Text(l10n.playerVolumeNormalization),
          subtitle: Text(l10n.playerVolumeNormalizationDescription),
          value: settings.volumeNormalization,
          onChanged: (value) => unawaited(controller.setVolumeNormalization(value)),
        ),
        SwitchListTile(
          key: const ValueKey('equalizer-dynamic-compression'),
          title: Text(l10n.playerDynamicCompression),
          subtitle: Text(l10n.playerDynamicCompressionDescription),
          value: settings.dynamicCompression,
          onChanged: (value) => unawaited(controller.setDynamicCompression(value)),
        ),
      ],
    );
  }
}

/// Preset chips wrapped to the available width; "Custom" leads them (not selectable) while the gains match no preset.
class _PresetRow extends StatelessWidget {
  final EqualizerPreset? current;
  final ValueChanged<EqualizerPreset> onSelected;

  const _PresetRow({required this.current, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return FocusTraversalGroup(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (current == null)
              ChoiceChip(
                key: const ValueKey('equalizer-custom'),
                label: Text(equalizerPresetLabel(l10n, null)),
                selected: true,
              ),
            for (final preset in EqualizerPreset.values)
              ChoiceChip(
                key: ValueKey('equalizer-${preset.name}'),
                label: Text(equalizerPresetLabel(l10n, preset)),
                selected: current == preset,
                autofocus: current == preset,
                onSelected: (_) => onSelected(preset),
              ),
          ],
        ),
      ),
    );
  }
}

/// Graphic equalizer: the preamp column, then one column per band with a curve through the band gains.
///
/// Drag a column (or wheel over it) to change its gain in 1 dB steps; double-tap resets it to 0. With the keyboard
/// ↑/↓ change the focused column. On TV ([adjustOnSelect]) arrows move focus as usual until OK enters adjust mode:
/// then ↑/↓ change the gain, ←/→ move to the neighbor column, and OK or Back leave adjust mode.
class EqualizerGraph extends StatefulWidget {
  static const height = 220.0;

  final EqualizerGains gains;
  final ValueChanged<EqualizerGains> onChanged;
  final bool adjustOnSelect;
  final bool haptics;

  /// Focus the first band initially (e.g. when no preset chip is selected to take focus).
  final bool autofocus;

  const EqualizerGraph({
    super.key,
    required this.gains,
    required this.onChanged,
    this.adjustOnSelect = false,
    this.haptics = false,
    this.autofocus = false,
  });

  @override
  State<EqualizerGraph> createState() => _EqualizerGraphState();
}

class _EqualizerGraphState extends State<EqualizerGraph> {
  static final _columns = 1 + equalizerFrequencies.length;
  static const _gap = 8.0;
  static const _bubbleHeight = 28.0;
  static const _labelHeight = 24.0;

  static final _activateKeys = {
    LogicalKeyboardKey.select,
    LogicalKeyboardKey.enter,
    LogicalKeyboardKey.numpadEnter,
    LogicalKeyboardKey.gameButtonA,
  };

  late final _nodes = [for (var i = 0; i < _columns; i++) FocusNode(debugLabel: 'equalizer-$i')];
  late EqualizerGains _gains = widget.gains;
  int? _focused;
  int? _hovered;
  int? _dragging;
  int? _adjusting;

  @override
  void didUpdateWidget(EqualizerGraph oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.gains != oldWidget.gains) _gains = widget.gains;
  }

  @override
  void dispose() {
    for (final node in _nodes) {
      node.dispose();
    }
    super.dispose();
  }

  /// Column 0 is the preamp; column i > 0 is band i − 1.
  double _gain(int column) => column == 0 ? _gains.preamp : _gains.bands[column - 1];

  void _set(int column, double gain) {
    final value = gain.clamp(-equalizerMaxGain, equalizerMaxGain).roundToDouble();
    if (value == _gain(column)) return;
    setState(() => _gains = column == 0 ? _gains.withPreamp(value) : _gains.withBand(column - 1, value));
    widget.onChanged(_gains);
  }

  void _setFromDrag(int column, double dy) {
    final trackHeight = EqualizerGraph.height - _bubbleHeight - _labelHeight;
    final fraction = ((dy - _bubbleHeight) / trackHeight).clamp(0.0, 1.0);
    final before = _gain(column);
    _set(column, equalizerMaxGain - fraction * 2 * equalizerMaxGain);
    final after = _gain(column);
    if (widget.haptics && after != before) {
      unawaited(after == 0 ? HapticFeedback.mediumImpact() : HapticFeedback.selectionClick());
    }
  }

  KeyEventResult _onKey(int column, KeyEvent event) {
    if (event is KeyUpEvent) return KeyEventResult.ignored;
    final key = event.logicalKey;
    final adjusting = _adjusting == column;
    if (widget.adjustOnSelect && _activateKeys.contains(key)) {
      if (event is KeyDownEvent) setState(() => _adjusting = adjusting ? null : column);
      return KeyEventResult.handled;
    }
    if (adjusting && (key == LogicalKeyboardKey.escape || key == LogicalKeyboardKey.goBack)) {
      if (event is KeyDownEvent) setState(() => _adjusting = null);
      return KeyEventResult.handled;
    }
    if (!widget.adjustOnSelect || adjusting) {
      if (key == LogicalKeyboardKey.arrowUp) {
        _set(column, _gain(column) + 1);
        return KeyEventResult.handled;
      }
      if (key == LogicalKeyboardKey.arrowDown) {
        _set(column, _gain(column) - 1);
        return KeyEventResult.handled;
      }
    }
    if (adjusting && (key == LogicalKeyboardKey.arrowLeft || key == LogicalKeyboardKey.arrowRight)) {
      final next = column + (key == LogicalKeyboardKey.arrowLeft ? -1 : 1);
      if (next >= 0 && next < _columns) {
        setState(() => _adjusting = next);
        _nodes[next].requestFocus();
      }
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _onFocusChange(int column, bool focused) => setState(() {
    if (focused) {
      _focused = column;
    } else {
      if (_focused == column) _focused = null;
      if (_adjusting == column) _adjusting = null;
    }
  });

  void _onScroll(int column, PointerSignalEvent event) {
    if (event is! PointerScrollEvent || event.scrollDelta.dy == 0) return;
    GestureBinding.instance.pointerSignalResolver.register(event, (event) {
      final delta = (event as PointerScrollEvent).scrollDelta.dy;
      _set(column, _gain(column) + (delta < 0 ? 1 : -1));
    });
  }

  String _columnLabel(AppLocalizations l10n, int column) =>
      column == 0 ? l10n.playerEqualizerPreamp : frequencyLabel(l10n, equalizerFrequencies[column - 1]);

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final active = _dragging ?? _focused ?? _hovered;
    return SizedBox(
      height: EqualizerGraph.height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final columnWidth = (constraints.maxWidth - _gap) / _columns;
          double centerOf(int column) => column == 0 ? columnWidth / 2 : _gap + columnWidth * (column + 0.5);
          return Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _GraphPainter(
                    gains: _gains,
                    centers: [for (var i = 0; i < _columns; i++) centerOf(i)],
                    top: _bubbleHeight,
                    bottom: EqualizerGraph.height - _labelHeight,
                    focused: _focused,
                    adjusting: _adjusting,
                    colors: theme.colorScheme,
                  ),
                ),
              ),
              Row(
                children: [
                  for (var i = 0; i < _columns; i++) ...[
                    if (i == 1) const SizedBox(width: _gap),
                    SizedBox(width: columnWidth, child: _column(l10n, theme, i)),
                  ],
                ],
              ),
              if (active != null) _bubble(theme, active, centerOf(active), constraints.maxWidth),
            ],
          );
        },
      ),
    );
  }

  Widget _column(AppLocalizations l10n, ThemeData theme, int column) {
    final gain = _gain(column);
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: column == _focused ? theme.colorScheme.primary : theme.colorScheme.onSurfaceVariant,
    );
    return Semantics(
      key: ValueKey(column == 0 ? 'equalizer-preamp' : 'equalizer-band-${column - 1}'),
      container: true,
      slider: true,
      label: _columnLabel(l10n, column),
      value: gainLabel(l10n, gain),
      increasedValue: gainLabel(l10n, (gain + 1).clamp(-equalizerMaxGain, equalizerMaxGain)),
      decreasedValue: gainLabel(l10n, (gain - 1).clamp(-equalizerMaxGain, equalizerMaxGain)),
      onIncrease: () => _set(column, gain + 1),
      onDecrease: () => _set(column, gain - 1),
      child: Focus(
        focusNode: _nodes[column],
        autofocus: widget.autofocus && column == 1,
        onKeyEvent: (_, event) => _onKey(column, event),
        onFocusChange: (focused) => _onFocusChange(column, focused),
        child: MouseRegion(
          cursor: SystemMouseCursors.resizeUpDown,
          onEnter: (_) => setState(() => _hovered = column),
          onExit: (_) => setState(() => _hovered = _hovered == column ? null : _hovered),
          child: Listener(
            onPointerSignal: (event) => _onScroll(column, event),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => _nodes[column].requestFocus(),
              onDoubleTap: () => _set(column, 0),
              onVerticalDragStart: (details) {
                _nodes[column].requestFocus();
                setState(() => _dragging = column);
                _setFromDrag(column, details.localPosition.dy);
              },
              onVerticalDragUpdate: (details) => _setFromDrag(column, details.localPosition.dy),
              onVerticalDragEnd: (_) => setState(() => _dragging = null),
              onVerticalDragCancel: () => setState(() => _dragging = null),
              child: Column(
                children: [
                  const Spacer(),
                  SizedBox(
                    height: _labelHeight,
                    child: Center(
                      child: column == 0
                          ? Icon(Icons.volume_up_outlined, size: 16, color: labelStyle?.color)
                          : Text(
                              frequencyShortLabel(l10n, equalizerFrequencies[column - 1]),
                              maxLines: 1,
                              overflow: TextOverflow.visible,
                              softWrap: false,
                              style: labelStyle,
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Gain of the active column above the graph; in adjust mode it also shows the ↑/↓ affordance.
  Widget _bubble(ThemeData theme, int column, double center, double width) {
    const bubbleWidth = 88.0;
    final adjusting = _adjusting == column;
    final background = adjusting ? theme.colorScheme.primary : theme.colorScheme.inverseSurface;
    final foreground = adjusting ? theme.colorScheme.onPrimary : theme.colorScheme.onInverseSurface;
    return Positioned(
      key: const ValueKey('equalizer-value'),
      top: 0,
      left: (center - bubbleWidth / 2).clamp(0.0, (width - bubbleWidth).clamp(0.0, double.infinity)),
      width: bubbleWidth,
      height: _bubbleHeight - 6,
      child: IgnorePointer(
        child: DecoratedBox(
          decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(11)),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (adjusting) Icon(Icons.unfold_more, size: 14, color: foreground),
                  Text(
                    gainLabel(context.l10n, _gain(column)),
                    style: theme.textTheme.labelMedium?.copyWith(color: foreground),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _GraphPainter extends CustomPainter {
  final EqualizerGains gains;
  final List<double> centers;
  final double top;
  final double bottom;
  final int? focused;
  final int? adjusting;
  final ColorScheme colors;

  _GraphPainter({
    required this.gains,
    required this.centers,
    required this.top,
    required this.bottom,
    required this.focused,
    required this.adjusting,
    required this.colors,
  });

  double _y(double gain) => top + (equalizerMaxGain - gain) / (2 * equalizerMaxGain) * (bottom - top);

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = colors.outlineVariant.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (final gain in [equalizerMaxGain, equalizerMaxGain / 2, -equalizerMaxGain / 2, -equalizerMaxGain]) {
      canvas.drawLine(Offset(0, _y(gain)), Offset(size.width, _y(gain)), grid);
    }
    final zero = _y(0);
    canvas.drawLine(
      Offset(0, zero),
      Offset(size.width, zero),
      Paint()
        ..color = colors.outline
        ..strokeWidth = 1.5,
    );
    final dividerX = (centers[0] + centers[1]) / 2;
    canvas.drawLine(Offset(dividerX, top - 4), Offset(dividerX, bottom + 4), grid);

    final points = [for (var i = 0; i < gains.bands.length; i++) Offset(centers[i + 1], _y(gains.bands[i]))];
    final curve = _smoothPath(points);
    final area = Path.from(curve)
      ..lineTo(points.last.dx, zero)
      ..lineTo(points.first.dx, zero)
      ..close();
    canvas.drawPath(area, Paint()..color = colors.primary.withValues(alpha: 0.14));
    canvas.drawPath(
      curve,
      Paint()
        ..color = colors.primary.withValues(alpha: 0.6)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2,
    );

    final track = Paint()
      ..color = colors.outlineVariant
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = colors.primary
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < centers.length; i++) {
      final x = centers[i];
      final gain = i == 0 ? gains.preamp : gains.bands[i - 1];
      final y = _y(gain);
      canvas.drawLine(Offset(x, top), Offset(x, bottom), track);
      if (gain != 0) canvas.drawLine(Offset(x, zero), Offset(x, y), fill);
      final radius = i == adjusting
          ? 10.0
          : i == focused
          ? 9.0
          : 7.0;
      canvas.drawCircle(Offset(x, y), radius, Paint()..color = colors.primary);
      canvas.drawCircle(
        Offset(x, y),
        radius,
        Paint()
          ..color = i == adjusting ? colors.onPrimary : colors.surface
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
  }

  /// Catmull-Rom spline through [points] as cubic Béziers.
  static Path _smoothPath(List<Offset> points) {
    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (var i = 0; i < points.length - 1; i++) {
      final p0 = points[i == 0 ? 0 : i - 1];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = points[i + 2 < points.length ? i + 2 : i + 1];
      final c1 = p1 + (p2 - p0) / 6;
      final c2 = p2 - (p3 - p1) / 6;
      path.cubicTo(c1.dx, c1.dy, c2.dx, c2.dy, p2.dx, p2.dy);
    }
    return path;
  }

  @override
  bool shouldRepaint(_GraphPainter old) =>
      old.gains != gains || old.focused != focused || old.adjusting != adjusting || old.colors != colors;
}
