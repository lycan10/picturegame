import '../models/game_level.dart';
import '../models/match_item.dart';

/// Display metadata for one world, from the manifest's `worlds` array
/// (served ordered by sort_order). Colors arrive as hex strings like
/// "0xFFE3F6EA"; unparsable values degrade to neutral defaults instead of
/// dropping the world.
class WorldMeta {
  final String key;
  final String title;
  final String subtitle;
  final String emoji;
  final int tint;
  final int accent;

  const WorldMeta({
    required this.key,
    required this.title,
    required this.subtitle,
    required this.emoji,
    required this.tint,
    required this.accent,
  });

  factory WorldMeta.fromJson(Map<String, dynamic> json) {
    int color(String field, int fallback) {
      final v = json[field];
      if (v is int) return v;
      if (v is String) return int.tryParse(v) ?? fallback;
      return fallback;
    }

    return WorldMeta(
      key: json['key'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      emoji: json['emoji'] as String? ?? '🧩',
      tint: color('tint', 0xFFF3EFFF),
      accent: color('accent', 0xFF7C3AED),
    );
  }
}

/// The parsed manifest: world display metadata (in server sort order) plus
/// the per-world level lists.
class ParsedContentManifest {
  final Map<String, WorldMeta> worlds;
  final Map<String, List<GameLevel>> levels;

  const ParsedContentManifest({required this.worlds, required this.levels});

  /// World keys in display order: the manifest's `worlds` order (sort_order),
  /// with any level-only worlds appended so nothing added on the server can
  /// be lost to a missing/malformed metadata row.
  List<String> get orderedWorldKeys => [
        ...worlds.keys.where(levels.containsKey),
        ...levels.keys.where((k) => !worlds.containsKey(k)),
      ];
}

/// Parses the server content manifest (GET /content) into world metadata and
/// per-world level lists. Tolerant by design: a single malformed world,
/// level or item is skipped rather than discarding the whole manifest (which
/// previously made admin-added content silently never load). Missing
/// picture/hint degrade gracefully instead of dropping the item.
ParsedContentManifest? parseContentManifest(Map<String, dynamic> manifest) {
  final levels = manifest['levels'];
  if (levels is! List) return null;
  final parsedLevels = <String, List<GameLevel>>{};
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
    (parsedLevels[world] ??= []).add(GameLevel(title, items));
  }
  if (parsedLevels.isEmpty) return null;

  final worlds = <String, WorldMeta>{};
  final rawWorlds = manifest['worlds'];
  if (rawWorlds is List) {
    for (final w in rawWorlds) {
      if (w is! Map) continue;
      final meta =
          WorldMeta.fromJson(Map<String, dynamic>.from(w.cast<String, dynamic>()));
      if (meta.key.isNotEmpty) worlds[meta.key] = meta;
    }
  }

  return ParsedContentManifest(worlds: worlds, levels: parsedLevels);
}
