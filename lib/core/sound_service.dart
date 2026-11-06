import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Game audio: short sound effects plus an optional looping music bed.
///
/// Settings are device-local (shared_preferences) and default to
/// effects-on / music-off. Music and effects play on completely independent
/// players with a "mix with others" audio context, so effects never pause or
/// duck the music — both play simultaneously. Music playback respects the
/// app lifecycle: it pauses in the background and resumes on return.
enum Sfx { success, wrong, complete, click, coin }

class SoundService with WidgetsBindingObserver {
  SoundService._();
  static final SoundService instance = SoundService._();

  static const _kSfxEnabled = 'sound_sfx_enabled';
  static const _kMusicEnabled = 'sound_music_enabled';
  static const _kSfxVolume = 'sound_sfx_volume';
  static const _kMusicVolume = 'sound_music_volume';

  AudioPlayer? _musicPlayer;
  final Map<Sfx, AudioPool> _pools = {};

  bool _sfxEnabled = true;
  bool _musicEnabled = false;
  double _sfxVolume = 1.0;
  double _musicVolume = 0.6;
  bool _initialized = false;
  bool _appInForeground = true;

  bool get sfxEnabled => _sfxEnabled;
  bool get musicEnabled => _musicEnabled;
  double get sfxVolume => _sfxVolume;
  double get musicVolume => _musicVolume;

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    final prefs = await SharedPreferences.getInstance();
    _sfxEnabled = prefs.getBool(_kSfxEnabled) ?? true;
    _musicEnabled = prefs.getBool(_kMusicEnabled) ?? false;
    _sfxVolume = (prefs.getDouble(_kSfxVolume) ?? 1.0).clamp(0.0, 1.0);
    _musicVolume = (prefs.getDouble(_kMusicVolume) ?? 0.6).clamp(0.0, 1.0);

    WidgetsBinding.instance.addObserver(this);
    try {
      // "Mix with others" → no exclusive audio focus: the SFX players and the
      // music player coexist (and neither pauses the other, nor the user's
      // own background audio).
      await AudioPlayer.global
          .setAudioContext(AudioContextConfig(focus: AudioContextConfigFocus.mixWithOthers).build());
    } catch (_) {
      // Global context is best-effort; playback still works with defaults.
    }
    _createPools();
    if (_musicEnabled && _appInForeground) {
      unawaited(_startMusic());
    }
  }

  /// Builds one small pool per effect so effects overlap freely and never
  /// touch the music player's playback.
  void _createPools() {
    for (final sfx in Sfx.values) {
      final name = switch (sfx) {
        Sfx.success => 'success.wav',
        Sfx.wrong => 'wrong.wav',
        Sfx.complete => 'complete.wav',
        Sfx.click => 'click.wav',
        Sfx.coin => 'coin.wav',
      };
      try {
        unawaited(
          AudioPool.create(
            source: AssetSource('sounds/$name'),
            maxPlayers: 3,
          ).then((pool) => _pools[sfx] = pool),
        );
      } catch (_) {
        // Audio unavailable — this effect stays silent.
      }
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

  Future<void> setSfxVolume(double volume) async {
    _sfxVolume = volume.clamp(0.0, 1.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kSfxVolume, _sfxVolume);
  }

  Future<void> setMusicVolume(double volume) async {
    _musicVolume = volume.clamp(0.0, 1.0);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kMusicVolume, _musicVolume);
    try {
      await _musicPlayer?.setVolume(_musicVolume);
    } catch (_) {}
  }

  Future<void> _startMusic() async {
    final player = _musicPlayer ??= AudioPlayer();
    try {
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(_musicVolume);
      await player.play(AssetSource('sounds/music_loop.mp3'));
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
    final pool = _pools[sfx];
    if (pool == null) return; // still loading or audio unavailable
    // Pool players overlap: rapid effects don't cut each other off, and the
    // music player keeps playing throughout.
    unawaited(() async {
      try {
        await pool.start(volume: _sfxVolume);
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
