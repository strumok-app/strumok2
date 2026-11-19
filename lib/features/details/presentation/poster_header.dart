import 'dart:math';

import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter/material.dart';

import '../../../app/widgets/app_network_image.dart';
import '../../../app/widgets/content_card.dart';
import '../../../app/widgets/network_image_aspect_ratio.dart';
import '../../../app/widgets/reveal_on_focus.dart';
import 'details_widgets.dart';

/// Narrow details header: full-width poster at its own aspect ratio with the title on a dark scrim at the top
/// and the Watch action on a fade to `surface` at the bottom.
///
/// Tapping the poster toggles both bars.
///
/// The poster is never taller than [maxHeight] (then cropped by `cover`) so some info stays above the fold, and the
/// header grows past the poster's height when the title and actions need more room.
class PosterHeader extends StatefulWidget {
  final ContentDetails details;
  final double maxHeight;

  const PosterHeader({super.key, required this.details, required this.maxHeight});

  @override
  State<PosterHeader> createState() => _PosterHeaderState();
}

class _PosterHeaderState extends State<PosterHeader> {
  static const _resizeDuration = Duration(milliseconds: 200);
  static const _fadeDuration = Duration(milliseconds: 200);

  /// Title bar and Watch bar; tapping the poster hides them to show it uncovered.
  var _barsVisible = true;

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return NetworkImageAspectRatio(
      url: widget.details.image,
      builder: (context, aspectRatio, unavailable) => LayoutBuilder(
        builder: (context, constraints) {
          // Until the poster is decoded it is assumed portrait.
          final posterHeight = unavailable
              ? 0.0
              : min(constraints.maxWidth / (aspectRatio ?? posterAspectRatio), widget.maxHeight);
          return TweenAnimationBuilder<double>(
            tween: Tween(end: posterHeight),
            duration: _resizeDuration,
            curve: Curves.easeOutCubic,
            builder: (context, height, child) => ConstrainedBox(
              constraints: BoxConstraints(minHeight: height),
              child: child,
            ),
            // Tight at max(poster height, title + actions) so the actions sit at the bottom either way.
            child: IntrinsicHeight(
              child: RevealOnFocus(
                margin: 0,
                child: GestureDetector(
                  key: const Key('posterHeader'),
                  behavior: HitTestBehavior.opaque,
                  onTap: unavailable ? null : () => setState(() => _barsVisible = !_barsVisible),
                  child: Stack(
                    children: [
                      Positioned.fill(child: AppNetworkImage(widget.details.image)),
                      AnimatedOpacity(
                        opacity: _barsVisible ? 1 : 0,
                        duration: _fadeDuration,
                        child: IgnorePointer(
                          ignoring: !_barsVisible,
                          child: ExcludeFocus(
                            excluding: !_barsVisible,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                DecoratedBox(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [Color(0xB3000000), Color(0x00000000)],
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                                    child: DetailsTitle(details: widget.details, overlay: true),
                                  ),
                                ),
                                const Spacer(),
                                DecoratedBox(
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      begin: Alignment.topCenter,
                                      end: Alignment.bottomCenter,
                                      colors: [surface.withValues(alpha: 0), surface.withValues(alpha: 0.85), surface],
                                      stops: const [0, 0.6, 1],
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(16, 48, 16, 8),
                                    child: WatchButton(details: widget.details),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
