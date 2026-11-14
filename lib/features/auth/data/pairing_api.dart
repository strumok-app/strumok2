import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';

import '../../../core/network/http_client.dart';
import '../domain/app_user.dart';

final _log = Logger('PairingApi');

/// Existing TV pairing cloud functions, unchanged (spec-04 §4.3).
class PairingApi {
  final http.Client client;
  final String domain;

  const PairingApi({required this.client, required this.domain});

  /// `https://{functionName.toLowerCase()}-{CLOUD_FUN_DOMAIN}`.
  Uri endpoint(String function) => Uri.parse('https://${function.toLowerCase()}-$domain');

  /// Code for logging in another device as the user owning [idToken].
  Future<String> generateCode(String idToken) async {
    final response = await _post(endpoint('generatecode'), headers: {'Authorization': 'Bearer $idToken'});
    if (response.statusCode >= 400) {
      _log.warning('generatecode failed: HTTP ${response.statusCode}');
      throw AuthFailedException('generatecode HTTP ${response.statusCode}');
    }
    return _field(response, 'code');
  }

  /// Firebase custom token for an upper-cased 6-character [code].
  Future<String> exchangeCode(String code) async {
    final response = await _post(endpoint('exchangecodefortoken'), body: {'code': code});
    if (response.statusCode >= 400) {
      _log.info('exchangecodefortoken rejected the code: HTTP ${response.statusCode}');
      throw const InvalidPairingCodeException();
    }
    return _field(response, 'token');
  }

  Future<http.Response> _post(Uri uri, {Map<String, String>? headers, Map<String, String>? body}) async {
    try {
      return await client.post(uri, headers: headers, body: body).timeout(httpTimeout);
    } catch (e) {
      throw AuthFailedException(e);
    }
  }

  static String _field(http.Response response, String name) {
    try {
      final value = (jsonDecode(response.body) as Map)[name];
      if (value is String && value.isNotEmpty) return value;
    } catch (_) {}
    throw AuthFailedException('Missing "$name" in response');
  }
}
