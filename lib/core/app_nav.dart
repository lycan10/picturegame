import 'package:flutter/material.dart';

/// Global navigator key so push-notification taps can open screens from
/// anywhere (no BuildContext available in background handlers).
class AppNav {
  AppNav._();
  static final GlobalKey<NavigatorState> key = GlobalKey<NavigatorState>();

  /// Pushes [page] onto the root navigator; no-op before the app is mounted.
  static void push(Widget page) {
    final context = key.currentContext;
    if (context == null) return;
    Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => page),
    );
  }
}
