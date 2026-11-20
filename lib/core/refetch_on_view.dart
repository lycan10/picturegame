import 'package:flutter/material.dart';

import 'app_nav.dart';

/// Mixin for screens that fetch data: [onViewVisible] fires EVERY time the
/// screen comes into view again — when the user returns from a screen pushed
/// on top of it — so lists/profiles are never stale ("re-fetch on every
/// view", regardless of whether the screen was open before). Pair it with
/// the screen's own initState load, which covers the first open.
///
/// ```dart
/// class _FriendsScreenState extends State<FriendsScreen> with RefetchOnView {
///   @override
///   void onViewVisible() => _load();
///   ...
/// }
/// ```
/// Requires `AppNav.routeObserver` in MaterialApp's navigatorObservers.
mixin RefetchOnView<T extends StatefulWidget> on State<T>
    implements RouteAware {
  /// Called when this screen becomes visible again after being covered.
  void onViewVisible();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      AppNav.routeObserver.subscribe(this, route);
    }
  }

  @override
  void dispose() {
    AppNav.routeObserver.unsubscribe(this);
    super.dispose();
  }

  // RouteAware's remaining members are deliberately no-ops: didPush fires on
  // the screen's own push (initState already fetched), didPop/didPushNext
  // relate to transitions where this screen isn't the one becoming visible.
  @override
  void didPush() {}

  @override
  void didPop() {}

  @override
  void didPushNext() {}

  @override
  void didPopNext() => onViewVisible();
}
