import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'app_config.dart';
import 'local_store.dart';

class ApiException implements Exception {
  final int? status;
  final String message;
  ApiException(this.message, [this.status]);

  bool get isNetworkError => status == null;

  @override
  String toString() => message;
}

/// Thin HTTP client for the backend with automatic access-token refresh.
class ApiClient {
  ApiClient._();
  static final ApiClient instance = ApiClient._();

  final LocalStore _store = LocalStore.instance;
  http.Client? _client;
  http.Client get _http => _client ??= http.Client();

  /// Set when a token refresh fails with 401 on the refresh endpoint —
  /// the session is dead and the caller should log out locally.
  bool sessionExpired = false;

  Future<String?> get accessToken async =>
      (await _store.auth)['accessToken'] as String?;
  Future<String?> get refreshToken async =>
      (await _store.auth)['refreshToken'] as String?;

  Future<void> saveSession({
    required String accessToken,
    required String refreshToken,
    Map<String, dynamic>? user,
  }) async {
    final auth = await _store.auth;
    await _store.saveAuth({
      ...auth,
      'accessToken': accessToken,
      'refreshToken': refreshToken,
      if (user != null) 'user': user,
    });
  }

  Future<void> clearSession() async {
    sessionExpired = false;
    await _store.clearAuth();
  }

  // ---- Core request --------------------------------------------------------

  Future<Map<String, dynamic>> _send(
    String method,
    String path, {
    Object? body,
    Map<String, String>? headers,
    bool authorized = false,
  }) async {
    try {
      final uri = Uri.parse('${AppConfig.apiV1}$path');
      final requestHeaders = {
        'Content-Type': 'application/json',
        ...?headers,
      };
      if (authorized) {
        final token = await accessToken;
        if (token != null) requestHeaders['Authorization'] = 'Bearer $token';
      }

      final request = http.Request(method, uri)..headers.addAll(requestHeaders);
      if (body != null) request.body = jsonEncode(body);

      final response =
          await _http.send(request).timeout(const Duration(seconds: 12));
      final responseText = await response.stream.bytesToString();

      // Access token expired → refresh once and retry.
      if (response.statusCode == 401 && authorized && !path.contains('/auth/')) {
        final refreshed = await _tryRefresh();
        if (refreshed) {
          return await _send(method, path,
              body: body, headers: headers, authorized: authorized);
        }
      }

      Map<String, dynamic> json;
      try {
        json = jsonDecode(responseText) as Map<String, dynamic>;
      } catch (_) {
        json = {'raw': responseText};
      }

      if (response.statusCode >= 400) {
        throw ApiException(
          (json['message'] as String?) ?? 'Request failed',
          response.statusCode,
        );
      }
      return json;
    } on TimeoutException {
      throw ApiException('Connection timed out', null);
    } catch (err) {
      if (err is ApiException) rethrow;
      throw ApiException('You appear to be offline', null);
    }
  }

  Future<bool> _tryRefresh() async {
    final refresh = await refreshToken;
    if (refresh == null) return false;
    try {
      final json = await _send('POST', '/auth/refresh',
          body: {'refreshToken': refresh});
      await saveSession(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
      );
      return true;
    } on ApiException catch (err) {
      if (err.status == 401) {
        sessionExpired = true;
        await clearSession();
      }
      return false;
    }
  }

  bool _isReachable = true;
  bool get lastRequestSucceeded => _isReachable;

  // ---- Auth ----------------------------------------------------------------

