import 'package:flutter/material.dart';

import '../app/moose_scope.dart';

/// Hook-calling facade for input decoration styles.
///
/// Returns [InputDecoration] instances produced by the active palette plugin's
/// `styles:input` hook.
///
/// Usage:
/// ```dart
/// TextFormField(
///   decoration: AppInputStyles.outlined(context, labelText: 'Email'),
/// )
/// ```
abstract final class AppInputStyles {
  static const _filledRadius = BorderRadius.all(Radius.circular(12));

  /// Standard outlined form field — used in auth screens.
  static InputDecoration outlined(
    BuildContext context, {
    String? labelText,
    Widget? suffixIcon,
  }) {
    final data = <String, dynamic>{
      'name': 'outlined', 'context': context,
      'labelText': labelText, 'suffixIcon': suffixIcon,
    };
    final result = MooseScope.hookRegistryOf(context).execute<dynamic>('styles:input', data);
    if (result is InputDecoration) return result;
    return _defaultOutlined(context, labelText: labelText, suffixIcon: suffixIcon);
  }

  /// Filled form field with rounded corners — used in address forms.
  static InputDecoration filled(
    BuildContext context, {
    String? hintText,
    Widget? prefixIcon,
  }) {
    final data = <String, dynamic>{
      'name': 'filled', 'context': context,
      'hintText': hintText, 'prefixIcon': prefixIcon,
    };
    final result = MooseScope.hookRegistryOf(context).execute<dynamic>('styles:input', data);
    if (result is InputDecoration) return result;
    return _defaultFilled(context, hintText: hintText, prefixIcon: prefixIcon);
  }

  /// Theme-only fallback for [outlined] when no `styles:input` hook is registered.
  static InputDecoration _defaultOutlined(
    BuildContext context, {
    String? labelText,
    Widget? suffixIcon,
  }) {
    final cs = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: labelText,
      border: const OutlineInputBorder(),
      focusedBorder: OutlineInputBorder(
        borderSide: BorderSide(color: cs.onSurface, width: 2),
      ),
      suffixIcon: suffixIcon,
    );
  }

  /// Theme-only fallback for [filled] when no `styles:input` hook is registered.
  static InputDecoration _defaultFilled(
    BuildContext context, {
    String? hintText,
    Widget? prefixIcon,
  }) {
    final cs = Theme.of(context).colorScheme;
    final dividerColor = Theme.of(context).dividerColor;
    return InputDecoration(
      hintText: hintText,
      prefixIcon: prefixIcon,
      filled: true,
      fillColor: cs.onSurface.withValues(alpha: 0.04),
      border: OutlineInputBorder(
        borderRadius: _filledRadius, borderSide: BorderSide(color: dividerColor),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: _filledRadius, borderSide: BorderSide(color: dividerColor),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: _filledRadius, borderSide: BorderSide(color: cs.primary, width: 2),
      ),
      errorBorder: const OutlineInputBorder(
        borderRadius: _filledRadius, borderSide: BorderSide(color: Colors.red, width: 1.5),
      ),
      focusedErrorBorder: const OutlineInputBorder(
        borderRadius: _filledRadius, borderSide: BorderSide(color: Colors.red, width: 2),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      errorStyle: const TextStyle(fontSize: 11),
    );
  }
}
