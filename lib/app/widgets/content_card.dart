import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router.dart';
import 'app_network_image.dart';

const posterAspectRatio = 2 / 3;

/// Poster card opening the details page. On focus (TV/keyboard) it scales up, shows a ring and scrolls into view.
class ContentCard extends StatefulWidget {
  final ContentInfo info;
  final double width;
  final bool autofocus;

  /// Replaces the secondary title (e.g. "Episode 3").
  final String? caption;

  /// 0..1 progress bar under the poster.
  final double? progress;

  /// Small label over the poster (e.g. supplier name).
  final String? badge;

  const ContentCard({
    super.key,
    required this.info,
    required this.width,
    this.autofocus = false,
    this.caption,
    this.progress,
    this.badge,
  });

  @override
  State<ContentCard> createState() => _ContentCardState();
}

class _ContentCardState extends State<ContentCard> {
  var _focused = false;

  void _onFocusChange(bool focused) {
    setState(() => _focused = focused);
    if (focused) {
      Scrollable.ensureVisible(context, alignment: 0.1, duration: const Duration(milliseconds: 150));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final info = widget.info;
    const radius = BorderRadius.all(Radius.circular(16));

    return SizedBox(
      width: widget.width,
      child: InkWell(
        autofocus: widget.autofocus,
        borderRadius: radius,
        focusColor: Colors.transparent,
        onFocusChange: _onFocusChange,
        onTap: () => context.push(AppRoutes.details(info.supplier, info.id)),
        child: AnimatedScale(
          scale: _focused ? 1.05 : 1,
          duration: const Duration(milliseconds: 120),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AspectRatio(
                aspectRatio: posterAspectRatio,
                child: Container(
                  foregroundDecoration: _focused
                      ? BoxDecoration(
                          borderRadius: radius,
                          border: Border.all(color: theme.colorScheme.onSurface, width: 3),
                        )
                      : null,
                  child: ClipRRect(
                    borderRadius: radius,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        AppNetworkImage(info.image),
                        if (widget.badge case final badge?)
                          Align(
                            alignment: Alignment.topLeft,
                            child: Container(
                              margin: const EdgeInsets.all(6),
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
                                borderRadius: const BorderRadius.all(Radius.circular(8)),
                              ),
                              child: Text(badge, style: theme.textTheme.labelSmall),
                            ),
                          ),
                        if (widget.progress case final progress? when progress > 0)
                          Align(
                            alignment: Alignment.bottomCenter,
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 4,
                              borderRadius: BorderRadius.zero,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(info.title, maxLines: 2, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall),
              if (widget.caption ?? info.secondaryTitle case final secondary? when secondary.isNotEmpty)
                Text(
                  secondary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
