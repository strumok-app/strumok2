import 'model.dart';

abstract interface class ContentSupplier {
  String get name;
  Set<String> get channels;
  Set<String> get defaultChannels;
  Set<ContentType> get supportedTypes;
  Set<ContentLanguage> get supportedLanguages;

  /// [page] is 1-based.
  Future<List<ContentInfo>> search(String query, {int page = 1});

  /// [page] is 1-based.
  Future<List<ContentInfo>> loadChannel(String channel, {int page = 1});

  Future<ContentDetails?> detailsById(String id);
}

abstract interface class ContentSupplierBundle {
  Future<void> load();
  List<ContentSupplier> get suppliers;
  void unload();
}
