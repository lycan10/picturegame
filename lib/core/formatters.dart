/// Compact number formatting for coins, points and cash amounts:
/// everything ≥ 1,000 uses a `k` suffix (≥ 1,000,000 uses `m`), so big
/// balances and scores stay readable everywhere in the app.
///
///     950     → "950"
///     1000    → "1k"
///     12500   → "12.5k"
///     250000  → "250k"
///     1200000 → "1.2m"
library;

String _trim(double d) {
  final s = d.toStringAsFixed(1);
  return s.endsWith('.0') ? s.substring(0, s.length - 2) : s;
}

/// Formats a whole count (coins, points, players…) compactly.
String formatCount(num n) {
  final v = n.round();
  final abs = v.abs();
  if (abs >= 1000000) return '${_trim(v / 1000000)}m';
  if (abs >= 1000) return '${_trim(v / 1000)}k';
  return '$v';
}

/// Formats a cash amount given in minor units (kobo/cents), e.g.
/// 1000000 minor NGN → "₦10k". Falls back to the currency code when no
/// symbol is known.
String formatCashMinor(num minor, String currency) {
  const symbols = {
    'NGN': '₦',
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
  };
  final symbol = symbols[currency] ?? '$currency ';
  return '$symbol${formatCount(minor / 100)}';
}
