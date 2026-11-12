import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/config.dart';
import '../../../core/network/http_client.dart';
import '../../suppliers/domain/ffi_bundle_info.dart';
import '../domain/app_release.dart';
import '../domain/update_check.dart';

part 'update_repositories.g.dart';

class SupplierBundleInfoRepository {
  final http.Client client;
  final String url;

  const SupplierBundleInfoRepository(this.client, this.url);

  Future<FfiBundleInfo> fetchLatest() async {
    if (url.isEmpty) throw const UpdateCheckNotConfiguredException('FFI_LIB_VERSION_CHECK_URL');
    final body = await client.getText(Uri.parse(url));
    return FfiBundleInfo.fromJson((jsonDecode(body) as Map).cast<String, Object?>());
  }
}

class AppReleaseRepository {
  final http.Client client;
  final String url;

  const AppReleaseRepository(this.client, this.url);

  Future<AppRelease> fetchLatest() async {
    if (url.isEmpty) throw const UpdateCheckNotConfiguredException('APP_VERSION_CHECK_URL');
    final body = await client.getText(Uri.parse(url));
    final release = AppRelease.tryParse((jsonDecode(body) as Map).cast<String, Object?>());
    if (release == null) throw FormatException('Invalid release metadata', body);
    return release;
  }
}

@Riverpod(keepAlive: true)
SupplierBundleInfoRepository supplierBundleInfoRepository(Ref ref) =>
    SupplierBundleInfoRepository(ref.watch(httpClientProvider), AppConfig.ffiLibVersionCheckUrl);

@Riverpod(keepAlive: true)
AppReleaseRepository appReleaseRepository(Ref ref) =>
    AppReleaseRepository(ref.watch(httpClientProvider), AppConfig.appVersionCheckUrl);
