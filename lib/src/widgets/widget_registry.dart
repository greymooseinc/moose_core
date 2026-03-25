import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../config/config_manager.dart';
import '../entities/section_config.dart';
import '../utils/logger.dart';
import 'feature_section.dart';
import 'unknown_section_widget.dart';

typedef SectionBuilderFn = FeatureSection Function(
  BuildContext context, {
  Map<String, dynamic>? data,
  void Function(String event, dynamic payload)? onEvent,
});

typedef WidgetBuilderFn = Widget? Function(
  BuildContext context, {
  Map<String, dynamic>? data,
  void Function(String event, dynamic payload)? onEvent,
});

class _Entry {
  final int priority;
  final WidgetBuilderFn builder;
  _Entry(this.priority, this.builder);
}

class WidgetRegistry {
  WidgetRegistry();

  final Map<String, List<_Entry>> _registry = {};
  ConfigManager _configManager = ConfigManager();
  final _logger = AppLogger('WidgetRegistry');

  /// Called by [MooseAppContext] after construction to wire the scoped
  /// [ConfigManager] in place of the default instance.
  void setConfigManager(ConfigManager cm) => _configManager = cm;

  /// Registers a [FeatureSection] builder for [name].
  ///
  /// Use this when the builder returns a [FeatureSection] and you want the
  /// settings abstraction (`getSetting`, `getDefaultSettings`) enforced.
  ///
  /// Multiple registrations for the same [name] are allowed. When [build] or
  /// [buildAll] is called, entries are invoked in descending [priority] order
  /// (highest priority first). Duplicate builder references are ignored.
  void registerSection(String name, SectionBuilderFn builder,
      {int priority = 0}) {
    _add(name, (ctx, {data, onEvent}) => builder(ctx, data: data, onEvent: onEvent), priority);
    _logger.debug('\'$name\' section registered');
  }

  /// Registers a plain [WidgetBuilderFn] for [name].
  ///
  /// Use this for lightweight builders — overlays, action buttons, loading
  /// indicators — that do not need the [FeatureSection] settings abstraction.
  ///
  /// Multiple registrations for the same [name] are allowed and all are called
  /// by [buildAll]. Duplicate builder references are ignored.
  void registerWidget(String name, WidgetBuilderFn builder,
      {int priority = 0}) {
    _add(name, builder, priority);
    _logger.debug('\'$name\' widget registered');
  }

  void _add(String name, WidgetBuilderFn builder, int priority) {
    final entries = _registry.putIfAbsent(name, () => []);
    final alreadyRegistered = entries.any((e) => e.builder == builder);
    if (alreadyRegistered) {
      debugPrint('WidgetRegistry: Duplicate builder ignored for "$name".');
      return;
    }
    entries.add(_Entry(priority, builder));
    entries.sort((a, b) => b.priority.compareTo(a.priority));
  }

  bool isRegistered(String name) {
    final entries = _registry[name];
    return entries != null && entries.isNotEmpty;
  }

  List<String> getRegisteredWidgets() {
    return _registry.keys.toList();
  }

  /// Removes all registered builders across every widget name.
  ///
  /// Called by [MooseAppContext.reloadConfig] before re-running plugin
  /// registration so that widget builders don't accumulate across reloads.
  void clearAll() {
    _registry.clear();
  }

  /// Removes all builders registered under [name].
  void unregister(String name) {
    _registry.remove(name);
  }

  /// Removes a specific [builder] from the entries registered under [name].
  ///
  /// Other builders registered under the same key are unaffected. Has no
  /// effect if [builder] is not currently registered under [name].
  void unregisterBuilder(String name, WidgetBuilderFn builder) {
    final entries = _registry[name];
    if (entries == null) return;
    entries.removeWhere((e) => e.builder == builder);
    if (entries.isEmpty) _registry.remove(name);
  }

  /// Returns the first non-null widget produced by the builders registered
  /// under [name], evaluated in descending priority order.
  ///
  /// If [fallback] is provided it is returned when no builder is registered or
  /// all builders return null — in both debug and release mode. When [fallback]
  /// is omitted the default behaviour applies: [UnknownSectionWidget] in debug
  /// mode, [SizedBox.shrink] in release mode.
  Widget build(
    String name,
    BuildContext context, {
    Map<String, dynamic>? data,
    void Function(String event, dynamic payload)? onEvent,
    Widget? fallback,
  }) {
    Widget resolveFallback() {
      if (fallback != null) return fallback;
      if (kDebugMode) {
        return UnknownSectionWidget(
          requestedName: name,
          availableKeys: _registry.keys.toList(),
        );
      }
      return const SizedBox.shrink();
    }

    final entries = _registry[name];
    if (entries == null || entries.isEmpty) return resolveFallback();

    for (final entry in entries) {
      try {
        final widget = entry.builder(context, data: data, onEvent: onEvent);
        if (widget != null) return widget;
      } catch (e, stack) {
        debugPrint('WidgetRegistry build error for "$name": $e\n$stack');
      }
    }
    return resolveFallback();
  }

  /// Returns all non-null widgets produced by every builder registered under
  /// [name], evaluated in descending priority order.
  ///
  /// If [fallback] is provided it is returned as a single-element list when no
  /// builder is registered or all builders return null. When [fallback] is
  /// omitted an empty list is returned in that case.
  ///
  /// Errors in individual builders are caught and logged; other builders
  /// continue executing.
  List<Widget> buildAll(
    String name,
    BuildContext context, {
    Map<String, dynamic>? data,
    void Function(String event, dynamic payload)? onEvent,
    Widget? fallback,
  }) {
    final entries = _registry[name];
    if (entries == null || entries.isEmpty) {
      return fallback != null ? [fallback] : [];
    }
    final results = <Widget>[];
    for (final entry in entries) {
      try {
        final widget = entry.builder(context, data: data, onEvent: onEvent);
        if (widget != null) results.add(widget);
      } catch (e, stack) {
        debugPrint('WidgetRegistry buildAll error for "$name": $e\n$stack');
      }
    }
    if (results.isEmpty && fallback != null) return [fallback];
    return results;
  }

  List<SectionConfig> getSections(String pluginName, String groupName) {
    final sections = _configManager.get('plugins:$pluginName:sections:$groupName');
    if (sections is List) {
      return sections
          .whereType<Map<String, dynamic>>()
          .map((json) => SectionConfig.fromJson(json))
          .toList();
    }
    return [];
  }

  List<Widget> buildSectionGroup(
    BuildContext context, {
    required String pluginName,
    required String groupName,
    Map<String, dynamic>? data,
    void Function(String event, dynamic payload)? onEvent,
  }) {
    final sectionConfigs = getSections(pluginName, groupName);
    final results = <Widget>[];
    for (final section in sectionConfigs.where((s) => s.active)) {
      final mergedData = {
        'settings': {...section.settings},
        ...?data,
      };
      final entries = _registry[section.name];
      if (entries == null || entries.isEmpty) continue;
      for (final entry in entries) {
        try {
          final widget = entry.builder(context, data: mergedData, onEvent: onEvent);
          if (widget != null) {
            results.add(widget);
            break; // one widget per section config entry (same as build())
          }
        } catch (e, stack) {
          debugPrint('WidgetRegistry buildSectionGroup error for "${section.name}": $e\n$stack');
        }
      }
    }
    return results;
  }
}
