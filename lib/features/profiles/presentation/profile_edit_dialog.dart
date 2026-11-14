import 'package:flutter/material.dart';

import '../../../app/widgets/text_field_arrow_escape.dart';
import '../../../core/localization.dart';
import '../domain/profile.dart';

typedef ProfileDraft = ({String name, int color});

/// Create/edit dialog: name + avatar color. Returns null when cancelled.
Future<ProfileDraft?> showProfileEditDialog(BuildContext context, {Profile? profile}) => showDialog<ProfileDraft>(
  context: context,
  builder: (_) => _ProfileEditDialog(profile: profile),
);

class _ProfileEditDialog extends StatefulWidget {
  final Profile? profile;

  const _ProfileEditDialog({this.profile});

  @override
  State<_ProfileEditDialog> createState() => _ProfileEditDialogState();
}

class _ProfileEditDialogState extends State<_ProfileEditDialog> {
  late final _name = TextEditingController(text: widget.profile?.name ?? '');
  late int _color = widget.profile?.colorSeed ?? profileColors[1];

  @override
  void initState() {
    super.initState();
    _name.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _save() {
    if (_name.text.trim().isEmpty) return;
    Navigator.of(context).pop<ProfileDraft>((name: _name.text.trim(), color: _color));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    return AlertDialog(
      title: Text(widget.profile == null ? l10n.profilesAdd : l10n.profilesEdit),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 16,
          children: [
            TextFieldArrowEscape(
              controller: _name,
              child: TextField(
                key: const Key('profileNameField'),
                controller: _name,
                autofocus: true,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _save(),
                decoration: InputDecoration(hintText: l10n.profilesName),
              ),
            ),
            Text(l10n.profilesColor, style: Theme.of(context).textTheme.titleSmall),
            FocusTraversalGroup(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final color in profileColors)
                    IconButton(
                      onPressed: () => setState(() => _color = color),
                      style: IconButton.styleFrom(backgroundColor: Color(color), fixedSize: const Size.square(44)),
                      icon: Icon(Icons.check, color: color == _color ? colors.surface : Colors.transparent),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(l10n.commonCancel)),
        FilledButton(onPressed: _name.text.trim().isEmpty ? null : _save, child: Text(l10n.commonSave)),
      ],
    );
  }
}
