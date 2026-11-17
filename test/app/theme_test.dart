import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/app/theme.dart';

void main() {
  testWidgets('all button types are pills (radius = height / 2)', (tester) async {
    final buttons = <Widget>[
      FilledButton(onPressed: () {}, child: const Text('filled')),
      FilledButton.tonal(onPressed: () {}, child: const Text('tonal')),
      ElevatedButton(onPressed: () {}, child: const Text('elevated')),
      OutlinedButton(onPressed: () {}, child: const Text('outlined')),
      TextButton(onPressed: () {}, child: const Text('text')),
      IconButton(onPressed: () {}, icon: const Icon(Icons.add)),
      IconButton.filledTonal(onPressed: () {}, icon: const Icon(Icons.tune)),
    ];
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(AppColorScheme.defaultScheme, brightness),
          home: Scaffold(body: Column(children: buttons)),
        ),
      );
      final shapes = tester.widgetList<Material>(
        find.descendant(of: find.byWidgetPredicate((w) => w is ButtonStyleButton), matching: find.byType(Material)),
      );
      expect(shapes, hasLength(buttons.length));
      for (final material in shapes) {
        expect(material.shape, isA<StadiumBorder>());
      }
    }
  });

  test('crimson uses the seed as primary with white text on it in both brightnesses', () {
    for (final brightness in Brightness.values) {
      final cs = buildColorScheme(AppColorScheme.crimson, brightness);
      expect(cs.primary, AppColorScheme.crimson.seed, reason: '$brightness');
      expect(cs.onPrimary, Colors.white, reason: '$brightness');
    }
  });

  test('selected switch thumb stays onPrimary (distinct from the track) in interactive states', () {
    for (final scheme in AppColorScheme.values) {
      for (final brightness in Brightness.values) {
        final theme = buildTheme(scheme, brightness);
        final cs = theme.colorScheme;
        for (final state in [WidgetState.hovered, WidgetState.focused, WidgetState.pressed]) {
          final thumb = theme.switchTheme.thumbColor!.resolve({WidgetState.selected, state});
          expect(thumb, cs.onPrimary, reason: '$scheme $brightness $state');
          expect(thumb, isNot(cs.primary), reason: '$scheme $brightness $state');
        }
        expect(theme.switchTheme.thumbColor!.resolve({WidgetState.selected, WidgetState.disabled}), isNull);
        expect(theme.switchTheme.thumbColor!.resolve({WidgetState.hovered}), isNull);
      }
    }
  });
}
