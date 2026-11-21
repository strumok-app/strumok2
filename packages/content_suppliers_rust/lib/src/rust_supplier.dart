import 'package:content_suppliers_api/content_suppliers_api.dart';

import '../rust/frb_generated.dart';
import '../rust/models.dart' as rust;

class RustContentSupplier implements ContentSupplier {
  @override
  final String name;
  final RustLibApi _api;

  RustContentSupplier({required this.name, required RustLibApi api}) : _api = api;

  @override
  late final Set<String> channels = _sync('getChannels', () => _api.crateApiGetChannels(supplier: name)).toSet();

  @override
  late final Set<String> defaultChannels = _sync(
    'getDefaultChannels',
    () => _api.crateApiGetDefaultChannels(supplier: name),
  ).toSet();

  @override
  late final Set<ContentType> supportedTypes = _sync(
    'getSupportedTypes',
    () => _api.crateApiGetSupportedTypes(supplier: name),
  ).map(_mapContentType).nonNulls.toSet();

  @override
  late final Set<ContentLanguage> supportedLanguages = _sync(
    'getSupportedLanguages',
    () => _api.crateApiGetSupportedLanguages(supplier: name),
  ).map((lang) => ContentLanguage.values.asNameMap()[lang]).nonNulls.toSet();

  @override
  Future<List<ContentInfo>> search(String query, {int page = 1}) async {
    final res = await _async('search', null, () => _api.crateApiSearch(supplier: name, query: query, page: page));
    return res.map(_mapInfo).toList();
  }

  @override
  Future<List<ContentInfo>> loadChannel(String channel, {int page = 1}) async {
    final res = await _async(
      'loadChannel',
      null,
      () => _api.crateApiLoadChannel(supplier: name, channel: channel, page: page),
    );
    return res.map(_mapInfo).toList();
  }

  @override
  Future<ContentDetails?> detailsById(String id) async {
    final res = await _async('getContentDetails', id, () => _api.crateApiGetContentDetails(supplier: name, id: id));
    return res == null ? null : _RustContentDetails(this, id, res);
  }

  ContentInfo _mapInfo(rust.ContentInfo info) => _RustContentInfo(name, info);

  T _sync<T>(String op, T Function() fn) {
    try {
      return fn();
    } catch (e) {
      throw ContentSuppliersException('FFI $op Failed [supplier=$name] error: $e');
    }
  }

  Future<T> _async<T>(String op, String? id, Future<T> Function() fn) async {
    try {
      return await fn();
    } catch (e) {
      final idPart = id == null ? '' : ' id=$id';
      throw ContentSuppliersException('FFI $op Failed [supplier=$name$idPart] error: $e');
    }
  }
}

ContentType? _mapContentType(rust.ContentType type) => ContentType.values.asNameMap()[type.name.toLowerCase()];

class _RustContentInfo implements ContentInfo {
  @override
  final String supplier;
  final rust.ContentInfo _info;

  _RustContentInfo(this.supplier, this._info);

  @override
  String get id => _info.id;
  @override
  String get title => _info.title;
  @override
  String? get secondaryTitle => _info.secondaryTitle;
  @override
  String get image => _info.image;
}

class _RustContentDetails implements ContentDetails {
  final RustContentSupplier _supplier;
  @override
  final String id;
  final rust.ContentDetails _details;

  _RustContentDetails(this._supplier, this.id, this._details);

  @override
  String get supplier => _supplier.name;
  @override
  String get title => _details.title;
  @override
  String? get originalTitle => _details.originalTitle;
  @override
  String get image => _details.image;
  @override
  String get description => _details.description;
  @override
  MediaType get mediaType => switch (_details.mediaType) {
    rust.MediaType.video => MediaType.video,
    rust.MediaType.manga => MediaType.manga,
  };
  @override
  List<String> get additionalInfo => _details.additionalInfo;
  @override
  late final List<ContentInfo> similar = _details.similar.map(_supplier._mapInfo).toList();

  @override
  Future<List<ContentMediaItem>> get mediaItems => _mediaItems.get(_loadMediaItems);
  final _mediaItems = _SuccessCache<List<ContentMediaItem>>();

