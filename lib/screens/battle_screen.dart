import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api_client.dart';
import '../core/formatters.dart';
import '../core/game_data.dart';
import 'package:share_plus/share_plus.dart';
import '../core/login_gate.dart';
import '../theme/app_theme.dart';
import 'battle_game_screen.dart';
import 'store_screen.dart';

/// Battle Arena lobby: start a friend room, join one by code, or quick-match.
/// Once a room goes active, this screen hands over to [BattleGameScreen].
class BattleScreen extends StatefulWidget {
  /// When set (e.g. from a "opponent is waiting" push notification), the
  /// screen opens straight into that room's waiting/lobby state.
  final String? rejoinCode;

  /// Whether the deep-linked rejoin is the room's host (default) or the
  /// lobby guest waiting for the host to start.
  final bool rejoinAsHost;

  const BattleScreen({super.key, this.rejoinCode, this.rejoinAsHost = true});

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  bool isWaiting = false;
  // Lobby: friend-room joiners wait here until the host accepts. The host
  // sees the lobby guest and a "Start battle" action; joiners see a wait card.
  bool _isHost = false;
  bool _inLobby = false;
  bool _canStart = false;
  String? _lobbyGuestName;

  String roomCode = '';
  Timer? _pollTimer;

  /// Guards against late responses acting after the user backed out.
  int _actionTicket = 0;
  bool _searchDialogOpen = false;
  bool _inviteDialogOpen = false;

  @override
  void initState() {
    super.initState();
    GameData.instance.addListener(_onGameDataChanged);
    // Deep link from a "your opponent is waiting" notification: reopen the
    // room's waiting/lobby state so the host can accept.
    final rejoin = widget.rejoinCode;
    if (rejoin != null && rejoin.isNotEmpty) {
      roomCode = rejoin;
      isWaiting = true;
      _isHost = widget.rejoinAsHost;
      _startPolling();
    }
  }

  @override
  void dispose() {
    GameData.instance.removeListener(_onGameDataChanged);
    _pollTimer?.cancel();
    super.dispose();
  }

  void _onGameDataChanged() {
    if (mounted) setState(() {});
  }

