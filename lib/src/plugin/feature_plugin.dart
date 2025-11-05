import '../actions/action_registry.dart';
import '../adapter/adapter_registry.dart';
import '../events/hook_registry.dart';
import '../widgets/addon_registry.dart';
import '../widgets/widget_registry.dart';
import 'package:flutter/material.dart';

abstract class FeaturePlugin {
  String get name;
  String get version;
  final HookRegistry hookRegistry = HookRegistry();
  final AddonRegistry addonRegistry = AddonRegistry();
  final WidgetRegistry widgetRegistry = WidgetRegistry();
  final AdapterRegistry adapterRegistry = AdapterRegistry();
  final ActionRegistry actionRegistry = ActionRegistry();

  /// Called when plugin is registered
  void onRegister();

  /// Called when plugin needs to be initialized
  Future<void> initialize();

  /// Optional: Plugin can provide routes
  Map<String, WidgetBuilder>? getRoutes();
}
