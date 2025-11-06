import '../config/config_manager.dart';
import '../entities/section_config.dart';
import 'feature_section.dart';
import 'package:flutter/material.dart';

typedef SectionBuilderFn = FeatureSection Function(
  BuildContext context, {
  Map<String, dynamic>? data,
  void Function(String event, dynamic payload)? onEvent,
});

class WidgetRegistry {
  static final WidgetRegistry _instance = WidgetRegistry._internal();

  /// Get the singleton instance
  factory WidgetRegistry() => _instance;

  /// Named constructor for explicit access
  static WidgetRegistry get instance => _instance;

  WidgetRegistry._internal();

  final Map<String, SectionBuilderFn> _registry = {};
  final ConfigManager _configManager = ConfigManager();

  void register(String name, SectionBuilderFn builder) {
    _registry[name] = builder;
    print('\'$name\' widget registered');
  }

  bool isRegistered(String name) {
    return _registry.containsKey(name);
  }

  List<String> getRegisteredWidgets() {
    return _registry.keys.toList();
  }

  void unregister(String name) {
    _registry.remove(name);
  }

  Widget build(
    String name,
    BuildContext context, {
    Map<String, dynamic>? data,
    void Function(String event, dynamic payload)? onEvent,
  }) {
    final builder = _registry[name];
    if (builder == null) {
      return Container();
    }
    return builder(context, data: data, onEvent: onEvent);
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
    return sectionConfigs
        .where((section) => section.active)
        .map((section) {
      return build(
        section.name,
        context,
        data: {
          'settings': {...section.settings},
          ...?data,
        },
        onEvent: onEvent,
      );
    }).toList();
  }
}