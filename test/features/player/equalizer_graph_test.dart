import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/core/localization.dart';
import 'package:strumok/features/player/domain/equalizer.dart';
import 'package:strumok/features/player/presentation/widgets/equalizer_page.dart';

void main() {
  late EqualizerGains gains;

  Future<void> pumpGraph(WidgetTester tester, {bool adjustOnSelect = false}) async {
    gains = EqualizerGains.flat;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('uk'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox.square(
                dimension: 24,
                child: InkWell(key: const ValueKey('above'), autofocus: true, onTap: () {}),
              ),
              SizedBox(
                width: 360,
                child: StatefulBuilder(
                  builder: (context, setState) => EqualizerGraph(
                    gains: gains,
                    adjustOnSelect: adjustOnSelect,
                    onChanged: (value) => setState(() => gains = value),
                  ),
                ),
              ),
              SizedBox.square(
                dimension: 24,
                child: InkWell(key: const ValueKey('below'), onTap: () {}),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> press(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyEvent(key);
    await tester.pumpAndSettle();
  }

  Key? focusedKey() {
    Key? key;
    FocusManager.instance.primaryFocus?.context?.visitAncestorElements((element) {
      key = element.widget.key is ValueKey<String> ? element.widget.key : null;
      return key == null;
    });
    return key;
  }

  testWidgets('tv: arrows move focus until OK enters adjust mode; then ↑/↓ change and ←/→ hop bands', (tester) async {
    await pumpGraph(tester, adjustOnSelect: true);
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(focusedKey(), const ValueKey('equalizer-preamp'));
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(focusedKey(), const ValueKey('equalizer-band-0'));
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(focusedKey(), const ValueKey('above'), reason: 'not adjusting: ↑ leaves the graph');
    expect(gains, EqualizerGains.flat);

    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(focusedKey(), const ValueKey('equalizer-band-0'));
    await press(tester, LogicalKeyboardKey.select);
    await press(tester, LogicalKeyboardKey.arrowUp);
    await press(tester, LogicalKeyboardKey.arrowUp);
    expect(gains.bands.first, 2);
    expect(find.descendant(of: find.byKey(const ValueKey('equalizer-value')), matching: find.text('+2 дБ')), findsOne);
    await press(tester, LogicalKeyboardKey.arrowRight);
    expect(focusedKey(), const ValueKey('equalizer-band-1'));
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(gains.bands.take(2), [2, -1], reason: 'still adjusting after ←/→');

    await press(tester, LogicalKeyboardKey.escape);
    expect(focusedKey(), const ValueKey('equalizer-band-1'), reason: 'Back only leaves adjust mode');
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(focusedKey(), const ValueKey('below'));
    expect(gains.bands.take(2), [2, -1]);
  });

  testWidgets('desktop: ↑/↓ change the focused column; wheel steps; double-tap resets; drag clamps', (tester) async {
    await pumpGraph(tester);
    final preamp = find.byKey(const ValueKey('equalizer-preamp'));
    final treble = find.byKey(const ValueKey('equalizer-band-9'));
    expect(find.descendant(of: treble, matching: find.text('16к')), findsOneWidget);

    await tester.tap(preamp);
    await tester.pump(kDoubleTapTimeout);
    await press(tester, LogicalKeyboardKey.arrowDown);
    expect(gains.preamp, -1);

    final pointer = TestPointer(1, PointerDeviceKind.mouse);
    await tester.sendEventToBinding(pointer.hover(tester.getCenter(treble)));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -20)));
    await tester.sendEventToBinding(pointer.scroll(const Offset(0, -20)));
    await tester.pumpAndSettle();
    expect(gains.bands.last, 2);

    await tester.tap(treble);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(treble);
    await tester.pumpAndSettle();
    expect(gains.bands.last, 0);

    await tester.drag(treble, const Offset(0, -1000));
    await tester.pumpAndSettle();
    expect(gains.bands.last, equalizerMaxGain);
    expect(gains.preamp, -1);
  });
}
