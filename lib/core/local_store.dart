import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent local storage for everything the app needs offline:
/// auth tokens, the game-state mirror, queued sync ops, cached content
/// manifests and cached network responses (leaderboard, achievements).
///
/// Auth data (access/refresh tokens, guest credentials) is kept in
/// flutter_secure_storage — Keychain on iOS, Keystore-backed storage on
/// Android — instead of plaintext SharedPreferences. Everything else
/// (game state, caches) stays in SharedPreferences: it isn't sensitive
/// and the secure path has stricter size/latency characteristics.
class LocalStore {
  LocalStore._();
  static final LocalStore instance = LocalStore._();

  SharedPreferences? _prefs;

  final FlutterSecureStorage _secure = const FlutterSecureStorage(
    iOptions: IOSOptions(accessibility: KeychainAccessibility.first_unlock),
  );

  Future<SharedPreferences> get _db async =>
      _prefs ??= await SharedPreferences.getInstance();

  // ---- Generic JSON blobs -------------------------------------------------

  Future<Map<String, dynamic>> getJson(String key) async {
    final raw = (await _db).getString(key);
    if (raw == null) return {};
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<void> setJson(String key, Map<String, dynamic> value) async {
    await (await _db).setString(key, jsonEncode(value));
  }

  Future<void> remove(String key) async {
    await (await _db).remove(key);
  }

  // ---- Auth ---------------------------------------------------------------

  static const _kAuth = 'auth';

  Future<Map<String, dynamic>> get auth async {
    // Secure storage can throw on rare device states (keychain resets,
    // missing plugin in tests) — treat that as "no session" rather than
    // crashing on startup.
    try {
      final raw = await _secure.read(key: _kAuth);
      if (raw != null) return _decodeAuth(raw);

      // One-time migration from the pre-secure-storage plaintext blob.
      final prefs = await _db;
      final legacy = prefs.getString(_kAuth);
      if (legacy != null) {
        await _secure.write(key: _kAuth, value: legacy);
        await prefs.remove(_kAuth);
        return _decodeAuth(legacy);
      }
      return {};
    } catch (_) {
      return {};
    }
  }

  Future<void> saveAuth(Map<String, dynamic> value) async {
    try {
      await _secure.write(key: _kAuth, value: jsonEncode(value));
    } catch (_) {
      // Storage unavailable — the session just won't survive a restart;
      // in-memory auth still works for this run.
    }
  }

  Future<void> clearAuth() async {
    try {
      await _secure.delete(key: _kAuth);
    } catch (_) {}
    // Also drop any legacy plaintext copy left by older app versions.
    await (await _db).remove(_kAuth);
  }

  Map<String, dynamic> _decodeAuth(String raw) {
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  // ---- Game state mirror (the offline source of truth for the UI) ----------

  static const _kGameState = 'game_state';
  static const _kPendingOps = 'pending_ops';

  Future<Map<String, dynamic>> get gameState async => getJson(_kGameState);
  Future<void> saveGameState(Map<String, dynamic> value) =>
      setJson(_kGameState, value);

  Future<List<dynamic>> get pendingOps async =>
      ((await getJson(_kPendingOps))['ops'] as List<dynamic>?) ?? [];
  Future<void> savePendingOps(List<Map<String, dynamic>> ops) =>
      setJson(_kPendingOps, {'ops': ops});

  // ---- Cached content manifest --------------------------------------------

  static const _kContent = 'content_manifest';

  Future<Map<String, dynamic>> get content async => getJson(_kContent);
  Future<void> saveContent(Map<String, dynamic> value) =>
      setJson(_kContent, value);

  // ---- Cached network payloads (leaderboard, achievements) -----------------

  static const _kLeaderboardCache = 'leaderboard_cache';
  static const _kAchievementsCache = 'achievements_cache';

  Future<Map<String, dynamic>> get leaderboardCache => getJson(_kLeaderboardCache);
  Future<void> saveLeaderboardCache(Map<String, dynamic> v) =>
      setJson(_kLeaderboardCache, v);

  Future<Map<String, dynamic>> get achievementsCache => getJson(_kAchievementsCache);
  Future<void> saveAchievementsCache(Map<String, dynamic> v) =>
      setJson(_kAchievementsCache, v);

  // ---- Cached server config (economy/gameplay values) ----------------------

  static const _kConfigCache = 'config_cache';

  Future<Map<String, dynamic>> get configCache => getJson(_kConfigCache);
  Future<void> saveConfigCache(Map<String, dynamic> v) =>
      setJson(_kConfigCache, v);
}
