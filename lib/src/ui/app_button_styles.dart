import 'package:flutter/material.dart';

import '../app/moose_scope.dart';
import 'style_hook_data.dart';

/// Hook-calling facade for button styles.
///
/// Returns [ButtonStyle] instances produced by the active palette plugin's
/// `styles:button` hook. [labelStyle] has no [BuildContext] and is a pure
/// static — button label text inherits the app's text theme font family.
///
/// Usage:
/// ```dart
/// ElevatedButton(
///   style: AppButtonStyles.primary(context),
///   child: Text('Label', style: AppButtonStyles.labelStyle()),
/// )
/// ```
abstract final class AppButtonStyles {
  static ButtonStyle _get(BuildContext context, String name) {
    final result = MooseScope.hookRegistryOf(context).execute<dynamic>(
      'styles:button',
      StyleHookData(name: name, context: context),
    );
    // If no hook was registered the registry returns the map unchanged — fall back to theme defaults.
    if (result is ButtonStyle) return result;
    return _default(context, name);
  }

  static const _shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(8)),
  );
  static const _padding = EdgeInsets.symmetric(horizontal: 24, vertical: 16);
  static const _fullWidth = Size(double.infinity, 56);

  /// Theme-only fallback used when no `styles:button` hook is registered.
  static ButtonStyle _default(BuildContext context, String name) {
    final cs = Theme.of(context).colorScheme;
    switch (name) {
      case 'primary':
        return ElevatedButton.styleFrom(
          backgroundColor: cs.primary, foregroundColor: cs.onPrimary,
          minimumSize: _fullWidth, padding: _padding, elevation: 0, shape: _shape,
        );
      case 'primaryCompact':
        return ElevatedButton.styleFrom(
          backgroundColor: cs.primary, foregroundColor: cs.onPrimary,
          padding: _padding, elevation: 0, shape: _shape,
        );
      case 'secondary':
        return OutlinedButton.styleFrom(
          foregroundColor: cs.onSurface, minimumSize: _fullWidth,
          padding: _padding, side: BorderSide(color: cs.outline), shape: _shape,
        );
      case 'secondaryCompact':
        return OutlinedButton.styleFrom(
          foregroundColor: cs.onSurface, padding: _padding,
          side: BorderSide(color: cs.outline), shape: _shape,
        );
      default:
        return ElevatedButton.styleFrom(
          backgroundColor: cs.primary, foregroundColor: cs.onPrimary, shape: _shape,
        );
    }
  }

  /// Full-width primary action button.
  static ButtonStyle primary(BuildContext context) => _get(context, 'primary');

  /// Compact primary button — auto-sizes to content.
  static ButtonStyle primaryCompact(BuildContext context) => _get(context, 'primaryCompact');

  /// Full-width outlined secondary button.
  static ButtonStyle secondary(BuildContext context) => _get(context, 'secondary');

  /// Compact outlined secondary button — auto-sizes to content.
  static ButtonStyle secondaryCompact(BuildContext context) => _get(context, 'secondaryCompact');

  /// Standard label style for all CTA buttons.
  ///
  /// Has no [BuildContext] — font family is inherited from the app's text theme.
  static TextStyle labelStyle({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w700,
    double letterSpacing = 1.2,
    Color? color,
  }) =>
      TextStyle(
        fontSize: fontSize,
        fontWeight: fontWeight,
        letterSpacing: letterSpacing,
        color: color,
      );
}
