import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/core/storage/offline_mode.dart';
import 'package:strumok/features/auth/domain/app_user.dart';
import 'package:strumok/features/auth/presentation/auth_providers.dart';
import 'package:strumok/features/collection/data/collection_repository.dart';
import 'package:strumok/features/collection/data/synced_collection_repository.dart';
import 'package:strumok/features/collection/domain/collection_item.dart';
import 'package:strumok/features/collection/presentation/collection_providers.dart';
import 'package:strumok/features/profiles/presentation/profiles_providers.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/test_overrides.dart';

void main() {
  const alice = AppUser(uid: 'u1', displayName: 'Alice', email: 'a@example.com', photoUrl: 'https://p/a.png');
  late FakeAuthBackend backend;
  late FakeGoogleSignIn google;
  late Map<String, FakeRemoteCollection> remotes;

  setUp(() {
    backend = FakeAuthBackend()
      ..usersByIdToken['g-alice'] = alice
      ..usersByCustomToken['custom-alice'] = alice
      ..codes['AB12CD'] = 'custom-alice'
      ..generatedCodes['u1'] = 'ZX98YU';
    google = FakeGoogleSignIn(idToken: 'g-alice');
    remotes = {};
  });

  Future<ProviderContainer> container() async {
    final c = ProviderContainer(
      overrides: [
        ...await testOverrides(),
        ...authOverrides(backend, google: google, remotes: remotes),
      ],
    );
    addTearDown(c.dispose);
    c.listen(collectionItemsProvider, (_, _) {});
    return c;
  }

  AccountController controller(ProviderContainer c) => c.read(accountControllerProvider.notifier);

  test('Google sign-in links the active profile and syncs its collection', () async {
    remotes['u1'] = FakeRemoteCollection()
      ..items[collectionItemKey('s', 'm1')] = const CollectionItem(
        id: 'm1',
        supplier: 's',
        title: 'Remote',
        image: '',
        status: CollectionStatus.inProgress,
        lastSeen: 10,
      );
    final c = await container();
    final profileId = c.read(activeProfileIdProvider);

    await controller(c).signInWithGoogle(profileId);

    final profile = c.read(activeProfileProvider);
    expect((profile.firebaseUid, profile.accountName, profile.accountPhotoUrl), ('u1', 'Alice', 'https://p/a.png'));
    expect(await c.read(authUserProvider(profileId).future), alice);
    final repository = c.read(collectionRepositoryProvider);
    expect(repository, isA<SyncedCollectionRepository>());
    await (repository as SyncedCollectionRepository).attached;
    await pumpEventQueue();
    expect((await c.read(collectionItemsProvider.future)).keys, [collectionItemKey('s', 'm1')]);
  });

  test('an account can be linked to one profile only', () async {
    final c = await container();
    final first = c.read(activeProfileIdProvider);
    final second = (await c.read(profilesProvider.notifier).create('Second', 0)).id;
    await controller(c).signInWithGoogle(first);

    await expectLater(
      controller(c).signInWithGoogle(second),
      throwsA(isA<AccountAlreadyLinkedException>().having((e) => e.profileId, 'profileId', first)),
    );
    expect(c.read(profilesProvider).firstWhere((p) => p.id == second).isLinked, isFalse);
    expect(backend.session(second).currentUser, isNull, reason: 'the second session is signed out again');
  });

  test('pairing code sign-in validates, upper-cases and reports rejected codes', () async {
    final c = await container();
    final profileId = c.read(activeProfileIdProvider);

    await expectLater(
      controller(c).signInWithPairingCode(profileId, 'ab1'),
      throwsA(isA<InvalidPairingCodeException>()),
    );
    expect(backend.requests, isEmpty, reason: 'invalid input is not sent');
    await expectLater(
      controller(c).signInWithPairingCode(profileId, 'zzzzzz'),
      throwsA(isA<InvalidPairingCodeException>()),
    );

    await controller(c).signInWithPairingCode(profileId, 'ab12cd');
    expect(backend.requests.last.bodyFields, {'code': 'AB12CD'});
    expect(c.read(activeProfileProvider).firebaseUid, 'u1');
  });

  test('generating a TV code uses the ID token of the active account', () async {
    final c = await container();
    await controller(c).signInWithGoogle(c.read(activeProfileIdProvider));
    expect(await controller(c).generatePairingCode(), 'ZX98YU');
    expect(backend.requests.last.headers['Authorization'], 'Bearer id-token-u1');
  });

  test('sign-out unlinks the profile, keeps the local collection and stops syncing', () async {
    final c = await container();
    final profileId = c.read(activeProfileIdProvider);
    await controller(c).signInWithGoogle(profileId);
    await c.read(authUserProvider(profileId).future);
    await c
        .read(collectionItemsProvider.notifier)
        .save(const CollectionItem(id: 'x', supplier: 's', title: 'Local', image: '', status: CollectionStatus.latter));

    await controller(c).signOut(profileId);
    await pumpEventQueue();

    expect(c.read(activeProfileProvider).isLinked, isFalse);
    expect(google.signOuts, 1);
    expect(backend.session(profileId).currentUser, isNull);
    expect(c.read(collectionRepositoryProvider), isA<LocalCollectionRepository>());
    expect((await c.read(collectionItemsProvider.future)).keys, [collectionItemKey('s', 'x')]);
  });

  test('a lost session unlinks the profile', () async {
    final c = await container();
    final profileId = c.read(activeProfileIdProvider);
    await controller(c).signInWithGoogle(profileId);
    c.listen(authUserProvider(profileId), (_, _) {});
    await pumpEventQueue();

    await backend.session(profileId).signOut();
    await pumpEventQueue();
    expect(c.read(activeProfileProvider).isLinked, isFalse);
  });

  test('offline mode keeps the collection local-only until it is turned off', () async {
    final c = await container();
    await controller(c).signInWithGoogle(c.read(activeProfileIdProvider));
    await pumpEventQueue();
    expect(c.read(collectionRepositoryProvider), isA<SyncedCollectionRepository>());

    await c.read(offlineModeProvider.notifier).set(true);
    expect(c.read(collectionRepositoryProvider), isA<LocalCollectionRepository>());

    await c.read(offlineModeProvider.notifier).set(false);
    expect(c.read(collectionRepositoryProvider), isA<SyncedCollectionRepository>());
  });

  test('cancelled Google consent changes nothing', () async {
    google.error = const AuthCancelledException();
    final c = await container();
    await expectLater(
      controller(c).signInWithGoogle(c.read(activeProfileIdProvider)),
      throwsA(isA<AuthCancelledException>()),
    );
    expect(c.read(activeProfileProvider).isLinked, isFalse);
  });
}
