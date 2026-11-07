import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AdMob ads wrapper: rewarded ads (store's "Earn Rewards for Free", in-game
/// hint recovery), rewarded interstitials (guest play gate), app-open ads
/// (cold start + warm resume), interstitials (level finish / quit / battle
/// end, frequency-capped) and native advanced ads.
///
/// The backend still gates every rewarded grant (`POST /store/reward-ad`,
/// capped at 10/day) — call that only from the ad SDK's `onUserEarnedReward`
/// callback, which fires when AdMob itself confirms the reward.
///
/// Configuration:
///  - Ad unit IDs default to Google's official TEST units (always fillable,
///    test ads only). Override for release with:
///    --dart-define=ADMOB_REWARDED_ID=ca-app-pub-XXXX/YYYY
///    --dart-define=ADMOB_INTERSTITIAL_ID=ca-app-pub-XXXX/YYYY
///    --dart-define=ADMOB_NATIVE_ID=ca-app-pub-XXXX/YYYY
///    --dart-define=ADMOB_APP_OPEN_ID=ca-app-pub-XXXX/YYYY
///    --dart-define=ADMOB_REWARDED_INTERSTITIAL_ID=ca-app-pub-XXXX/YYYY
///  - The AdMob *application* ID lives in AndroidManifest.xml / Info.plist and
///    must be swapped for the production app ID at release time.
class AdsService with WidgetsBindingObserver {
  AdsService._();
  static final AdsService instance = AdsService._();

  static const String _androidTestRewardedId =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _iosTestRewardedId =
      'ca-app-pub-3940256099942544/1712485313';
  static const String _androidTestInterstitialId =
      'ca-app-pub-3940256099942544/1033173712';
  static const String _iosTestInterstitialId =
      'ca-app-pub-3940256099942544/4411468910';
  static const String _androidTestNativeId =
      'ca-app-pub-3940256099942544/2247696110';
  static const String _iosTestNativeId =
      'ca-app-pub-3940256099942544/3986624511';
  static const String _androidTestAppOpenId =
      'ca-app-pub-3940256099942544/9257395921';
  static const String _iosTestAppOpenId =
      'ca-app-pub-3940256099942544/5575463023';
  static const String _androidTestRewardedInterstitialId =
      'ca-app-pub-3940256099942544/5354046371';
  static const String _iosTestRewardedInterstitialId =
      'ca-app-pub-3940256099942544/6978759864';

  /// Minimum gap between two interstitials, so back-to-back levels or a
  /// battle finished right after a level don't stack ads on the user.
  static const Duration _interstitialMinGap = Duration(seconds: 90);

  /// Show the on-app-open interstitial only every Nth launch.
  static const int _appOpenEveryLaunches = 3;

  static const _kLaunchCount = 'ads_launch_count';

  bool _initialized = false;
  InterstitialAd? _interstitial;
  bool _loadingInterstitial = false;
  DateTime? _lastInterstitialShown;
  bool _appOpenInterstitialDone = false;

  AppOpenAd? _appOpen;
  bool _loadingAppOpen = false;
  DateTime? _lastAppOpenShown;
  /// Set while a full-screen experience is in progress (live battle) so an
  /// app-open ad never interrupts it on resume.
  bool suppressAppOpen = false;

  bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  String get rewardedAdUnitId {
    const override = String.fromEnvironment('ADMOB_REWARDED_ID');
    if (override.isNotEmpty) return override;
    return Platform.isIOS ? _iosTestRewardedId : _androidTestRewardedId;
  }

  String get interstitialAdUnitId {
    const override = String.fromEnvironment('ADMOB_INTERSTITIAL_ID');
    if (override.isNotEmpty) return override;
    return Platform.isIOS ? _iosTestInterstitialId : _androidTestInterstitialId;
  }

  String get nativeAdUnitId {
    const override = String.fromEnvironment('ADMOB_NATIVE_ID');
    if (override.isNotEmpty) return override;
    return Platform.isIOS ? _iosTestNativeId : _androidTestNativeId;
  }

  String get appOpenAdUnitId {
    const override = String.fromEnvironment('ADMOB_APP_OPEN_ID');
    if (override.isNotEmpty) return override;
    return Platform.isIOS ? _iosTestAppOpenId : _androidTestAppOpenId;
  }

  String get rewardedInterstitialAdUnitId {
    const override = String.fromEnvironment('ADMOB_REWARDED_INTERSTITIAL_ID');
    if (override.isNotEmpty) return override;
    return Platform.isIOS ? _iosTestRewardedInterstitialId : _androidTestRewardedInterstitialId;
  }

  /// Minimum gap between two app-open ads, so switching back to the app
  /// doesn't feel like an ad wall.
  static const Duration _appOpenMinGap = Duration(hours: 4);

  Future<void> init() async {
    if (!isSupported || _initialized) return;
    _initialized = true;
    WidgetsBinding.instance.addObserver(this);
    await MobileAds.instance.initialize();
    unawaited(loadInterstitial());
    unawaited(loadAppOpen());
  }

  // ---------------------------------------------------------------------------
  // App open
  // ---------------------------------------------------------------------------

  /// Preloads an app-open ad. Re-armed after every show.
  Future<void> loadAppOpen() async {
    if (!isSupported || _loadingAppOpen || _appOpen != null) return;
    _loadingAppOpen = true;
    try {
      await AppOpenAd.load(
        adUnitId: appOpenAdUnitId,
        request: const AdRequest(),
        adLoadCallback: AppOpenAdLoadCallback(
          onAdLoaded: (ad) {
            _appOpen = ad;
            _loadingAppOpen = false;
          },
          onAdFailedToLoad: (_) {
            _loadingAppOpen = false;
          },
        ),
      );
    } catch (_) {
      _loadingAppOpen = false;
    }
  }

  /// Cold-start entry point: called once from the home screen's first frame.
  /// The preload races the first frame, so wait briefly for it before giving
  /// up (splash/UI is already visible — the ad lands after it, never before).
  Future<void> showAppOpenOnLaunch() async {
    if (!isSupported || suppressAppOpen) return;
    if (_appOpen == null && _loadingAppOpen) {
      final deadline = DateTime.now().add(const Duration(seconds: 4));
      while (_appOpen == null &&
          _loadingAppOpen &&
          DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
    await _maybeShowAppOpen();
  }

  /// Shows the preloaded app-open ad if one is ready and the frequency cap
  /// allows it. Never throws; reloads after showing.
  Future<void> _maybeShowAppOpen() async {
    if (!isSupported || suppressAppOpen) return;
    if (_appOpen == null) return;
    final last = _lastAppOpenShown;
    if (last != null && DateTime.now().difference(last) < _appOpenMinGap) {
      return;
    }

    final ad = _appOpen!;
    _appOpen = null;
    _lastAppOpenShown = DateTime.now();

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        unawaited(loadAppOpen());
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        unawaited(loadAppOpen());
      },
    );
    try {
      await ad.show();
    } catch (_) {
      ad.dispose();
      unawaited(loadAppOpen());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Warm resume: the classic app-open moment (cold start shows the splash).
    if (state == AppLifecycleState.resumed) {
      unawaited(_maybeShowAppOpen());
    }
  }

  // ---------------------------------------------------------------------------
  // Rewarded interstitial
  // ---------------------------------------------------------------------------

  /// Loads and shows a rewarded interstitial — an interstitial the user opts
  /// into (used as the gate for guest gameplay). [onDone] fires when the ad
  /// is dismissed, or immediately when nothing could be loaded (offline /
  /// no fill / unsupported), so the caller's flow never gets stuck.
  Future<bool> showRewardedInterstitial({required VoidCallback onDone}) async {
    if (!isSupported) {
      onDone();
      return false;
    }

    final result = Completer<bool>();
    try {
      await RewardedInterstitialAd.load(
        adUnitId: rewardedInterstitialAdUnitId,
        request: const AdRequest(),
        rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
                onDone();
              },
              onAdFailedToShowFullScreenContent: (ad, _) {
                ad.dispose();
                onDone();
              },
            );
            ad.show(onUserEarnedReward: (_, __) {});
            if (!result.isCompleted) result.complete(true);
          },
          onAdFailedToLoad: (_) {
            onDone();
            if (!result.isCompleted) result.complete(false);
          },
        ),
      );
    } catch (_) {
      onDone();
      if (!result.isCompleted) result.complete(false);
    }
    return result.future;
  }

  // ---------------------------------------------------------------------------
  // Rewarded
  // ---------------------------------------------------------------------------

  /// Loads and shows a rewarded ad.
  ///
  /// [onEarned] fires only when AdMob confirms the user earned the reward;
  /// [onClosed] fires when the ad is dismissed (after earned or skipped).
  /// Returns false when no ad could be loaded (offline, no fill, unsupported
  /// platform) so the caller can show a fallback message.
  Future<bool> showRewarded({
    required VoidCallback onEarned,
    required VoidCallback onClosed,
  }) async {
    if (!isSupported) return false;

    final result = Completer<bool>();
    try {
      await RewardedAd.load(
        adUnitId: rewardedAdUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            ad.fullScreenContentCallback = FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
                onClosed();
              },
              onAdFailedToShowFullScreenContent: (ad, _) {
                ad.dispose();
                onClosed();
              },
            );
            ad.show(onUserEarnedReward: (_, __) => onEarned());
            if (!result.isCompleted) result.complete(true);
          },
          onAdFailedToLoad: (_) {
            if (!result.isCompleted) result.complete(false);
          },
        ),
      );
    } catch (_) {
      if (!result.isCompleted) result.complete(false);
    }
    return result.future;
  }

  // ---------------------------------------------------------------------------
  // Interstitial
  // ---------------------------------------------------------------------------

  /// Preloads an interstitial. Called after init and re-armed after every
  /// show, so the next trigger usually has an ad ready.
  Future<void> loadInterstitial() async {
    if (!isSupported || _loadingInterstitial || _interstitial != null) return;
    _loadingInterstitial = true;
    try {
      await InterstitialAd.load(
        adUnitId: interstitialAdUnitId,
        request: const AdRequest(),
        adLoadCallback: InterstitialAdLoadCallback(
          onAdLoaded: (ad) {
            _interstitial = ad;
            _loadingInterstitial = false;
          },
          onAdFailedToLoad: (_) {
            _loadingInterstitial = false;
          },
        ),
      );
    } catch (_) {
      _loadingInterstitial = false;
    }
  }

  /// Shows a preloaded interstitial if one is ready and the frequency cap
  /// allows it. Never blocks gameplay: when nothing shows, [onDone] still
  /// fires (after the ad is dismissed, or immediately when skipped).
  Future<void> showInterstitial({VoidCallback? onDone}) async {
    if (!isSupported) {
      onDone?.call();
      return;
    }
    if (_interstitial == null || !_capAllows()) {
      onDone?.call();
      return;
    }

    final ad = _interstitial!;
    _interstitial = null;
    _lastInterstitialShown = DateTime.now();

    var finished = false;
    void finish() {
      if (finished) return;
      finished = true;
      onDone?.call();
      unawaited(loadInterstitial());
    }

    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        finish();
      },
      onAdFailedToShowFullScreenContent: (ad, _) {
        ad.dispose();
        finish();
      },
    );

    try {
      ad.show();
    } catch (_) {
      ad.dispose();
      finish();
    }
  }

  bool _capAllows() {
    final last = _lastInterstitialShown;
    if (last != null && DateTime.now().difference(last) < _interstitialMinGap) {
      return false;
    }
    return true;
  }

  /// App-open interstitial: every [_appOpenEveryLaunches] launches, shown once
  /// per cold start, subject to the same min-gap cap. Call once from the home
  /// screen's first frame so it lands after the UI is visible.
  Future<void> maybeShowAppOpenInterstitial() async {
    if (_appOpenInterstitialDone) return;
    _appOpenInterstitialDone = true;
    // A real app-open ad takes precedence — never stack two open ads.
    if (_appOpen != null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final count = (prefs.getInt(_kLaunchCount) ?? 0) + 1;
      await prefs.setInt(_kLaunchCount, count);
      if (count % _appOpenEveryLaunches != 0) return;
    } catch (_) {
      return;
    }
    await showInterstitial();
  }

  /// Dart-side factory id — must match the platform ad factories registered
  /// in MainActivity.kt (Android) and AppDelegate.swift (iOS).
  static const String nativeAdFactoryId = 'picturegames_native';
}

