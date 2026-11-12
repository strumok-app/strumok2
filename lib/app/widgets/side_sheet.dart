import 'dart:math';

import 'package:flutter/material.dart';

/// Panel sliding in from the trailing edge; Escape/back, a tap outside or the close button dismisses it.
Future<T?> showSideSheet<T>(BuildContext context, {required String title, required WidgetBuilder builder}) =>
    showGeneralDialog<T>(
      context: context,
      barrierDismissible: true,
      barrierLabel: MaterialLocalizations.of(context).modalBarrierDismissLabel,
      barrierColor: Colors.black54,
      transitionDuration: const Duration(milliseconds: 220),
      pageBuilder: (context, _, _) => SideSheet(title: title, child: builder(context)),
      transitionBuilder: (_, animation, _, child) => SlideTransition(
        position: Tween(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
        child: child,
      ),
    );

class SideSheet extends StatelessWidget {
  final String title;
  final Widget child;

  const SideSheet({super.key, required this.title, required this.child});

  static const maxWidth = 420.0;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: SizedBox(
        width: min(maxWidth, screenWidth),
        height: double.infinity,
        child: Material(
          color: theme.colorScheme.surfaceContainerLow,
          borderRadius: screenWidth > maxWidth
              ? const BorderRadiusDirectional.horizontal(start: Radius.circular(28))
              : null,
          clipBehavior: Clip.antiAlias,
          child: SafeArea(
            left: false,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 12, 4),
                  child: Row(
                    children: [
                      Expanded(child: Text(title, style: theme.textTheme.titleLarge)),
                      const CloseButton(),
                    ],
                  ),
                ),
                Expanded(child: child),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
