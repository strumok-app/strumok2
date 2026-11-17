import 'dart:math';

import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:strumok/app/widgets/trailing_fade.dart';

import '../../../app/widgets/app_network_image.dart';
import '../../../app/widgets/content_card.dart';
import '../../../app/widgets/content_row.dart';
import '../../../app/widgets/state_views.dart';
import '../../../core/localization.dart';
import '../../collection/presentation/collection_providers.dart';
import '../../suppliers/data/supplier_registry.dart';
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
      AsyncError(:final error, isLoading: false) => _DetailsError(
        supplier: supplier,
        id: id,
        error: error is ProviderException ? error.exception : error,
        onRetry: () => ref.invalidate(provider),
      ),
      _ => const Center(child: CircularProgressIndicator()),
    };
  }
}

/// Content gone or its supplier missing from the library: offer removing the stale collection item.
class _DetailsError extends ConsumerWidget {
  final String supplier;
  final String id;
  final Object error;
  final VoidCallback onRetry;

  const _DetailsError({required this.supplier, required this.id, required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final gone = error is ContentNotFoundException || error is SupplierNotFoundException;
    final item = gone ? ref.watch(collectionItemProvider(supplier, id)) : null;
    return LoadErrorView(
      autofocus: true,
      message: switch (error) {
        ContentNotFoundException() => l10n.detailsNotFound,
        SupplierNotFoundException() => l10n.detailsSupplierUnavailable(supplier),
        _ => null,
      },
      onRetry: onRetry,
      action: item == null
          ? null
          : TextButton.icon(
              icon: const Icon(Icons.bookmark_remove_outlined),
              label: Text(l10n.collectionRemove),
              onPressed: () async {
                await ref.read(collectionItemsProvider.notifier).remove(item.key);
                if (context.mounted) await Navigator.of(context).maybePop();
              },
            ),
    );
  }
}

/// Two zones: scrolling content on the left, poster pinned on the right. The poster is flush with the
/// pane's top, trailing and bottom edges; the pane's rounded clip shapes its corners. Horizontal rows end at the
/// poster's edge and fade out there, so cards scrolling towards the poster dissolve instead of being cut by it.
class _WideDetails extends StatelessWidget {
  final ContentDetails details;
  final Size viewport;

  const _WideDetails({required this.details, required this.viewport});

  static const _padding = 24.0;

  @override
  Widget build(BuildContext context) {
    // Full height at poster ratio, but never wider than 40% of the pane (then cropped by `cover`).
    final posterWidth = min(viewport.height * posterAspectRatio, viewport.width * 0.4);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(vertical: _padding),
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: _padding),
                child: DetailsInfo(details: details),
              ),
              for (var section in _sections(details)) TrailingFade(child: section),
            ],
          ),
        ),
        SizedBox(width: posterWidth, child: AppNetworkImage(details.image)),
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
