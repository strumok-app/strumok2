import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/app/widgets/text_field_arrow_escape.dart';

void main() {
  late TextEditingController controller;
  late FocusNode field;

  setUp(() {
    controller = TextEditingController();
    field = FocusNode(debugLabel: 'field');
  });
  tearDown(() {
    controller.dispose();
    field.dispose();
  });

  Widget button(String label) => TextButton(key: Key(label), onPressed: () {}, child: Text(label));

  Future<void> pumpLayout(WidgetTester tester, String text, {int? caret}) async {
    controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: caret ?? text.length),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              button('up'),
              Row(
                children: [
                  button('left'),
                  Expanded(
                    child: TextFieldArrowEscape(
                      controller: controller,
                      child: TextField(controller: controller, focusNode: field),
                    ),
                  ),
                  button('right'),
                ],
              ),
              button('down'),
            ],
          ),
        ),
      ),
    );
    field.requestFocus();
    await tester.pump();
    controller.selection = TextSelection.collapsed(offset: caret ?? text.length);
    await tester.pump();
  }

  String? focused() {
    final primary = FocusManager.instance.primaryFocus;
    if (primary == field) return 'field';
    return primary?.context?.findAncestorWidgetOfExactType<TextButton>()?.key?.toString();
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pump();
  }

  testWidgets('up/down always leave the field', (tester) async {
    await pumpLayout(tester, 'abc', caret: 1);
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(focused(), "[<'up'>]");

    await pumpLayout(tester, 'abc', caret: 1);
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(focused(), "[<'down'>]");
  });

  testWidgets('left/right move the caret inside the text and leave from its boundary', (tester) async {
    await pumpLayout(tester, 'abc', caret: 1);
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(focused(), 'field');
    expect(controller.selection.baseOffset, 2);
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(controller.selection.baseOffset, 3);
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(focused(), "[<'right'>]");

    await pumpLayout(tester, 'abc', caret: 1);
    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(controller.selection.baseOffset, 0);
    expect(focused(), 'field');
    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(focused(), "[<'left'>]");
  });

  testWidgets('empty field lets left and right through', (tester) async {
    await pumpLayout(tester, '');
    await press(tester, LogicalKeyboardKey.arrowLeft);
    expect(focused(), "[<'left'>]");

    await pumpLayout(tester, '');
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(focused(), "[<'right'>]");
  });

  testWidgets('holding an arrow stops at the boundary', (tester) async {
    await pumpLayout(tester, 'abc', caret: 2);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();
    expect(focused(), 'field');
    expect(controller.selection.baseOffset, 3);
  });

  testWidgets('shift+arrow keeps selecting text', (tester) async {
    await pumpLayout(tester, 'abc', caret: 0);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await press(tester, LogicalKeyboardKey.arrowLeft);
    await press(tester, LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(focused(), 'field');
  });
}
