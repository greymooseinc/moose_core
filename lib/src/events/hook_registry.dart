import '../utils/logger.dart';

/// A single hook entry: callback + priority level.
class Hook {
  /// Execution priority — higher values run first.
  final int priority;

  /// The transformation callback for this hook.
  final dynamic Function(dynamic) callback;

  /// Creates a [Hook] with the given [priority] and [callback].
  Hook(this.priority, this.callback);
}

/// Registry for named synchronous and asynchronous transformation hooks.
///
/// Hooks let plugins modify framework data (cart items, checkout fields, etc.)
/// without coupling to each other. Each hook is a chain of callbacks executed
/// in priority order, each receiving the output of the previous callback.
///
/// Example:
/// ```dart
/// // Plugin A enriches cart items
/// hookRegistry.register('cart:enrich_items', (items) {
///   return (items as List).map((i) => {...i, 'enriched': true}).toList();
/// }, priority: 10);
///
/// // Apply all hooks
/// final enriched = hookRegistry.execute<List>('cart:enrich_items', rawItems);
/// ```
class HookRegistry {
  /// Creates an independent [HookRegistry] instance.
  HookRegistry();

  final Map<String, List<Hook>> _hooks = {};
  final _logger = AppLogger('HookRegistry');

  /// Register [callback] for [hookName] with the given [priority].
  ///
  /// Higher [priority] values run first. Registering the same [callback]
  /// reference twice is a no-op — useful during config reloads.
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
  /// debug mode and an error is logged in all modes — the hook's output is
  /// skipped and execution continues with the remaining hooks. Async callbacks
  /// must use [executeAsync] instead.
  T execute<T>(String hookName, T data) {
    if (!_hooks.containsKey(hookName)) return data;

    dynamic result = data;
    for (final hook in _hooks[hookName]!) {
      try {
        final returned = hook.callback(result);
        if (returned is Future) {
          assert(
            false,
            'Hook "$hookName" returned a Future. '
            'Async callbacks must be registered and called via executeAsync().',
          );
          _logger.error(
            'Hook "$hookName" returned a Future inside execute() — '
            'skipping result. Use executeAsync() for async hooks.',
          );
          continue; // keep previous result, skip this hook's output
        }
        result = returned;
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

  /// Remove a specific [callback] from [hookName]. No-op if not registered.
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

  /// Clear all hooks registered under [hookName].
  void clearHooks(String hookName) {
    _hooks[hookName]?.clear();
  }

  /// Clear every registered hook across all names. Alias for [clearAll].
  void clearAllHooks() {
    _hooks.clear();
  }

  /// Returns every hook name that has at least one registered callback.
  List<String> getRegisteredHooks() => _hooks.keys.toList();

  /// Returns the number of callbacks registered for [hookName].
  int getHookCount(String hookName) {
    return _hooks[hookName]?.length ?? 0;
  }

  /// Returns `true` when at least one callback is registered for [hookName].
  bool hasHook(String hookName) {
    return _hooks.containsKey(hookName) && _hooks[hookName]!.isNotEmpty;
  }
}