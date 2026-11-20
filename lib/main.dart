import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'core/ads_service.dart';
import 'core/api_client.dart';
import 'core/app_config.dart';
import 'core/game_data.dart';
import 'core/app_nav.dart';
import 'core/notification_service.dart';
import 'core/push_notification_service.dart';
import 'core/games_services_manager.dart';
import 'core/iap_service.dart';
import 'core/sound_service.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase and Crashlytics. A config failure must not leave a
  // frozen splash — the app still runs (without push/Crashlytics reporting).
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Pass all uncaught "fatal" errors from the framework to Crashlytics
    FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

    // Pass all uncaught asynchronous errors that aren't handled by the Flutter framework to Crashlytics
    PlatformDispatcher.instance.onError = (error, stack) {
      FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
      return true;
    };
  } catch (err) {
    debugPrint('[main] Firebase init failed — running without it: $err');
  }

  // Release builds must never talk to a cleartext backend: login tokens
  // over plain http are sniffable on any shared network. Debug builds keep
  // the local-dev defaults (see AppConfig.baseUrl).
  if (kReleaseMode && AppConfig.usesCleartext) {
    runApp(const _CleartextConfigErrorApp());
    return;
  }

  // Load persisted state, restore any session. Corrupt persisted data must
  // never brick the app before the first frame — a failed init still starts
  // the app with fresh/default state. Sync happens after the first frame
  // (GameData.init fires it non-blocking), so the splash never waits on the
  // network.
  try {
    await GameData.instance.init();
  } catch (err) {
    debugPrint('[main] GameData init failed — starting fresh: $err');
  }

  // A dead session (refresh rejected, credentials wiped) must drop the
  // cached user — otherwise the UI shows signed-in while every call 401s.
  ApiClient.instance.onSessionExpired = GameData.instance.handleSessionExpired;

  // AdMob rewarded ads (store rewards + in-game hint recovery). Must never
  // block startup: a failed SDK init just means ads are unavailable.
  try {
    await AdsService.instance.init();
  } catch (_) {}

  // Sound effects + optional music (device-local settings).
  await SoundService.instance.init();

  // Daily reminder: re-arm the OS schedule if it's enabled (self-healing).
  try {
    await NotificationService.instance.init();
  } catch (_) {}

  // FCM push (contest/battle notifications) — best-effort, never blocks.
  try {
    await PushNotificationService.instance.init();
  } catch (_) {}

  // Initialize In-App Purchases. Grants are settled SERVER-SIDE in
  // IapService (POST /store/iap/verify → authoritative wallet) — never grant
  // locally here, the next sync snapshot would wipe it.
  try {
    await IapService.instance.init();
    IapService.instance.onPurchaseSuccess = (def) {
      debugPrint('[IAP] Settled ${def.id} — +${def.rewardAmount} '
          '${def.isCoins ? 'coins' : 'hints'}');
    };
  } catch (_) {}

  // Silent sign-in to Apple Game Center / Google Play Games
  try {
    GameServicesManager.instance.signIn(silent: true);
  } catch (_) {}

  runApp(const PictureMatchApp());
}

class _CleartextConfigErrorApp extends StatelessWidget {
  const _CleartextConfigErrorApp();

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const Scaffold(
        body: Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.lock_outline_rounded,
                    size: 48, color: AppColors.purple),
                SizedBox(height: 16),
                Text(
                  'Configuration error',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 8),
                Text(
                  'This build points at a non-https backend. Rebuild with\n'
                  '--dart-define=API_BASE_URL=https://<your-backend-url>',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class PictureMatchApp extends StatefulWidget {
  const PictureMatchApp({super.key});

  @override
  State<PictureMatchApp> createState() => _PictureMatchAppState();
}

class _PictureMatchAppState extends State<PictureMatchApp> {
  @override
  void initState() {
    super.initState();
    // Cold-start notification taps that arrived during the init chain are
    // buffered in AppNav; flush them now that the navigator exists.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      AppNav.flushPending();
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Picture Match',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      navigatorKey: AppNav.key,
      navigatorObservers: [AppNav.routeObserver],
      home: const HomeScreen(),
    );
  }
}
