import 'package:flutter/material.dart';

import '../events/event_bus.dart';

/// Centralized navigation service that uses EventBus for decoupled navigation.
///
/// This allows plugins to intercept and handle navigation events (like tab switching)
/// while falling back to standard Flutter Navigator if no listeners handle the event.
///
/// ## Usage:
/// ```dart
/// // Standard navigation (works exactly like Navigator.pushNamed)
/// AppNavigator.pushNamed(context, '/product', arguments: {'id': '123'});
///
/// // Tab switching (if BottomTabbedHomePlugin is active, it intercepts)
/// AppNavigator.switchToTab(context, 'cart');
///
/// // Pop (respects custom handlers)
/// AppNavigator.pop(context);
/// ```
///
/// ## For Plugin Authors:
/// Listen to navigation events in your plugin:
/// ```dart
/// AppNavigator.eventBus.on('navigation.switch_to_tab', (event) {
///   final tabId = event.data['tabId'] as String?;
///   final context = event.data['context'] as BuildContext;
///   final markHandled = event.data['_markHandled'] as Function;
///
///   // Switch to tab...
///   markHandled(null);
/// });
/// ```
class AppNavigator {
  static final EventBus _eventBus = EventBus();

  /// Push a named route.
  ///
  /// First fires a navigation event to allow plugins to intercept.
  /// Falls back to [Navigator.pushNamed] if no listener handles it.
  static Future<T?> pushNamed<T extends Object?>(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) async {
    bool handled = false;
    Object? result;

    _eventBus.fire(
      'navigation.push_named',
      data: {
        'routeName': routeName,
        'arguments': arguments,
        'context': context,
        '_markHandled': (Object? res) {
          handled = true;
          result = res;
        },
        'onSwitched': () {
          Navigator.pushNamed<T>(context, routeName, arguments: arguments);
        },
      },
    );

    // Wait a frame to allow listeners to mark as handled
    await Future.delayed(Duration.zero);

    if (!handled) {
      // No plugin handled it, use standard Navigator
      return Navigator.pushNamed<T>(context, routeName, arguments: arguments);
    }

    return result as T?;
  }

  static Future<T?> pushReplacementNamed<T extends Object?, TO extends Object?>(
    BuildContext context,
    String routeName, {
    TO? result,
    Object? arguments,
  }) async {
    bool handled = false;
    Object? handlerResult;

    _eventBus.fire(
      'navigation.push_replacement_named',
      data: {
        'routeName': routeName,
        'arguments': arguments,
        'result': result,
        'context': context,
        '_markHandled': (Object? res) {
          handled = true;
          handlerResult = res;
        },
        'onSwitched': () {
          Navigator.pushReplacementNamed<T, TO>(context, routeName, result: result, arguments: arguments);
        },
      },
    );

    // Wait a frame to allow listeners to mark as handled
    await Future.delayed(Duration.zero);

    if (!handled) {
      // No plugin handled it, use standard Navigator
      return Navigator.pushReplacementNamed<T, TO>(context, routeName, result: result, arguments: arguments);
    }

    return handlerResult as T?;
  }

  /// Push a route.
  ///
  /// First fires a navigation event to allow plugins to intercept.
  /// Falls back to [Navigator.push] if no listener handles it.
  static Future<T?> push<T extends Object?>(
    BuildContext context,
    Route<T> route,
  ) async {
    bool handled = false;
    Object? result;

    _eventBus.fire(
      'navigation.push',
      data: {
        'route': route,
        'context': context,
        '_markHandled': (Object? res) {
          handled = true;
          result = res;
        },
        'onSwitched': () {
          Navigator.push<T>(context, route);
        },
      },
    );

    // Wait a frame to allow listeners to mark as handled
    await Future.delayed(Duration.zero);

    if (!handled) {
      // No plugin handled it, use standard Navigator
      return Navigator.push<T>(context, route);
    }

    return result as T?;
  }

  /// Pop the current route.
  ///
  /// First fires a navigation event to allow plugins to intercept.
  /// Falls back to [Navigator.pop] if no listener handles it.
  static void pop<T extends Object?>(BuildContext context, [T? result]) {
    bool handled = false;

    _eventBus.fire(
      'navigation.pop',
      data: {
        'result': result,
        'context': context,
        '_markHandled': (Object? res) {
          handled = true;
        },
        'onSwitched': () {
          if (Navigator.canPop(context)) {
           Navigator.pop<T>(context);
          }
        },
      },
    );

    // If no plugin handled it, use standard Navigator
    if (!handled && Navigator.canPop(context)) {
      Navigator.pop(context, result);
    }
  }

  /// Switch to a tab by ID.
  ///
  /// This is a convenience method specifically for tab switching.
  /// If BottomTabbedHomePlugin (or similar) is active, it will handle the switch.
  /// Otherwise, falls back to [pushNamed] with the tab's route.
  static Future<void> switchToTab(
    BuildContext context,
    String tabId,
  ) async {
    bool handled = false;

    _eventBus.fire(
      'navigation.switch_to_tab',
      data: {
        'tabId': tabId,
        'context': context,
        '_markHandled': (Object? res) {
          handled = true;
        },
      },
    );

    // Wait a frame to allow listeners to mark as handled
    await Future.delayed(Duration.zero);

    if (!handled) {
      // Fallback: try to navigate to the tab's route
      // This works if the tab route is registered normally
      await pushNamed(context, '/$tabId');
    }
  }

  /// Switch to a tab by index.
  ///
  /// This is a convenience method specifically for tab switching by index.
  static Future<void> switchToTabIndex(
    BuildContext context,
    int index,
  ) async {
    bool handled = false;

    _eventBus.fire(
      'navigation.switch_to_tab_index',
      data: {
        'index': index,
        'context': context,
        '_markHandled': (Object? res) {
          handled = true;
        },
      },
    );

    // Wait a frame to allow listeners to mark as handled
    await Future.delayed(Duration.zero);

    // No fallback for index-based switching since we don't know the route
    if (!handled) {
      debugPrint('AppNavigator: No handler for tab index $index');
    }
  }

  static bool canPop<T extends Object?>(BuildContext context, [T? result]) {
    return Navigator.canPop(context);
  }

  /// Get the EventBus instance for advanced use cases.
  ///
  /// Plugins can use this to listen to navigation events directly.
  static EventBus get eventBus => _eventBus;
}
