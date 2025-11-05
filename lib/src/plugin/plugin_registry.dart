import 'package:moose_core/services.dart';

import 'feature_plugin.dart';

import 'package:flutter/material.dart';

/// Singleton registry for managing feature plugins.
///
/// The PluginRegistry provides centralized management of feature plugins,
/// allowing plugins to be registered and initialized on-the-fly.
///
/// ## Key Features:
/// - **Singleton Pattern**: Only one registry instance exists
/// - **Factory-Based Registration**: Plugins registered via factory functions
/// - **Immediate Initialization**: Plugins are initialized as they are registered
/// - **Type Safety**: Generic methods for type-safe plugin retrieval
///
/// ## Example Usage:
/// ```dart
/// final registry = PluginRegistry();
///
/// // Register and initialize plugins
/// await registry.registerPlugin(() => HomePlugin());
/// await registry.registerPlugin(() => ProductsPlugin());
/// await registry.registerPlugin(() => CartPlugin());
///
/// // Get plugin if needed
/// final homePlugin = registry.getPlugin<HomePlugin>('home');
/// ```
class PluginRegistry {
  static final PluginRegistry _instance = PluginRegistry._internal();
  factory PluginRegistry() => _instance;
  PluginRegistry._internal();

  final Map<String, FeaturePlugin> _plugins = {};
  final _logger = AppLogger('PluginRegistry');

  /// Registers and initializes a feature plugin.
  ///
  /// The plugin is created and initialized immediately when this method is called.
  ///
  /// **Parameters:**
  /// - [factory]: Function that creates the plugin instance
  ///
  /// **Behavior:**
  /// 1. Calls the factory function to create the plugin
  /// 2. Calls plugin.onRegister()
  /// 3. Calls plugin.initialize() and awaits completion
  /// 4. Caches the plugin instance
  ///
  /// **Example:**
  /// ```dart
  /// await registry.registerPlugin(() => ProductsPlugin());
  /// ```
  Future<void> registerPlugin(FeaturePlugin Function() factory) async {
    final plugin = factory();
    _plugins[plugin.name] = plugin;

    // Call onRegister hook
    plugin.onRegister();
    _logger.success('Registered plugin: ${plugin.name} (${plugin.version})');

    // Initialize the plugin
    await plugin.initialize();
    _logger.success('Initialized plugin: ${plugin.name}');
  }

  /// Retrieves a registered plugin by name with type safety.
  ///
  /// **Type Parameters:**
  /// - [T]: The specific plugin type (must extend [FeaturePlugin])
  ///
  /// **Parameters:**
  /// - [name]: The name of the plugin to retrieve
  ///
  /// **Returns:**
  /// - [T]: The plugin cast to the specified type
  ///
  /// **Throws:**
  /// - [Exception]: If plugin with given name is not registered
  ///
  /// **Example:**
  /// ```dart
  /// final productsPlugin = registry.getPlugin<ProductsPlugin>('products');
  /// ```
  T getPlugin<T extends FeaturePlugin>(String name) {
    if (!_plugins.containsKey(name)) {
      throw Exception('Plugin $name not registered');
    }
    return _plugins[name] as T;
  }

  /// Checks if a plugin with the given name is registered.
  ///
  /// **Parameters:**
  /// - [name]: The plugin name to check
  ///
  /// **Returns:**
  /// - [bool]: true if plugin is registered, false otherwise
  bool hasPlugin(String name) => _plugins.containsKey(name);

  /// Returns a list of all registered plugin names.
  ///
  /// **Returns:**
  /// - [List<String>]: Names of all registered plugins
  List<String> getRegisteredPlugins() => _plugins.keys.toList();

  /// Returns the total number of registered plugins.
  ///
  /// **Returns:**
  /// - [int]: Count of registered plugins
  int get pluginCount => _plugins.length;

  /// Returns all routes from all registered plugins.
  ///
  /// Collects routes from each plugin's getRoutes() method and merges them
  /// into a single map. If multiple plugins define the same route, the last
  /// plugin's route will take precedence.
  ///
  /// **Returns:**
  /// - [Map<String, WidgetBuilder>]: Combined routes from all plugins
  ///
  /// **Example:**
  /// ```dart
  /// final allRoutes = registry.getAllRoutes();
  /// // Returns: {'/home': ..., '/products': ..., '/cart': ...}
  /// ```
  Map<String, WidgetBuilder> getAllRoutes() {
    final routes = <String, WidgetBuilder>{};

    for (final plugin in _plugins.values) {
      final pluginRoutes = plugin.getRoutes();
      if (pluginRoutes != null) {
        routes.addAll(pluginRoutes);
      }
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

  /// Clears all registered plugins (for testing).
  ///
  /// **Warning:** Use with caution - this will remove all plugins.
  void clearAll() {
    _plugins.clear();
  }
}
