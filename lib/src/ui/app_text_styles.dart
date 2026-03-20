import 'package:flutter/material.dart';

import '../app/moose_scope.dart';
import 'style_hook_data.dart';

/// Hook-calling facade for text styles.
///
/// Returns the [TextStyle] produced by whichever palette plugin has registered
/// the `styles:text` hook. [ThemeDefaultPlugin] provides the default
/// implementation; swap it by registering a higher-priority handler.
///
/// Usage:
/// ```dart
/// Text('Title', style: AppTextStyles.appBarTitle(context))
/// ```
abstract final class AppTextStyles {
  static TextStyle _get(BuildContext context, String name) {
    final result = MooseScope.hookRegistryOf(context).execute<dynamic>(
      'styles:text',
      StyleHookData(name: name, context: context),
    );
    // If no hook was registered the registry returns the map unchanged — fall back to theme defaults.
    if (result is TextStyle) return result;
    return _default(context, name);
  }

  /// Theme-only fallback used when no `styles:text` hook is registered.
  static TextStyle _default(BuildContext context, String name) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    switch (name) {
      case 'appBarTitle':
        return (tt.labelSmall ?? const TextStyle()).copyWith(
          fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 2.0,
          color: cs.onSurface,
        );
      case 'sectionHeader':
        return (tt.titleLarge ?? const TextStyle()).copyWith(
          fontSize: 18, fontWeight: FontWeight.w700, color: cs.onSurface,
        );
      case 'formLabel':
        return (tt.labelSmall ?? const TextStyle()).copyWith(
          fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1.0,
          color: cs.onSurface.withValues(alpha: 0.87),
        );
      case 'screenTitle':
        return (tt.headlineMedium ?? const TextStyle()).copyWith(
          fontSize: 28, fontWeight: FontWeight.w700, letterSpacing: 1.0,
          color: cs.onSurface,
        );
      case 'modalTitle':
        return (tt.titleLarge ?? const TextStyle()).copyWith(
          fontSize: 20, fontWeight: FontWeight.w700, color: cs.onSurface,
        );
      case 'bodySecondary':
        return (tt.bodyMedium ?? const TextStyle()).copyWith(
          fontSize: 14, color: cs.onSurface.withValues(alpha: 0.6),
        );
      case 'hint':
        return (tt.bodyMedium ?? const TextStyle()).copyWith(
          fontSize: 14, color: cs.onSurface.withValues(alpha: 0.5),
        );
      case 'caption':
        return (tt.labelSmall ?? const TextStyle()).copyWith(
          fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1.2,
          color: cs.onSurface.withValues(alpha: 0.6),
        );
      case 'sectionLabel':
        return (tt.labelSmall ?? const TextStyle()).copyWith(
          fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5,
          color: cs.onSurface.withValues(alpha: 0.8),
        );
      case 'bodyMedium':
        return (tt.bodyMedium ?? const TextStyle()).copyWith(
          fontSize: 14, fontWeight: FontWeight.w500, color: cs.onSurface,
        );
      case 'bodyLarge':
        return (tt.bodyLarge ?? const TextStyle()).copyWith(
          fontSize: 15, fontWeight: FontWeight.w500, color: cs.onSurface,
        );
      case 'bodyXLarge':
        return (tt.bodyLarge ?? const TextStyle()).copyWith(
          fontSize: 16, fontWeight: FontWeight.w600, color: cs.onSurface,
        );
      default:
        return TextStyle(color: cs.onSurface);
    }
  }

  /// AppBar title — typically Inter w700 13px ls:2.0, theme onSurface colour.
  static TextStyle appBarTitle(BuildContext context) => _get(context, 'appBarTitle');

  /// Section heading inside a screen — typically Inter w700 18px.
  static TextStyle sectionHeader(BuildContext context) => _get(context, 'sectionHeader');

  /// Form field label — typically Inter w600 12px ls:1.0 at 87% opacity.
  static TextStyle formLabel(BuildContext context) => _get(context, 'formLabel');

  /// Large screen heading — typically Inter w700 28px ls:1.0.
  static TextStyle screenTitle(BuildContext context) => _get(context, 'screenTitle');

  /// Modal / bottom-sheet title — typically Inter w700 20px.
  static TextStyle modalTitle(BuildContext context) => _get(context, 'modalTitle');

  /// Secondary body text — typically Inter 14px at 60% opacity.
  static TextStyle bodySecondary(BuildContext context) => _get(context, 'bodySecondary');

  /// Hint / placeholder text — typically Inter 14px at 50% opacity.
  static TextStyle hint(BuildContext context) => _get(context, 'hint');

  /// Small caption / badge label — typically Inter w600 11px ls:1.2 at 60% opacity.
  static TextStyle caption(BuildContext context) => _get(context, 'caption');

  /// Small section label — typically Inter w700 11px ls:1.5 at 80% opacity.
  static TextStyle sectionLabel(BuildContext context) => _get(context, 'sectionLabel');

  /// Medium body text — typically Inter w500 14px.
  static TextStyle bodyMedium(BuildContext context) => _get(context, 'bodyMedium');

  /// Large body text — typically Inter w500 15px.
  static TextStyle bodyLarge(BuildContext context) => _get(context, 'bodyLarge');

  /// Extra-large body text — typically Inter w600 16px.
  static TextStyle bodyXLarge(BuildContext context) => _get(context, 'bodyXLarge');
}
