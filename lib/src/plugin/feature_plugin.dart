import 'package:flutter/material.dart';
import 'package:moose_core/adapters.dart';
import 'package:moose_core/services.dart';
import 'package:moose_core/widgets.dart';

abstract class FeaturePlugin {
  String get name;
  String get version;
  final HookRegistry hookRegistry = HookRegistry();
  final AddonRegistry addonRegistry = AddonRegistry();
  final WidgetRegistry widgetRegistry = WidgetRegistry();
  final AdapterRegistry adapterRegistry = AdapterRegistry();
  final ActionRegistry actionRegistry = ActionRegistry();
  final EventBus eventBus = EventBus();

  /// Called when plugin is registered
  void onRegister();

  /// Called when plugin needs to be initialized
  Future<void> initialize();

  /// Optional: Plugin can provide routes
  Map<String, WidgetBuilder>? getRoutes();
}
