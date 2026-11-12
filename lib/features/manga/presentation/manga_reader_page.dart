import 'package:flutter/material.dart';

import '../../../app/widgets/not_implemented_view.dart';
import '../../../core/localization.dart';

/// Full-screen; outside the app shell.
class MangaReaderPage extends StatelessWidget {
  final String supplier;
  final String id;

  /// Chapter index to open; null resumes from the collection (M3).
  final int? item;

  const MangaReaderPage({super.key, required this.supplier, required this.id, this.item});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(),
    body: NotImplementedView(title: context.l10n.readerTitle),
  );
}
