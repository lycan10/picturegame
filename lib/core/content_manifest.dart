import '../models/game_level.dart';
import '../models/match_item.dart';

/// Parses the server content manifest (GET /content) into per-world level
/// lists. Tolerant by design: a single malformed level/item is skipped
/// rather than discarding the whole manifest (which previously made
/// admin-added content silently never load). Missing picture/hint degrade
/// gracefully instead of dropping the item.
Map<String, List<GameLevel>>? parseContentManifest(Map<String, dynamic> manifest) {
  final levels = manifest['levels'];
  if (levels is! List) return null;
  final result = <String, List<GameLevel>>{};
  for (final level in levels) {
    if (level is! Map) continue;
    final world = level['world'];
    final title = level['title'];
    if (world is! String || world.isEmpty || title is! String) continue;
    final rawItems = level['items'];
    final items = <MatchItem>[];
    if (rawItems is List) {
      for (final item in rawItems) {
        if (item is! Map) continue;
        final id = item['id'];
        final word = item['word'];
        if (id is! String || word is! String) continue;
        items.add(MatchItem(
          id: id,
          word: word,
          picture: item['picture'] is String ? item['picture'] as String : '❓',
          hint: item['hint'] is String ? item['hint'] as String : '',
        ));
      }
    }
    (result[world] ??= []).add(GameLevel(title, items));
  }
  return result.isEmpty ? null : result;
}
