import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization.dart';
import '../player_controller.dart';
import '../subtitle_size.dart';

/// Supplier subtitles over the video on one merged translucent black background; [bottom] lifts them above
/// visible controls. While the selected subtitles load, a placeholder line is shown instead.
class SubtitleOverlay extends ConsumerWidget {
  final double bottom;

  const SubtitleOverlay({super.key, required this.bottom});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final size = ref.watch(subtitleSizeProvider);
    final loading = ref.watch(playerControllerProvider.select((s) => s?.subtitleLoading ?? false));
    final style = TextStyle(fontSize: size, height: 1.2, color: Colors.white);
    return IgnorePointer(
      child: AnimatedPadding(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: EdgeInsets.fromLTRB(32, 0, 32, bottom),
        child: Align(
          alignment: Alignment.bottomCenter,
          child: loading
              ? SubtitleLines(
                  key: const Key('subtitleLoading'),
                  lines: [context.l10n.playerSubtitlesLoading],
                  style: style.copyWith(fontSize: size * 0.75, color: Colors.white70),
                )
              : ValueListenableBuilder(
                  valueListenable: ref.read(playerControllerProvider.notifier).subtitleLines,
                  builder: (context, lines, _) => lines.isEmpty
                      ? const SizedBox.shrink()
                      : SubtitleLines(key: const Key('subtitleText'), lines: lines, style: style),
                ),
        ),
      ),
    );
  }
}

/// Subtitles on a small surface (mini player, PiP): laid out on a [referenceWidth] canvas and scaled down, so they
/// keep their size relative to the picture.
class ScaledSubtitleOverlay extends StatelessWidget {
  static const referenceWidth = 960.0;

  const ScaledSubtitleOverlay({super.key});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final size = constraints.biggest;
      if (!size.isFinite || size.isEmpty) return const SizedBox.shrink();
      if (size.width >= referenceWidth) return const SubtitleOverlay(bottom: 24);
      return FittedBox(
        child: SizedBox(
          width: referenceWidth,
          height: referenceWidth * size.height / size.width,
          child: const SubtitleOverlay(bottom: 24),
        ),
      );
    },
  );
}

/// Centered lines whose backgrounds join into one shape: a corner is rounded only where it sticks out past the
/// neighboring line, and square where it meets a wider (or about as wide) one.
class SubtitleLines extends StatelessWidget {
  static const radius = 4.0;
  static const background = Color(0x99000000);
  static const _padding = EdgeInsets.symmetric(horizontal: 8, vertical: 2);

  final List<String> lines;
  final TextStyle style;

  const SubtitleLines({super.key, required this.lines, required this.style});

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final effective = DefaultTextStyle.of(context).style.merge(style);
      final textScaler = MediaQuery.textScalerOf(context);
      final direction = Directionality.of(context);
      final maxWidth = math.max(0.0, constraints.maxWidth - _padding.horizontal);
      final widths = [for (final line in lines) _measure(line, effective, textScaler, direction, maxWidth)];
      return Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (index, line) in lines.indexed)
            DecoratedBox(
              decoration: BoxDecoration(color: background, borderRadius: cornersFor(widths, index)),
              child: Padding(
                padding: _padding,
                child: Text(
                  line,
                  textAlign: TextAlign.center,
                  textWidthBasis: TextWidthBasis.longestLine,
                  style: style,
                ),
              ),
            ),
        ],
      );
    },
  );

  static double _measure(String text, TextStyle style, TextScaler scaler, TextDirection direction, double maxWidth) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textAlign: TextAlign.center,
      textDirection: direction,
      textScaler: scaler,
      textWidthBasis: TextWidthBasis.longestLine,
    )..layout(maxWidth: maxWidth);
    final width = painter.width;
    painter.dispose();
    return width;
  }

  /// Square where the neighbor is wider, or sticks out by less than the radius on each side (a tiny rounded
  /// notch would look broken).
  static BorderRadius cornersFor(List<double> widths, int index) {
    bool joins(int neighbor) =>
        neighbor >= 0 && neighbor < widths.length && widths[neighbor] >= widths[index] - 2 * radius;
    const round = Radius.circular(radius);
    return BorderRadius.vertical(
      top: joins(index - 1) ? Radius.zero : round,
      bottom: joins(index + 1) ? Radius.zero : round,
    );
  }
}
