import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:rhttp/rhttp.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'http_client.g.dart';

const httpTimeout = Duration(seconds: 30);

/// Rust (reqwest) client: HTTP/2 negotiated via ALPN, HTTP/1.1 fallback, pooled keep-alive connections.
/// Status codes are returned, not thrown, to keep `package:http` semantics.
/// reqwest sends no User-Agent by default and some APIs (GitHub) answer 403 without one.
Future<http.Client> createHttpClient({required String appVersion}) async {
  await Rhttp.init();
  return RhttpCompatibleClient.create(
    settings: ClientSettings(
      httpVersionPref: HttpVersionPref.all,
      throwOnStatusCode: false,
      userAgent: 'Strumok/$appVersion (${Platform.operatingSystem})',
      timeoutSettings: const TimeoutSettings(connectTimeout: httpTimeout, keepAliveTimeout: Duration(seconds: 90)),
    ),
  );
}

/// The single HTTP client for app code (suppliers do their own networking in Rust); created in main().
@Riverpod(keepAlive: true)
http.Client httpClient(Ref ref) => throw UnimplementedError('httpClientProvider must be overridden in main()');

class HttpStatusException implements IOException {
  final Uri uri;
  final int statusCode;

  const HttpStatusException(this.uri, this.statusCode);

  @override
  String toString() => 'HTTP $statusCode for $uri';
}

extension HttpClientGetText on http.Client {
  Future<String> getText(Uri uri, {Map<String, String>? headers}) async {
    final response = await get(uri, headers: headers).timeout(httpTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpStatusException(uri, response.statusCode);
    }
    return response.body;
  }
}
