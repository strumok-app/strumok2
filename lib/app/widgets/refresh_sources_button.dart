import 'package:flutter/material.dart';

import '../../core/localization.dart';

/// Loads an item's sources again (e.g. after links expired); used in source / translation side sheet headers.
class RefreshSourcesButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const RefreshSourcesButton({super.key = const Key('refreshSources'), required this.onPressed});

  @override
  Widget build(BuildContext context) =>
      IconButton(tooltip: context.l10n.commonRefreshSources, onPressed: onPressed, icon: const Icon(Icons.refresh));
}
