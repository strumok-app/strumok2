import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/app/widgets/reveal_on_focus.dart';

void main() {
  late ScrollController controller;

  Future<void> pump(WidgetTester tester, {required double viewport, required int groupButtons}) async {
    tester.view.physicalSize = Size(800, viewport);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    controller = ScrollController();
    addTearDown(controller.dispose);

    Widget button(String key) => SizedBox(
      height: 100,
      child: TextButton(key: Key(key), onPressed: () {}, child: Text(key)),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ListView(
            controller: controller,
            children: [
              for (var i = 0; i < 3; i++) button('before$i'),
              RevealOnFocus(
                margin: 0,
                child: Column(
                  children: [
                    const SizedBox(height: 150, child: Text('group title')),
                    for (var i = 0; i < groupButtons; i++) button('in$i'),
                  ],
                ),
              ),
              for (var i = 0; i < 6; i++) button('after$i'),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> focusAndMoveUp(WidgetTester tester, String from) async {
    Focus.of(tester.element(find.text(from))).requestFocus();
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.pumpAndSettle();
  }

  setUp(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.alwaysTraditional);
  tearDown(() => FocusManager.instance.highlightStrategy = FocusHighlightStrategy.automatic);

  testWidgets('entering a group from below reveals its title', (tester) async {
    await pump(tester, viewport: 400, groupButtons: 1);
    controller.jumpTo(600);
    await tester.pumpAndSettle();
    await focusAndMoveUp(tester, 'after0');

    // Group spans 300..550 and fits: the title (300..450) must be on screen.
    expect(controller.offset, lessThanOrEqualTo(300));
    expect(tester.getRect(find.text('group title')).top, greaterThanOrEqualTo(0));
  });

  testWidgets('a group taller than the viewport scrolls to its start while the focused item stays visible', (
    tester,
  ) async {
    await pump(tester, viewport: 300, groupButtons: 4);
    controller.jumpTo(800);
    await tester.pumpAndSettle();
    await focusAndMoveUp(tester, 'after0');

    // Group spans 300..850; focused in3 spans 750..850, so the closest offset to 300 that keeps it visible is 550.
    expect(controller.offset, 550);
  });

  testWidgets('moving inside a group does not scroll further', (tester) async {
    await pump(tester, viewport: 600, groupButtons: 2);
    Focus.of(tester.element(find.text('in0'))).requestFocus();
    await tester.pumpAndSettle();
    final offset = controller.offset;

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pumpAndSettle();
    expect(controller.offset, offset);
  });
}
