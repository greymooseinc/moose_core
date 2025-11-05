class Hook {
  final int priority;
  final dynamic Function(dynamic) callback;
  Hook(this.priority, this.callback);
}

class HookRegistry {
  static final HookRegistry _instance = HookRegistry._internal();

  /// Get the singleton instance
  factory HookRegistry() => _instance;

  /// Named constructor for explicit access
  static HookRegistry get instance => _instance;

  HookRegistry._internal();

  final Map<String, List<Hook>> _hooks = {};

  void register(String hookName, dynamic Function(dynamic) callback, {int priority = 1}) {
    _hooks.putIfAbsent(hookName, () => []);
    _hooks[hookName]!.add(Hook(priority, callback));

    // sort highest priority first
    _hooks[hookName]!.sort((a, b) => b.priority.compareTo(a.priority));
    print('\'$hookName\' hook registered with priority $priority');
  }

  T execute<T>(String hookName, T data) {
    if (!_hooks.containsKey(hookName)) return data;

    dynamic result = data;
    for (final hook in _hooks[hookName]!) {
      try {
        result = hook.callback(result);
      } catch (e, stack) {
        print('Error executing hook "$hookName": $e\n$stack');
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