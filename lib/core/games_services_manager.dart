import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:games_services/games_services.dart';

/// Service managing native Game Center (iOS) and Play Games Services (Android).
///
/// Features:
/// - Silent / Interactive Player Authentication
/// - Achievement reporting & Native UI display
/// - Leaderboard score submission & Native UI display
/// - Saved Games / Cloud Saves (Snapshot backup of player progress)
class GameServicesManager {
  GameServicesManager._();
  static final GameServicesManager instance = GameServicesManager._();

  static const String _defaultSaveSlot = 'picture_match_cloud_save';

  bool _isSignedIn = false;
  bool get isSignedIn => _isSignedIn;
  String? _playerId;
  String? get playerId => _playerId;

  /// Initializes and signs in the player with Game Center or Google Play Games.
  Future<bool> signIn({bool silent = true}) async {
    try {
      final result = await GameAuth.signIn();
      _isSignedIn = result != null;
      if (_isSignedIn) {
        try {
          final player = await GameAuth.player.first;
          _playerId = player?.playerID;
        } catch (_) {}
      }
      debugPrint('[GameServices] Signed in: $_isSignedIn (Player ID: $_playerId)');
      return _isSignedIn;
    } catch (e) {
      debugPrint('[GameServices] Sign-in error: $e');
      _isSignedIn = false;
      return false;
    }
  }

  /// Check current sign-in status
  Future<bool> checkSignInStatus() async {
    try {
      _isSignedIn = await GameAuth.isSignedIn;
      return _isSignedIn;
    } catch (_) {
      _isSignedIn = false;
      return false;
    }
  }

  // ===========================================================================
  // Leaderboards
  // ===========================================================================

  /// Submits player high score or stars to the native platform leaderboard.
  Future<void> submitScore({
    required int score,
    required String androidLeaderboardId,
    required String iOSLeaderboardId,
  }) async {
    if (!_isSignedIn) {
      final signedIn = await signIn();
      if (!signedIn) return;
    }

    try {
      await Leaderboards.submitScore(
        score: Score(
          androidLeaderboardID: androidLeaderboardId,
          iOSLeaderboardID: iOSLeaderboardId,
          value: score,
        ),
      );
      debugPrint('[GameServices] Submitted score: $score');
    } catch (e) {
      debugPrint('[GameServices] Error submitting score: $e');
    }
  }

  /// Opens the native platform leaderboard UI overlay.
  Future<void> showLeaderboards({
    String? androidLeaderboardId,
    String? iOSLeaderboardId,
  }) async {
    if (!_isSignedIn) {
      final signedIn = await signIn();
      if (!signedIn) return;
    }

    try {
      await Leaderboards.showLeaderboards(
        androidLeaderboardID: androidLeaderboardId ?? '',
        iOSLeaderboardID: iOSLeaderboardId ?? '',
      );
    } catch (e) {
      debugPrint('[GameServices] Error showing leaderboards: $e');
    }
  }

  // ===========================================================================
  // Achievements
  // ===========================================================================

  /// Unlocks an achievement on Apple Game Center or Google Play Games.
  Future<void> unlockAchievement({
    required String androidAchievementId,
    required String iOSAchievementId,
  }) async {
    if (!_isSignedIn) {
      final signedIn = await signIn();
      if (!signedIn) return;
    }

    try {
      await Achievements.unlock(
        achievement: Achievement(
          androidID: androidAchievementId,
          iOSID: iOSAchievementId,
        ),
      );
      debugPrint('[GameServices] Unlocked achievement: $androidAchievementId / $iOSAchievementId');
    } catch (e) {
      debugPrint('[GameServices] Error unlocking achievement: $e');
    }
  }

  /// Increments a stepped achievement (Android / iOS).
  Future<void> incrementAchievement({
    required String androidAchievementId,
    required String iOSAchievementId,
    required int steps,
  }) async {
    if (!_isSignedIn) {
      final signedIn = await signIn();
      if (!signedIn) return;
    }

    try {
      await Achievements.increment(
        achievement: Achievement(
          androidID: androidAchievementId,
          iOSID: iOSAchievementId,
          steps: steps,
        ),
      );
      debugPrint('[GameServices] Incremented achievement: steps=$steps');
    } catch (e) {
      debugPrint('[GameServices] Error incrementing achievement: $e');
    }
  }

  /// Opens the native achievements UI overlay.
  Future<void> showAchievements() async {
    if (!_isSignedIn) {
      final signedIn = await signIn();
      if (!signedIn) return;
    }

    try {
      await Achievements.showAchievements();
    } catch (e) {
      debugPrint('[GameServices] Error showing achievements: $e');
    }
  }

  // ===========================================================================
  // Saved Games / Cloud Saves
  // ===========================================================================

  /// Saves the player's progress payload directly to the platform's cloud save snapshot.
  Future<bool> saveProgressToCloud({
    required Map<String, dynamic> gameJson,
    String slotName = _defaultSaveSlot,
    String description = 'Picture Match Cloud Save',
    Duration? playedTime,
  }) async {
    if (!_isSignedIn) {
      final ok = await signIn();
      if (!ok) return false;
    }

    try {
      final jsonPayload = jsonEncode(gameJson);
      await SaveGame.saveGame(
        data: jsonPayload,
        name: slotName,
        description: description,
        playedTime: playedTime,
      );
      debugPrint('[GameServices] Progress saved to cloud snapshot ($slotName)');
      return true;
    } catch (e) {
      debugPrint('[GameServices] Failed to save progress to cloud: $e');
      return false;
    }
  }

  /// Loads the player's progress snapshot from the cloud.
  Future<Map<String, dynamic>?> loadProgressFromCloud({
    String slotName = _defaultSaveSlot,
  }) async {
    if (!_isSignedIn) {
      final ok = await signIn();
      if (!ok) return null;
    }

    try {
      final savedData = await SaveGame.loadGame(name: slotName);
      if (savedData == null || savedData.isEmpty) {
        debugPrint('[GameServices] No cloud save snapshot found.');
        return null;
      }
      final decoded = jsonDecode(savedData) as Map<String, dynamic>;
      debugPrint('[GameServices] Progress loaded from cloud snapshot ($slotName)');
      return decoded;
    } catch (e) {
      debugPrint('[GameServices] Failed to load progress from cloud: $e');
      return null;
    }
  }

  /// Displays the native Saved Games UI (Google Play Games on Android).
  Future<void> showSavedGamesUI({String title = 'Saved Games'}) async {
    try {
      await SaveGame.showSavedGames(title: title);
    } catch (e) {
      debugPrint('[GameServices] Error showing saved games: $e');
    }
  }
}

