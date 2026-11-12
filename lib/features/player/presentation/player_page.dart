import 'package:flutter/material.dart';

import '../../../app/widgets/not_implemented_view.dart';
import '../../../core/localization.dart';

/// Full-screen; outside the app shell.
class PlayerPage extends StatelessWidget {
  final String supplier;
  final String id;

  /// Media item index to start; null resumes from the collection (M3).
  final int? item;

  const PlayerPage({super.key, required this.supplier, required this.id, this.item});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: NotImplementedView(title: context.l10n.playerTitle),
  );
}
