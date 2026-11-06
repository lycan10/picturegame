import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/api_client.dart';
import '../core/sound_service.dart';
import '../theme/app_theme.dart';

/// Where the player receives contest cash prizes: Nigerian bank transfer via
/// Paystack. The account number is verified against Paystack when the backend
/// has credentials, and always stored/read masked on the client side.
class PayoutDetailsScreen extends StatefulWidget {
  const PayoutDetailsScreen({super.key});

  @override
  State<PayoutDetailsScreen> createState() => _PayoutDetailsScreenState();
}

class _PayoutDetailsScreenState extends State<PayoutDetailsScreen> {
  final _holderCtrl = TextEditingController();
  final _accountCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  List<Map<String, dynamic>> _banks = [];
  Map<String, dynamic>? _selectedBank;
  bool _loading = true;
  bool _saving = false;
  bool _configured = false;
  String? _verifiedName;
  String? _maskedNumber;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _holderCtrl.dispose();
    _accountCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiClient.instance.banks(),
        ApiClient.instance.payoutDetails(),
      ]);
      final banksJson = (results[0]['banks'] as List? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      final details = results[1];
      if (!mounted) return;
      setState(() {
        _banks = banksJson;
        _configured = details['configured'] as bool? ?? false;
        if (_configured) {
          _holderCtrl.text = details['holderName'] as String? ?? '';
          _phoneCtrl.text = details['phone'] as String? ?? '';
          _maskedNumber = details['accountNumberMasked'] as String?;
          _verifiedName = details['verifiedName'] as String?;
        }
        _loading = false;
      });
    } on ApiException catch (err) {
      if (!mounted) return;
      setState(() {
        _error = err.isNetworkError
            ? 'You are offline — reconnect to manage payout details.'
            : err.message;
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    if (_selectedBank == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Select your bank first'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final res = await ApiClient.instance.savePayoutDetails(
        holderName: _holderCtrl.text.trim(),
        bankCode: _selectedBank!['code'] as String,
        bankName: _selectedBank!['name'] as String,
        accountNumber: _accountCtrl.text.trim(),
        phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
      );
      if (!mounted) return;
      playSfx(Sfx.success);
      final verified = res['verifiedName'] as String?;
      setState(() {
        _configured = true;
        _maskedNumber = res['accountNumberMasked'] as String?;
        _verifiedName = verified;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            verified != null
                ? 'Payout details saved — account verified as "$verified" ✓'
                : 'Payout details saved!',
          ),
          backgroundColor: const Color(0xFF10B981),
          behavior: SnackBarBehavior.floating,
        ),
      );
      _accountCtrl.clear();
    } on ApiException catch (err) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            err.isNetworkError
                ? 'You are offline — saving needs a connection.'
                : err.message,
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _clear() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dCtx) => AlertDialog(
        title: const Text('Clear payout details?'),
        content: const Text(
          'Your saved account details will be removed. You can set them up again anytime.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dCtx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dCtx, true),
            child: const Text('Clear'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ApiClient.instance.clearPayoutDetails();
    if (!mounted) return;
    setState(() {
      _configured = false;
      _maskedNumber = null;
      _verifiedName = null;
      _holderCtrl.clear();
      _phoneCtrl.clear();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Payout details',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                _banner(),
                const SizedBox(height: 18),
                if (_configured && _maskedNumber != null) ...[
                  _savedCard(),
                  const SizedBox(height: 16),
                ],
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _fieldLabel('Account holder name'),
                      TextFormField(
                        controller: _holderCtrl,
                        textCapitalization: TextCapitalization.words,
                        inputFormatters: [
                          LengthLimitingTextInputFormatter(100),
                        ],
                        decoration: const InputDecoration(
                          hintText: 'As registered at your bank',
                          border: OutlineInputBorder(),
                        ),
                        validator: (v) => (v == null || v.trim().length < 3)
                            ? 'Enter the full account holder name'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      _fieldLabel('Bank'),
                      DropdownButtonFormField<Map<String, dynamic>>(
                        value: _selectedBank,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          hintText: 'Select your bank',
                          border: OutlineInputBorder(),
                        ),
                        items: _banks
                            .map(
                              (b) => DropdownMenuItem(
                                value: b,
                                child: Text(
                                  b['name'] as String? ?? '',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _selectedBank = v),
                      ),
                      const SizedBox(height: 14),
                      _fieldLabel('Account number'),
                      TextFormField(
                        controller: _accountCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        decoration: InputDecoration(
                          hintText: '10 digits (NUBAN)',
                          border: const OutlineInputBorder(),
                          helperText: _configured && _maskedNumber != null
                              ? 'Currently saved: $_maskedNumber — enter a new number to change'
                              : null,
                        ),
                        validator: (v) => (v == null || v.trim().length != 10)
                            ? 'Account number must be 10 digits'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      _fieldLabel('Phone (optional)'),
                      TextFormField(
                        controller: _phoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          hintText: 'For payout coordination',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 20),
                      SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _saving ? null : _save,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.purple,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: _saving
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.save_rounded),
                          label: Text(
                            _configured
                                ? 'Update details'
                                : 'Save payout details',
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                        ),
                      ),
                      if (_configured) ...[
                        const SizedBox(height: 10),
                        Center(
                          child: TextButton(
                            onPressed: _clear,
                            child: const Text(
                              'Clear saved details',
                              style: TextStyle(color: Colors.redAccent),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: const TextStyle(
                      color: Colors.redAccent,
                      fontSize: 12.5,
                    ),
                  ),
                ],
                const SizedBox(height: 24),
                const Center(
                  child: Text(
                    'Stored securely • account numbers are only shown to '
                    'administrators for paying your prizes',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: Colors.black38),
                  ),
                ),
              ],
            ),
    );
  }

  Widget _banner() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.purple.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.emoji_events_rounded, color: AppColors.purple, size: 22),
          SizedBox(width: 10),
          Expanded(
            child: Text(
              'Contest cash prizes are sent by bank transfer. Set up your '
              'account details once — if you win, your prize goes straight here.',
              style: TextStyle(fontSize: 12.5, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _savedCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF0FDF4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF10B981).withValues(alpha: 0.35),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_rounded, color: Color(0xFF10B981)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Saved: $_maskedNumber\n$_verifiedName',
              style: const TextStyle(fontSize: 13, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  Widget _fieldLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }
}
