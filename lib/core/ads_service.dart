import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// AdMob ads wrapper: rewarded ads (store's "Earn Rewards for Free", in-game
/// hint recovery), interstitials (level finish / quit / battle end / app open,
/// frequency-capped) and anchored banners.
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
///    --dart-define=ADMOB_BANNER_ID=ca-app-pub-XXXX/YYYY
///  - The AdMob *application* ID lives in AndroidManifest.xml / Info.plist and
///    must be swapped for the production app ID at release time.
class AdsService {
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
  static const String _androidTestBannerId =
      'ca-app-pub-3940256099942544/6300978111';
  static const String _iosTestBannerId =
      'ca-app-pub-3940256099942544/2934735716';

  /// Minimum gap between two interstitials, so back-to-back levels or a
  /// battle finished right after a level don't stack ads on the user.
  static const Duration _interstitialMinGap = Duration(seconds: 90);

  /// Show the on-app-open interstitial only every Nth launch.
  static const int _appOpenEveryLaunches = 3;

  static const _kLastInterstitialAt = 'ads_last_interstitial_at';
  static const _kLaunchCount = 'ads_launch_count';

  bool _initialized = false;
  InterstitialAd? _interstitial;
  bool _loadingInterstitial = false;
  DateTime? _lastInterstitialShown;
  bool _appOpenInterstitialDone = false;

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

  String get bannerAdUnitId {
    const override = String.fromEnvironment('ADMOB_BANNER_ID');
    if (override.isNotEmpty) return override;
    return Platform.isIOS ? _iosTestBannerId : _androidTestBannerId;
  }

  Future<void> init() async {
    if (!isSupported || _initialized) return;
    _initialized = true;
    await MobileAds.instance.initialize();
    unawaited(loadInterstitial());
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

  // ---------------------------------------------------------------------------
  // Banner
  // ---------------------------------------------------------------------------

  /// Anchored adaptive banner size for the given screen width.
  Future<AdSize> anchoredBannerSize(BuildContext context) async {
    final width = MediaQuery.sizeOf(context).width.truncate();
    final size = await AdSize.getCurrentOrientationAnchoredAdaptiveBannerAdSize(width);
    return size ?? AdSize.banner;
  }
}

/// Self-managing anchored adaptive banner: loads on first layout, collapses to
/// zero height while loading or on load failure, disposes itself.
class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});

  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _ad;
  bool _loaded = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_ad == null) _load();
  }

  Future<void> _load() async {
    if (!AdsService.instance.isSupported) return;
    final size = await AdsService.instance.anchoredBannerSize(context);
    if (!mounted) return;
    final ad = BannerAd(
      adUnitId: AdsService.instance.bannerAdUnitId,
      size: size,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (_) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (ad, _) => ad.dispose(),
      ),
    );
    setState(() => _ad = ad);
    unawaited(ad.load());
  }

  @override
  void dispose() {
    _ad?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ad = _ad;
    if (ad == null || !_loaded) return const SizedBox.shrink();
    return SafeArea(
      top: false,
      child: SizedBox(
        width: ad.size.width.toDouble(),
        height: ad.size.height.toDouble(),
        child: AdWidget(ad: ad),
      ),
    );
  }
}
