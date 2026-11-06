import 'package:flutter/material.dart';

import '../core/game_data.dart';
import '../theme/app_theme.dart';

/// Server notification inbox: contest invites, match reminders, results.
/// Items arrive via the sync snapshot; "mark all read" hits the backend.
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final GameData game = GameData.instance;

  @override
  void initState() {
    super.initState();
    game.refreshNotifications();
  }

  String _when(String? createdAt) {
    if (createdAt == null) return '';
    final t = DateTime.tryParse(createdAt)?.toLocal();
    if (t == null) return '';
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes}m ago';
    if (diff.inDays < 1) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${t.day}/${t.month}/${t.year}';
  }

  IconData _iconFor(String? type) {
    switch (type) {
      case 'contest_qualified':
        return Icons.emoji_events_rounded;
      case 'contest_match_ready':
        return Icons.sports_kabaddi_rounded;
      case 'contest_reminder':
        return Icons.alarm_rounded;
      case 'contest_result':
        return Icons.wysiwyg_rounded;
      default:
        return Icons.notifications_rounded;
    }
  }

  Color _accentFor(String? type) {
    switch (type) {
      case 'contest_qualified':
        return const Color(0xFFF5B82E);
      case 'contest_result':
        return const Color(0xFF10B981);
      default:
        return AppColors.purple;
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = game.notifications;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications',
            style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (game.unreadNotifications > 0)
            TextButton(
              onPressed: () => game.markNotificationsRead(),
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: items.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.notifications_off_rounded,
                        size: 56, color: Colors.grey),
                    SizedBox(height: 14),
                    Text('No notifications yet',
                        style: TextStyle(fontWeight: FontWeight.bold)),
                    SizedBox(height: 6),
                    Text(
                      'Contest invites, match reminders and results will show up here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.black54),
                    ),
                  ],
                ),
              ),
            )
          : AnimatedBuilder(
              animation: game,
              builder: (context, _) => ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (context, i) {
                  final n = items[i];
                  final read = n['read'] as bool? ?? false;
                  final type = n['type'] as String?;
                  return Container(
                    decoration: BoxDecoration(
                      color: read ? Colors.white : const Color(0xFFF4F1FE),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: read ? const Color(0xFFEDEEF4) : AppColors.purple.withValues(alpha: 0.25),
                      ),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: _accentFor(type).withValues(alpha: 0.15),
                        child: Icon(_iconFor(type), color: _accentFor(type), size: 22),
                      ),
                      title: Row(
                        children: [
                          Expanded(
                            child: Text(
                              n['title'] as String? ?? '',
                              style: TextStyle(
                                fontWeight: read ? FontWeight.w700 : FontWeight.w900,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (!read)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.purple,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 3),
                          Text(
                            n['body'] as String? ?? '',
                            style: const TextStyle(fontSize: 12.5, color: Colors.black87),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _when(n['createdAt'] as String?),
                            style: const TextStyle(fontSize: 10.5, color: Colors.black38),
                          ),
                        ],
                      ),
                      onTap: () {
                        if (!read) game.markNotificationsRead([n['id'] as String]);
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }
}
