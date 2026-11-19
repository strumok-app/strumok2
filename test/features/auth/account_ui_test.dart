import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/app/router.dart';
import 'package:strumok/core/platform/device_class.dart';
import 'package:strumok/features/auth/domain/app_user.dart';
import 'package:strumok/features/auth/presentation/auth_providers.dart';
import 'package:strumok/features/profiles/presentation/profiles_providers.dart';
import 'package:strumok/features/settings/presentation/settings_page.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/test_app.dart';

void main() {
  const alice = AppUser(uid: 'u1', displayName: 'Alice');
  late FakeAuthBackend backend;

  setUp(() {
    backend = FakeAuthBackend()
      ..usersByIdToken['g-alice'] = alice
      ..usersByCustomToken['custom-alice'] = alice
      ..codes['AB12CD'] = 'custom-alice'
      ..generatedCodes['u1'] = 'ZX98YU';
  });

  Future<ProviderContainer> openAccountMenu(
    WidgetTester tester, {
    DeviceClass deviceClass = DeviceClass.desktop,
  }) async {
    final container = await pumpApp(
      tester,
      deviceClass: deviceClass,
      extraOverrides: authOverrides(
        backend,
        google: deviceClass == DeviceClass.tv ? null : FakeGoogleSignIn(idToken: 'g-alice'),
      ),
    );
    await tester.tap(find.byKey(const Key('accountMenuButton')));
    await tester.pumpAndSettle();
    return container;
  }

  testAppWidgets('desktop: Google sign-in only, no pairing code', (tester) async {
    await openAccountMenu(tester);
    expect(find.text('Ви не увійшли'), findsOneWidget);
    expect(find.byKey(const Key('accountSignInGoogle')), findsOneWidget);
    expect(find.byKey(const Key('accountSignInWithCode')), findsNothing);
  });

  testAppWidgets('tv: sign in with a code, then the menu shows the account actions', (tester) async {
    final container = await openAccountMenu(tester, deviceClass: DeviceClass.tv);
    expect(find.text('Ви не увійшли'), findsOneWidget);

    await tester.tap(find.byKey(const Key('accountSignInWithCode')));
    await tester.pumpAndSettle();
    final submit = find.byKey(const Key('pairingCodeSubmit'));
    await tester.enterText(find.byKey(const Key('pairingCodeField')), 'ab-12');
    await tester.pump();
    expect(tester.widget<FilledButton>(submit).onPressed, isNull, reason: 'filtered to "AB12", too short');

    await tester.enterText(find.byKey(const Key('pairingCodeField')), 'ab12cd');
    await tester.pump();
    expect(find.text('AB12CD'), findsOneWidget);
    await tester.tap(submit);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('pairingCodeField')), findsNothing);
    expect(find.text('Alice'), findsOneWidget);
    expect(find.byKey(const Key('accountSignOut')), findsOneWidget);
    expect(container.read(activeProfileProvider).firebaseUid, 'u1');
  });

  testAppWidgets('a rejected code shows a snackbar and keeps the dialog open', (tester) async {
    await openAccountMenu(tester, deviceClass: DeviceClass.tv);
    await tester.tap(find.byKey(const Key('accountSignInWithCode')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('pairingCodeField')), 'zzzzzz');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.text('Невірний або прострочений код'), findsOneWidget);
    expect(find.byKey(const Key('pairingCodeField')), findsOneWidget);
  });

  testAppWidgets('tv: no Google sign-in; back in the code field moves focus to the accept button', (tester) async {
    final container = await openAccountMenu(tester, deviceClass: DeviceClass.tv);
    expect(find.byKey(const Key('accountSignInGoogle')), findsNothing);

    await tester.tap(find.byKey(const Key('accountSignInWithCode')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('pairingCodeField')), 'ab12cd');
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('AB12CD'), findsOneWidget, reason: 'input is kept');
    final focused = FocusManager.instance.primaryFocus?.context?.findAncestorWidgetOfExactType<FilledButton>();
    expect(focused?.key, const Key('pairingCodeSubmit'));

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pairingCodeField')), findsNothing);
    expect(find.text('Alice'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    unawaited(container.read(routerProvider).push(AppRoutes.settings));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('accountConnectTv')), findsNothing, reason: 'TVs do not generate codes');
  });

  testAppWidgets('sign out from the account header returns to signed out', (tester) async {
    await openAccountMenu(tester);
    await tester.tap(find.byKey(const Key('accountSignInGoogle')));
    await tester.pumpAndSettle();
    expect(find.text('Alice'), findsOneWidget);

    await tester.tap(find.byKey(const Key('accountSignOut')));
    await tester.pumpAndSettle();
    expect(find.text('Ви не увійшли'), findsOneWidget);
    expect(find.byKey(const Key('accountSignOut')), findsNothing);
  });

  testAppWidgets('settings: connect TV shows the generated code only when signed in', (tester) async {
    final container = await openAccountMenu(tester);
    await tester.tap(find.descendant(of: find.byType(Dialog), matching: find.text('Налаштування')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('accountConnectTv'), skipOffstage: false), findsNothing);

    await container.read(accountControllerProvider.notifier).signInWithGoogle(container.read(activeProfileIdProvider));
    await tester.pumpAndSettle();
    final connectTv = find.byKey(const Key('accountConnectTv'));
    await tester.scrollUntilVisible(
      connectTv,
      200,
      scrollable: find.descendant(of: find.byType(SettingsPage), matching: find.byType(Scrollable)).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(connectTv);
    await tester.pump();
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    final dialogSurface = find.descendant(of: find.byType(AlertDialog), matching: find.byType(Material)).first;
    expect(tester.getSize(dialogSurface).height, lessThan(300), reason: 'loading keeps the dialog compact');
    await tester.pumpAndSettle();
    expect(find.text('ZX98YU'), findsOneWidget);
    await tester.tap(find.text('Закрити'));
    await tester.pumpAndSettle();
    expect(find.text('ZX98YU'), findsNothing);
  });

  testAppWidgets('an account linked to another profile offers to switch to it', (tester) async {
    final container = await openAccountMenu(tester);
    final other = await container.read(profilesProvider.notifier).create('Тато', 0);
    await container.read(profilesProvider.notifier).linkAccount(other.id, alice);
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('accountSignInGoogle')));
    await tester.pumpAndSettle();
    expect(find.textContaining('«Тато»'), findsOneWidget);
    await tester.tap(find.text('Перейти до профілю'));
    await tester.pumpAndSettle();
    expect(container.read(activeProfileIdProvider), other.id);
    expect(container.read(accountsAvailableProvider), isTrue);
  });

  testAppWidgets('manage profiles (tv): a non-active profile signs in with a code and out again', (tester) async {
    final container = await pumpApp(tester, deviceClass: DeviceClass.tv, extraOverrides: authOverrides(backend));
    final other = await container.read(profilesProvider.notifier).create('Діти', 0);
    container.read(profilePickPendingProvider.notifier).done();
    unawaited(container.read(routerProvider).push(AppRoutes.settingsProfiles));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(Key('profileSignIn-${other.id}')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('pairingCodeField')), 'ab12cd');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(find.textContaining('Alice'), findsOneWidget);
    expect(container.read(profilesProvider).firstWhere((p) => p.id == other.id).firebaseUid, 'u1');
    expect(container.read(activeProfileProvider).isLinked, isFalse, reason: 'the active profile is untouched');

    await tester.tap(find.byKey(Key('profileSignOut-${other.id}')));
    await tester.pumpAndSettle();
    expect(container.read(profilesProvider).firstWhere((p) => p.id == other.id).isLinked, isFalse);
  });
}
