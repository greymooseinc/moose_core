import 'package:intl/intl.dart';

/// Helper class for formatting monetary values consistently across the app.
///
/// This wrapper centralizes currency-specific options (locale, symbol,
/// decimal precision, grouping) so UI widgets don’t have to duplicate logic.
class CurrencyFormatter {
  CurrencyFormatter._();

  /// Formats a numeric or string amount into a localized currency string.
  ///
  /// - [amount] can be `int`, `double`, `num`, or a numeric [String].
  /// - [currencySymbol] overrides the display symbol (e.g. `$`, `€`).
  /// - [currencyCode] (e.g. `USD`, `EUR`) is appended when [showCode] is true.
  /// - [locale] controls digits/grouping; defaults to device locale.
  /// - [decimalDigits] configures precision.
  /// - Set [useGrouping] to `false` to remove thousands separators.
  /// - Use [customPattern] for advanced formatting (see `NumberFormat`).
  static String format(
    Object? amount, {
    String? currencySymbol,
    String? currencyCode,
    String? locale,
    int decimalDigits = 2,
    bool useGrouping = true,
    bool showCode = false,
    String? customPattern,
  }) {
    final numericAmount = _toNum(amount);
    if (numericAmount == null ||
        numericAmount.isNaN ||
        !numericAmount.isFinite) {
      return '-';
    }

    final formatter = NumberFormat.currency(
      locale: locale,
      symbol: currencySymbol ?? _symbolForCode(currencyCode),
      name: currencyCode,
      decimalDigits: decimalDigits,
      customPattern: customPattern,
    );

    if (!useGrouping) {
      formatter.turnOffGrouping();
    }

    var formatted = formatter.format(numericAmount.toDouble());

    if (showCode && currencyCode != null && currencyCode.isNotEmpty) {
      formatted = '$formatted $currencyCode';
    }

    return formatted.trim();
  }

  /// Formats a delta value with +/- semantics (useful for discounts).
  static String formatDelta(
    num amount, {
    String? currencySymbol,
    String? currencyCode,
    String? locale,
    int decimalDigits = 2,
  }) {
    final formatted = format(
      amount.abs(),
      currencySymbol: currencySymbol,
      currencyCode: currencyCode,
      locale: locale,
      decimalDigits: decimalDigits,
    );
    final prefix = amount >= 0 ? '+' : '−';
    return '$prefix$formatted';
  }

  /// Formats a min/max price range.
  static String formatRange(
    num minAmount,
    num maxAmount, {
    String? currencySymbol,
    String? currencyCode,
    String? locale,
    int decimalDigits = 2,
  }) {
    if (minAmount == maxAmount) {
      return format(
        minAmount,
        currencySymbol: currencySymbol,
        currencyCode: currencyCode,
        locale: locale,
        decimalDigits: decimalDigits,
      );
    }

    final lower = format(
      minAmount,
      currencySymbol: currencySymbol,
      currencyCode: currencyCode,
      locale: locale,
      decimalDigits: decimalDigits,
    );
    final upper = format(
      maxAmount,
      currencySymbol: currencySymbol,
      currencyCode: currencyCode,
      locale: locale,
      decimalDigits: decimalDigits,
    );
    return '$lower - $upper';
  }

  static String? _symbolForCode(String? code) {
    if (code == null) return null;
    switch (code.toUpperCase()) {
      case 'USD':
        return '\$';
      case 'EUR':
        return '€';
      case 'GBP':
        return '£';
      case 'JPY':
        return '¥';
      case 'CAD':
        return 'CA\$';
      case 'AUD':
        return 'A\$';
      default:
        return null;
    }
  }

  static num? _toNum(Object? amount) {
    if (amount == null) return null;
    if (amount is num) return amount;
    if (amount is String) {
      final trimmed = amount.trim();
      if (trimmed.isEmpty) return null;

      final direct = num.tryParse(trimmed);
      if (direct != null) return direct;

      var sanitized = trimmed.replaceAll(RegExp(r'[^\d,.\-+]'), '');

      if (sanitized.contains(',') && sanitized.contains('.')) {
        if (sanitized.lastIndexOf('.') < sanitized.lastIndexOf(',')) {
          sanitized = sanitized.replaceAll('.', '').replaceAll(',', '.');
        } else {
          sanitized = sanitized.replaceAll(',', '');
        }
      } else if (sanitized.contains(',')) {
        final commaMatches = RegExp(',').allMatches(sanitized).length;
        if (commaMatches == 1 && sanitized.split(',').last.length <= 2) {
          sanitized = sanitized.replaceAll(',', '.');
        } else {
          sanitized = sanitized.replaceAll(',', '');
        }
      }

      return num.tryParse(sanitized);
    }
    return null;
  }
}
