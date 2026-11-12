---
name: riverpod-feature
description: 'Scaffold a new feature module (data/domain/presentation) with Riverpod code-generated providers, tests and l10n. Use when starting any new screen or service.'
---

# Riverpod feature scaffold

Rules: [architecture-and-state.instructions.md](../../instructions/architecture-and-state.instructions.md).

## Steps
1. Create `lib/features/<feature>/{data,domain,presentation}/`.
2. Domain: immutable models + pure logic (no Flutter/Firebase/FFI imports). Add unit tests first for non-trivial logic.
3. Data: repository interface in `domain/`, implementation in `data/`. Expose it:
   ```dart
   @Riverpod(keepAlive: true)
   FooRepository fooRepository(Ref ref) => FooRepositoryImpl(ref.watch(httpClientProvider));
   ```
4. Presentation state:
   ```dart
   @riverpod
   class FooController extends _$FooController {
     @override
     Future<FooState> build(FooKey key) async => ref.watch(fooRepositoryProvider).load(key);

     Future<void> doSomething() async {
       final repo = ref.read(fooRepositoryProvider);
       final next = await AsyncValue.guard(() => repo.update(...));
       if (!ref.mounted) return;
       state = next;
     }
   }
   ```
   Family keys must have value equality (records or Equatable).
5. Widgets: `ConsumerWidget`; render `AsyncValue` with loading / error (+Retry, focusable) / data.
   If layouts differ per device class, create `foo_screen.dart` (adaptive switch) + `foo_view_{mobile,desktop,tv}.dart`.
6. Strings → ARB (skill `localization-strings`).
7. Route registration in `lib/app/router.dart`.
8. Run: `dart run build_runner build -d && flutter analyze && flutter test`.

## Test template
```dart
final container = ProviderContainer(overrides: [
  fooRepositoryProvider.overrideWithValue(FakeFooRepository()),
]);
addTearDown(container.dispose);
expect(await container.read(fooControllerProvider(key).future), ...);
```
