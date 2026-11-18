import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:strumok/core/platform/single_instance.dart';

/// Another process holds the lock.
Future<bool> lockHeld(RandomAccessFile file) async => false;

void main() {
  late Directory dir;
  final instances = <SingleInstance>[];

  setUp(() => dir = Directory.systemTemp.createTempSync('single_instance'));

  tearDown(() async {
    for (final instance in instances) {
      await instance.dispose();
    }
    instances.clear();
    dir.deleteSync(recursive: true);
  });

  Future<SingleInstance> first() async {
    final instance = (await SingleInstance.acquire(dir))!;
    instances.add(instance);
    return instance;
  }

  Map<String, Object?> info() =>
      jsonDecode(File(p.join(dir.path, SingleInstance.infoFileName)).readAsStringSync()) as Map<String, Object?>;

  test('the first instance takes the lock and publishes its pid and port', () async {
    await first();
    expect(info()['pid'], pid);
    expect(info()['port'], isA<int>());
    expect(File(p.join(dir.path, SingleInstance.lockFileName)).existsSync(), isTrue);
  });

  test('a second instance asks the first to come to the front and quits', () async {
    final running = await first();
    final activated = running.activations.first;

    final second = await SingleInstance.acquire(dir, lock: lockHeld, processId: pid + 1);
    expect(second, isNull);
    await activated.timeout(const Duration(seconds: 5));
  });

  test('requests made before the app listens are delivered later', () async {
    final running = await first();
    expect(await SingleInstance.acquire(dir, lock: lockHeld, processId: pid + 1), isNull);
    expect(await SingleInstance.acquire(dir, lock: lockHeld, processId: pid + 2), isNull);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    final received = <void>[];
    final subscription = running.activations.listen(received.add);
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(received, hasLength(2));
    await subscription.cancel();
  });

  test('hot restart: the process holding the lock acquires it again', () async {
    final before = await first();
    final oldPort = info()['port'];
    final again = await SingleInstance.acquire(dir, lock: lockHeld);
    expect(again, isNotNull);
    instances.add(again!);
    expect(info()['port'], isNot(oldPort));
    expect(before, isNot(same(again)));
  });

  test('an unreachable running instance (no or stale info) still means quitting', () async {
    expect(await SingleInstance.acquire(dir, lock: lockHeld, processId: pid + 1), isNull);

    final unused = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = unused.port;
    await unused.close();
    File(p.join(dir.path, SingleInstance.infoFileName)).writeAsStringSync(jsonEncode({'pid': 1, 'port': port}));
    expect(await SingleInstance.acquire(dir, lock: lockHeld, processId: pid + 1), isNull);
  });
}