  Future<Map<String, dynamic>> register({
    required String email,
    required String username,
    required String password,
  }) async {
    final json = await _send('POST', '/auth/register', body: {
      'email': email,
      'username': username,
      'password': password,
    });
    await saveSession(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      user: json['user'] as Map<String, dynamic>?,
    );
    _isReachable = true;
    return json;
  }

  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final json = await _send('POST', '/auth/login', body: {
      'email': email,
      'password': password,
    });
    await saveSession(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      user: json['user'] as Map<String, dynamic>?,
    );
    _isReachable = true;
    return json;
  }

  /// Creates an anonymous account so progress syncs without a signup.
  /// Returns the generated credentials (persisted by the caller) so the
  /// guest can re-login later on this device.
  Future<Map<String, dynamic>> createGuest() async {
    final json = await _send('POST', '/auth/guest');
    await saveSession(
      accessToken: json['accessToken'] as String,
      refreshToken: json['refreshToken'] as String,
      user: json['user'] as Map<String, dynamic>?,
    );
    final creds = json['guestCredentials'] as Map<String, dynamic>?;
    if (creds != null) {
      final auth = await _store.auth;
      await _store.saveAuth({
        ...auth,
        'guestCredentials': creds,
      });
    }
    _isReachable = true;
    return json;
  }

  Future<void> logout() async {
    final refresh = await refreshToken;
    try {
      if (refresh != null) {
        await _send('POST', '/auth/logout', body: {'refreshToken': refresh});
      }
    } on ApiException {
      // Best effort — clearing local state is what matters.
    }
    await clearSession();
  }

  /// Revokes every refresh token — signs out all devices.
  Future<void> logoutAll() async {
    try {
      await _send('POST', '/auth/logout-all', authorized: true);
    } on ApiException {
      // Best effort.
    }
    await clearSession();
  }

  /// Permanently deletes the account server-side. Full accounts must confirm
  /// with their password; guests are deleted without one.
  Future<void> deleteAccount({String? password}) async {
    await _send('DELETE', '/auth/account', authorized: true, body: {
      if (password != null) 'password': password,
    });
    await clearSession();
  }

  /// Full JSON export of everything the server stores about the player.
  Future<Map<String, dynamic>> exportData() =>
      _send('GET', '/profile/export', authorized: true);

  /// Upgrade the signed-in guest account to a full account, keeping all
  /// server-side progress. Returns the updated user.
  Future<Map<String, dynamic>> upgrade({
    required String email,
    required String username,
    required String password,
  }) async {
    final json = await _send('POST', '/auth/upgrade', authorized: true, body: {
      'email': email,
      'username': username,
      'password': password,
    });
    final auth = await _store.auth;
    await _store.saveAuth({...auth, 'user': json['user'] as Map<String, dynamic>?});
    _isReachable = true;
    return json;
  }

  // ---- Password & email account flows ---------------------------------------

  /// Requests a 6-digit reset code by email. The backend always answers ok
  /// (no account enumeration); with SMTP unconfigured the response carries
  /// the code as [devCode] for local testing.
  Future<Map<String, dynamic>> forgotPassword(String email) =>
      _send('POST', '/auth/forgot-password', body: {'email': email});

  Future<Map<String, dynamic>> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) =>
      _send('POST', '/auth/reset-password', body: {
        'email': email,
        'code': code,
        'newPassword': newPassword,
      });

  /// Changes the password; rotates the session (new tokens are returned).
  Future<Map<String, dynamic>> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final json = await _send('POST', '/auth/change-password', body: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
    if (json['accessToken'] is String && json['refreshToken'] is String) {
      await saveSession(
        accessToken: json['accessToken'] as String,
        refreshToken: json['refreshToken'] as String,
      );
    }
    return json;
  }

  Future<Map<String, dynamic>> verifyEmail(String code) =>
      _send('POST', '/auth/verify-email', body: {'code': code},
          authorized: true);

  Future<Map<String, dynamic>> resendVerificationEmail() =>
      _send('POST', '/auth/verify-email/resend', authorized: true);

  // ---- Paystack checkout ---------------------------------------------------

  /// Step 1: create a hosted checkout transaction. Returns
  /// {reference, checkoutUrl, amount, currency, product}.
  Future<Map<String, dynamic>> paystackInitialize(String productId) =>
      _send('POST', '/store/paystack/initialize', authorized: true, body: {
        'productId': productId,
      });

  /// Step 3 (after the WebView closes): server-verified settlement.
  Future<Map<String, dynamic>> paystackVerify(String reference) =>
      _send('POST', '/store/paystack/verify', authorized: true, body: {
        'reference': reference,
      });

  // ---- Sync ----------------------------------------------------------------

  Future<Map<String, dynamic>> pullSnapshot() =>
      _send('GET', '/sync', authorized: true);

  Future<Map<String, dynamic>> pushOps(List<Map<String, dynamic>> ops) =>
      _send('POST', '/sync/push', body: {'ops': ops}, authorized: true);

  // ---- Content ---------------------------------------------------------------

  Future<Map<String, dynamic>> contentVersion() =>
      _send('GET', '/content/version');

  Future<Map<String, dynamic>> contentManifest() => _send('GET', '/content');

  // ---- Leaderboard / profile / store / achievements --------------------------

  Future<Map<String, dynamic>> leaderboard(String period) =>
      _send('GET', '/leaderboard?period=$period', authorized: true);

  Future<Map<String, dynamic>> profile() => _send('GET', '/profile', authorized: true);

  Future<Map<String, dynamic>> updateProfile({
    String? displayName,
    String? avatarEmoji,
    String? username,
    bool clearAvatar = false,
  }) =>
      _send('PATCH', '/profile', authorized: true, body: {
        if (displayName != null) 'displayName': displayName,
        if (avatarEmoji != null) 'avatarEmoji': avatarEmoji,
        if (username != null) 'username': username,
        if (clearAvatar) 'avatarUrl': null,
      });

  /// Uploads a new profile picture (raw image bytes; PNG, JPEG or WebP,
  /// max 5MB). Returns {avatarUrl} pointing at the public media URL.
  Future<Map<String, dynamic>> uploadAvatar({
    required Uint8List bytes,
    required String contentType,
  }) async {
    try {
      final uri = Uri.parse('${AppConfig.apiV1}/profile/avatar');
      final token = await accessToken;
      final response = await _http
          .post(uri,
              headers: {
                'Content-Type': contentType,
                if (token != null) 'Authorization': 'Bearer $token',
              },
              body: bytes)
          .timeout(const Duration(seconds: 20));
      Map<String, dynamic> json;
      try {
        json = jsonDecode(response.body) as Map<String, dynamic>;
      } catch (_) {
        json = {'raw': response.body};
      }
      if (response.statusCode >= 400) {
        // 401 here usually means the stored access token expired — refresh
        // once and retry before giving up.
        if (response.statusCode == 401 && await _tryRefresh()) {
          return await uploadAvatar(bytes: bytes, contentType: contentType);
        }
        throw ApiException(
          (json['message'] as String?) ?? 'Upload failed',
          response.statusCode,
        );
      }
      _isReachable = true;
      return json;
    } on TimeoutException {
      throw ApiException('Connection timed out', null);
    } catch (err) {
      if (err is ApiException) rethrow;
      throw ApiException('You appear to be offline', null);
    }
  }

  Future<Map<String, dynamic>> wallet() => _send('GET', '/store/wallet', authorized: true);

  Future<Map<String, dynamic>> purchase(String productId, {String? receipt}) =>
      _send('POST', '/store/purchase', authorized: true, body: {
        'productId': productId,
        'platform': 'mobile',
        if (receipt != null) 'receipt': receipt,
      });

  Future<Map<String, dynamic>> rewardAd(String kind) =>
      _send('POST', '/store/reward-ad', authorized: true, body: {'kind': kind});

  Future<Map<String, dynamic>> spend(String kind, int amount) =>
      _send('POST', '/store/spend', authorized: true, body: {'kind': kind, 'amount': amount});

  Future<Map<String, dynamic>> dailyReward() =>
      _send('POST', '/store/daily-reward', authorized: true);

  Future<Map<String, dynamic>> achievements() =>
      _send('GET', '/achievements', authorized: true);

  Future<Map<String, dynamic>> claimAchievement(String id) =>
      _send('POST', '/achievements/$id/claim', authorized: true);

  // ---- Battles -------------------------------------------------------------

  Future<Map<String, dynamic>> createBattleRoom() =>
      _send('POST', '/battles/rooms', authorized: true);

  Future<Map<String, dynamic>> quickMatch() =>
      _send('POST', '/battles/quick', authorized: true);

  Future<Map<String, dynamic>> joinBattleRoom(String code) =>
      _send('POST', '/battles/rooms/$code/join', authorized: true);

  Future<Map<String, dynamic>> battleState(String code) =>
      _send('GET', '/battles/rooms/$code', authorized: true);

  Future<Map<String, dynamic>> answerBattle(String code, int roundNo, String choice) =>
      _send('POST', '/battles/rooms/$code/answer', authorized: true,
          body: {'roundNo': roundNo, 'choice': choice});

  Future<void> cancelBattleRoom(String code) =>
      _send('DELETE', '/battles/rooms/$code', authorized: true);
}
