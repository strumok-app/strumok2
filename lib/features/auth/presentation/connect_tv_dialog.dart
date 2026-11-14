import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logging/logging.dart';

import '../../../core/localization.dart';
import 'auth_providers.dart';

final _log = Logger('ConnectTv');

/// Shows a pairing code for logging in a TV as the active profile's account (spec-04 §4.3).
Future<void> showConnectTvDialog(BuildContext context) =>
    showDialog<void>(context: context, builder: (_) => const ConnectTvDialog());

class ConnectTvDialog extends ConsumerStatefulWidget {
  const ConnectTvDialog({super.key});

  @override
  ConsumerState<ConnectTvDialog> createState() => _ConnectTvDialogState();
}

class _ConnectTvDialogState extends ConsumerState<ConnectTvDialog> {
  late Future<String> _code = _generate();

  Future<String> _generate() =>
      ref.read(accountControllerProvider.notifier).generatePairingCode().catchError((Object e) {
        _log.warning('Could not generate a pairing code', e);
        throw e;
      });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return AlertDialog(
      title: Text(l10n.connectTvTitle),
      content: SizedBox(
        width: 400,
        child: FutureBuilder(
          future: _code,
          builder: (context, snapshot) => switch (snapshot) {
            AsyncSnapshot(:final data?) => Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 16,
              children: [
                SelectableText(
                  data,
                  key: const Key('pairingCode'),
                  style: theme.textTheme.displayMedium?.copyWith(letterSpacing: 12, fontFamily: 'monospace'),
                ),
                Text(l10n.connectTvInstruction, textAlign: TextAlign.center),
              ],
            ),
            AsyncSnapshot(hasError: true) => Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 16,
              children: [
                Text(l10n.connectTvFailed, style: TextStyle(color: theme.colorScheme.error)),
                OutlinedButton(onPressed: () => setState(() => _code = _generate()), child: Text(l10n.commonRetry)),
              ],
            ),
            _ => const Padding(
              padding: EdgeInsets.all(24),
              // heightFactor keeps the dialog sized to the spinner instead of the full available height.
              child: Center(heightFactor: 1, child: CircularProgressIndicator()),
            ),
          },
        ),
      ),
      actions: [
        TextButton(autofocus: true, onPressed: () => Navigator.of(context).pop(), child: Text(l10n.commonClose)),
      ],
    );
  }
}
