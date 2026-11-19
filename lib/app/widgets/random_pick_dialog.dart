import 'dart:async';
import 'dart:math';

import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:logging/logging.dart';

import '../../core/localization.dart';
import '../../core/utils/random_pick.dart';
import '../router.dart';
import 'app_network_image.dart';
import 'content_card.dart';

final _log = Logger('RandomPick');

/// Shows a random item of [loadPool] with "Open", "Another one" and "Close"; "Open" goes to its details.
/// Items already shown are not repeated until all were shown. [weight] makes some items more likely.
Future<void> showRandomPickDialog<T extends ContentInfo>(
  BuildContext context, {
  required Future<List<T>> Function() loadPool,
  double Function(T)? weight,
  Random? random,
}) async {
  final picked = await showDialog<T>(
    context: context,
    builder: (_) => RandomPickDialog<T>(loadPool: loadPool, weight: weight, random: random),
  );
  if (picked != null && context.mounted) unawaited(context.push(AppRoutes.details(picked.supplier, picked.id)));
}

class RandomPickDialog<T extends ContentInfo> extends StatefulWidget {
  final Future<List<T>> Function() loadPool;
  final double Function(T)? weight;
  final Random? random;

  const RandomPickDialog({super.key, required this.loadPool, this.weight, this.random});

  @override
  State<RandomPickDialog<T>> createState() => _RandomPickDialogState<T>();
}

class _RandomPickDialogState<T extends ContentInfo> extends State<RandomPickDialog<T>> {
  static const _maxPosterWidth = 320.0;

  /// Dialog insets and content padding around the content.
  static const _chromeWidth = 128.0;

  /// Dialog insets, title, texts under the poster and buttons.
  static const _chromeHeight = 340.0;

  late final _random = widget.random ?? Random();
  final _openFocus = FocusNode(debugLabel: 'randomPickOpen');
  final _closeFocus = FocusNode(debugLabel: 'randomPickClose');
  List<T>? _pool;
  final _shown = <int>{};
  int? _current;

  @override
  void initState() {
    super.initState();
    // The pool may load more pages, which must not change providers while the dialog is being built.
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    _openFocus.dispose();
    _closeFocus.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    List<T> pool;
    try {
      pool = await widget.loadPool();
    } catch (e, st) {
      _log.warning('Random pick pool failed', e, st);
      pool = const [];
    }
    if (!mounted) return;
    setState(() {
      _pool = pool;
      _pickNext();
    });
    // Focus lands on the main action once there is a result (the dialog opens without one while loading).
    (_current == null ? _closeFocus : _openFocus).requestFocus();
  }

  void _pickNext() {
    final pool = _pool!;
    if (_shown.length >= pool.length) _shown.removeWhere((i) => i != _current);
    _current = pickRandomIndex(pool, _random, exclude: _shown, weight: widget.weight);
    if (_current case final index?) _shown.add(index);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final pool = _pool;
    final current = _current == null ? null : pool![_current!];

    // Fixed content width so long titles wrap instead of widening the dialog; the poster shrinks to fit short screens
    // (the rest of the dialog takes about [_chromeHeight]).
    final screen = MediaQuery.sizeOf(context);
    final contentWidth = min(_maxPosterWidth, screen.width - _chromeWidth);
    final posterWidth = min(contentWidth, max(96.0, (screen.height - _chromeHeight) * posterAspectRatio));

    final Widget content;
    if (pool == null) {
      content = const SizedBox(height: 120, child: Center(child: CircularProgressIndicator()));
    } else if (current == null) {
      content = Text(l10n.randomPickEmpty);
    } else {
      content = Column(
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          SizedBox(
            width: posterWidth,
            child: AspectRatio(
              aspectRatio: posterAspectRatio,
              child: ClipRRect(
                borderRadius: const BorderRadius.all(Radius.circular(16)),
                child: AppNetworkImage(current.image),
              ),
            ),
          ),
          Text(current.title, textAlign: TextAlign.center, style: theme.textTheme.titleMedium),
          Text(
            [?current.secondaryTitle, current.supplier].where((s) => s.isNotEmpty).join(' · '),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      );
    }

    return AlertDialog(
      title: Row(
        children: [
          Expanded(child: Text(l10n.rowPickRandom)),
          IconButton(
            key: const Key('randomPickClose'),
            focusNode: _closeFocus,
            tooltip: l10n.commonClose,
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close),
          ),
        ],
      ),
      content: SizedBox(
        width: contentWidth,
        child: SingleChildScrollView(child: content),
      ),
      actionsAlignment: MainAxisAlignment.spaceBetween,
      actions: current == null
          ? null
          : [
              OutlinedButton.icon(
                key: const Key('randomPickAnother'),
                onPressed: pool!.length > 1 ? () => setState(_pickNext) : null,
                icon: const Icon(Icons.casino_outlined),
                label: Text(l10n.randomPickAnother),
              ),
              FilledButton(
                key: const Key('randomPickOpen'),
                focusNode: _openFocus,
                onPressed: () => Navigator.of(context).pop(current),
                child: Text(l10n.randomPickOpen),
              ),
            ],
    );
  }
}
