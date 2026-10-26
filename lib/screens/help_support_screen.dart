import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../theme/app_theme.dart';

/// Help & Support — how to play, scoring, hints, battles, account answers
/// and a contact channel.
class HelpSupportScreen extends StatelessWidget {
  const HelpSupportScreen({super.key});

  static const _supportEmail = 'support@picturematch.app';

  Future<void> _contact(BuildContext context) async {
    final uri = Uri(
      scheme: 'mailto',
      path: _supportEmail,
      query: 'subject=${Uri.encodeComponent('Picture Match support')}',
    );
    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        await Clipboard.setData(const ClipboardData(text: _supportEmail));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            behavior: SnackBarBehavior.floating,
            content: Text('No mail app found — $_supportEmail copied.'),
          ));
        }
      }
    } catch (_) {
      await Clipboard.setData(const ClipboardData(text: _supportEmail));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text('No mail app found — $_supportEmail copied.'),
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
        title: const Text('Help & Support',
            style:
                TextStyle(fontWeight: FontWeight.w900, color: AppColors.ink)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          _faq(
            icon: Icons.extension_rounded,
            title: 'How do I play?',
            body: 'Drag each word chip onto the picture it matches. Complete '
                'every match in a level to finish it — finishing a level '
                'unlocks the next one.',
          ),
          _faq(
            icon: Icons.star_rounded,
            title: 'How are stars and points earned?',
            body: 'You get +100 points per match, and hints cost −25. Three '
                'stars means every match was correct on the first try with no '
                'hints; 80%+ accuracy earns two stars, and finishing always '
                'earns at least one. Replay levels to improve your best.',
          ),
          _faq(
            icon: Icons.lightbulb_rounded,
            title: 'How do hints work?',
            body: 'Hints are a consumable you own. In a level, the Hint '
                'button lets you choose: reveal an extra clue, remove a wrong '
                'option, or get a nudge toward the right picture. Each use '
                'costs 1 hint and −25 points. Earn more from the store or by '
                'watching a rewarded ad.',
          ),
          _faq(
            icon: Icons.sports_esports_rounded,
            title: 'How do battles work?',
            body: 'You and an opponent see the same picture each round — tap '
                'the matching word before the 30-second timer runs out. A '
                'wrong answer or timeout costs a heart; you each start with '
                'three. Last player standing wins +200 points and +50 coins.',
          ),
          _faq(
            icon: Icons.local_fire_department_rounded,
            title: 'What keeps my streak alive?',
            body: 'Complete at least one level each day (UTC). Missing a day '
                'resets the streak, but your points and stars stay safe.',
          ),
          _faq(
            icon: Icons.cloud_off_rounded,
            title: 'Does the game work offline?',
            body: 'Yes. Levels, progress, coins and settings all work and are '
                'saved on your device. When you sign in and come back online, '
                'everything syncs automatically — nothing is lost.',
          ),
          _faq(
            icon: Icons.account_balance_wallet_rounded,
            title: 'Questions about a purchase?',
            body: 'Purchases are processed securely by Paystack. For refunds '
                'or billing questions, email us with your transaction '
                'reference and we will help.',
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Still need help?',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink)),
                const SizedBox(height: 4),
                const Text(
                  'Email us at $_supportEmail — we usually reply within a day.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => _contact(context),
                  icon: const Icon(Icons.mail_outline_rounded, size: 18),
                  label: const Text('Contact support'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.purple,
                    minimumSize: const Size(0, 46),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Center(
            child: Text(
              'PICTURE MATCH  •  SUPPORT',
              style: TextStyle(
                  color: Colors.grey, fontSize: 10, letterSpacing: 1.2),
            ),
          ),
        ],
      ),
    );
  }

  Widget _faq({
    required IconData icon,
    required String title,
    required String body,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.purple.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(13),
            ),
            child: Icon(icon, color: AppColors.purple, size: 20),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: AppColors.ink)),
                const SizedBox(height: 5),
                Text(body,
                    style: const TextStyle(
                        fontSize: 12.5, height: 1.5, color: Colors.black54)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
