import 'package:flutter/material.dart';

import '../app/moose_scope.dart';
import '../events/event_bus.dart';

/// Centralized navigation service that uses EventBus for decoupled navigation.
///
/// Provides both a fluent `.of(context)` API and static shortcut methods.
/// The EventBus is resolved from `context.moose.eventBus` — no global state.
///
/// ## Fluent API (preferred):
/// ```dart
/// MooseNavigator.of(context).pushNamed('/product', arguments: {'id': '123'});
/// MooseNavigator.of(context).pop();
/// ```
///
/// ## Static shortcuts (convenience):
/// ```dart
/// MooseNavigator.pushNamed(context, '/product', arguments: {'id': '123'});
/// MooseNavigator.pop(context);
/// ```
///
/// ## Tab switching:
/// ```dart
/// MooseNavigator.of(context).switchToTab('cart');
/// ```
///
/// ## For Plugin Authors:
/// Listen to navigation events in your plugin's `onInit()`:
/// ```dart
/// eventBus.on('navigation.switch_to_tab', (event) {
///   final tabId = event.data['tabId'] as String?;
///   final markHandled = event.data['_markHandled'] as Function;
///   // Switch to tab...
///   markHandled(null);
/// });
/// ```
class MooseNavigator {
  MooseNavigator._();

  /// Returns a [MooseNavigatorProxy] bound to [context].
  ///
  /// The proxy resolves the [EventBus] from `context.moose.eventBus` so no
  /// global state is required.
  static MooseNavigatorProxy of(BuildContext context) =>
      MooseNavigatorProxy(context, MooseScope.of(context).eventBus);

  // ---------------------------------------------------------------------------
  // Static shortcuts — delegate to .of(context)
  // ---------------------------------------------------------------------------

  /// Push a named route.
  static Future<T?> pushNamed<T extends Object?>(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) =>
      of(context).pushNamed<T>(routeName, arguments: arguments);

  /// Push a named route, replacing the current route.
  static Future<T?> pushReplacementNamed<T extends Object?, TO extends Object?>(
    BuildContext context,
    String routeName, {
    TO? result,
    Object? arguments,
  }) =>
      of(context).pushReplacementNamed<T, TO>(routeName, result: result, arguments: arguments);

  /// Push a named route and remove all routes until [predicate] returns true.
  static Future<T?> pushNamedAndRemoveUntil<T extends Object?>(
    BuildContext context,
    String routeName,
    RoutePredicate predicate, {
    Object? arguments,
  }) =>
      of(context).pushNamedAndRemoveUntil<T>(routeName, predicate, arguments: arguments);

  /// Push a [Route] directly.
  static Future<T?> push<T extends Object?>(
    BuildContext context,
    Route<T> route,
  ) =>
      of(context).push<T>(route);

  /// Pop the current route.
  static void pop<T extends Object?>(BuildContext context, [T? result]) =>
      of(context).pop<T>(result);

  /// Whether the navigator can pop.
  static bool canPop(BuildContext context) => Navigator.canPop(context);

  /// Switch to a tab by ID.
  static Future<void> switchToTab(BuildContext context, String tabId) =>
      of(context).switchToTab(tabId);

  /// Switch to a tab by index.
  static Future<void> switchToTabIndex(BuildContext context, int index) =>
      of(context).switchToTabIndex(index);
}

/// Proxy returned by [MooseNavigator.of].
///
/// Holds the [BuildContext] and [EventBus] used for all navigation calls.
/// Each method fires an EventBus event (allowing plugins to intercept) then
/// falls back to the standard Flutter [Navigator] if no plugin handles it.
class MooseNavigatorProxy {
  final BuildContext _context;
  final EventBus _bus;

  const MooseNavigatorProxy(this._context, this._bus);

  /// Push a named route.
  Future<T?> pushNamed<T extends Object?>(
    String routeName, {
    Object? arguments,
  }) async {
    bool handled = false;
    Object? result;

    _bus.fire(
      'navigation.push_named',
      data: {
        'routeName': routeName,
        'arguments': arguments,
        'context': _context,
        '_markHandled': (Object? res) {
          handled = true;
          result = res;
        },
        'onSwitched': () {
          Navigator.pushNamed<T>(_context, routeName, arguments: arguments);
        },
      },
    );

    await Future.delayed(Duration.zero);

    if (!handled && _context.mounted) {
      return Navigator.pushNamed<T>(_context, routeName, arguments: arguments);
    }

    return result as T?;
  }

