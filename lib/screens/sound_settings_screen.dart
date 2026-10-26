import 'package:flutter/material.dart';

import '../core/sound_service.dart';
import '../theme/app_theme.dart';

/// Sound & Music — device-local audio settings with real playback:
/// effect sounds during gameplay and an optional looping music bed.
class SoundSettingsScreen extends StatefulWidget {
  const SoundSettingsScreen({super.key});

  @override
  State<SoundSettingsScreen> createState() => _SoundSettingsScreenState();
}

class _SoundSettingsScreenState extends State<SoundSettingsScreen> {
  bool _sfx = true;
  bool _music = false;

  @override
  void initState() {
    super.initState();
    final sound = SoundService.instance;
    _sfx = sound.sfxEnabled;
    _music = sound.musicEnabled;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Sound & Music',
            style:
                TextStyle(fontWeight: FontWeight.w900, color: AppColors.ink)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _settingCard(
            icon: Icons.music_note_rounded,
            title: 'Background music',
            subtitle: 'A calm loop while you play. Turns off automatically '
                'when the app goes to the background.',
            value: _music,
            onChanged: (value) async {
              await SoundService.instance.setMusicEnabled(value);
              setState(() => _music = value);
            },
          ),
          const SizedBox(height: 12),
          _settingCard(
            icon: Icons.volume_up_rounded,
            title: 'Sound effects',
            subtitle: 'Match, mistake and level-complete sounds.',
            value: _sfx,
            onChanged: (value) async {
              await SoundService.instance.setSfxEnabled(value);
              setState(() => _sfx = value);
              // Audible confirmation when switching on.
              if (value) SoundService.instance.play(Sfx.success);
            },
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.palePurple.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              children: [
                Icon(Icons.graphic_eq_rounded, size: 18, color: AppColors.purple),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Your choices are saved on this device and apply '
                    'immediately — no account needed.',
                    style: TextStyle(fontSize: 11.5, color: AppColors.ink),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _settingCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.purple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.purple, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink)),
                const SizedBox(height: 4),
                Text(subtitle,
                    style: const TextStyle(fontSize: 12, color: Colors.grey)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Switch.adaptive(
            value: value,
            activeThumbColor: AppColors.purple,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}
