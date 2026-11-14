import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/widgets/text_field_arrow_escape.dart';
import '../../../core/localization.dart';
import '../domain/app_user.dart';
import '../domain/pairing_code.dart';
import 'account_flows.dart';
import 'auth_providers.dart';

/// Signs [profileId] in with a code generated on another device (spec-04 §4.3). Returns true when signed in.
Future<bool> showPairingCodeDialog(BuildContext context, String profileId) async =>
    await showDialog<bool>(
      context: context,
      builder: (_) => PairingCodeDialog(profileId: profileId),
    ) ??
    false;

class PairingCodeDialog extends ConsumerStatefulWidget {
  final String profileId;

  const PairingCodeDialog({super.key, required this.profileId});

  @override
  ConsumerState<PairingCodeDialog> createState() => _PairingCodeDialogState();
}

class _PairingCodeDialogState extends ConsumerState<PairingCodeDialog> {
  final _controller = TextEditingController();
  final _field = FocusNode(debugLabel: 'pairingCodeField');
  final _accept = FocusNode(debugLabel: 'pairingCodeAccept');
  var _busy = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
    _field.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _field.dispose();
    _accept.dispose();
    super.dispose();
  }

  bool get _valid => normalizePairingCode(_controller.text) != null;

  Future<void> _submit() async {
    if (_busy || !_valid) return;
    setState(() => _busy = true);
    final ok = await runAccountAction(
      context,
      ref,
      () => ref.read(accountControllerProvider.notifier).signInWithPairingCode(widget.profileId, _controller.text),
      onError: (e) => e is InvalidPairingCodeException ? context.l10n.pairingCodeInvalid : null,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop(true);
      return;
    }
    setState(() => _busy = false);
    _controller.selection = TextSelection(baseOffset: 0, extentOffset: _controller.text.length);
    _field.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    // Back from the field moves focus to the accept button instead of discarding the code (spec-04 §4.3).
    return PopScope(
      canPop: !_field.hasFocus && !_busy,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_busy) _accept.requestFocus();
      },
      child: AlertDialog(
        title: Text(l10n.pairingCodeTitle),
        content: SizedBox(
          width: 400,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: 16,
            children: [
              Text(l10n.pairingCodeInstruction),
              TextFieldArrowEscape(
                controller: _controller,
                child: TextField(
                  key: const Key('pairingCodeField'),
                  controller: _controller,
                  focusNode: _field,
                  autofocus: true,
                  enabled: !_busy,
                  textAlign: TextAlign.center,
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  enableSuggestions: false,
                  textInputAction: TextInputAction.done,
                  style: theme.textTheme.headlineMedium?.copyWith(letterSpacing: 8, fontFamily: 'monospace'),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
                    LengthLimitingTextInputFormatter(pairingCodeLength),
                    const _UpperCaseFormatter(),
                  ],
                  decoration: InputDecoration(labelText: l10n.pairingCodeLabel, counterText: ''),
                  onSubmitted: (_) => _valid ? _submit() : _accept.requestFocus(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: _busy ? null : () => Navigator.of(context).pop(false), child: Text(l10n.commonCancel)),
          FilledButton(
            key: const Key('pairingCodeSubmit'),
            focusNode: _accept,
            onPressed: _busy || !_valid ? null : _submit,
            child: _busy
                ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(l10n.accountSignIn),
          ),
        ],
      ),
    );
  }
}

class _UpperCaseFormatter extends TextInputFormatter {
  const _UpperCaseFormatter();

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}
