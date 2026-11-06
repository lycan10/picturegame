import 'package:flutter/material.dart';

import '../core/api_client.dart';
import '../core/formatters.dart';
import '../core/sound_service.dart';
import '../theme/app_theme.dart';

/// Friends: list, incoming requests (accept/reject), and username search for
/// discovering players. Battle invites go out from the battle screen.
class FriendsScreen extends StatefulWidget {
  const FriendsScreen({super.key});

  @override
  State<FriendsScreen> createState() => _FriendsScreenState();
}

class _FriendsScreenState extends State<FriendsScreen> {
  List<Map<String, dynamic>> _friends = [];
  List<Map<String, dynamic>> _incoming = [];
  List<Map<String, dynamic>> _searchResults = [];
  String _query = '';
  bool _loading = true;
  bool _searching = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final json = await ApiClient.instance.friends();
      if (!mounted) return;
      setState(() {
        _friends = (json['friends'] as List? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _incoming = (json['incoming'] as List? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
        _loading = false;
        _error = null;
      });
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = err.isNetworkError ? 'You are offline.' : err.message;
      });
    }
  }

  Future<void> _search(String q) async {
    setState(() {
      _query = q;
      _searching = q.trim().length >= 2;
    });
    if (!_searching) {
      _searchResults = [];
      return;
    }
    try {
      final json = await ApiClient.instance.friendLookup(q);
      if (!mounted) return;
      setState(() {
        _searchResults = (json['results'] as List? ?? [])
            .whereType<Map>()
            .map((e) => Map<String, dynamic>.from(e))
            .toList();
      });
    } on ApiException {
      // Leave previous results; the next keystroke retries.
    }
  }

  Future<void> _sendRequest(String userId) async {
    try {
      final json = await ApiClient.instance.sendFriendRequest(userId);
      final result = json['result'] as String? ?? 'sent';
      if (!mounted) return;
      playSfx(Sfx.click);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(switch (result) {
            'auto-accepted' => 'You are now friends! 🎉',
            'already-friends' => 'You are already friends.',
            _ => 'Friend request sent!',
          }),
          behavior: SnackBarBehavior.floating,
        ),
      );
      await _load();
      await _search(_query);
    } on ApiException catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(err.isNetworkError ? 'You are offline.' : err.message),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _accept(String userId) async {
    try {
      await ApiClient.instance.acceptFriendRequest(userId);
      if (!mounted) return;
      playSfx(Sfx.success);
      await _load();
    } on ApiException catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(err.message), behavior: SnackBarBehavior.floating),
      );
    }
  }

  Future<void> _reject(String userId) async {
    try {
      await ApiClient.instance.removeFriend(userId);
      if (!mounted) return;
      await _load();
    } on ApiException {
      // Already gone — refresh anyway.
      if (mounted) await _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Friends', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(18),
                children: [
                  TextField(
                    onChanged: _search,
                    decoration: InputDecoration(
                      hintText: 'Search players by username…',
                      prefixIcon: const Icon(Icons.search_rounded),
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(color: Color(0xFFEDEEF4)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  if (_searching) ...[
                    _sectionTitle('Search results'),
                    const SizedBox(height: 8),
                    if (_searchResults.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('No players found.',
                            style: TextStyle(color: Colors.black38)),
                      )
                    else
                      ..._searchResults.map(_searchCard),
                    const SizedBox(height: 18),
                  ],

                  if (_incoming.isNotEmpty) ...[
                    _sectionTitle('Friend requests'),
                    const SizedBox(height: 8),
                    ..._incoming.map(_requestCard),
                    const SizedBox(height: 18),
                  ],

                  _sectionTitle('My friends (${_friends.length})'),
                  const SizedBox(height: 8),
                  if (_friends.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No friends yet. Search above, or add players you meet '
                        'in quick matches and on the leaderboard!',
                        style: TextStyle(color: Colors.black38, height: 1.4),
                      ),
                    )
                  else
                    ..._friends.map(_userCard),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12.5)),
                  ],
                ],
              ),
            ),
    );
  }

  Widget _sectionTitle(String text) => Text(
        text,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: AppColors.ink),
      );

  Widget _userCard(Map<String, dynamic> user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDEEF4)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.purple.withValues(alpha: 0.12),
            child: Text(user['avatar'] as String? ?? '🧑',
                style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user['name'] as String? ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                Text(
                  '${user['username']} · ${formatCount((user['points'] as num?)?.toInt() ?? 0)} pts',
                  style: const TextStyle(fontSize: 11.5, color: Colors.black45),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.person_remove_rounded, size: 20, color: Colors.black38),
            onPressed: () => _reject(user['userId'] as String),
          ),
        ],
      ),
    );
  }

  Widget _searchCard(Map<String, dynamic> user) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEDEEF4)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.purple.withValues(alpha: 0.12),
            child: Text(user['avatar'] as String? ?? '🧑',
                style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(user['name'] as String? ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                Text(
                  '${user['username']} · ${formatCount((user['points'] as num?)?.toInt() ?? 0)} pts',
                  style: const TextStyle(fontSize: 11.5, color: Colors.black45),
                ),
              ],
            ),
          ),
          FilledButton.icon(
            onPressed: () => _sendRequest(user['userId'] as String),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.purple,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              minimumSize: const Size(0, 34),
            ),
            icon: const Icon(Icons.person_add_rounded, size: 15),
            label: const Text('Add', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _requestCard(Map<String, dynamic> request) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF4F1FE),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.purple.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: AppColors.purple.withValues(alpha: 0.12),
            child: Text(request['avatar'] as String? ?? '🧑',
                style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(request['name'] as String? ?? '',
                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14)),
                Text(request['username'] as String? ?? '',
                    style: const TextStyle(fontSize: 11.5, color: Colors.black45)),
              ],
            ),
          ),
          FilledButton(
            onPressed: () => _accept(request['userId'] as String),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.purple,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              minimumSize: const Size(0, 34),
            ),
            child: const Text('Accept', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          ),
          const SizedBox(width: 6),
          OutlinedButton(
            onPressed: () => _reject(request['userId'] as String),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              minimumSize: const Size(0, 34),
            ),
            child: const Text('Reject', style: TextStyle(fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
