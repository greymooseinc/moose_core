import 'package:flutter/material.dart';
import 'package:moose_core/adapters.dart';
import 'package:moose_core/entities.dart';
import 'package:moose_core/services.dart';
import 'package:moose_core/widgets.dart';

import '../app/moose_app_context.dart';

/// Base class for all feature plugins in the application.
///
/// Feature plugins are self-contained modules that provide specific functionality
/// to the application. Each plugin has access to various registries for hooks,
/// addons, widgets, adapters, actions, and the event bus for inter-plugin communication.
///
/// ## Plugin Lifecycle:
/// 1. **Creation**: Plugin instance is created via factory function
/// 2. **Configuration Check**: PluginRegistry checks if plugin is active in environment.json
/// 3. **Registration**: If active, onRegister() is called for setup
/// 4. **Initialization**: initialize() is called for async setup (API connections, etc.)
///
/// ## Configuration:
/// Plugins can be configured in environment.json under the `plugins` key:
/// ```json
/// {
///   "plugins": {
///     "products": {
///       "active": true,
///       "settings": {
///         "cache": {
///           "productsTTL": 300,
///           "categoriesTTL": 600
///         }
///       },
///       "sections": {
///         "main": [...]
///       }
///     }
///   }
/// }
/// ```
///
/// ## Available Registries:
/// - **hookRegistry**: Register lifecycle hooks that other plugins can trigger
/// - **addonRegistry**: Register addons that extend functionality
/// - **widgetRegistry**: Register UI components/sections
/// - **adapterRegistry**: Register backend adapters (WooCommerce, Shopify, etc.)
/// - **actionRegistry**: Register custom actions for user interactions
/// - **eventBus**: Publish/subscribe to events across plugins
///
/// ## Example Implementation:
/// ```dart
/// class ProductsPlugin extends FeaturePlugin {
///   @override
///   String get name => 'products';
///
///   @override
///   String get version => '1.0.0';
///
///   @override
///   void onRegister() {
///     // Register widgets
///     widgetRegistry.register('product.list', (context, {data, onEvent}) {
///       return ProductListWidget(data: data);
///     });
///
///     // Register adapters
///     adapterRegistry.registerProductsAdapter(WooProductsAdapter());
///   }
///
///   @override
///   Future<void> initialize() async {
///     // Async initialization (API setup, cache warming, etc.)
///     await loadInitialData();
///   }
///
///   @override
///   Map<String, WidgetBuilder>? getRoutes() {
///     return {
///       '/products': (context) => ProductsScreen(),
///       '/product': (context) => ProductDetailScreen(),
///     };
///   }
/// }
/// ```
abstract class FeaturePlugin {
  String get name;
  String get version;

  /// Injected by [PluginRegistry.register] before [onRegister] is called.
  /// All registry access goes through this scoped context.
  late MooseAppContext appContext;

  // Convenience getters — delegate to the injected appContext.
  HookRegistry get hookRegistry => appContext.hookRegistry;
  AddonRegistry get addonRegistry => appContext.addonRegistry;
  WidgetRegistry get widgetRegistry => appContext.widgetRegistry;
  AdapterRegistry get adapterRegistry => appContext.adapterRegistry;
  ActionRegistry get actionRegistry => appContext.actionRegistry;
  EventBus get eventBus => appContext.eventBus;

  /// JSON Schema for plugin configuration validation.
  ///
  /// Plugins should override this to define their configuration structure.
  /// This schema follows the JSON Schema specification and is used to validate
  /// plugin settings in environment.json.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// Map<String, dynamic> get configSchema => {
  ///   'type': 'object',
  ///   'properties': {
  ///     'cache': {
  ///       'type': 'object',
  ///       'properties': {
  ///         'productsTTL': {
  ///           'type': 'integer',
  ///           'minimum': 0,
  ///           'description': 'Cache TTL for products in seconds',
  ///         },
  ///       },
  ///     },
  ///   },
  /// };
  /// ```
  Map<String, dynamic> get configSchema => {'type': 'object'};

  /// Returns default settings for this plugin.
  ///
  /// These defaults are used when:
  /// - The plugin is first installed and no configuration exists
  /// - A specific setting key is missing from environment.json
  ///
  /// Plugins should override this to provide sensible defaults for all
  /// configuration options defined in their configSchema.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// Map<String, dynamic> getDefaultSettings() {
  ///   return {
  ///     'cache': {
  ///       'productsTTL': 300,
  ///       'categoriesTTL': 600,
  ///     },
  ///     'display': {
  ///       'itemsPerPage': 20,
  ///       'showOutOfStock': true,
  ///     },
  ///   };
  /// }
  /// ```
  Map<String, dynamic> getDefaultSettings() => {};

  /// Called when plugin is registered
  void onRegister();

  /// Called when plugin needs to be initialized
  Future<void> initialize();

  /// Optional: Plugin can provide routes
  Map<String, WidgetBuilder>? getRoutes();

  /// Optional: Bottom navigation tabs exposed by this plugin.
  ///
  /// Plugin authors can override this getter and return a const list of tabs:
  /// ```dart
  /// @override
  /// List<BottomTab> get bottomTabs => const [
  ///   BottomTab(id: 'products', label: 'Products', route: '/products'),
  /// ];
  /// ```
  /// The [PluginRegistry] automatically registers the underlying hooks so
  /// individual plugins do not have to interact with `bottom_tabs:filter_tabs`.
  List<BottomTab> get bottomTabs => const [];

  T getSetting<T>(String key) {
    return appContext.configManager.get('plugins:$name:settings:$key');
  }
}
