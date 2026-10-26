import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../data/game_levels.dart';
import '../models/game_level.dart';
import '../models/match_item.dart';
import 'api_client.dart';
import 'app_config.dart';
import 'local_store.dart';

/// Client-side mirror of the server's achievement catalog (same ids/targets).
class AchievementDef {
  final String id;
  final String title;
  final String description;
  final String category;
  final int target;
  final int points;
  final bool isSpecial;
  final int progress;
  final bool unlocked;
  final bool claimed;

  const AchievementDef({
    required this.id,
    required this.title,
    required this.description,
    required this.category,
    required this.target,
    required this.points,
    this.isSpecial = false,
    this.progress = 0,
    this.unlocked = false,
    this.claimed = false,
  });

  factory AchievementDef.fromJson(Map<String, dynamic> json) => AchievementDef(
        id: json['id'] as String,
        title: json['title'] as String,
        description: json['description'] as String,
        category: json['category'] as String,
        target: json['target'] as int,
        points: json['points'] as int,
        isSpecial: json['isSpecial'] as bool? ?? false,
        progress: json['progress'] as int? ?? 0,
        unlocked: json['unlocked'] as bool? ?? false,
        claimed: json['claimed'] as bool? ?? false,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'category': category,
        'target': target,
        'points': points,
        'isSpecial': isSpecial,
        'progress': progress,
        'unlocked': unlocked,
        'claimed': claimed,
      };
}

const List<AchievementDef> kAchievementDefaults = [
  AchievementDef(id: 'first_login', title: 'Welcome Back', description: 'Log in for the first time.', category: 'daily', target: 1, points: 50),
  AchievementDef(id: 'three_day_streak', title: 'Getting Consistent', description: 'Log in for 3 consecutive days.', category: 'daily', target: 3, points: 100),
  AchievementDef(id: 'seven_day_streak', title: 'Week Warrior', description: 'Maintain a 7-day login streak.', category: 'daily', target: 7, points: 250),
  AchievementDef(id: 'thirty_day_streak', title: 'Unstoppable', description: 'Log in for 30 consecutive days.', category: 'daily', target: 30, points: 1000, isSpecial: true),
  AchievementDef(id: 'first_battle', title: 'Into the Arena', description: 'Complete your first battle.', category: 'battle', target: 1, points: 100),
  AchievementDef(id: 'five_wins', title: 'Rising Champion', description: 'Win 5 battles.', category: 'battle', target: 5, points: 250),
  AchievementDef(id: 'twenty_five_wins', title: 'Battle Legend', description: 'Win 25 battles.', category: 'battle', target: 25, points: 750, isSpecial: true),
  AchievementDef(id: 'ten_win_streak', title: 'Win Streak', description: 'Win 10 battles in a row.', category: 'battle', target: 10, points: 500),
  AchievementDef(id: 'comeback', title: 'The Comeback', description: 'Win a battle with only one heart remaining.', category: 'battle', target: 1, points: 300),
  AchievementDef(id: 'perfect_battle', title: 'Untouchable', description: 'Win a battle without losing a heart.', category: 'battle', target: 1, points: 350),
  AchievementDef(id: 'first_perfect', title: 'Sharp Mind', description: 'Answer 10 questions correctly in a row.', category: 'skill', target: 10, points: 200),
  AchievementDef(id: 'speedster', title: 'Speedster', description: 'Answer 10 questions within 3 seconds each.', category: 'skill', target: 10, points: 250),
  AchievementDef(id: 'hundred_correct', title: 'Word Wizard', description: 'Match 100 pictures correctly.', category: 'skill', target: 100, points: 400),
  AchievementDef(id: 'flawless_round', title: 'Perfect Round', description: 'Complete 20 matches without a mistake.', category: 'skill', target: 20, points: 500),
  AchievementDef(id: 'first_hundred', title: 'Point Collector', description: 'Earn your first 100 points.', category: 'progress', target: 100, points: 50),
  AchievementDef(id: 'five_thousand', title: 'High Scorer', description: 'Earn 5,000 total points.', category: 'progress', target: 5000, points: 300),
  AchievementDef(id: 'animal_expert', title: 'Animal Expert', description: 'Correctly identify 50 animals.', category: 'progress', target: 50, points: 200),
  AchievementDef(id: 'flag_master', title: 'Flag Master', description: 'Correctly identify 50 country flags.', category: 'progress', target: 50, points: 200),
  AchievementDef(id: 'comeback_kid', title: 'Never Give Up', description: 'Return to the game after a 7-day absence.', category: 'special', target: 1, points: 150, isSpecial: true),
  AchievementDef(id: 'all_rounder', title: 'All-Rounder', description: 'Earn an achievement in every category.', category: 'special', target: 5, points: 600, isSpecial: true),
  AchievementDef(id: 'early_bird', title: 'Early Bird', description: 'Complete a match before 8 AM.', category: 'special', target: 1, points: 100, isSpecial: true),
];

