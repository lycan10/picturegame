import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api_client.dart';
import '../theme/app_theme.dart';

import 'dart:convert';

/// Shows the account's full data export (from GET /profile/export): a
/// readable summary plus the raw JSON, with a copy-to-clipboard button.
class DataExportScreen extends StatefulWidget {
  const DataExportScreen({super.key});

  @override
  State<DataExportScreen> createState() => _DataExportScreenState();
}

class _DataExportScreenState extends State<DataExportScreen> {
  Map<String, dynamic>? _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final data = await ApiClient.instance.exportData();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.isNetworkError
            ? 'You need a connection to export your data.'
            : err.message;
        _loading = false;
      });
    }
  }

  String get _prettyJson {
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(_data ?? {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.canvas,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text('My data',
            style:
                TextStyle(fontWeight: FontWeight.w900, color: AppColors.ink)),
        actions: [
          if (_data != null)
            IconButton(
              tooltip: 'Copy JSON',
              icon: const Icon(Icons.copy_rounded, color: AppColors.purple),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _prettyJson));
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  behavior: SnackBarBehavior.floating,
                  content: Text('Data copied to clipboard.'),
                ));
              },
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.purple))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_error!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.redAccent)),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    Text(
                      'Everything this game stores about your account, '
                      'exported just for you.',
                      style: TextStyle(
                          fontSize: 13,
                          height: 1.5,
                          color: AppColors.ink.withValues(alpha: 0.65)),
                    ),
                    const SizedBox(height: 16),
                    _summaryGrid(),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                      ),
                      constraints: const BoxConstraints(minHeight: 220),
                      child: SingleChildScrollView(
                        child: Text(
                          _prettyJson,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 11,
                            height: 1.5,
                            color: AppColors.ink,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
    );
  }

  Widget _summaryGrid() {
    final data = _data!;
    final profile = data['profile'] as Map<String, dynamic>? ?? {};
    final stats = data['stats'] as Map<String, dynamic>? ?? {};
    final progress = (data['levelProgress'] as List?)?.length ?? 0;
    final achievements = (data['achievements'] as List?)?.length ?? 0;
    final wallet = (data['walletHistory'] as List?)?.length ?? 0;

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _summaryCard(
                  'Account', '${profile['username'] ?? '—'}', Icons.person_rounded),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _summaryCard('Points',
                  '${stats['total_points'] ?? 0}', Icons.stars_rounded),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _summaryCard('Levels played',
                  '$progress', Icons.extension_rounded),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _summaryCard('Achievements',
                  '$achievements', Icons.workspace_premium_rounded),
            ),
          ],
        ),
        const SizedBox(height: 12),
        _summaryCard('Wallet history entries', '$wallet',
            Icons.account_balance_wallet_rounded),
      ],
    );
  }

  Widget _summaryCard(String label, String value, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: AppColors.purple),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    color: AppColors.ink)),
          ),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
        ],
      ),
    );
  }
}