  void _showNeedCoinsDialog({required int needed, required String modeName}) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: const Row(
          children: [
            Icon(Icons.stars_rounded, color: Color(0xFFF5B82E), size: 28),
            SizedBox(width: 10),
            Text('More Coins Needed'),
          ],
        ),
        content: Text(
          '$modeName costs $needed coins to enter. '
          'You currently have ${formatCount(GameData.instance.coins)} coins.\n\n'
          'Visit the store to get coins or complete game levels to earn more!',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              Navigator.pop(dialogContext);
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const StoreScreen()),
              );
            },
            icon: const Icon(Icons.shopping_bag_rounded, size: 18),
            label: const Text('Get Coins'),
            style: FilledButton.styleFrom(backgroundColor: AppColors.purple),
          ),
        ],
      ),
    );
  }

  Future<void> _createRoom() async {
    // Battles need an account (opponent identity, ranking, results).
    if (!await ensureSignedIn(context)) return;
    if (!mounted) return;

    final createCost = GameData.instance.createBattleCost;
    if (GameData.instance.coins < createCost) {
      _showNeedCoinsDialog(needed: createCost, modeName: 'Challenge a Friend');
      return;
    }

    final ticket = ++_actionTicket;

    String code;
    try {
      final json = await ApiClient.instance.createBattleRoom();
      code = json['code'] as String;
    } on ApiException catch (err) {
      if (!mounted || ticket != _actionTicket) return;
      if (err.message.contains('Not enough coins')) {
        _showNeedCoinsDialog(needed: createCost, modeName: 'Challenge a Friend');
      } else {
        _showMessage(err.isNetworkError
            ? "You're offline — battles need an internet connection."
            : err.message);
      }
      return;
    }

    if (!mounted || ticket != _actionTicket) return;
    setState(() {
      roomCode = code;
      isWaiting = true;
      _isHost = true;
      _inLobby = false;
      _canStart = false;
      _lobbyGuestName = null;
    });

    _showInviteDialog();
    _startPolling();
  }

  Future<void> _quickMatch() async {
    // Battles need an account (opponent identity, ranking, results).
    if (!await ensureSignedIn(context)) return;
    if (!mounted) return;

    final quickCost = GameData.instance.quickBattleCost;
    if (GameData.instance.coins < quickCost) {
      _showNeedCoinsDialog(needed: quickCost, modeName: 'Quick Match');
      return;
    }

    final ticket = ++_actionTicket;

    _showSearchingDialog();

    Map<String, dynamic> json;
    try {
      json = await ApiClient.instance.quickMatch();
    } on ApiException catch (err) {
      if (!mounted || ticket != _actionTicket) return;
      _closeSearchDialog();
      if (err.message.contains('Not enough coins')) {
        _showNeedCoinsDialog(needed: quickCost, modeName: 'Quick Match');
      } else {
        _showMessage(err.isNetworkError
            ? 'Quick match needs an internet connection.'
            : err.message);
      }
      return;
    }

    if (!mounted || ticket != _actionTicket) return;
    final code = json['code'] as String;
    final status = json['status'] as String?;

    // Someone was already waiting — the join happened server-side and deducted coins.
    if (status == 'active') {
      await GameData.instance.spendCoins(GameData.instance.quickBattleCost);
      await _enterBattle(code);
      return;
    }

    setState(() {
      roomCode = code;
      _isHost = true;
      _inLobby = false;
      _canStart = false;
      _lobbyGuestName = null;
    });
    _startPolling();
  }

  Future<void> _joinByCode() async {
    // Battles need an account (opponent identity, ranking, results).
    if (!await ensureSignedIn(context)) return;
    if (!mounted) return;

    final controller = TextEditingController();
    var joining = false;
    String? error;

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          void setJoining(bool value) =>
              setDialogState(() => joining = value);
          void setError(String? value) => setDialogState(() => error = value);

          return AlertDialog(
          backgroundColor: AppColors.canvas,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Join a Battle',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.ink,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Enter the 6-character code your friend shared.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: controller,
                autofocus: true,
                textCapitalization: TextCapitalization.characters,
                maxLength: 6,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 6,
                  color: AppColors.purple,
                ),
                decoration: InputDecoration(
                  counterText: '',
                  filled: true,
                  fillColor: Colors.white,
                  hintText: 'ABC123',
                  errorText: error,
                ),
                onSubmitted: (_) => _submitJoin(
                  dialogContext,
                  controller,
                  setJoining,
                  setError,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
            ),
          ElevatedButton.icon(
              onPressed: joining
                  ? null
                  : () => _submitJoin(
                      dialogContext,
                      controller,
                      setJoining,
                      setError,
                    ),
              icon: joining
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.login_rounded, size: 18),
              label: const Text('Join Battle'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.purple,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        );
        },
      ),
    );
  }

  Future<void> _submitJoin(
    BuildContext dialogContext,
    TextEditingController controller,
    void Function(bool) setJoining,
    void Function(String?) setError,
  ) async {
    final code = controller.text.trim().toUpperCase();
    if (code.length != 6) {
      setError('Enter the full 6-character code');
      return;
    }

    setJoining(true);
    try {
      final json = await ApiClient.instance.joinBattleRoom(code);
      if (!dialogContext.mounted) return;
      final status = json['status'] as String?;
      final inLobby = json['inLobby'] as bool? ?? false;
      if (status != 'active' && !inLobby) {
        setJoining(false);
        setError('That room is no longer available');
        return;
      }
      await GameData.instance.spendCoins(GameData.instance.createBattleCost);
      if (!dialogContext.mounted) return;
      Navigator.pop(dialogContext);
      if (inLobby) {
        // Friend-room lobby: the host must accept before the battle starts.
        setState(() {
          roomCode = code;
          isWaiting = true;
          _isHost = false;
          _inLobby = true;
          _canStart = false;
        });
        _showMessage('In the lobby — waiting for the host to start the battle');
        _startPolling();
        return;
      }
      await _enterBattle(code);
    } on ApiException catch (err) {
      if (!dialogContext.mounted) return;
      setJoining(false);
      if (err.message.contains('Not enough coins')) {
        Navigator.pop(dialogContext);
        if (mounted) {
          _showNeedCoinsDialog(needed: GameData.instance.createBattleCost, modeName: 'Join Battle');
        }
      } else {
        setError(err.isNetworkError ? 'No connection — try again' : err.message);
      }
    }
  }

  /// Closes any open waiting/search dialog and opens the live battle.
  Future<void> _enterBattle(String code) async {
    _pollTimer?.cancel();
    if (mounted && (_searchDialogOpen || _inviteDialogOpen)) {
      _searchDialogOpen = false;
      _inviteDialogOpen = false;
      Navigator.of(context, rootNavigator: true).pop();
    }
    if (!mounted) return;

    await Navigator.of(context, rootNavigator: true).push(
      MaterialPageRoute(builder: (_) => BattleGameScreen(code: code)),
    );

    if (!mounted) return;
    setState(() {
      isWaiting = false;
      roomCode = '';
    });
  }

  /// Polls the battle room every 2s while waiting; an active state means an
  /// opponent joined and gameplay can begin.
  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      final code = roomCode;
      if (code.isEmpty) {
        timer.cancel();
        return;
      }
      try {
        final state = await ApiClient.instance.battleState(code);
        final status = state['status'] as String?;
        if (!mounted || status == null) return;
        if (status == 'active') {
          timer.cancel();
          // The host's local wallet mirrors the server charge at join time;
          // joiners already spent locally when they joined.
          if (_isHost) {
            final isQuick = _searchDialogOpen;
            await GameData.instance.spendCoins(isQuick
                ? GameData.instance.quickBattleCost
                : GameData.instance.createBattleCost);
          }
          await _enterBattle(code);
        } else if (status == 'waiting') {
          final inLobby = state['inLobby'] as bool? ?? false;
          final canStart = state['canStart'] as bool? ?? false;
          final guestName =
              (state['guest'] as Map<String, dynamic>?)?['name'] as String?;
          if (!mounted) return;
          setState(() {
            _inLobby = inLobby;
            _canStart = canStart;
            _lobbyGuestName = inLobby ? guestName : null;
          });
        } else if (status == 'expired') {
          timer.cancel();
          _closeDialogs();
          setState(() {
            isWaiting = false;
            roomCode = '';
          });
          _showMessage('The room closed — no one joined in time.');
        }
      } on ApiException {
        // Offline — keep waiting quietly.
      }
    });
  }

  void _closeDialogs() {
    if (_searchDialogOpen || _inviteDialogOpen) {
      _searchDialogOpen = false;
      _inviteDialogOpen = false;
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  void _closeSearchDialog() {
    if (_searchDialogOpen) {
      _searchDialogOpen = false;
      Navigator.of(context, rootNavigator: true).pop();
    }
  }

  void _cancelRoom() async {
    _actionTicket++; // invalidate in-flight requests
    _pollTimer?.cancel();
    final code = roomCode;
    // A lobby guest just leaves — the room belongs to the host.
    if (!_isHost) {
      if (!mounted) return;
      setState(() {
        isWaiting = false;
        _inLobby = false;
        _canStart = false;
        _lobbyGuestName = null;
        roomCode = '';
      });
      return;
    }
    if (code.isNotEmpty && GameData.instance.isLoggedIn) {
      try {
        await ApiClient.instance.cancelBattleRoom(code);
      } on ApiException {
        // Best effort — the room also expires on its own.
      }
    }
    if (!mounted) return;
    setState(() {
      isWaiting = false;
      roomCode = '';
    });
  }

  /// Opens the native share sheet with a properly framed invite message.
  Future<void> _shareBattleInvite() async {
    final host = GameData.instance.displayName;
    await SharePlus.instance.share(
      ShareParams(
        title: '⚔️ Battle invite: $roomCode',
        text: '⚔️ $host challenged you to a battle in Picture Match!\n\n'
            'Join with this code: $roomCode\n\n'
            'How to play:\n'
            '1. Open Picture Match\n'
            '2. Go to Battles → Join a Battle\n'
            '3. Enter the code above\n\n'
            '3 lives each — last player standing wins! 🏆',
      ),
    );
  }

  void _copyCode() {
    Clipboard.setData(ClipboardData(text: roomCode));
    _showMessage('Battle code copied — send it to your friend!');
  }

  void _showSearchingDialog() {
    _searchDialogOpen = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.canvas,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(color: AppColors.purple),
            const SizedBox(height: 20),
            const Text(
              'Searching for an opponent…',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'This usually only takes a moment.',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.withValues(alpha: 0.9),
              ),
            ),
            const SizedBox(height: 18),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _searchDialogOpen = false;
                _cancelRoom();
              },
              child: const Text(
                'Cancel Search',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInviteDialog() {
    _inviteDialogOpen = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppColors.canvas,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: const Text(
          'Invite a Friend',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: AppColors.ink,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Share this battle code with your friend.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            // Compact code + one-tap copy.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.purple.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: AppColors.purple.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'BATTLE ROOM CODE',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.2,
                            color: Colors.grey,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          roomCode,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 3,
                            color: AppColors.purple,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy code',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: roomCode));
                      _showMessage('Battle code copied — send it to your friend!');
                    },
                    icon: const Icon(Icons.copy_rounded,
                        size: 20, color: AppColors.purple),
                  ),
                  IconButton(
                    tooltip: 'Share invite',
                    onPressed: () {
                      unawaited(_shareBattleInvite());
                    },
                    icon: const Icon(Icons.share_rounded,
                        size: 20, color: AppColors.purple),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showFriendPicker,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  side: const BorderSide(color: AppColors.purple),
                ),
                icon: const Icon(Icons.person_add_rounded,
                    size: 18, color: AppColors.purple),
                label: const Text('Invite a friend',
                    style: TextStyle(
                        color: AppColors.purple,
                        fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 12),
            const Row(
              children: [
                Icon(
                  Icons.favorite_rounded,
                  color: Colors.redAccent,
                  size: 18,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '3 lives each. Last player standing wins!',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(dialogContext);
              _inviteDialogOpen = false;
            },
            child: const Text(
              'Close',
              style: TextStyle(color: Colors.grey),
            ),
          ),
        ],
      ),
    );
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              const SizedBox(height: 24),
              _buildHeroCard(),
              const SizedBox(height: 28),
              _buildSectionTitle(
                'CHOOSE YOUR BATTLE',
                'How do you want to play?',
              ),
              const SizedBox(height: 16),
              _buildBattleOption(
                icon: Icons.people_alt_rounded,
                title: 'Challenge a Friend',
                subtitle:
                    'Invite a friend to a private battle (${formatCount(GameData.instance.createBattleCost)} coins)',
                tag: '${formatCount(GameData.instance.createBattleCost)} 🪙',
                onTap: _createRoom,
              ),
              const SizedBox(height: 12),
              _buildBattleOption(
                icon: Icons.bolt_rounded,
                title: 'Quick Match',
                subtitle:
                    'Find an opponent and start playing (${formatCount(GameData.instance.quickBattleCost)} coins)',
                tag: '${formatCount(GameData.instance.quickBattleCost)} 🪙',
                onTap: _quickMatch,
              ),
              const SizedBox(height: 12),
              _buildBattleOption(
                icon: Icons.keyboard_alt_outlined,
                title: 'Enter Battle Code',
                subtitle: 'Got a code from a friend? Jump in (Free)',
                tag: 'JOIN',
                onTap: _joinByCode,
              ),
              const SizedBox(height: 28),
              _buildSectionTitle(
                'BATTLE RULES',
                'Only one player survives',
              ),
              const SizedBox(height: 16),
              _buildRulesCard(),
              const SizedBox(height: 24),
              _buildWaitingCard(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: AppColors.purple.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(15),
          ),
          child: const Icon(
            Icons.sports_esports_rounded,
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
                'Battle Arena',
                style: TextStyle(
                  fontSize: 23,
                  fontWeight: FontWeight.w900,
                  color: AppColors.ink,
                ),
              ),
              SizedBox(height: 3),
              Text(
                'Challenge. Survive. Win.',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFF5B82E).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(30),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.stars_rounded,
                color: Color(0xFFF5B82E),
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                formatCount(GameData.instance.coins),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 7,
          ),
          decoration: BoxDecoration(
            color: Colors.red.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(30),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.favorite_rounded,
                color: Colors.redAccent,
                size: 16,
              ),
              SizedBox(width: 4),
              Text(
                '3 Lives',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHeroCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF7C3AED),
            Color(0xFF4C1D95),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            top: -10,
            child: Icon(
              Icons.bolt_rounded,
              size: 115,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.17),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'ENDLESS VERSUS',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(height: 18),
              const Text(
                'Think Fast.\nStay Alive.',
                style: TextStyle(
                  fontSize: 32,
                  height: 1.15,
                  fontWeight: FontWeight.w900,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Match pictures to words. One mistake costs a life. '
                'Keep going until your opponent runs out of hearts.',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  _heroFeature(Icons.favorite_rounded, '3 Lives'),
                  const SizedBox(width: 16),
                  _heroFeature(Icons.all_inclusive_rounded, 'No Levels'),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroFeature(IconData icon, String label) {
    return Row(
      children: [
        Icon(icon, color: Colors.white, size: 17),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 11,
            letterSpacing: 1.5,
            fontWeight: FontWeight.w800,
            color: AppColors.purple,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.bold,
            color: AppColors.ink,
          ),
        ),
      ],
    );
  }

  Widget _buildBattleOption({
    required IconData icon,
    required String title,
    required String subtitle,
    required String tag,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: AppColors.ink.withValues(alpha: 0.06),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: AppColors.purple.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  icon,
                  color: AppColors.purple,
                  size: 27,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.ink,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 6),
              Column(
                children: [
                  Text(
                    tag,
                    style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w900,
                      color: AppColors.purple,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 7),
                  const Icon(
                    Icons.arrow_forward_ios_rounded,
                    size: 14,
                    color: AppColors.purple,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRulesCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.ink.withValues(alpha: 0.06),
        ),
      ),
      child: Column(
        children: [
          _ruleRow(
            icon: Icons.favorite_rounded,
            color: Colors.redAccent,
            title: 'Start with 3 lives',
            subtitle: 'Every player begins with three hearts.',
          ),
          const SizedBox(height: 20),
          _ruleRow(
            icon: Icons.timer_rounded,
            color: Colors.orange,
            title: 'Answer before time runs out',
            subtitle: 'Wrong answers and timeouts cost a life.',
          ),
          const SizedBox(height: 20),
          _ruleRow(
            icon: Icons.all_inclusive_rounded,
            color: AppColors.purple,
            title: 'Keep playing endlessly',
            subtitle: 'No levels. Questions continue until someone loses.',
          ),
          const SizedBox(height: 20),
          _ruleRow(
            icon: Icons.emoji_events_rounded,
            color: Colors.amber.shade700,
            title: 'Last player standing wins',
            subtitle: 'Survive longer than your opponent to win.',
          ),
        ],
      ),
    );
  }

  Widget _ruleRow({
    required IconData icon,
    required Color color,
    required String title,
    required String subtitle,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 21),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: AppColors.ink,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 11,
                  height: 1.5,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildWaitingCard() {
    if (!isWaiting) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.purple.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppColors.purple.withValues(alpha: 0.15),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.purple,
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Waiting for your opponent',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: AppColors.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              InkWell(
                onTap: _copyCode,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(2),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Room: $roomCode',
                        style: const TextStyle(
                          fontSize: 13,
                          color: AppColors.purple,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Icon(Icons.copy_rounded,
                          size: 14, color: AppColors.purple),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Share invite',
                visualDensity: VisualDensity.compact,
                onPressed: _shareBattleInvite,
                icon: const Icon(Icons.share_rounded,
                    size: 18, color: AppColors.purple),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (_inLobby && !_isHost) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFEFF6FF),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.4)),
              ),
              child: Column(
                children: [
                  const Text(
                    'In the lobby — waiting for the host to start…',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF1E40AF),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _leaveLobby,
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        side: const BorderSide(color: Colors.redAccent),
                      ),
                      icon: const Icon(Icons.exit_to_app_rounded,
                          size: 17, color: Colors.redAccent),
                      label: const Text('Leave lobby (coins refunded)',
                          style: TextStyle(
                              color: Colors.redAccent,
                              fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ] else if (_inLobby && _canStart) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF0FDF4),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.4)),
              ),
              child: Column(
                children: [
                  Text(
                    '$_lobbyGuestName is waiting in the lobby!',
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF166534),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _startBattle,
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF10B981),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('Start battle',
                          style: TextStyle(fontWeight: FontWeight.w800)),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
          ] else ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _showFriendPicker,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  side: const BorderSide(color: AppColors.purple),
                ),
                icon: const Icon(Icons.person_add_rounded, size: 18, color: AppColors.purple),
                label: const Text('Invite a friend',
                    style: TextStyle(
                        color: AppColors.purple, fontWeight: FontWeight.w800)),
              ),
            ),
            const SizedBox(height: 4),
          ],
          TextButton(
            onPressed: _cancelRoom,
            child: const Text(
              'Cancel Room',
              style: TextStyle(color: Colors.redAccent),
            ),
          ),
        ],
      ),
    );
  }

  /// Lobby guest leaves: server frees the slot and refunds both players.
  Future<void> _leaveLobby() async {
    final code = roomCode;
    if (code.isEmpty) return;
    try {
      final json = await ApiClient.instance.leaveLobby(code);
      final refunded = (json['refunded'] as num?)?.toInt() ?? 0;
      if (refunded > 0) await GameData.instance.addCoins(refunded);
      if (!mounted) return;
      setState(() {
        isWaiting = false;
        _inLobby = false;
        _canStart = false;
        _lobbyGuestName = null;
        roomCode = '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('You left the lobby — $refunded coins refunded.'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on ApiException catch (err) {
      if (!mounted) return;
      _showMessage(err.isNetworkError
          ? 'You are offline — leaving needs a connection.'
          : err.message);
      // The lobby may have moved on regardless — the next poll reconciles.
      if (err.status != null) {
        setState(() {
          isWaiting = false;
          _inLobby = false;
          roomCode = '';
        });
      }
    }
  }

  /// Host accepts the lobby: activates the battle and enters it.
  Future<void> _startBattle() async {
    final code = roomCode;
    if (code.isEmpty || !mounted) return;
    try {
      await ApiClient.instance.startBattle(code);
      if (!mounted) return;
      // Mirror the server charge that happened when the opponent joined.
      await GameData.instance.spendCoins(GameData.instance.createBattleCost);
      await _enterBattle(code);
    } on ApiException catch (err) {
      _showMessage(err.isNetworkError
          ? 'You are offline — starting needs a connection.'
          : err.message);
    }
  }

  /// Lets the host pick one of their friends and send a battle invite push.
  Future<void> _showFriendPicker() async {
    List<Map<String, dynamic>> friends = [];
    String? error;
    final invited = <String>{};

    await showDialog<void>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (dialogContext, setDialogState) {
          // Load once.
          if (friends.isEmpty && error == null && !invited.isNotEmpty) {
            ApiClient.instance.friends().then((json) {
              if (!dialogContext.mounted) return;
              setDialogState(() {
                friends = (json['friends'] as List? ?? [])
                    .whereType<Map>()
                    .map((e) => Map<String, dynamic>.from(e))
                    .toList();
              });
            }).catchError((Object e) {
              if (!dialogContext.mounted) return;
              setDialogState(() => error = 'Could not load friends');
            });
          }

          return AlertDialog(
            backgroundColor: AppColors.canvas,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: const Text('Invite a friend',
                style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.ink)),
            content: SizedBox(
              width: double.maxFinite,
              child: error != null
                  ? Text(error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13))
                  : friends.isEmpty
                      ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'No friends yet. Add friends from the Friends screen, '
                            'the leaderboard, or after a quick match!',
                            style: TextStyle(fontSize: 13, height: 1.4),
                          ),
                        )
                      : ListView.builder(
                          shrinkWrap: true,
                          itemCount: friends.length,
                          itemBuilder: (context, i) {
                            final f = friends[i];
                            final isInvited = invited.contains(f['userId']);
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.purple.withValues(alpha: 0.12),
                                child: Text(f['avatar'] as String? ?? '🧑',
                                    style: const TextStyle(fontSize: 16)),
                              ),
                              title: Text(f['name'] as String? ?? '',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800, fontSize: 13.5)),
                              subtitle: Text(f['username'] as String? ?? '',
                                  style: const TextStyle(fontSize: 11)),
                              trailing: isInvited
                                  ? const Icon(Icons.check_circle_rounded,
                                      color: Color(0xFF10B981))
                                  : TextButton(
                                      onPressed: () async {
                                        try {
                                          await ApiClient.instance.inviteFriendToBattle(
                                              roomCode, f['userId'] as String);
                                          setDialogState(() => invited.add(f['userId'] as String));
                                        } on ApiException catch (err) {
                                          if (!dialogContext.mounted) return;
                                          ScaffoldMessenger.of(dialogContext).showSnackBar(
                                            SnackBar(
                                                content: Text(err.message),
                                                behavior: SnackBarBehavior.floating),
                                          );
                                        }
                                      },
                                      child: const Text('Invite',
                                          style: TextStyle(
                                              color: AppColors.purple,
                                              fontWeight: FontWeight.w800)),
                                    ),
                            );
                          },
                        ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Close', style: TextStyle(color: Colors.grey)),
              ),
            ],
          );
        },
      ),
    );
  }
}
