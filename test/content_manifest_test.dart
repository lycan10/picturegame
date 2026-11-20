import 'package:flutter_test/flutter_test.dart';
import 'package:picture_match/core/content_manifest.dart';

void main() {
  // Exact shape GET /content returns (verified against the worker).
  Map<String, dynamic> manifestWithLevels(int count) => {
        'version': 42,
        'worlds': [
          {
            'key': 'animals',
            'title': 'Animal Kingdom',
            'subtitle': 'Meet animals from around the world',
            'emoji': '🦁',
            'tint': '0xFFE3F6EA',
            'accent': '0xFF2E9E5B',
          },
          {
            'key': 'countries',
            'title': 'Flags of the World',
            'subtitle': 'Spot countries by their flags',
            'emoji': '🌍',
            'tint': '0xFFE5ECFF',
            'accent': '0xFF3F6BE0',
          },
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
    expect(parsed!.levels['animals']!.length, 9);
    expect(parsed.levels['countries']!.length, 9);
    expect(parsed.levels['animals']![8].title, 'Level 17');
    expect(parsed.levels['animals']![8].items.length, 1);
  });

  test('parses world metadata with hex color strings and keeps server order', () {
    final parsed = parseContentManifest(manifestWithLevels(4))!;
    expect(parsed.worlds.keys.toList(), ['animals', 'countries']);
    final animals = parsed.worlds['animals']!;
    expect(animals.title, 'Animal Kingdom');
    expect(animals.emoji, '🦁');
    expect(animals.tint, 0xFFE3F6EA);
    expect(animals.accent, 0xFF2E9E5B);
    expect(parsed.orderedWorldKeys, ['animals', 'countries']);
  });

  test('a brand-new admin world appears in the ordered key list', () {
    final m = manifestWithLevels(6);
    (m['worlds'] as List).add({
      'key': 'fruits',
      'title': 'Fruit Frenzy',
      'subtitle': 'Fresh from the orchard',
      'emoji': '🍎',
      'tint': '0xFFFFE8E8',
      'accent': '0xFFE05263',
    });
    (m['levels'] as List).add({
      'world': 'fruits',
      'idx': 0,
      'title': 'Level F1',
      'items': [
        {'id': 'f1', 'word': 'Apple', 'picture': '🍎', 'hint': 'hint'},
      ],
    });
    final parsed = parseContentManifest(m)!;
    expect(parsed.orderedWorldKeys, ['animals', 'countries', 'fruits']);
    expect(parsed.worlds['fruits']!.title, 'Fruit Frenzy');
    expect(parsed.levels['fruits']!.length, 1);
  });

  test('level-only worlds (missing metadata row) still get a key', () {
    final m = manifestWithLevels(2);
    (m['levels'] as List).add({
      'world': 'orphan',
      'idx': 0,
      'title': 'Level O1',
      'items': [
        {'id': 'o1', 'word': 'Orphan', 'picture': '🧩', 'hint': 'hint'},
      ],
    });
    final parsed = parseContentManifest(m)!;
    expect(parsed.orderedWorldKeys, ['animals', 'countries', 'orphan']);
  });

  test('malformed world metadata is skipped without dropping worlds/levels', () {
    final m = manifestWithLevels(4);
    final worlds = List<dynamic>.from(m['worlds'] as List);
    worlds.insert(1, 'garbage'); // sits between animals and countries
    m['worlds'] = worlds;
    final parsed = parseContentManifest(m)!;
    // 'garbage' is skipped; both real worlds survive, order preserved.
    expect(parsed.worlds.keys.toList(), ['animals', 'countries']);
    expect(parsed.levels.keys.toList(), containsAll(['animals', 'countries']));
    expect(parsed.orderedWorldKeys, ['animals', 'countries']);
  });

  test('tolerates malformed levels without losing the rest', () {
    final m = <String, dynamic>{
      ...manifestWithLevels(6),
      'levels': List<dynamic>.from(manifestWithLevels(6)['levels'] as List),
    };
    (m['levels'] as List<dynamic>).insert(3, 'garbage');
    final parsed = parseContentManifest(m);
    expect(parsed, isNotNull);
    expect(parsed!.levels['animals']!.length, 3);
    expect(parsed.levels['countries']!.length, 3);
  });

  test('item-less levels (admin work-in-progress) are skipped, not shipped', () {
    final m = manifestWithLevels(18);
    // Empty out the LAST animal level only — the other 17 must survive.
    ((m['levels'] as List)[16] as Map)['items'] = <Map>[];
    final parsed = parseContentManifest(m)!;
    expect(parsed.levels['animals']!.length, 8);
    expect(parsed.levels['countries']!.length, 9);
  });

  test('returns null on a manifest without levels', () {
    expect(parseContentManifest({'version': 1}), isNull);
  });
}
