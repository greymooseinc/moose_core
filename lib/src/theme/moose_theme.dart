import 'package:flutter/material.dart';

import '../ui/style_hook_data.dart';

// ── Per-style-type abstract companions ───────────────────────────────────────
//
// Each companion class declares one abstract method per named variant.
// Subclasses that miss a variant get a compile error — no silent gaps.
//
// The dispatcher (`resolve`) is implemented once here so theme authors
// don't have to write the switch themselves.

/// Abstract text-style contract for a [MooseTheme].
///
/// Extend this and implement every method. The compiler will flag any missing
/// variant as an error, ensuring all call sites are covered.
abstract class MooseTextStyles {
  TextStyle appBarTitle(BuildContext ctx);
  TextStyle sectionHeader(BuildContext ctx);
  TextStyle formLabel(BuildContext ctx);
  TextStyle screenTitle(BuildContext ctx);
  TextStyle modalTitle(BuildContext ctx);
  TextStyle bodySecondary(BuildContext ctx);
  TextStyle hint(BuildContext ctx);
  TextStyle caption(BuildContext ctx);
  TextStyle sectionLabel(BuildContext ctx);
  TextStyle bodyMedium(BuildContext ctx);
  TextStyle bodyLarge(BuildContext ctx);
  TextStyle bodyXLarge(BuildContext ctx);

  /// Dispatcher — called by the `styles:text` hook. Do not override.
  TextStyle resolve(String name, BuildContext ctx) {
    switch (name) {
      case 'appBarTitle':    return appBarTitle(ctx);
      case 'sectionHeader':  return sectionHeader(ctx);
      case 'formLabel':      return formLabel(ctx);
      case 'screenTitle':    return screenTitle(ctx);
      case 'modalTitle':     return modalTitle(ctx);
      case 'bodySecondary':  return bodySecondary(ctx);
      case 'hint':           return hint(ctx);
      case 'caption':        return caption(ctx);
      case 'sectionLabel':   return sectionLabel(ctx);
      case 'bodyMedium':     return bodyMedium(ctx);
      case 'bodyLarge':      return bodyLarge(ctx);
      case 'bodyXLarge':     return bodyXLarge(ctx);
      default: throw ArgumentError('Unknown text style: "$name"');
    }
  }
}

/// Abstract button-style contract for a [MooseTheme].
///
/// Extend this and implement every method.
abstract class MooseButtonStyles {
  ButtonStyle primary(BuildContext ctx);
  ButtonStyle primaryCompact(BuildContext ctx);
  ButtonStyle secondary(BuildContext ctx);
  ButtonStyle secondaryCompact(BuildContext ctx);

  /// Dispatcher — called by the `styles:button` hook. Do not override.
  ButtonStyle resolve(String name, BuildContext ctx) {
    switch (name) {
      case 'primary':          return primary(ctx);
      case 'primaryCompact':   return primaryCompact(ctx);
      case 'secondary':        return secondary(ctx);
      case 'secondaryCompact': return secondaryCompact(ctx);
      default: throw ArgumentError('Unknown button style: "$name"');
    }
  }
}

/// Abstract input-decoration contract for a [MooseTheme].
///
/// Extend this and implement every method.
abstract class MooseInputStyles {
  InputDecoration outlined(BuildContext ctx, StyleHookData data);
  InputDecoration filled(BuildContext ctx, StyleHookData data);

  /// Dispatcher — called by the `styles:input` hook. Do not override.
  InputDecoration resolve(String name, BuildContext ctx, StyleHookData data) {
    switch (name) {
      case 'outlined': return outlined(ctx, data);
      case 'filled':   return filled(ctx, data);
      default: throw ArgumentError('Unknown input style: "$name"');
    }
  }
}

// ── MooseTheme ───────────────────────────────────────────────────────────────

/// Abstract base class for a moose_core theme.
///
/// A [MooseTheme] bundles a complete visual configuration — [ThemeData] for
/// light/dark modes plus typed style companions for text, buttons, inputs,
/// and optional custom styles.
///
/// ## Compile-time enforcement
///
/// Instead of implementing a single `resolveText(String, BuildContext)` method
/// that could silently miss variants, you implement typed companions:
///
/// ```dart
/// class _MyTextStyles extends MooseTextStyles {
///   @override TextStyle appBarTitle(BuildContext ctx) => ...;
///   @override TextStyle sectionHeader(BuildContext ctx) => ...;
///   // Dart compiler errors on any missing method ↑
/// }
/// ```
///
/// ## Usage
///
/// ```dart
/// class MyTheme extends MooseTheme {
///   @override String get name => 'my_theme';
///   @override ThemeData get light => MyThemes.light;
///   @override ThemeData get dark => MyThemes.dark;
///   @override MooseTextStyles get textStyles => _MyTextStyles();
///   @override MooseButtonStyles get buttonStyles => _MyButtonStyles();
///   @override MooseInputStyles get inputStyles => _MyInputStyles();
/// }
/// ```
///
/// Register themes in [MooseApp]:
/// ```dart
/// MooseApp(
///   themes: [DefaultTheme(), MyTheme()],
///   ...
/// )
/// ```
///
/// Select the active theme in `environment.json`:
/// ```json
/// { "theme": "my_theme" }
/// ```
///
/// If the `"theme"` key is absent or does not match any registered theme name,
/// the first theme in the list is used as the fallback.
abstract class MooseTheme {
  /// The unique identifier for this theme.
  ///
  /// Must match the value of the `"theme"` key in `environment.json` to be
  /// selected automatically at startup.
  String get name;

  /// The [ThemeData] applied when the device is in light mode.
  ThemeData get light;

  /// The [ThemeData] applied when the device is in dark mode.
  ThemeData get dark;

  /// Text style companion — implement all variants; the compiler enforces each one.
  MooseTextStyles get textStyles;

  /// Button style companion — implement all variants; the compiler enforces each one.
  MooseButtonStyles get buttonStyles;

  /// Input decoration companion — implement all variants; the compiler enforces each one.
  MooseInputStyles get inputStyles;

  /// Optionally returns a style value for the given [name] background variant.
  ///
  /// Called by the `styles:background` hook. Typically returns a [BoxDecoration]
  /// but may return a [Widget] for special variants (e.g. mesh gradient screens).
  /// Return `null` to fall through to theme defaults. Override when the theme
  /// provides custom background styles.
  dynamic resolveBackground(
    String name,
    BuildContext ctx,
    Map<String, dynamic> data,
  ) =>
      null;

  /// Optionally returns a custom style value for the given [name].
  ///
  /// Called by the `styles:custom` hook. Return `null` to fall through. Use
  /// this for theme-specific style tokens that don't fit the standard hooks.
  dynamic resolveCustom(String name, BuildContext ctx) => null;
}