/// Self-managing AdMob Native Advanced ad: loads on first layout, collapses to
/// zero height while loading or on load failure, disposes itself. The ad view
/// itself is built by the platform factories (icon, headline, body, media, CTA).
class NativeAdWidget extends StatefulWidget {
  const NativeAdWidget({super.key});

  @override
  State<NativeAdWidget> createState() => _NativeAdWidgetState();
}

class _NativeAdWidgetState extends State<NativeAdWidget> {
  NativeAd? _ad;
  bool _loaded = false;
  int _attempts = 0;

  @override
  void initState() {
    super.initState();
    final NativeAd ad = NativeAd(
      adUnitId: AdsService.instance.nativeAdUnitId,
      factoryId: AdsService.nativeAdFactoryId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (Ad ad) {
          debugPrint('[ads] native loaded');
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          // code 0 = no fill (unit OK, no demand); code 1/3 point at the unit
          // id or the unit's TYPE in the AdMob console — a Banner unit cannot
          // serve native ads and always returns no-fill.
          debugPrint(
              '[ads] native failed: code ${error.code} ${error.domain}: ${error.message}');
          ad.dispose();
          _ad = null;
          // Retry a few times with backoff — factory warm-up and transient
          // no-fill both resolve on later attempts.
          _attempts += 1;
          if (_attempts <= 3 && mounted) {
            Future<void>.delayed(Duration(seconds: 10 * _attempts), () {
              if (mounted && !_loaded) _load();
            });
          }
        },
      ),
    );
    _ad = ad;
    // Never let an ad failure (tests, offline, uncreated ad unit) crash the
    // host screen.
    ad.load().catchError((Object _) {});
  }

  void _load() {
    if (!AdsService.instance.isSupported) return;
    final NativeAd ad = NativeAd(
      adUnitId: AdsService.instance.nativeAdUnitId,
      factoryId: AdsService.nativeAdFactoryId,
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (Ad ad) {
          debugPrint('[ads] native loaded');
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          debugPrint(
              '[ads] native failed: code ${error.code} ${error.domain}: ${error.message}');
          ad.dispose();
          _ad = null;
          _attempts += 1;
          if (_attempts <= 3 && mounted) {
            Future<void>.delayed(Duration(seconds: 10 * _attempts), () {
              if (mounted && !_loaded) _load();
            });
          }
        },
      ),
    );
    _ad = ad;
    ad.load().catchError((Object _) {});
  }

  @override
  void dispose() {
    _ad?.dispose();
    _ad = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final NativeAd? ad = _ad;
    if (!_loaded || ad == null) {
      return const SizedBox.shrink();
    }
    return SafeArea(
      top: false,
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFEDEEF4)),
        ),
        // Bounded box: the platform factory renders inside it. The native
        // template (headline + media + body + CTA) needs ~250-280 logical px.
        height: 280,
        child: AdWidget(ad: ad),
      ),
    );
  }
}
