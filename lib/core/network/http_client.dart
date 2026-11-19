import 'dart:async';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'alpn_http_client.dart';

part 'http_client.g.dart';

const httpTimeout = Duration(seconds: 30);

/// Pure Dart client: HTTP/2 negotiated via ALPN, HTTP/1.1 fallback, pooled keep-alive connections.
/// Status codes are returned, not thrown (`package:http` semantics). Some APIs (GitHub) answer 403 without a User-Agent.
Future<http.Client> createHttpClient({required String appVersion}) async =>
    AlpnHttpClient(userAgent: 'Strumok/$appVersion (${Platform.operatingSystem})', connectTimeout: httpTimeout);

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
