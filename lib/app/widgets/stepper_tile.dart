import 'package:flutter/material.dart';

import '../../core/localization.dart';

/// Label with − value + buttons; D-pad friendly (←/→ between the buttons), unlike a slider.
class StepperTile extends StatelessWidget {
  final String label;
  final String value;
  final VoidCallback? onDecrease;
  final VoidCallback? onIncrease;
  final EdgeInsetsGeometry? contentPadding;

  const StepperTile({
    super.key,
    required this.label,
    required this.value,
    this.onDecrease,
    this.onIncrease,
    this.contentPadding,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListTile(
      contentPadding: contentPadding,
      title: Text(label),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(tooltip: l10n.playerDecrease, onPressed: onDecrease, icon: const Icon(Icons.remove)),
          SizedBox(
            width: 72,
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
            ),
          ),
          IconButton(tooltip: l10n.playerIncrease, onPressed: onIncrease, icon: const Icon(Icons.add)),
        ],
      ),
    );
  }
}
