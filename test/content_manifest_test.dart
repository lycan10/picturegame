import 'package:flutter_test/flutter_test.dart';
import 'package:picture_match/core/content_manifest.dart';

void main() {
  // Exact shape GET /content returns (verified against the worker).
  Map<String, dynamic> manifestWithLevels(int count) => {
        'version': 42,
        'worlds': [
          {'key': 'animals', 'title': 'Animal Kingdom'},
          {'key': 'countries', 'title': 'Flags of the World'},
        ],
        'levels': [
          for (var i = 0; i < count; i++)
            {
              'world': i % 2 == 0 ? 'animals' : 'countries',
              'idx': i ~/ 2,
              'title': 'Level ${i + 1}',
              'items': [
                {'id': 'item-$i', 'word': 'Word $i', 'picture': '🦁', 'hint': 'hint'},
              ],
            },
        ],
      };

  test('parses every admin-added level into its world', () {
    final parsed = parseContentManifest(manifestWithLevels(18));
    expect(parsed, isNotNull);
    expect(parsed!['animals']!.length, 9);
    expect(parsed['countries']!.length, 9);
    expect(parsed['animals']![8].title, 'Level 17');
    expect(parsed['animals']![8].items.length, 1);
  });

  test('tolerates malformed levels without losing the rest', () {
    final m = <String, dynamic>{
      ...manifestWithLevels(6),
      'levels': List<dynamic>.from(manifestWithLevels(6)['levels'] as List),
    };
    (m['levels'] as List<dynamic>).insert(3, 'garbage');
    final parsed = parseContentManifest(m);
    expect(parsed, isNotNull);
    expect(parsed!['animals']!.length, 3);
    expect(parsed['countries']!.length, 3);
  });

  test('empty-item levels still appear in the grid', () {
    final m = manifestWithLevels(18);
    for (final l in (m['levels'] as List)) {
      (l as Map)['items'] = <Map>[];
    }
    final parsed = parseContentManifest(m);
    expect(parsed!['animals']!.length, 9);
    expect(parsed['animals']![7].items, isEmpty);
  });

  test('returns null on a manifest without levels', () {
    expect(parseContentManifest({'version': 1}), isNull);
  });
}
