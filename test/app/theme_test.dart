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
}
