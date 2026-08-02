import 'package:flutter_test/flutter_test.dart';

import 'package:dramabox_free/presentation/pages/dramafren_webview_page.dart';

void main() {
  group('parseDramafrenShareLink', () {
    test('dramaboxdb.com episode share link', () {
      final parsed = parseDramafrenShareLink(
        'https://www.dramaboxdb.com/ar/ep/41000116643_divorced-at-the-wedding-day/594240384_Episode-1',
      );
      expect(parsed.id, '41000116643');
      expect(parsed.slug, 'divorced-at-the-wedding-day');
    });

    test('dramafren box detail link', () {
      final parsed = parseDramafrenShareLink(
        'https://dramabox.dramafren.org/index.php?page=detail&id=42000020487&lang=en&slug=some-slug',
      );
      expect(parsed.id, '42000020487');
      expect(parsed.slug, 'some-slug');
    });

    test('play.dramabox.com numeric id', () {
      final parsed = parseDramafrenShareLink(
        'https://play.dramabox.com/detail/41000116643',
      );
      expect(parsed.id, '41000116643');
      expect(parsed.slug, isNull);
    });

    test('bare numeric id', () {
      final parsed = parseDramafrenShareLink('41000116643');
      expect(parsed.id, '41000116643');
    });

    test('unknown link falls back to uri', () {
      final parsed = parseDramafrenShareLink(
        'https://example.com/random/page',
      );
      expect(parsed.id, isNull);
      expect(parsed.uri, isNotNull);
    });

    test('empty input', () {
      final parsed = parseDramafrenShareLink('');
      expect(parsed.id, isNull);
      expect(parsed.uri, isNull);
    });
  });

  group('dramafrenDetailPath', () {
    test('dramafren_dramabox uses index.php detail route', () {
      expect(
        dramafrenDetailPath(
          'dramafren_dramabox',
          '41000116643',
          'Divorced at the Wedding Day',
        ),
        'index.php?page=detail&id=41000116643&slug=divorced-at-the-wedding-day',
      );
    });

    test('shortwave uses plain query route', () {
      expect(
        dramafrenDetailPath('shortwave', '42', 'Some Drama'),
        'id=42&slug=some-drama',
      );
    });
  });
}
