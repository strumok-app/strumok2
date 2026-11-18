import 'package:content_suppliers_api/content_suppliers_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:strumok/features/downloads/domain/offline_layout.dart';

void main() {
  test('names follow the legacy offline layout', () {
    expect(OfflineLayout.contentDirName('uakino', 'films/123-name.html'), 'uakino_films%2F123-name.html');
    expect(OfflineLayout.videoFileName('Server 1 (UA)'), 'Server%201%20(UA).mp4');
    expect(OfflineLayout.subtitleFileName('Українські'), '${Uri.encodeComponent('Українські')}.vtt');
    expect(OfflineLayout.pagesDirName('UA team'), 'pages_UA%20team');
  });

  test('names are valid on Windows and decode back', () {
    final name = OfflineLayout.encode('a*b:c?"d|e<f>');
    expect(name, isNot(matches(RegExp(r'[*:?"|<>/\\]'))));
    expect(OfflineLayout.decode(name), 'a*b:c?"d|e<f>');
    expect(OfflineLayout.decode('100%'), '100%', reason: 'malformed escapes are kept');
  });

  test('page file names are ordered and keep the image extension', () {
    expect(OfflineLayout.pageFileName(0, 'https://img.example/ch/1.PNG?x=1'), '0001.png');
    expect(OfflineLayout.pageFileName(41, 'https://img.example/ch/42.webp'), '0042.webp');
    expect(OfflineLayout.pageFileName(9, 'https://img.example/page?id=5'), '0010.jpg');
  });

  group('parseContentDirName', () {
    test('splits at the first underscore by default', () {
      expect(OfflineLayout.parseContentDirName('uakino_films%2F1_2'), ('uakino', 'films/1_2'));
    });

    test('prefers the longest known supplier name', () {
      expect(OfflineLayout.parseContentDirName('anime_ua_show_1', suppliers: ['anime', 'anime_ua']), (
        'anime_ua',
        'show_1',
      ));
    });

    test('rejects names without a supplier or an id', () {
      expect(OfflineLayout.parseContentDirName('nounderscore'), isNull);
      expect(OfflineLayout.parseContentDirName('_x'), isNull);
      expect(OfflineLayout.parseContentDirName('alpha_'), isNull);
    });
  });

  test('details.json round trip and tolerant reading', () {
    const details = OfflineDetails(
      title: 'Title',
      secondaryTitle: 'Original',
      image: 'https://img.example/p.jpg',
      mediaType: MediaType.manga,
      additionalInfo: ['2024', 'Drama'],
      description: 'About',
    );
    expect(OfflineDetails.fromJson(details.toJson()), details);
    expect(details.toJson().keys, ['title', 'secondaryTitle', 'image', 'mediaType', 'additionalInfo', 'description']);
    expect(
      OfflineDetails.fromJson({'title': 'T'}),
      const OfflineDetails(title: 'T', image: '', mediaType: MediaType.video),
    );
  });
}
