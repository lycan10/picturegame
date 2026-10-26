import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Game audio: short sound effects plus an optional looping music bed.
///
/// Settings are device-local (shared_preferences) and default to
/// effects-on / music-off. Music playback respects the app lifecycle —
/// it pauses in the background and resumes on return.
enum Sfx { success, wrong, complete, click, coin }

class SoundService with WidgetsBindingObserver {
  SoundService._();
  static final SoundService instance = SoundService._();

  static const _kSfxEnabled = 'sound_sfx_enabled';
  static const _kMusicEnabled = 'sound_music_enabled';

  final AudioPlayer _sfxPlayer = AudioPlayer();
  AudioPlayer? _musicPlayer;

  bool _sfxEnabled = true;
  bool _musicEnabled = false;
  bool _initialized = false;
  bool _appInForeground = true;

  bool get sfxEnabled => _sfxEnabled;
  bool get musicEnabled => _musicEnabled;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    _sfxEnabled = prefs.getBool(_kSfxEnabled) ?? true;
    _musicEnabled = prefs.getBool(_kMusicEnabled) ?? false;

    WidgetsBinding.instance.addObserver(this);
    if (_musicEnabled && _appInForeground) {
      unawaited(_startMusic());
    }
  }

  Future<void> setSfxEnabled(bool enabled) async {
    _sfxEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSfxEnabled, enabled);
  }

  Future<void> setMusicEnabled(bool enabled) async {
    _musicEnabled = enabled;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kMusicEnabled, enabled);
    if (enabled && _appInForeground) {
      await _startMusic();
    } else {
      await _stopMusic();
    }
  }

  Future<void> _startMusic() async {
    final player = _musicPlayer ??= AudioPlayer();
    try {
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(0.5);
      await player.play(AssetSource('sounds/music_loop.wav'));
    } catch (_) {
      // Audio not available (e.g. tests / desktop without device) — ignore.
    }
  }

  Future<void> _stopMusic() async {
    try {
      await _musicPlayer?.stop();
    } catch (_) {}
  }

  void play(Sfx sfx) {
    if (!_sfxEnabled) return;
    final name = switch (sfx) {
      Sfx.success => 'success.wav',
      Sfx.wrong => 'wrong.wav',
      Sfx.complete => 'complete.wav',
      Sfx.click => 'click.wav',
      Sfx.coin => 'coin.wav',
    };
    // One player, restarted per effect — cheap and avoids overlapping pools.
    unawaited(() async {
      try {
        await _sfxPlayer.stop();
        await _sfxPlayer.play(AssetSource('sounds/$name'));
      } catch (_) {}
    }());
  }

  // ---- Lifecycle ----------------------------------------------------------

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appInForeground = state == AppLifecycleState.resumed;
    if (!_initialized) return;
    if (_appInForeground && _musicEnabled) {
      unawaited(_startMusic());
    } else {
      unawaited(_stopMusic());
    }
  }
}

/// Convenience hook so callers can do `SoundService.play(Sfx.success)`
/// without touching the singleton twice.
void playSfx(Sfx sfx) => SoundService.instance.play(sfx);
