import 'dart:math';

import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/widgets/app_network_image.dart';
import '../../../app/widgets/content_card.dart';
import '../../../app/widgets/content_row.dart';
import '../../../app/widgets/state_views.dart';
import '../../../core/localization.dart';
import 'details_providers.dart';
import 'details_widgets.dart';

/// Poster left / info right on wide screens; poster header + scroll on narrow ones (spec-01 Details).
class DetailsPage extends ConsumerWidget {
  final String supplier;
  final String id;

  const DetailsPage({super.key, required this.supplier, required this.id});

  static const _wideBreakpoint = 720.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = contentDetailsProvider(supplier, id);
    return switch (ref.watch(provider)) {
      AsyncData(:final value) => LayoutBuilder(
        builder: (context, constraints) => constraints.maxWidth >= _wideBreakpoint
            ? _WideDetails(details: value, viewport: constraints.biggest)
            : _NarrowDetails(details: value),
      ),
      AsyncError(:final error) => LoadErrorView(
        autofocus: true,
        message: error is ContentNotFoundException ? context.l10n.detailsNotFound : null,
        onRetry: () => ref.invalidate(provider),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

/// Two zones: scrolling content on the left, poster pinned on the right.
class _WideDetails extends StatelessWidget {
  final ContentDetails details;
  final Size viewport;

  const _WideDetails({required this.details, required this.viewport});

  static const _padding = 24.0;

  @override
  Widget build(BuildContext context) {
    // Poster fills the visible height, but never more than 40% of the width.
    final posterHeight = min(viewport.height - 2 * _padding, viewport.width * 0.4 / posterAspectRatio);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: _padding),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: _padding),
                child: DetailsInfo(details: details),
              ),
              ..._sections(details),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, _padding, _padding, _padding),
          child: SizedBox(
            height: posterHeight,
            width: posterHeight * posterAspectRatio,
            child: ClipRRect(
              borderRadius: const BorderRadius.all(Radius.circular(16)),
              child: AppNetworkImage(details.image),
            ),
          ),
        ),
      ],
    );
  }
}

class _NarrowDetails extends StatelessWidget {
  final ContentDetails details;

  const _NarrowDetails({required this.details});

  @override
  Widget build(BuildContext context) {
    final surface = Theme.of(context).colorScheme.surface;
    return ListView(
      children: [
        SizedBox(
          height: 320,
          child: Stack(
            fit: StackFit.expand,
            children: [
              AppNetworkImage(details.image),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [surface.withValues(alpha: 0), surface],
                    stops: const [0.5, 1],
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: DetailsInfo(details: details),
        ),
        ..._sections(details),
      ],
    );
  }
}

List<Widget> _sections(ContentDetails details) => [
  if (details.similar.isNotEmpty) _SimilarRow(details: details),
  const SizedBox(height: 24),
];

class _SimilarRow extends StatelessWidget {
  final ContentDetails details;

  const _SimilarRow({required this.details});

  @override
  Widget build(BuildContext context) => ContentRow.items(title: context.l10n.detailsSimilar, items: details.similar);
}
