import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:strumok/features/auth/data/pairing_api.dart';
import 'package:strumok/features/auth/domain/app_user.dart';
import 'package:strumok/features/auth/domain/pairing_code.dart';

void main() {
  test('pairing code: exactly 6 latin letters/digits, upper-cased (spec-04 §4.3)', () {
    expect(normalizePairingCode('ab12cd'), 'AB12CD');
    expect(normalizePairingCode(' AB12CD '), 'AB12CD');
    for (final invalid in ['ab12c', 'ab12cde', 'ab-12c', 'аб12cd', '']) {
      expect(normalizePairingCode(invalid), isNull, reason: invalid);
    }
  });

  group('PairingApi', () {
    late List<http.Request> requests;
    PairingApi api(http.Response Function(http.Request) respond) {
      requests = [];
      return PairingApi(
        domain: 'abc-ew.a.run.app',
        client: MockClient((request) async {
          requests.add(request);
          return respond(request);
        }),
      );
    }

    test('generatecode: POST with the Bearer ID token, no body', () async {
      final code = await api((_) => http.Response(jsonEncode({'code': 'AB12CD'}), 200)).generateCode('tok');
      expect(code, 'AB12CD');
      final request = requests.single;
      expect(request.method, 'POST');
      expect(request.url.toString(), 'https://generatecode-abc-ew.a.run.app');
      expect(request.headers['Authorization'], 'Bearer tok');
      expect(request.body, isEmpty);
    });

    test('exchangecodefortoken: form-encoded code', () async {
      final token = await api((_) => http.Response(jsonEncode({'token': 'custom'}), 200)).exchangeCode('AB12CD');
      expect(token, 'custom');
      final request = requests.single;
      expect(request.url.toString(), 'https://exchangecodefortoken-abc-ew.a.run.app');
      expect(request.headers['content-type'], startsWith('application/x-www-form-urlencoded'));
      expect(request.bodyFields, {'code': 'AB12CD'});
    });

    test('errors: rejected code, failed generation, malformed response', () async {
      await expectLater(
        api((_) => http.Response('nope', 404)).exchangeCode('AB12CD'),
        throwsA(isA<InvalidPairingCodeException>()),
      );
      await expectLater(api((_) => http.Response('', 500)).generateCode('t'), throwsA(isA<AuthFailedException>()));
      await expectLater(
        api((_) => http.Response('{}', 200)).exchangeCode('AB12CD'),
        throwsA(isA<AuthFailedException>()),
      );
    });
  });
}