  Future<List<ContentMediaItem>> _loadMediaItems() async {
    final items =
        _details.mediaItems ??
        await _supplier._async<List<rust.ContentMediaItem>>(
          'loadMediaItems',
          id,
          () => _supplier._api.crateApiLoadMediaItems(supplier: supplier, id: id, params: _details.params),
        );
    return [for (final (i, item) in items.indexed) _RustContentMediaItem(_supplier, id, i, item)];
  }
}

class _RustContentMediaItem implements ContentMediaItem {
  final RustContentSupplier _supplier;
  final String _contentId;
  @override
  final int number;
  final rust.ContentMediaItem _item;

  _RustContentMediaItem(this._supplier, this._contentId, this.number, this._item);

  @override
  String get title => _item.title;
  @override
  String? get section => _item.section;
  @override
  String? get image => _item.image;

  @override
  Future<List<ContentMediaItemSource>> get sources => _sources.get(_loadSources);
  final _sources = _SuccessCache<List<ContentMediaItemSource>>();

  Future<List<ContentMediaItemSource>> _loadSources() async {
    final sources =
        _item.sources ??
        await _supplier._async<List<rust.ContentMediaItemSource>>(
          'loadMediaItemSources',
          _contentId,
          () => _supplier._api.crateApiLoadMediaItemSources(
            supplier: _supplier.name,
            id: _contentId,
            params: _item.params,
          ),
        );
    return [for (final source in sources) _mapSource(source)];
  }

  ContentMediaItemSource _mapSource(rust.ContentMediaItemSource source) => switch (source) {
    rust.ContentMediaItemSource_Video(
      :final link,
      :final description,
      :final headers,
      :final hlsProxy,
      :final language,
    ) =>
      _RustVideoSource(link, description, headers, hlsProxy, _mapLanguage(language)),
    rust.ContentMediaItemSource_Subtitle(:final link, :final description, :final headers, :final language) =>
      _RustSubtitleSource(link, description, headers, _mapLanguage(language)),
    rust.ContentMediaItemSource_Manga() => _RustMangaSource(_supplier, _contentId, source),
  };
}

ContentLanguage? _mapLanguage(String? language) =>
    language == null ? null : ContentLanguage.values.asNameMap()[language];

class _RustVideoSource extends VideoMediaItemSource {
  final String _link;
  @override
  final String description;
  @override
  final Map<String, String>? headers;
  @override
  final bool hlsProxy;
  @override
  final ContentLanguage? language;

  _RustVideoSource(this._link, this.description, this.headers, this.hlsProxy, this.language);

  @override
  Future<Uri> get link async => Uri.parse(_link);
}

class _RustSubtitleSource extends SubtitleMediaItemSource {
  final String _link;
  @override
  final String description;
  @override
  final Map<String, String>? headers;
  @override
  final ContentLanguage? language;

  _RustSubtitleSource(this._link, this.description, this.headers, this.language);

  @override
  Future<Uri> get link async => Uri.parse(_link);
}

class _RustMangaSource extends MangaMediaItemSource {
  final RustContentSupplier _supplier;
  final String _contentId;
  final rust.ContentMediaItemSource_Manga _source;

  _RustMangaSource(this._supplier, this._contentId, this._source);

  @override
  String get description => _source.description;
  @override
  Map<String, String>? get headers => _source.headers;
  @override
  ContentLanguage? get language => _mapLanguage(_source.language);

  @override
  Future<List<String>> get allPages => _pages.get(_loadPages);
  final _pages = _SuccessCache<List<String>>();

  Future<List<String>> _loadPages() async =>
      _source.pages ??
      await _supplier._async<List<String>>(
        'loadMangaPages',
        _contentId,
        () => _supplier._api.crateApiLoadMangaPages(supplier: _supplier.name, id: _contentId, params: _source.params),
      );
}

/// Caches a lazy load per object (spec-02 §2.3); a failed load is retried on the next access.
class _SuccessCache<T> {
  Future<T>? _future;

  Future<T> get(Future<T> Function() load) => _future ??= load().catchError((Object e, StackTrace st) {
    _future = null;
    Error.throwWithStackTrace(e, st);
  });
}
