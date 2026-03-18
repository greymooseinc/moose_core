import 'package:flutter/material.dart';

import '../app/moose_scope.dart';

/// Hook-calling facade for background styles.
///
/// Returns [BoxDecoration] or [Widget] instances produced by the active palette
/// plugin's `styles:background` hook. Falls back to plain theme-derived colours
/// if no hook is registered.
///
/// ## Named backgrounds
///
/// | Name | Typical use |
/// |---|---|
/// | `screen` | Full-screen scaffold background (may be a gradient or solid) |
/// | `card` | Product cards, list items, bottom sheets |
/// | `section` | Section header band, promo strip |
/// | `header` | Hero / top-of-screen band inside a SliverAppBar or banner |
/// | `input` | Text field fill |
/// | `chip` | Filter chip / tag background |
/// | `overlay` | Scrim/modal overlay behind bottom sheets and dialogs |
///
/// ## Usage
///
/// ```dart
/// import 'package:moose_core/ui.dart';
///
/// // Scaffold body with a decorative screen background
/// Scaffold(
///   body: AppBackgroundStyles.screenWidget(context,
///     child: CustomScrollView(...),
///   ),
/// )
///
/// // Card with themed decoration
/// DecoratedBox(
///   decoration: AppBackgroundStyles.card(context),
///   child: ProductCard(),
/// )
/// ```
abstract final class AppBackgroundStyles {
  // ── BoxDecoration variants ────────────────────────────────────────────────────

  /// Full-screen scaffold background decoration.
  static BoxDecoration screen(BuildContext context) =>
      _getDecoration(context, 'screen');

  /// Card / list-item background decoration.
  static BoxDecoration card(BuildContext context) =>
      _getDecoration(context, 'card');

  /// Section header band decoration.
  static BoxDecoration section(BuildContext context) =>
      _getDecoration(context, 'section');

  /// Hero / top-of-screen header band decoration.
  static BoxDecoration header(BuildContext context) =>
      _getDecoration(context, 'header');

  /// Text field fill decoration.
  static BoxDecoration input(BuildContext context) =>
      _getDecoration(context, 'input');

  /// Filter chip / tag background decoration.
  static BoxDecoration chip(BuildContext context) =>
      _getDecoration(context, 'chip');

  /// Modal scrim / overlay decoration.
  static BoxDecoration overlay(BuildContext context) =>
      _getDecoration(context, 'overlay');

  // ── Widget variant ────────────────────────────────────────────────────────────

  /// Wraps [child] with the `screen` background as a full-size [Stack].
  ///
  /// Use this as the Scaffold body when the background may be a widget
  /// (e.g. an animated gradient) rather than a plain [BoxDecoration]:
  ///
  /// ```dart
  /// Scaffold(
  ///   body: AppBackgroundStyles.screenWidget(context,
  ///     child: CustomScrollView(...),
  ///   ),
  /// )
  /// ```
  static Widget screenWidget(BuildContext context, {required Widget child}) {
    final data = <String, dynamic>{
      'name': 'screen_widget',
      'context': context,
      'child': child,
    };
    final result = MooseScope.hookRegistryOf(context)
        .execute<dynamic>('styles:background', data);
    if (result is Widget) return result;
    // Fallback — plain DecoratedBox with the screen BoxDecoration.
    return DecoratedBox(
      decoration: screen(context),
      child: SizedBox.expand(child: child),
    );
  }

  // ── Internal ─────────────────────────────────────────────────────────────────

  static BoxDecoration _getDecoration(BuildContext context, String name) {
    final data = <String, dynamic>{'name': name, 'context': context};
    final result = MooseScope.hookRegistryOf(context)
        .execute<dynamic>('styles:background', data);
    if (result is BoxDecoration) return result;
    return _defaultDecoration(context, name);
  }

  /// Theme-only fallback — used when no `styles:background` hook is registered.
  static BoxDecoration _defaultDecoration(BuildContext context, String name) {
    final cs = Theme.of(context).colorScheme;
    switch (name) {
      case 'screen':
        return BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor);
      case 'card':
        return BoxDecoration(
          color: cs.surface,
          borderRadius: BorderRadius.circular(12),
        );
      case 'section':
        return BoxDecoration(
          color: cs.surfaceContainerHighest,
        );
      case 'header':
        return BoxDecoration(color: cs.primary);
      case 'input':
        return BoxDecoration(
          color: cs.onSurface.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(12),
        );
      case 'chip':
        return BoxDecoration(
          color: cs.onSurface.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(100),
        );
      case 'overlay':
        return BoxDecoration(color: Colors.black.withValues(alpha: 0.50));
      default:
        return BoxDecoration(color: cs.surface);
    }
  }
}
