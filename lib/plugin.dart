/// Plugin system for moose_core package.
///
/// This module exports the plugin architecture components that enable modular,
/// feature-based application development. Each feature is implemented as a self-contained plugin.
library plugin;

export 'src/plugin/feature_plugin.dart';
export 'src/plugin/plugin_registry.dart';
