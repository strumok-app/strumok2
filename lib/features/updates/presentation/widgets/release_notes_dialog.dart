import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/localization.dart';
import '../../domain/app_release.dart';

Future<void> showReleaseNotesDialog(BuildContext context, AppRelease release) => showDialog<void>(
  context: context,
  builder: (_) => ReleaseNotesDialog(release: release),
);

/// Shows the release description; Up/Down scroll the text while focus stays on "Close" (D-pad on TV).
class ReleaseNotesDialog extends StatefulWidget {
  final AppRelease release;

  const ReleaseNotesDialog({super.key, required this.release});

  @override
  State<ReleaseNotesDialog> createState() => _ReleaseNotesDialogState();
}

class _ReleaseNotesDialogState extends State<ReleaseNotesDialog> {
  static const _scrollStep = 120.0;
  final _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent || !_scroll.hasClients) return KeyEventResult.ignored;
    final delta = switch (event.logicalKey) {
      LogicalKeyboardKey.arrowDown => _scrollStep,
      LogicalKeyboardKey.arrowUp => -_scrollStep,
      _ => null,
    };
    if (delta == null) return KeyEventResult.ignored;
    final position = _scroll.position;
    final target = (position.pixels + delta).clamp(position.minScrollExtent, position.maxScrollExtent);
    _scroll.animateTo(target, duration: const Duration(milliseconds: 120), curve: Curves.easeOut);
    return KeyEventResult.handled;
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: _onKey,
      child: AlertDialog(
        title: Text(l10n.appUpdateReleaseNotesTitle(widget.release.version.toString())),
        content: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Scrollbar(
            controller: _scroll,
            child: SingleChildScrollView(controller: _scroll, child: Text(widget.release.notes ?? '')),
          ),
        ),
        actions: [
          TextButton(autofocus: true, onPressed: () => Navigator.of(context).pop(), child: Text(l10n.commonClose)),
        ],
      ),
    );
  }
}
