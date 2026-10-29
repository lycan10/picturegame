import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'firebase_options.dart';
import 'core/ads_service.dart';
import 'core/app_config.dart';
import 'core/game_data.dart';
import 'core/games_services_manager.dart';
import 'core/iap_service.dart';
import 'core/sound_service.dart';
import 'screens/home_screen.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase and Crashlytics
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

  // Release builds must never talk to a cleartext backend: login tokens
  // over plain http are sniffable on any shared network. Debug builds keep
  // the local-dev defaults (see AppConfig.baseUrl).
  if (kReleaseMode && AppConfig.usesCleartext) {
    runApp(const _CleartextConfigErrorApp());
    return;
  }

  // Load persisted state, restore any session and sync in the background.
  // The app is fully usable immediately — sync happens offline-first.
  await GameData.instance.init();

  // AdMob rewarded ads (store rewards + in-game hint recovery). Must never
  // block startup: a failed SDK init just means ads are unavailable.
  try {
    await AdsService.instance.init();
  } catch (_) {}

  // Sound effects + optional music (device-local settings).
  await SoundService.instance.init();

  // Initialize In-App Purchases
  try {
    await IapService.instance.init();
    IapService.instance.onPurchaseSuccess = (def) {
      if (def.isCoins) {
        GameData.instance.addCoins(def.rewardAmount);
      } else {
        GameData.instance.addHints(def.rewardAmount);
      }
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

class PictureMatchApp extends StatelessWidget {
  const PictureMatchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Picture Match',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const HomeScreen(),
    );
  }
}
