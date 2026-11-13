import 'package:content_suppliers_api/content_suppliers_api.dart';

import 'localization.dart';

extension ContentLabels on AppLocalizations {
  String contentType(ContentType type) => switch (type) {
    ContentType.movie => contentTypeMovie,
    ContentType.anime => contentTypeAnime,
    ContentType.cartoon => contentTypeCartoon,
    ContentType.series => contentTypeSeries,
    ContentType.manga => contentTypeManga,
  };

  String contentLanguage(ContentLanguage language) => switch (language) {
    ContentLanguage.en => languageEn,
    ContentLanguage.uk => languageUk,
    ContentLanguage.ja => languageJa,
  };

  String mediaType(MediaType type) => switch (type) {
    MediaType.video => mediaTypeVideo,
    MediaType.manga => mediaTypeManga,
  };
}
