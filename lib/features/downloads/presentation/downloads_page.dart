import 'package:flutter/material.dart';

import '../../../app/widgets/not_implemented_view.dart';
import '../../../core/localization.dart';

class DownloadsPage extends StatelessWidget {
  const DownloadsPage({super.key});

  @override
  Widget build(BuildContext context) => NotImplementedView(title: context.l10n.navDownloads);
}
