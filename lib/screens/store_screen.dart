import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen> {
  int coinBalance = 250;
  int hintBalance = 3;
  int selectedTab = 0;

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _watchAd(String rewardType) {
    // TODO: Show a rewarded ad and grant the reward only
    // after the ad SDK confirms the reward callback.
    _showMessage(
      'Connect rewarded ads to earn $rewardType.',
    );
  }

  void _purchaseCoins(int coins, String productId) {
    // TODO: Connect to Google Play Billing / Apple StoreKit.
    // Grant coins only after verified purchase confirmation.
    _showMessage(
      'Connect in-app purchases for $productId.',
    );
  }

  void _purchaseHints(int hints, String productId) {
    // TODO: Connect to in-app purchases or use earned coins.
    _showMessage(
      'Connect in-app purchases for $productId.',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildWalletCard(),
              const SizedBox(height: 28),
              _buildTabs(),
              const SizedBox(height: 22),
              if (selectedTab == 0) ...[
                _buildSectionTitle(
                  'Coin Bundles',
                  'Power up your game with more coins.',
                ),
                const SizedBox(height: 16),
                _buildCoinBundle(
                  title: 'Starter Pack',
                  coins: 500,
                  price: '\$0.99',
                  icon: Icons.savings_rounded,
                  color: const Color(0xFF10B981),
                  productId: 'coins_500',
                ),
                _buildCoinBundle(
                  title: 'Popular Pack',
                  coins: 1500,
                  price: '\$1.99',
                  icon: Icons.monetization_on_rounded,
                  color: const Color(0xFF7C3AED),
                  productId: 'coins_1500',
                  badge: 'POPULAR',
                ),
                _buildCoinBundle(
                  title: 'Mega Pack',
                  coins: 4000,
                  price: '\$4.99',
                  icon: Icons.diamond_rounded,
                  color: const Color(0xFFF59E0B),
                  productId: 'coins_4000',
                ),
                _buildCoinBundle(
                  title: 'Ultimate Pack',
                  coins: 10000,
                  price: '\$9.99',
                  icon: Icons.workspace_premium_rounded,
                  color: const Color(0xFFEC4899),
                  productId: 'coins_10000',
                  badge: 'BEST VALUE',
                ),
              ] else ...[
                _buildSectionTitle(
                  'Hint Packs',
                  'Get help when you need it most.',
                ),
                const SizedBox(height: 16),
                _buildHintBundle(
                  title: 'Quick Help',
                  hints: 3,
                  price: '\$0.99',
                  description: 'Perfect for a tricky question.',
                  productId: 'hints_3',
                ),
                _buildHintBundle(
                  title: 'Smart Player',
                  hints: 10,
                  price: '\$1.99',
                  description: 'Keep your streak alive.',
                  productId: 'hints_10',
                  badge: 'POPULAR',
                ),
                _buildHintBundle(
                  title: 'Hint Master',
                  hints: 30,
                  price: '\$4.99',
                  description: 'A generous supply of extra help.',
                  productId: 'hints_30',
                  badge: 'BEST VALUE',
                ),
              ],
              const SizedBox(height: 28),
              _buildFreeRewards(),
              const SizedBox(height: 24),
              _buildHintGuide(),
              const SizedBox(height: 20),
              const Center(
                child: Text(
                  'Purchases are subject to platform store terms.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: const Icon(Icons.arrow_back_ios),
        ),
        const SizedBox(
          width: 3,
        ),
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.purple.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(
            Icons.storefront_rounded,
            color: AppColors.purple,
            size: 27,
          ),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Game Store',
                style: TextStyle(
                  color: AppColors.ink,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
              SizedBox(height: 4),
              Text(
                'Coins, hints and power-ups.',
                style: TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => _showMessage(
            'Connect your purchase service to restore purchases.',
          ),
          icon: const Icon(
            Icons.restore_rounded,
            color: AppColors.purple,
          ),
          tooltip: 'Restore purchases',
        ),
      ],
    );
  }

  Widget _buildWalletCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF7C3AED),
            Color(0xFF4C1D95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet_rounded,
                color: Colors.white.withValues(alpha: 0.85),
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                'MY WALLET',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.85),
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Row(
            children: [
              Expanded(
                child: _walletItem(
                  icon: Icons.monetization_on_rounded,
                  label: 'COINS',
                  value: _formatNumber(coinBalance),
                  color: const Color(0xFFFFD166),
                ),
              ),
              Container(
                width: 1,
                height: 52,
                color: Colors.white.withValues(alpha: 0.2),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: _walletItem(
                  icon: Icons.lightbulb_rounded,
                  label: 'HINTS',
                  value: '$hintBalance',
                  color: const Color(0xFF86EFAC),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.play_circle_fill_rounded,
                  color: Colors.white,
                  size: 23,
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Watch an ad to earn free rewards',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: Colors.white.withValues(alpha: 0.8),
                  size: 14,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _walletItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      children: [
        Icon(icon, color: color, size: 30),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 10,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTabs() {
    return Container(
      padding: const EdgeInsets.all(5),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          _tabButton(
            label: 'Coins',
            icon: Icons.monetization_on_rounded,
            index: 0,
          ),
          _tabButton(
            label: 'Hints',
            icon: Icons.lightbulb_rounded,
            index: 1,
          ),
        ],
      ),
    );
  }

  Widget _tabButton({
    required String label,
    required IconData icon,
    required int index,
  }) {
    final selected = selectedTab == index;

    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => selectedTab = index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 13),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(11),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.04),
                      blurRadius: 8,
                    ),
                  ]
                : [],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 19,
                color: selected ? AppColors.purple : Colors.grey,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  color: selected ? AppColors.purple : Colors.grey,
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: AppColors.ink,
            fontSize: 20,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: const TextStyle(
            color: Colors.grey,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildCoinBundle({
    required String title,
    required int coins,
    required String price,
    required IconData icon,
    required Color color,
    required String productId,
    String? badge,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(
          color: badge != null
              ? color.withValues(alpha: 0.35)
              : Colors.grey.withValues(alpha: 0.12),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 57,
            height: 57,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(icon, color: color, size: 32),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        title,
                        style: const TextStyle(
                          color: AppColors.ink,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (badge != null) ...[
                      const SizedBox(width: 6),
                      Flexible(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            badge,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: color,
                              fontSize: 8,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(
                      Icons.monetization_on_rounded,
                      color: color,
                      size: 18,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      _formatNumber(coins),
                      style: TextStyle(
                        color: color,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'coins',
                      style: TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _purchaseCoins(coins, productId),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.purple,
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                horizontal: 13,
                vertical: 12,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              price,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHintBundle({
    required String title,
    required int hints,
    required String price,
    required String description,
    required String productId,
    String? badge,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(21),
        border: Border.all(
          color: Colors.grey.withValues(alpha: 0.12),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 57,
                height: 57,
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF2CC),
                  borderRadius: BorderRadius.circular(17),
                ),
                child: const Icon(
                  Icons.lightbulb_rounded,
                  color: Color(0xFFD99A00),
                  size: 32,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: const TextStyle(
                              color: AppColors.ink,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        if (badge != null) ...[
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              badge,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: AppColors.purple,
                                fontSize: 8,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    Text(
                      description,
                      style: const TextStyle(
                        color: Colors.grey,
                        fontSize: 11,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '$hints hints',
                      style: const TextStyle(
                        color: AppColors.purple,
                        fontWeight: FontWeight.w900,
                        fontSize: 17,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _purchaseHints(hints, productId),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.purple,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: Text(
                'Get Hints • $price',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFreeRewards() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFFE7F8EF),
        borderRadius: BorderRadius.circular(23),
        border: Border.all(color: const Color(0xFFB9EACD)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.card_giftcard_rounded,
                color: Color(0xFF15803D),
                size: 25,
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Earn Rewards for Free',
                  style: TextStyle(
                    color: Color(0xFF166534),
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            'Watch a short rewarded ad to earn extra game resources.',
            style: TextStyle(
              color: Color(0xFF39734E),
              fontSize: 12,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          _freeRewardRow(
            icon: Icons.monetization_on_rounded,
            title: 'Free Coins',
            reward: '+50 coins',
            onTap: () => _watchAd('50 coins'),
          ),
          const SizedBox(height: 10),
          _freeRewardRow(
            icon: Icons.lightbulb_rounded,
            title: 'Free Hint',
            reward: '+1 hint',
            onTap: () => _watchAd('1 hint'),
          ),
          const SizedBox(height: 14),
          Text(
            'Availability may be limited by ad supply or daily reward limits.',
            style: TextStyle(
              color: const Color(0xFF166534).withValues(alpha: 0.8),
              fontSize: 10,
            ),
          ),
        ],
      ),
    );
  }

  Widget _freeRewardRow({
    required IconData icon,
    required String title,
    required String reward,
    required VoidCallback onTap,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
      ),
      child: Row(
        children: [
          Icon(icon, color: const Color(0xFF16A34A), size: 24),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.ink,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  reward,
                  style: const TextStyle(
                    color: Color(0xFF15803D),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF15803D),
              foregroundColor: Colors.white,
              elevation: 0,
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.play_arrow_rounded, size: 17),
                SizedBox(width: 3),
                Text(
                  'Watch',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHintGuide() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How hints work',
            style: TextStyle(
              color: AppColors.ink,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          SizedBox(height: 14),
          _HintDescription(
            icon: Icons.visibility_rounded,
            title: 'Reveal a clue',
            subtitle: 'Show an extra clue for a difficult match.',
          ),
          SizedBox(height: 12),
          _HintDescription(
            icon: Icons.remove_circle_outline_rounded,
            title: 'Remove a wrong option',
            subtitle: 'Eliminate one incorrect answer.',
          ),
          SizedBox(height: 12),
          _HintDescription(
            icon: Icons.lightbulb_circle_rounded,
            title: 'Get a nudge',
            subtitle: 'Receive a hint without revealing the answer.',
          ),
        ],
      ),
    );
  }

  String _formatNumber(int number) {
    if (number >= 1000) {
      final value = number / 1000;
      return '${value == value.roundToDouble() ? value.toInt() : value.toStringAsFixed(1)}K';
    }
    return number.toString();
  }
}

class _HintDescription extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _HintDescription({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 38,
          height: 38,
          decoration: BoxDecoration(
            color: AppColors.purple.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: AppColors.purple,
            size: 20,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontWeight: FontWeight.bold,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
