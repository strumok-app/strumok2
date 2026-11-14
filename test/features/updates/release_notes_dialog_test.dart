import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/core/localization.dart';
import 'package:strumok/features/updates/domain/app_release.dart';
import 'package:strumok/features/updates/presentation/widgets/release_notes_dialog.dart';

void main() {
  final release = AppRelease.tryParse({
    'name': 'v1.32.0',
    'body': [for (var i = 0; i < 80; i++) '* change $i'].join('\r\n'),
    'assets': <Object>[],
  })!;

  Future<void> pumpDialog(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('uk'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) =>
              TextButton(onPressed: () => showReleaseNotesDialog(context, release), child: const Text('open')),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the release body with a focused close button', (tester) async {
    await pumpDialog(tester);

    expect(find.text('Що нового у версії 1.32.0'), findsOneWidget);
    expect(find.textContaining('* change 0\n* change 1'), findsOneWidget);
    final close = find.widgetWithText(TextButton, 'Закрити');
    expect(Focus.of(tester.element(find.text('Закрити'))).hasPrimaryFocus, isTrue);

    await tester.tap(close);
    await tester.pumpAndSettle();
    expect(find.byType(ReleaseNotesDialog), findsNothing);
  });

  testWidgets('arrow keys scroll the notes while focus stays on close', (tester) async {
    await pumpDialog(tester);
    final scrollable = tester.state<ScrollableState>(
      find.descendant(of: find.byType(ReleaseNotesDialog), matching: find.byType(Scrollable)),
    );
    expect(scrollable.position.pixels, 0);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, greaterThan(0));
    expect(Focus.of(tester.element(find.text('Закрити'))).hasPrimaryFocus, isTrue);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
    expect(scrollable.position.pixels, 0);
  });
}
