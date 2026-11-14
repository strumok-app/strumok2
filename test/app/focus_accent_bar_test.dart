import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/app/widgets/focus_accent_bar.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) => tester.pumpWidget(MaterialApp(home: Center(child: child)));

  testWidgets('accent bar sits outside the leading edge and grows on focus', (tester) async {
    const child = SizedBox(key: Key('card'), width: 300, height: 64);
    await pump(tester, const FocusAccentBar(focused: false, child: child));
    await tester.pumpAndSettle();
    final bar = find.descendant(of: find.byType(FocusAccentBar), matching: find.byType(AnimatedContainer));
    expect(tester.getSize(bar).height, 0);

    await pump(tester, const FocusAccentBar(focused: true, child: child));
    await tester.pumpAndSettle();
    final cardRect = tester.getRect(find.byKey(const Key('card')));
    final barRect = tester.getRect(bar);
    expect(barRect.height, 32);
    expect(barRect.right, lessThanOrEqualTo(cardRect.left - FocusAccentBar.offset + FocusAccentBar.width));
    expect(barRect.center.dy, cardRect.center.dy);
  });
}
