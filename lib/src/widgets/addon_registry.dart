import 'package:flutter/material.dart';

typedef WidgetBuilderFn = Widget? Function(
  BuildContext context, {
  Map<String, dynamic>? data,
  void Function(String event, dynamic payload)? onEvent,
});

class Addon {
  final int priority;
  final WidgetBuilderFn builder;
  Addon(this.priority, this.builder);
}

class AddonRegistry {
  static final AddonRegistry _instance = AddonRegistry._internal();

  /// Get the singleton instance
  factory AddonRegistry() => _instance;

  /// Named constructor for explicit access
  static AddonRegistry get instance => _instance;

  AddonRegistry._internal();

  final Map<String, List<Addon>> _addons = {};

  void register(String name, WidgetBuilderFn builder, {int priority = 1}) {
    _addons.putIfAbsent(name, () => []);
    final existing = _addons[name]!;
    final alreadyRegistered =
        existing.any((addon) => addon.builder == builder);
    if (alreadyRegistered) {
      debugPrint(
        'AddonRegistry: Duplicate builder ignored for "$name".',
      );
      return;
    }
    existing.add(Addon(priority, builder));

    // sort highest priority first
    existing.sort((a, b) => b.priority.compareTo(a.priority));
    print('\'$name\' Addon registered with priority $priority');
  }

  List<Widget> build<T>(String name, BuildContext context, {
    Map<String, dynamic>? data,
    void Function(String event, dynamic payload)? onEvent,
  }) {
    final builders = _addons[name];
    if (builders == null || builders.isEmpty) return [];
    final results = <Widget>[];
    for (final b in builders) {
      try {
        final widget = b.builder(context, data: data, onEvent: onEvent);
        if (widget != null) {
          results.add(widget);
        }
      } catch (e, stack) {
        debugPrint('Addon error in zone "$name": $e\n$stack');
      }
    }

    return results;
  }

  void removeAddon(String name, WidgetBuilderFn builder) {
    if (_addons.containsKey(name)) {
      _addons[name]!.removeWhere((addon) => addon.builder == builder);
    }
  }

  void clearAddons(String name) {
    _addons[name]?.clear();
  }

  void clearAllAddons() {
    _addons.clear();
  }

  List<String> getRegisteredAddons() => _addons.keys.toList();

  int getAddonCount(String name) {
    return _addons[name]?.length ?? 0;
  }

  bool hasAddon(String name) {
    return _addons.containsKey(name) && _addons[name]!.isNotEmpty;
  }
}