/// Single source of truth for player data across the app.
///
/// Offline-first design:
/// 1. Every gameplay mutation updates this object, persists to LocalStore
///    immediately (works with zero connectivity) and queues a sync op.
/// 2. [trySync] drains the op queue against `POST /sync/push` (idempotent op
///    ids) and replaces local state with the server snapshot it returns.
/// 3. Without an account the app behaves exactly as before — fully playable,
///    persisted locally; when a login happens later the queued ops sync up.
class GameData extends ChangeNotifier {
  GameData._();
  static final GameData instance = GameData._();

  final LocalStore _store = LocalStore.instance;
  final ApiClient _api = ApiClient.instance;

  // ---- Player state (mirrors the server snapshot) --------------------------
  int totalScore = 0;
  int coins = 0;
  int hints = 0;
  int streakDays = 0;
  int levelsToday = 0;
  static const int dailyGoal = 3;
  static const int maxStarsPerLevel = 3;
  final List<String> worldKeys = ['animals', 'countries'];

  String lastCategory = 'animals';
  final Map<String, Set<int>> unlocked = {
    'animals': {0},
    'countries': {0},
  };
  final Map<String, Map<int, int>> bestStars = {
    'animals': {},
    'countries': {},
  };

  // ---- Auth ----------------------------------------------------------------
  Map<String, dynamic>? user;
  bool get isLoggedIn => user != null;
  bool get isGuest => user?['isGuest'] as bool? ?? false;
  String get displayName => user?['displayName'] as String? ?? 'Player One';
  String get username => user?['username'] as String? ?? '@player_one';
  String get avatarEmoji => user?['avatarEmoji'] as String? ?? '🧑';

  // ---- Content (fetched game data, persisted for offline) -------------------
  Map<String, List<GameLevel>> _content = {
    'animals': animalLevels,
    'countries': countryLevels,
  };
  int contentVersion = 0;

  // ---- Achievements ---------------------------------------------------------
  List<AchievementDef> achievements = kAchievementDefaults;

  // ---- Sync bookkeeping -----------------------------------------------------
  final List<Map<String, dynamic>> _pendingOps = [];
  bool _syncing = false;
  DateTime? _lastSyncAt;

  /// 'offline' | 'syncing' | 'synced' | 'local' (no account yet)
  String get syncStatus {
    if (_syncing) return 'syncing';
    if (user == null) return 'local';
    return _lastSyncAt != null ? 'synced' : 'offline';
  }

  bool get hasPendingOps => _pendingOps.isNotEmpty;
  DateTime? get lastSyncAt => _lastSyncAt;

  bool _initialized = false;

