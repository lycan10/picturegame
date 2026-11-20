import 'package:flutter/material.dart';

/// Global navigator key so push-notification taps can open screens from
/// anywhere (no BuildContext available in background handlers).
class AppNav {
  AppNav._();
  static final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();

  /// Route observer feeding the [RefetchOnView] mixin — every pushed screen
  /// that opts in re-fetches when it becomes visible again.
  static final RouteObserver<ModalRoute<void>> routeObserver =
      RouteObserver<ModalRoute<void>>();

  /// Index of the active home bottom-nav tab. Pushed screens can't use route
  /// events for the four IndexedStack tabs (tab switches emit no route
  /// events), so screens like the leaderboard/battle arena listen here and
  /// re-fetch when their tab comes into view.
  static final ValueNotifier<int> homeTab = ValueNotifier<int>(0);

  /// Deep-link taps that arrive before the navigator mounts (cold-start
  /// notification taps during the init chain) are buffered here and flushed
  /// by [flushPending] once the first frame is up — the old no-op silently
  /// dropped them.
  static final List<Widget> _pending = [];

  static void push(Widget page) {
    final context = key.currentContext;
    if (context == null) {
      if (_pending.length < 5) _pending.add(page);
      return;
    }
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }

  /// Call once after the first frame is mounted (PictureMatchApp initState).
  static void flushPending() {
    final context = key.currentContext;
    if (context == null || _pending.isEmpty) return;
    for (final page in List<Widget>.from(_pending)) {
      Navigator.of(context, rootNavigator: true).push(
        MaterialPageRoute(builder: (_) => page),
      );
    }
    _pending.clear();
  }
}