  /// Push a named route, replacing the current route.
  Future<T?> pushReplacementNamed<T extends Object?, TO extends Object?>(
    String routeName, {
    TO? result,
    Object? arguments,
  }) async {
    bool handled = false;
    Object? handlerResult;

    _bus.fire(
      'navigation.push_replacement_named',
      data: {
        'routeName': routeName,
        'arguments': arguments,
        'result': result,
        'context': _context,
        '_markHandled': (Object? res) {
          handled = true;
          handlerResult = res;
        },
        'onSwitched': () {
          Navigator.pushReplacementNamed<T, TO>(_context, routeName,
              result: result, arguments: arguments);
        },
      },
    );

    await Future.delayed(Duration.zero);

    if (!handled && _context.mounted) {
      return Navigator.pushReplacementNamed<T, TO>(_context, routeName,
          result: result, arguments: arguments);
    }

    return handlerResult as T?;
  }

  /// Push a named route and remove all routes until [predicate] returns true.
  Future<T?> pushNamedAndRemoveUntil<T extends Object?>(
    String routeName,
    RoutePredicate predicate, {
    Object? arguments,
  }) async {
    bool handled = false;
    Object? result;

    _bus.fire(
      'navigation.push_named_and_remove_until',
      data: {
        'routeName': routeName,
        'arguments': arguments,
        'context': _context,
        '_markHandled': (Object? res) {
          handled = true;
          result = res;
        },
        'onSwitched': () {
          Navigator.pushNamedAndRemoveUntil<T>(_context, routeName, predicate,
              arguments: arguments);
        },
      },
    );

    await Future.delayed(Duration.zero);

    if (!handled && _context.mounted) {
      return Navigator.pushNamedAndRemoveUntil<T>(_context, routeName, predicate,
          arguments: arguments);
    }

    return result as T?;
  }

  /// Push a [Route] directly.
  Future<T?> push<T extends Object?>(Route<T> route) async {
    bool handled = false;
    Object? result;

    _bus.fire(
      'navigation.push',
      data: {
        'route': route,
        'context': _context,
        '_markHandled': (Object? res) {
          handled = true;
          result = res;
        },
        'onSwitched': () {
          Navigator.push<T>(_context, route);
        },
      },
    );

    await Future.delayed(Duration.zero);

    if (!handled && _context.mounted) {
      return Navigator.push<T>(_context, route);
    }

    return result as T?;
  }

  /// Pop the current route.
  void pop<T extends Object?>([T? result]) {
    bool handled = false;

    _bus.fire(
      'navigation.pop',
      data: {
        'result': result,
        'context': _context,
        '_markHandled': (Object? res) {
          handled = true;
        },
        'onSwitched': () {
          if (Navigator.canPop(_context)) {
            Navigator.pop<T>(_context);
          }
        },
      },
    );

    if (!handled && Navigator.canPop(_context)) {
      Navigator.pop(_context, result);
    }
  }

  /// Switch to a tab by ID.
  Future<void> switchToTab(String tabId) async {
    bool handled = false;

    _bus.fire(
      'navigation.switch_to_tab',
      data: {
        'tabId': tabId,
        'context': _context,
        '_markHandled': (Object? res) {
          handled = true;
        },
      },
    );

    await Future.delayed(Duration.zero);

    if (!handled && _context.mounted) {
      await pushNamed('/$tabId');
    }
  }

  /// Switch to a tab by index.
  Future<void> switchToTabIndex(int index) async {
    bool handled = false;

    _bus.fire(
      'navigation.switch_to_tab_index',
      data: {
        'index': index,
        'context': _context,
        '_markHandled': (Object? res) {
          handled = true;
        },
      },
    );

    await Future.delayed(Duration.zero);

    if (!handled) {
      debugPrint('MooseNavigator: No handler for tab index $index');
    }
  }
}
