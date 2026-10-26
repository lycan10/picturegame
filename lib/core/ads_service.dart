import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// AdMob rewarded-ads wrapper behind the store's "Earn Rewards for Free" and
/// the in-game "out of hints" recovery flow.
///
/// The backend still gates every grant (`POST /store/reward-ad`, capped at
/// 10/day) — call this only from the ad SDK's `onUserEarnedReward` callback,
/// which fires when AdMob itself confirms the reward.
///
/// Configuration:
///  - Ad unit IDs default to Google's official TEST rewarded unit (always
///    fillable, test ads only). Override for release with:
///    --dart-define=ADMOB_REWARDED_ID=ca-app-pub-XXXX/YYYY
///  - The AdMob *application* ID lives in AndroidManifest.xml / Info.plist.
class AdsService {
  AdsService._();
  static final AdsService instance = AdsService._();

  static const String _androidTestRewardedId =
      'ca-app-pub-3940256099942544/5224354917';
  static const String _iosTestRewardedId =
      'ca-app-pub-3940256099942544/1712485313';

  bool _initialized = false;

  bool get isSupported =>
      !kIsWeb && (Platform.isAndroid || Platform.isIOS);

  String get rewardedAdUnitId {
    const override = String.fromEnvironment('ADMOB_REWARDED_ID');
    if (override.isNotEmpty) return override;
    return Platform.isIOS ? _iosTestRewardedId : _androidTestRewardedId;
  }

  Future<void> init() async {
    if (!isSupported || _initialized) return;
    _initialized = true;
    await MobileAds.instance.initialize();
  }

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
}