  // =========================================================================
  // Lifecycle
  // =========================================================================

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await _loadLocal();
    await trySync();
  }

  Future<void> _loadLocal() async {
    final state = await _store.gameState;
    totalScore = state['totalScore'] as int? ?? 0;
    coins = state['coins'] as int? ?? 0;
    hints = state['hints'] as int? ?? 0;
    streakDays = state['streakDays'] as int? ?? 0;
    levelsToday = state['levelsToday'] as int? ?? 0;
    lastCategory = state['lastCategory'] as String? ?? 'animals';

    final rawUnlocked = state['unlocked'] as Map<String, dynamic>?;
    if (rawUnlocked != null) {
      rawUnlocked.forEach((key, value) {
        unlocked[key] = (value as List).map((e) => e as int).toSet();
      });
    }
    final rawStars = state['bestStars'] as Map<String, dynamic>?;
    if (rawStars != null) {
      rawStars.forEach((key, value) {
        bestStars[key] =
            (value as Map<String, dynamic>).map((k, v) => MapEntry(int.parse(k), v as int));
      });
    }

    final cachedUser = (await _store.auth)['user'] as Map<String, dynamic>?;
    user = cachedUser;

    final ops = await _store.pendingOps;
    _pendingOps
      ..clear()
      ..addAll(ops.cast<Map<String, dynamic>>());

    final content = await _store.content;
    final loaded = _parseContent(content);
    if (loaded != null) {
      _content = loaded;
      contentVersion = content['version'] as int? ?? 0;
    }

    final cachedAchievements = (await _store.achievementsCache)['achievements']
        as List<dynamic>?;
    if (cachedAchievements != null && cachedAchievements.isNotEmpty) {
      achievements = cachedAchievements
          .map((a) => AchievementDef.fromJson(a as Map<String, dynamic>))
          .toList();
    }
  }

  Future<void> _persist() async {
    await _store.saveGameState({
      'totalScore': totalScore,
      'coins': coins,
      'hints': hints,
      'streakDays': streakDays,
      'levelsToday': levelsToday,
      'lastCategory': lastCategory,
      'unlocked': unlocked.map((k, v) => MapEntry(k, v.toList())),
      'bestStars': bestStars
          .map((k, v) => MapEntry(k, v.map((key, val) => MapEntry('$key', val)))),
    });
  }

  Future<void> _queueOp(String type, Map<String, dynamic> payload) async {
    _pendingOps.add({
      'opId': 'op-${DateTime.now().microsecondsSinceEpoch}-${_pendingOps.length}-${Random().nextInt(1 << 16)}',
      'type': type,
      'payload': payload,
    });
    await _store.savePendingOps(_pendingOps);
  }

  // =========================================================================
  // Sessions: there is NO silent guest creation. The app is fully playable
  // without an account (progress persists locally and queued ops sync on the
  // first login). Server-backed features gate themselves behind a real
  // account via login_gate.dart.
  // =========================================================================

  // =========================================================================
  // Sync engine
  // =========================================================================

  Future<void> trySync() async {
    if (_syncing || user == null) return;
    _syncing = true;
    notifyListeners();

    try {
      Map<String, dynamic> snapshot;
      if (_pendingOps.isNotEmpty) {
        // Small batches keep each push well inside the Worker's per-request
        // D1 query budget even after a long offline session (ops are
        // idempotent, so a dropped connection mid-batch is safe to retry).
        final batch = List<Map<String, dynamic>>.from(_pendingOps.take(30));
        final json = await _api.pushOps(batch);
        snapshot = json['snapshot'] as Map<String, dynamic>;
        final applied = (json['applied'] as List).cast<String>();
        _pendingOps.removeWhere((op) => applied.contains(op['opId'] as String));
        await _store.savePendingOps(_pendingOps);
      } else {
        snapshot = await _api.pullSnapshot();
      }
      await _applySnapshot(snapshot);
      _lastSyncAt = DateTime.now();

      // Refresh server-computed achievements in the background.
      _refreshAchievements();
      _refreshContentIfStale(snapshot['contentVersion'] as int?);
    } on ApiException catch (err) {
      if (err.isNetworkError) {
        _lastSyncAt = _lastSyncAt; // keep previous state; still offline
      }
      // 401s already handled inside ApiClient (refresh + retry).
    } finally {
      _syncing = false;
      notifyListeners();
    }
  }

  Future<void> _applySnapshot(Map<String, dynamic> snapshot) async {
    final stats = snapshot['stats'] as Map<String, dynamic>?;
    if (stats != null) {
      totalScore = stats['totalPoints'] as int? ?? totalScore;
      coins = stats['coins'] as int? ?? coins;
      hints = stats['hints'] as int? ?? hints;
      streakDays = stats['streakDays'] as int? ?? streakDays;
      levelsToday = stats['levelsToday'] as int? ?? levelsToday;
    }

    final progress = snapshot['progress'] as List<dynamic>?;
    if (progress != null) {
      for (final world in worldKeys) {
        bestStars[world] ??= {};
      }
      for (final row in progress) {
        final world = row['world'] as String;
        final idx = row['levelIndex'] as int;
        final stars = row['bestStars'] as int;
        bestStars[world]![idx] = max(bestStars[world]![idx] ?? 0, stars);
        // Completing a level unlocks the one after it (if it exists).
        if (stars > 0 && idx + 1 < (_content[world]?.length ?? 0)) {
          unlocked[world]?.add(idx + 1);
        }
      }
      // First level of every world is always unlocked.
      for (final world in worldKeys) {
        unlocked[world]?.add(0);
      }
    }

    final state = snapshot['state'] as Map<String, dynamic>?;
    if (state?['lastCategory'] is String) {
      lastCategory = state!['lastCategory'] as String;
    }
    if (state?['leaderboard_public'] is bool) {
      _leaderboardPublic = state!['leaderboard_public'] as bool;
    }

    await _persist();
    notifyListeners();
  }

  Future<void> _refreshAchievements() async {
    try {
      final json = await _api.achievements();
      final list = (json['achievements'] as List)
          .map((a) => AchievementDef.fromJson(a as Map<String, dynamic>))
          .toList();
      achievements = list;
      await _store.saveAchievementsCache({
        'achievements': list.map((a) => a.toJson()).toList(),
      });
      notifyListeners();
    } on ApiException {
      // Keep cached achievements.
    }
  }

  /// Fetches the content manifest when the server version moved; the manifest
  /// is persisted so fetched game data works offline from then on.
  Future<void> _refreshContentIfStale(int? serverVersion) async {
    if (serverVersion == null || serverVersion == contentVersion) return;
    try {
      final manifest = await _api.contentManifest();
      final parsed = _parseContent(manifest);
      if (parsed != null) {
        _content = parsed;
        contentVersion = manifest['version'] as int;
        await _store.saveContent(manifest);
        notifyListeners();
      }
    } on ApiException {
      // Keep current content.
    }
  }

  Map<String, List<GameLevel>>? _parseContent(Map<String, dynamic> manifest) {
    try {
      final levels = manifest['levels'] as List<dynamic>;
      final result = <String, List<GameLevel>>{};
      for (final level in levels) {
        final world = level['world'] as String;
        final items = (level['items'] as List)
            .map((i) => MatchItem(
                  id: i['id'] as String,
                  word: i['word'] as String,
                  picture: i['picture'] as String,
                  hint: i['hint'] as String,
                ))
            .toList();
        (result[world] ??= []).add(GameLevel(level['title'] as String, items));
      }
      return result.isEmpty ? null : result;
    } catch (_) {
      return null;
    }
  }

  List<GameLevel> levelsFor(String category) =>
      _content[category] ??
      (category == 'countries' ? countryLevels : animalLevels);

  // =========================================================================
  // Gameplay mutations (update local state immediately, queue for sync)
  // =========================================================================

  bool isWorldUnlocked(String category) {
    final index = worldKeys.indexOf(category);
    if (index <= 0) return true;
    final prevCategory = worldKeys[index - 1];
    final levels = levelsFor(prevCategory);
    final prevUnlocked = unlocked[prevCategory] ?? {};
    final lastLevelIndex = levels.length - 1;
    return prevUnlocked.contains(lastLevelIndex) &&
        (bestStars[prevCategory]?[lastLevelIndex] ?? 0) > 0;
  }

  Future<void> completeLevel(
    String category,
    int levelIndex,
    int points,
    int stars,
  ) async {
    totalScore += points;
    levelsToday += 1;

    final levels = levelsFor(category);
    final nextIndex = levelIndex + 1;
    if (nextIndex < levels.length) {
      unlocked[category]?.add(nextIndex);
    }
    final previous = bestStars[category]?[levelIndex] ?? 0;
    bestStars[category]![levelIndex] = max(previous, stars);

    lastCategory = category;

    await _persist();
    await _queueOp('level_completed', {
      'world': category,
      'levelIndex': levelIndex,
      'points': points,
      'stars': stars,
    });
    await _queueOp('state_set', {'key': 'lastCategory', 'value': category});
    notifyListeners();
    unawaited(trySync());
  }

  /// Consumes one stored hint. Hints are enforced: returns false (and spends
  /// nothing) when the wallet is empty — callers should offer the store or a
  /// rewarded ad instead. The server validates the balance again on sync.
  Future<bool> useHint() async {
    if (hints < 1) return false;
    hints -= 1;
    await _persist();
    await _queueOp('hint_used', {});
    notifyListeners();
    return true;
  }

  Future<void> setLastCategory(String category) async {
    if (lastCategory == category) return;
    lastCategory = category;
    await _persist();
    await _queueOp('state_set', {'key': 'lastCategory', 'value': category});
    notifyListeners();
  }

  // ---- Privacy ---------------------------------------------------------------
  // Optimistic mirror of app_state.leaderboard_public (server default true).
  // The leaderboard queries honour it server-side; the toggle lives in
  // Privacy & Security.
  bool _leaderboardPublic = true;
  bool get leaderboardPublic => _leaderboardPublic;

  Future<void> setLeaderboardPublic(bool value) async {
    if (_leaderboardPublic == value) return;
    _leaderboardPublic = value;
    notifyListeners();
    await _queueOp('state_set', {'key': 'leaderboard_public', 'value': value});
    unawaited(trySync());
  }

  // =========================================================================
  // Auth actions
  // =========================================================================

  Future<String?> login(String email, String password) async {
    try {
      final json = await _api.login(email: email, password: password);
      await _adoptAccount(json);
      return null;
    } on ApiException catch (err) {
      return err.message;
    }
  }

  Future<String?> register(
    String email,
    String username,
    String password,
  ) async {
    try {
      // A signed-in guest upgrades in place (keeps server-side progress);
      // a local-only player creates a fresh account and syncs queued ops up.
      if (isLoggedIn && isGuest) {
        final json = await _api.upgrade(
          email: email,
          username: username,
          password: password,
        );
        user = json['user'] as Map<String, dynamic>?;
        notifyListeners();
        await trySync();
        return null;
      }
      final json = await _api.register(
        email: email,
        username: username,
        password: password,
      );
      await _adoptAccount(json);
      return null;
    } on ApiException catch (err) {
      return err.message;
    }
  }

  Future<void> _adoptAccount(Map<String, dynamic> json) async {
    user = json['user'] as Map<String, dynamic>?;
    notifyListeners();
    // Push everything played offline up to the new account, then converge.
    await trySync();
  }

  Future<void> logout() async {
    await _api.logout();
    user = null;
    _lastSyncAt = null;
    notifyListeners();
  }

  Future<void> refreshProfile() async {
    if (user == null) return;
    try {
      final json = await _api.profile();
      final profile = json['profile'] as Map<String, dynamic>?;
      if (profile != null) {
        final auth = await _store.auth;
        final merged = {...(auth['user'] as Map<String, dynamic>? ?? {})};
        merged['displayName'] = profile['displayName'];
        merged['username'] = profile['username'];
        merged['avatarEmoji'] = profile['avatarEmoji'];
        merged['avatarUrl'] = profile['avatarUrl'];
        merged['emailVerified'] = profile['emailVerified'];
        merged['isGuest'] = profile['isGuest'];
        user = merged;
        await _store.saveAuth({...auth, 'user': merged});
        notifyListeners();
      }
    } on ApiException {
      // Offline — keep cached profile.
    }
  }

  // =========================================================================
  // Account management (password & email, profile editing)
  // =========================================================================

  String? get avatarUrl => user?['avatarUrl'] as String?;
  bool get emailVerified => user?['emailVerified'] as bool? ?? false;

  /// Returns the public URL for a stored avatar path, or null.
  String? avatarNetworkUrl() {
    final path = avatarUrl;
    return path == null ? null : '${AppConfig.baseUrl}$path';
  }

  /// Requests a password-reset code; returns null on success (the backend
  /// answers ok regardless of whether the account exists).
  Future<String?> forgotPassword(String email) async {
    try {
      await _api.forgotPassword(email);
      return null;
    } on ApiException catch (err) {
      return err.message;
    }
  }

  /// Resets the password with an emailed code. Returns null on success.
  Future<String?> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    try {
      await _api.resetPassword(
        email: email,
        code: code,
        newPassword: newPassword,
      );
      return null;
    } on ApiException catch (err) {
      return err.message;
    }
  }

  /// Changes the password (requires the current one). Rotates the session.
  Future<String?> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    try {
      await _api.changePassword(
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return null;
    } on ApiException catch (err) {
      return err.message;
    }
  }

  /// Confirms the account email with the emailed code. Returns null on
  /// success, updating the cached user.
  Future<String?> verifyEmailCode(String code) async {
    try {
      await _api.verifyEmail(code);
      await _mergeUser({'emailVerified': true});
      return null;
    } on ApiException catch (err) {
      return err.message;
    }
  }

  /// Sends a fresh verification email. Returns null on success.
  Future<String?> resendVerificationEmail() async {
    try {
      await _api.resendVerificationEmail();
      return null;
    } on ApiException catch (err) {
      return err.message;
    }
  }

  /// PATCHes profile fields and merges the server response into the
  /// cached user. Returns null on success.
  Future<String?> updateProfile({
    String? displayName,
    String? username,
    String? avatarEmoji,
    bool clearAvatar = false,
  }) async {
    try {
      final json = await _api.updateProfile(
        displayName: displayName,
        username: username,
        avatarEmoji: avatarEmoji,
        clearAvatar: clearAvatar,
      );
      final profile = json['profile'] as Map<String, dynamic>?;
      if (profile != null) {
        await _mergeUser({
          'displayName': profile['displayName'],
          'username': profile['username'],
          'avatarEmoji': profile['avatarEmoji'],
          'avatarUrl': profile['avatarUrl'],
        });
      }
      return null;
    } on ApiException catch (err) {
      return err.message;
    }
  }

  /// Uploads a profile photo. [contentType] is 'image/png', 'image/jpeg' or
  /// 'image/webp'. Returns null on success (avatar URL cached locally).
  Future<String?> uploadAvatar(Uint8List bytes, String contentType) async {
    try {
      final json = await _api.uploadAvatar(
        bytes: bytes,
        contentType: contentType,
      );
      await _mergeUser({'avatarUrl': json['avatarUrl']});
      return null;
    } on ApiException catch (err) {
      return err.message;
    }
  }

  /// Merges fields into the cached user (and persisted auth blob).
  Future<void> _mergeUser(Map<String, dynamic> fields) async {
    final auth = await _store.auth;
    final merged = {...(auth['user'] as Map<String, dynamic>? ?? user ?? {})};
    merged.addAll(fields);
    user = merged;
    await _store.saveAuth({...auth, 'user': merged});
    notifyListeners();
  }

  // =========================================================================
  // Store / economy (online actions with graceful offline handling)
  // =========================================================================

  /// Paystack step 1: open a hosted checkout session.
  /// Returns {reference, checkoutUrl, ...} or throws [ApiException].
  Future<Map<String, dynamic>> startCheckout(String productId) =>
      _api.paystackInitialize(productId);

  /// Paystack step 3: settle the purchase server-side after the WebView
  /// closes. Returns null on success (wallet refreshed), or an error message.
  Future<String?> verifyPurchase(String reference) async {
    try {
      final json = await _api.paystackVerify(reference);
      if (json['ok'] != true) {
        return json['status'] == 'abandoned'
            ? 'Payment was not completed.'
            : 'Payment not confirmed yet — check again in a minute.';
      }
      coins = json['coins'] as int? ?? coins;
      hints = json['hints'] as int? ?? hints;
      await _persist();
      notifyListeners();
      return null;
    } on ApiException catch (err) {
      return err.message;
    }
  }

  Future<String?> watchAdReward(String kind) async {
    try {
      final json = await _api.rewardAd(kind);
      coins = json['coins'] as int? ?? coins;
      hints = json['hints'] as int? ?? hints;
      await _persist();
      notifyListeners();
      return null;
    } on ApiException catch (err) {
      return err.message;
    }
  }

  Future<String?> claimDailyReward() async {
    try {
      final json = await _api.dailyReward();
      coins = json['coins'] as int? ?? coins;
      hints = json['hints'] as int? ?? hints;
      if (json['ok'] == true) {
        // Points come back with the next sync snapshot.
        unawaited(trySync());
      }
      await _persist();
      notifyListeners();
      return json['alreadyClaimed'] == true ? 'Already claimed today' : null;
    } on ApiException catch (err) {
      return err.message;
    }
  }

  Future<String?> claimAchievement(String id) async {
    try {
      await _api.claimAchievement(id);
      achievements = achievements
          .map((a) => a.id == id ? a.copyWithClaimed() : a)
          .toList();
      await _store.saveAchievementsCache({
        'achievements': achievements.map((a) => a.toJson()).toList(),
      });
      unawaited(trySync());
      notifyListeners();
      return null;
    } on ApiException catch (err) {
      return err.message;
    }
  }
}

extension _AchievementClaim on AchievementDef {
  AchievementDef copyWithClaimed() => AchievementDef(
        id: id,
        title: title,
        description: description,
        category: category,
        target: target,
        points: points,
        isSpecial: isSpecial,
        progress: progress,
        unlocked: unlocked,
        claimed: true,
      );
}
