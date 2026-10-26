import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/notification_service.dart';
import '../theme/app_theme.dart';

/// Daily reminder settings — device-local notifications ("Manage your
/// reminders"). The choice and time are persisted on this device; the
/// scheduled notification survives reboots.
class NotificationSettingsScreen extends StatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  State<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends State<NotificationSettingsScreen> {
  static const _kEnabled = 'notif_daily_enabled';
  static const _kHour = 'notif_daily_hour';
  static const _kMinute = 'notif_daily_minute';

  bool _enabled = false;
  int _hour = 19;
  int _minute = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _enabled = prefs.getBool(_kEnabled) ?? false;
      _hour = prefs.getInt(_kHour) ?? 19;
      _minute = prefs.getInt(_kMinute) ?? 0;
    });
  }

  String get _timeLabel =>
      '${_hour.toString().padLeft(2, '0')}:${_minute.toString().padLeft(2, '0')}';

  Future<void> _setEnabled(bool enabled) async {
    if (_busy) return;
    setState(() => _busy = true);

    try {
      if (enabled) {
        final granted = await NotificationService.instance.requestPermission();
        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              behavior: SnackBarBehavior.floating,
              content: Text(
                  'Notifications are blocked for this app — enable them in system settings.'),
            ));
          }
          setState(() => _busy = false);
          return;
        }
        await NotificationService.instance.scheduleDailyReminder(
          hour: _hour,
          minute: _minute,
        );
      } else {
        await NotificationService.instance.cancelDailyReminder();
      }

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_kEnabled, enabled);
      if (!mounted) return;
      setState(() => _enabled = enabled);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _hour, minute: _minute),
    );
    if (picked == null) return;

    setState(() {
      _hour = picked.hour;
      _minute = picked.minute;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kHour, _hour);
    await prefs.setInt(_kMinute, _minute);

    if (_enabled) {
      await NotificationService.instance
          .scheduleDailyReminder(hour: _hour, minute: _minute);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('Daily reminder moved to $_timeLabel.'),
        ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('Notifications',
            style:
                TextStyle(fontWeight: FontWeight.w900, color: AppColors.ink)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: _cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Daily reminder',
                              style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.ink)),
                          SizedBox(height: 4),
                          Text(
                            'A daily nudge to play and keep your streak alive.',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                    Switch.adaptive(
                      value: _enabled,
                      activeThumbColor: AppColors.purple,
                      onChanged: _busy ? null : _setEnabled,
                    ),
                  ],
                ),
                if (_enabled) ...[
                  const SizedBox(height: 10),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.schedule_rounded,
                        color: AppColors.purple),
                    title: const Text('Reminder time',
                        style: TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w700)),
                    subtitle: const Text('Local time on this device',
                        style: TextStyle(fontSize: 11)),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: AppColors.palePurple,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(_timeLabel,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: AppColors.purple)),
                    ),
                    onTap: _busy ? null : _pickTime,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: _cardDecoration(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Try it out',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink)),
                const SizedBox(height: 4),
                const Text(
                  'Send a test notification to see what the reminder looks like.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: _busy
                      ? null
                      : () async {
                          await NotificationService.instance
                              .showTestNotification();
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            behavior: SnackBarBehavior.floating,
                            content: Text('Test notification sent!'),
                          ));
                        },
                  icon: const Icon(Icons.notifications_active_outlined,
                      size: 18),
                  label: const Text('Send test notification'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.purple,
                    side: BorderSide(
                        color: AppColors.purple.withValues(alpha: 0.4)),
                  ),
                ),
              ],
            ),
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
                Icon(Icons.lock_outline_rounded,
                    size: 18, color: AppColors.purple),
                SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Reminders are scheduled on this device only — no account '
                    'needed, and nothing is sent to a server.',
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

  BoxDecoration _cardDecoration() => BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      );
}
