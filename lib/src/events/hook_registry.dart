import '../utils/logger.dart';

class Hook {
  final int priority;
  final dynamic Function(dynamic) callback;
  Hook(this.priority, this.callback);
}

class HookRegistry {
  HookRegistry();

  final Map<String, List<Hook>> _hooks = {};
  final _logger = AppLogger('HookRegistry');

  void register(String hookName, dynamic Function(dynamic) callback, {int priority = 1}) {
    final hooks = _hooks.putIfAbsent(hookName, () => []);
    // Deduplicate by callback identity — same closure registered twice (e.g.
    // during a config reload) is silently ignored, matching WidgetRegistry.
    if (hooks.any((h) => h.callback == callback)) return;
    hooks.add(Hook(priority, callback));

    // sort highest priority first
    hooks.sort((a, b) => b.priority.compareTo(a.priority));
    _logger.debug('\'$hookName\' hook registered with priority $priority');
  }

  /// Execute all hooks for [hookName] synchronously, threading [data] through
  /// each callback in priority order.
  ///
  /// If any registered callback returns a [Future], an assertion is thrown in
  /// debug mode — async callbacks must use [executeAsync] instead. In release
  /// mode the Future leaks through unchecked, so always use the correct method.
  T execute<T>(String hookName, T data) {
    if (!_hooks.containsKey(hookName)) return data;

    dynamic result = data;
    for (final hook in _hooks[hookName]!) {
      try {
        result = hook.callback(result);
        assert(
          result is! Future,
          'Hook "$hookName" returned a Future. '
          'Async callbacks must be registered and called via executeAsync().',
        );
      } catch (e, stack) {
        _logger.error('Error executing hook "$hookName"', e, stack);
        // Continue executing other hooks even if one fails
      }
    }
    return result as T;
  }

  /// Execute all hooks for [hookName] asynchronously, threading [data] through
  /// each callback in priority order and awaiting each result.
  ///
  /// Use this when one or more registered callbacks return a [Future]. Sync
  /// callbacks are also supported — their return value is used directly.
  ///
  /// Example:
  /// ```dart
  /// hookRegistry.register('cart:enrich_items', (items) async {
  ///   return await enrichWithPricing(items as List);
  /// });
  ///
  /// final enriched = await hookRegistry.executeAsync<List>('cart:enrich_items', rawItems);
  /// ```
  Future<T> executeAsync<T>(String hookName, T data) async {
    if (!_hooks.containsKey(hookName)) return data;

    dynamic result = data;
    for (final hook in _hooks[hookName]!) {
      try {
        final returned = hook.callback(result);
        result = returned is Future ? await returned : returned;
      } catch (e, stack) {
        _logger.error('Error executing async hook "$hookName"', e, stack);
        // Continue executing other hooks even if one fails
      }
    }
    return result as T;
  }

  void removeHook(String hookName, dynamic Function(dynamic) callback) {
    if (_hooks.containsKey(hookName)) {
      _hooks[hookName]!.removeWhere((hook) => hook.callback == callback);
    }
  }

  /// Removes all registered hooks across every hook name.
  ///
  /// Called by [MooseAppContext.reloadConfig] before re-running plugin
  /// registration so that hooks don't accumulate across reloads.
  void clearAll() {
    _hooks.clear();
  }

  void clearHooks(String hookName) {
    _hooks[hookName]?.clear();
  }

  void clearAllHooks() {
    _hooks.clear();
  }

  List<String> getRegisteredHooks() => _hooks.keys.toList();

  int getHookCount(String hookName) {
    return _hooks[hookName]?.length ?? 0;
  }

  bool hasHook(String hookName) {
    return _hooks.containsKey(hookName) && _hooks[hookName]!.isNotEmpty;
  }
}