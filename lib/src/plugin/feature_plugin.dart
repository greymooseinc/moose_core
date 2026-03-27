import 'package:flutter/material.dart';
import 'package:moose_core/adapters.dart';
import 'package:moose_core/cache.dart';
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
/// 4. **Initialization**: onInit() is called for async setup (API connections, etc.)
/// 5. **Start**: onStart() is called once all plugins finished initialization
/// 6. **Runtime**: onAppLifecycle() is called for app foreground/background changes
/// 7. **Stop**: onStop() is called during app teardown
///
/// ## Configuration:
/// Plugins are configured in `environment.json` under the top-level `"plugins"`
/// array. Each entry carries an `"id"` matching the plugin's [name], plus
/// optional `"active"`, `"settings"`, and `"sections"` keys.
/// `ConfigManager.initialize()` normalises the array into a keyed map
/// internally, so [getSetting] continues to work without changes.
///
/// ```json
/// {
///   "plugins": [
///     {
///       "id": "products",
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
///   ]
/// }
/// ```
///
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
///     // Register a FeatureSection
///     widgetRegistry.registerSection('product.list', (context, {data, onEvent}) {
///       return ProductListSection(data: data);
///     });
///
///     // Register a plain widget (overlay, button, loader, etc.)
///     widgetRegistry.registerWidget('product.card.badge', (context, {data, onEvent}) {
///       return SaleBadge(productId: data?['productId'] as String?);
///     }, priority: 10);
///
///     // Register adapters
///     adapterRegistry.registerProductsAdapter(WooProductsAdapter());
///   }
///
///   @override
///   Future<void> onInit() async {
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

/// Signature for a plugin-provided page slot builder.
///
/// Called by [MooseBootstrapper] when navigating to a route whose
/// `environment.json` entry carries a `"pageSlotIdentifier"` that matches
/// a key in [FeaturePlugin.pageSlots].
///
/// - [pageConfig] — the full page entry map from `environment.json`
///   (includes `route`, `sections`, `appBar`, `pageSlotIdentifier`, etc.).
/// - [settings] — the top-level `"settings"` map from that entry
///   (empty map when absent). Use this for static filter presets and other
///   per-page configuration that does not belong in `sections`.
/// - [routeArgs] — the value of `ModalRoute.of(context)?.settings.arguments`
///   at route-build time, or `null` if the route was pushed without arguments.
///   Use this for runtime data that cannot be known at config time, such as
///   the `productId` passed when navigating to a detail screen.
typedef PageSlotBuilder = Widget Function(
  BuildContext context,
  Map<String, dynamic> pageConfig,
  Map<String, dynamic> settings,
  Object? routeArgs,
);

abstract class FeaturePlugin {
  String get name;
  String get version;

  /// Injected by [PluginRegistry.register] before [onRegister] is called.
  /// All registry access goes through this scoped context.
  late MooseAppContext appContext;

  // Convenience getters — delegate to the injected appContext.
  HookRegistry get hookRegistry => appContext.hookRegistry;
  WidgetRegistry get widgetRegistry => appContext.widgetRegistry;
  AdapterRegistry get adapterRegistry => appContext.adapterRegistry;
  ActionRegistry get actionRegistry => appContext.actionRegistry;
  ConfigManager get configManager => appContext.configManager;
  EventBus get eventBus => appContext.eventBus;
  AppLogger get logger => appContext.logger;
  CacheManager get cache => appContext.cache;

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

  /// Called when plugin needs to be initialized.
  Future<void> onInit() async {}

  /// Called after all plugins have finished [onInit].
  ///
  /// Use this for work that depends on other plugins already being initialized.
  Future<void> onStart() async {}

  /// Called when the app lifecycle changes.
  Future<void> onAppLifecycle(AppLifecycleState state) async {}

  /// Called during app teardown.
  ///
  /// Use this to release subscriptions/resources owned by the plugin.
  Future<void> onStop() async {}

  /// Optional: Plugin can provide routes.
  ///
  /// Return a map of route paths to [WidgetBuilder]s. Return `null` (the
  /// default) when the plugin contributes no routes. Page-screen routes
  /// defined in `environment.json` under the `pages` key are registered
  /// automatically by [MooseBootstrapper] and do not require a plugin override.
  Map<String, WidgetBuilder>? getRoutes() => null;

  /// Optional: Plugin-provided page slot handlers.
  ///
  /// A page slot is a reusable screen factory that `environment.json` can
  /// instantiate any number of times by declaring a page entry with a
  /// `"pageSlotIdentifier"` field matching one of the keys in this map.
  /// Each instantiation gets its own route path, `sections` array, `appBar`
  /// config, and optional `settings` map — allowing multiple distinct pages
  /// to share the same plugin-provided screen logic without duplicating
  /// Dart routes.
  ///
  /// The identifier is an opaque string; by convention use a path-like format
  /// such as `"plugins/<name>/slots/<slot>"` (e.g.
  /// `"plugins/products/slots/product_list"`), but any unique string works.
  ///
  /// Static filters example (no runtime args needed):
  /// ```dart
  /// @override
  /// Map<String, PageSlotBuilder>? get pageSlots => {
  ///   'plugins/products/slots/product_list': (context, pageConfig, settings, routeArgs) {
  ///     final filters = settings['filters'] != null
  ///         ? ProductFilters.fromJson(Map<String, dynamic>.from(settings['filters'] as Map))
  ///         : null;
  ///     return BlocProvider.value(
  ///       value: _freshListBloc(filters),
  ///       child: ProductsListScreen(filters: filters, pageConfig: pageConfig),
  ///     );
  ///   },
  /// };
  /// ```
  ///
  /// Runtime argument example (e.g. product detail needing a `productId`):
  /// ```dart
  /// @override
  /// Map<String, PageSlotBuilder>? get pageSlots => {
  ///   'plugins/products/slots/product_detail': (context, pageConfig, settings, routeArgs) {
  ///     final productId = _extractProductId(routeArgs); // reads from routeArgs
  ///     return BlocProvider.value(
  ///       value: _detailBlocFor(productId),
  ///       child: ProductDetailScreen(pageConfig: pageConfig),
  ///     );
  ///   },
  /// };
  /// ```
  ///
  /// In `environment.json`:
  /// ```json
  /// {
  ///   "route": "/products/item",
  ///   "pageSlotIdentifier": "plugins/products/slots/product_detail",
  ///   "appBar": { "title": "" },
  ///   "sections": [ { "name": "moose.products.section.detail:image_gallery" } ]
  /// }
  /// ```
  Map<String, PageSlotBuilder>? get pageSlots => null;

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

  /// Returns a plugin setting value cast to [T].
  ///
  /// Looks up `plugins:<name>:settings:<key>` in the [ConfigManager].
  /// If the key is absent (returns `null`) and [defaultValue] is provided,
  /// [defaultValue] is returned. If neither the key nor a default exist, this
  /// throws a [TypeError] at the cast site — prefer always supplying a
  /// [defaultValue] or declaring a setting in [getDefaultSettings].
  T getSetting<T>(String key, {T? defaultValue}) {
    final value = appContext.configManager.get('plugins:$name:settings:$key');
    return (value ?? defaultValue) as T;
  }
}
