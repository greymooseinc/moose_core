import 'package:flutter/material.dart';
import 'package:moose_core/entities.dart';
import 'package:moose_core/services.dart';

import '../app/moose_app_context.dart';
import 'feature_plugin.dart';

/// App-scoped registry for managing feature plugins.
///
/// Create one [PluginRegistry] per [MooseAppContext] (done automatically).
/// Use [MooseBootstrapper] to register and initialize plugins.
///
/// ## Lifecycle:
/// 1. [register] — sync: inject [MooseAppContext], call [FeaturePlugin.onRegister]
/// 2. [initializeAll] — async: call [FeaturePlugin.initialize] on every active plugin
class PluginRegistry {
  PluginRegistry();

  final Map<String, FeaturePlugin> _plugins = {};
  final _logger = AppLogger('PluginRegistry');
  final List<BottomTab> _bottomTabs = [];
  bool _bottomTabsHookRegistered = false;

  /// Synchronously registers a plugin and injects the [appContext].
  ///
  /// - Reads plugin active/inactive state from [MooseAppContext.configManager].
  /// - Registers plugin defaults in the config manager.
  /// - Injects [appContext] into the plugin **before** calling [FeaturePlugin.onRegister],
  ///   so the plugin can access registries inside `onRegister`.
  /// - Registers any bottom-navigation tabs the plugin declares.
  ///
  /// Inactive plugins (configured with `active: false`) are silently skipped.
  void register(FeaturePlugin plugin, {required MooseAppContext appContext}) {
    final defaults = plugin.getDefaultSettings();
    if (defaults.isNotEmpty) {
      appContext.configManager.registerPluginDefaults(plugin.name, defaults);
      _logger.info('Registered defaults for plugin: ${plugin.name}');
    }

    final pluginConfigData = appContext.configManager.get('plugins:${plugin.name}');
    final pluginConfig = pluginConfigData is Map<String, dynamic>
        ? PluginConfig.fromJson(plugin.name, pluginConfigData)
        : PluginConfig(name: plugin.name, active: true);

    if (!pluginConfig.active) {
      _logger.info('Skipping inactive plugin: ${plugin.name}');
      return;
    }

    // Inject context BEFORE onRegister so the plugin can use registries inside it.
    plugin.appContext = appContext;
    _plugins[plugin.name] = plugin;

    plugin.onRegister();
    _logger.success('Registered plugin: ${plugin.name} (${plugin.version})');

    _registerBottomTabs(plugin, appContext.hookRegistry);
  }

  /// Asynchronously initializes every registered plugin in registration order.
  ///
  /// Optionally collects per-plugin timing into [timings] (populated by
  /// [MooseBootstrapper] for the [BootstrapReport]).
  Future<void> initializeAll({Map<String, Duration>? timings}) async {
    for (final plugin in _plugins.values) {
      final sw = Stopwatch()..start();
      await plugin.initialize();
      sw.stop();
      timings?[plugin.name] = sw.elapsed;
      _logger.success('Initialized plugin: ${plugin.name}');
    }
  }

  void _registerBottomTabs(FeaturePlugin plugin, HookRegistry hookRegistry) {
    final tabs = plugin.bottomTabs;
    if (tabs.isEmpty) return;

    for (final tab in tabs) {
      final existingIndex = _bottomTabs.indexWhere((t) => t.id == tab.id);
      if (existingIndex != -1) {
        _bottomTabs[existingIndex] = tab;
      } else {
        _bottomTabs.add(tab);
      }
    }

    if (_bottomTabsHookRegistered) return;

    hookRegistry.register(
      'bottom_tabs:filter_tabs',
      (existingTabs) {
        if (existingTabs is! List<BottomTab>) return existingTabs;
        final merged = List<BottomTab>.from(existingTabs);
        for (final tab in _bottomTabs) {
          final idx = merged.indexWhere((t) => t.id == tab.id);
          if (idx != -1) {
            merged[idx] = tab;
          } else {
            merged.add(tab);
          }
        }
        return merged;
      },
      priority: 10,
    );

    _bottomTabsHookRegistered = true;
  }

  /// Returns the registered plugin for [name], cast to [T].
  ///
  /// Throws if no plugin with that name has been registered.
  T getPlugin<T extends FeaturePlugin>(String name) {
    if (!_plugins.containsKey(name)) {
      throw Exception('Plugin "$name" not registered');
    }
    return _plugins[name] as T;
  }

  bool hasPlugin(String name) => _plugins.containsKey(name);

  List<String> getRegisteredPlugins() => _plugins.keys.toList();

  int get pluginCount => _plugins.length;

  /// Collects routes from all registered plugins into a single map.
  ///
  /// If no plugin registers `/home`, a minimal placeholder is added.
  Map<String, WidgetBuilder> getAllRoutes() {
    final routes = <String, WidgetBuilder>{};
    for (final plugin in _plugins.values) {
      final pluginRoutes = plugin.getRoutes();
      if (pluginRoutes != null) routes.addAll(pluginRoutes);
    }
    if (!routes.containsKey('/home')) {
      routes['/home'] = (context) => Scaffold(
            body: Center(
              child: Text(
                'Hello!',
                style: Theme.of(context).textTheme.headlineLarge,
              ),
            ),
          );
    }
    return routes;
  }

  /// Clears all registered plugins. Use in tests only.
  void clearAll() {
    _plugins.clear();
    _bottomTabs.clear();
    _bottomTabsHookRegistered = false;
  }
}
