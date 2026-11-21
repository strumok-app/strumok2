// ignore_for_file: invalid_use_of_internal_member, invalid_use_of_protected_member

import 'dart:io';

import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated_io.dart';

import 'rust/frb_generated.dart';
import 'rust/frb_generated.io.dart';
import 'src/rust_supplier.dart';

/// Loads an external supplier bundle by path. `RustLib.init()` is never used: it would load the dummy lib
/// and is a singleton, which prevents hot swapping bundles (spec-02 §2.4).
class RustContentSuppliersBundle implements ContentSupplierBundle {
  static const compatibleApiVersion = 5;

  final String directory;
  final String libName;

  _SuppliersEntrypoint? _entrypoint;
  ExternalLibrary? _library;
  List<ContentSupplier> _suppliers = const [];

  RustContentSuppliersBundle({required this.directory, required this.libName});

  static String libFileName(String libName) => Platform.isWindows ? '$libName.dll' : 'lib$libName.so';

  String get libPath => '$directory${Platform.pathSeparator}${libFileName(libName)}';

  @override
  List<ContentSupplier> get suppliers => _suppliers;

  @override
  Future<void> load() async {
    if (_entrypoint != null) return;

    final path = libPath;
    if (!File(path).existsSync()) {
      throw ContentSuppliersException('Rust Suppliers lib not found in path: $path');
    }

    final library = ExternalLibrary.open(path);
    final entrypoint = _SuppliersEntrypoint();
    try {
      await entrypoint.initImpl(externalLibrary: library, forceSameCodegenVersion: false);
    } catch (e) {
      library.ffiDynamicLibrary.close();
      throw ContentSuppliersException('FFI load failed [path=$path] error: $e');
    }

    final api = entrypoint.api;
    _suppliers = [for (final name in api.crateApiAvalaibleSuppliers()) RustContentSupplier(name: name, api: api)];
    _entrypoint = entrypoint;
    _library = library;
  }

  @override
  void unload() {
    _suppliers = const [];
    _entrypoint?.disposeImpl();
    _library?.ffiDynamicLibrary.close();
    _entrypoint = null;
    _library = null;
  }
}

class _SuppliersEntrypoint extends BaseEntrypoint<RustLibApi, RustLibApiImpl, RustLibWire> {
  @override
  ApiImplConstructor<RustLibApiImpl, RustLibWire> get apiImplConstructor => RustLibApiImpl.new;

  @override
  WireConstructor<RustLibWire> get wireConstructor => RustLibWire.fromExternalLibrary;

  @override
  Future<void> executeRustInitializers() async {
    await api.crateApiInitApp();
  }

  @override
  ExternalLibraryLoaderConfig get defaultExternalLibraryLoaderConfig => RustLib.kDefaultExternalLibraryLoaderConfig;

  @override
  String get codegenVersion => RustLib.instance.codegenVersion;

  @override
  int get rustContentHash => RustLib.instance.rustContentHash;
}
