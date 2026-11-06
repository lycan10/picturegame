import 'dart:io';

import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../screens/contest_screen.dart';
import '../screens/battle_game_screen.dart';
import '../screens/battle_screen.dart';
import '../screens/friends_screen.dart';
import '../screens/quick_match_invite_screen.dart';
import 'api_client.dart';
import 'app_nav.dart';
import 'game_data.dart';
import 'notification_service.dart';

/// FCM push notifications: registers the device token with the backend
/// (once signed in), surfaces foreground messages via the local notification
/// plugin, and re-registers on token rotation.
///
/// Everything degrades silently — no Firebase config, denied permissions or a
/// simulator without APNs simply means no push (in-app inbox still works).
/// Background/terminated messages are rendered by the system tray
/// automatically because the server sends `notification` payloads.
class PushNotificationService {
  PushNotificationService._();
  static final PushNotificationService instance = PushNotificationService._();

  String? _token;
  String? _registeredToken;
  String? _registeredUserId;
  bool _initialized = false;

  Future<void> init() async {
    if (_initialized || kIsWeb) return;
    _initialized = true;

    try {
      // Background messages must be handled by a top-level function; the
      // server's `notification` payloads are shown by the OS automatically.
      FirebaseMessaging.onBackgroundMessage(firebaseBackgroundHandler);

      final settings = await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      if (settings.authorizationStatus != AuthorizationStatus.authorized &&
          settings.authorizationStatus != AuthorizationStatus.provisional) {
        return;
      }

      // Foreground: FCM does not display anything itself — mirror it locally
      // (payload carries the message data so taps can deep-link).
      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        NotificationService.instance.showNow(
          id: (message.messageId ?? message.sentTime?.millisecondsSinceEpoch ?? 0)
              .hashCode & 0x7fffffff,
          title: message.notification?.title ?? 'Picture Match 🎯',
          body: message.notification?.body ?? '',
          payload: jsonEncode(message.data),
        );
      });

      // Tap handling: tray taps while backgrounded, cold-start taps, and taps
      // on locally-shown notifications (foreground mirror).
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleTap(message.data);
      });
      FirebaseMessaging.instance.getInitialMessage().then((message) {
        if (message != null) _handleTap(message.data);
      });
      NotificationService.tapStream.listen((payload) {
        if (payload == null || payload.isEmpty) return;
        try {
          _handleTap(jsonDecode(payload) as Map<String, dynamic>);
        } catch (_) {}
      });

      FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        _token = token;
        _register();
      });
      _token = await FirebaseMessaging.instance.getToken();

      // Registration needs an account — retry whenever auth state changes.
      GameData.instance.addListener(_onGameData);
      await _register();
    } catch (err) {
      // Push is best-effort; never break app startup over it.
      debugPrint('[push] init skipped: $err');
    }
  }

  void _onGameData() {
    if (GameData.instance.isLoggedIn) _register();
  }

  /// Deep-links notification taps by payload kind.
  void _handleTap(Map<String, dynamic> data) {
    final code = data['code'];
    switch (data['kind']) {
      case 'quick_invite':
      case 'battle_invite':
        if (code is String && code.isNotEmpty) {
          AppNav.push(QuickMatchInviteScreen(code: code));
        }
      case 'battle_lobby':
        // Host: reopen the room's lobby to accept the waiting opponent.
        if (code is String && code.isNotEmpty) {
          AppNav.push(BattleScreen(rejoinCode: code));
        }
      case 'battle_live':
        if (code is String && code.isNotEmpty) {
          AppNav.push(BattleGameScreen(code: code));
        }
      case 'friend_request':
      case 'friend_accepted':
      case 'friends':
        AppNav.push(const FriendsScreen());
      case 'contest':
        AppNav.push(const ContestScreen());
    }
  }

  Future<void> _register() async {
    final token = _token;
    if (token == null || !GameData.instance.isLoggedIn) return;
    final userId = GameData.instance.user?['id'] as String?;
    if (_registeredToken == token && _registeredUserId != null && _registeredUserId == userId) {
      return;
    }
    try {
      final platform = Platform.isIOS ? 'ios' : (Platform.isAndroid ? 'android' : 'unknown');
      await ApiClient.instance.registerDeviceToken(token, platform);
      _registeredToken = token;
      _registeredUserId = userId;
    } on ApiException {
      // Offline or unauthenticated — retried on the next auth/sync change.
    } catch (_) {}
  }
}

@pragma('vm:entry-point')
Future<void> firebaseBackgroundHandler(RemoteMessage message) async {
  // Deliberately empty: the OS renders `notification` payloads in the tray
  // while the app is backgrounded; tapping opens the app (cold start passes
  // through main → init, which re-registers the token if rotated).
}
