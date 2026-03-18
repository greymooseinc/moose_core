import 'package:flutter/material.dart';

import '../app/moose_scope.dart';

/// Hook-calling facade for custom / ad-hoc styles.
///
/// Allows any plugin to register named styles under the `styles:custom` hook
/// without needing a dedicated facade method per style. Useful for one-off or
/// plugin-specific styles that don't belong in the core style contracts.
///
/// ## Registering a custom style
///
/// ```dart
/// // In any FeaturePlugin.onRegister():
/// hookRegistry.register('styles:custom', (data) {
///   final map = data as Map<String, dynamic>;
///   final name = map['name'] as String;
///   final context = map['context'] as BuildContext;
///   switch (name) {
///     case 'promo_badge':
///       return TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.error);
///     default:
///       return map; // pass through unknown names to lower-priority handlers
///   }
/// });
/// ```
///
/// ## Consuming a custom style
///
/// ```dart
/// import 'package:moose_core/ui.dart';
///
/// final style = AppCustomStyles.get<TextStyle>(context, 'promo_badge');
/// final card  = AppCustomStyles.get<BoxDecoration>(context, 'card_elevated');
/// ```
abstract final class AppCustomStyles {
  /// Returns the custom style registered under [name] via the `styles:custom` hook,
  /// cast to [T].
  ///
  /// [T] can be any style type — [TextStyle], [ButtonStyle], [InputDecoration],
  /// [BoxDecoration], or any other type a plugin chooses to register.
  ///
  /// Throws a [TypeError] at runtime if the resolved value cannot be cast to [T].
  ///
  /// ```dart
  /// final style = AppCustomStyles.get<TextStyle>(context, 'promo_badge');
  /// final card  = AppCustomStyles.get<BoxDecoration>(context, 'card_elevated');
  /// ```
  static T get<T>(BuildContext context, String name) =>
      MooseScope.hookRegistryOf(context)
          .execute<dynamic>(
            'styles:custom',
            <String, dynamic>{'name': name, 'context': context},
          ) as T;
}
