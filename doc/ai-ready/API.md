# moose_core API Reference

> Complete API reference for the moose_core package

## Package Modules

The moose_core package is organized into focused modules:

```dart
// Import everything
import 'package:moose_core/moose_core.dart';

// Or import specific modules
import 'package:moose_core/app.dart';            // MooseAppContext, MooseScope, MooseBootstrapper
import 'package:moose_core/entities.dart';       // Domain entities
import 'package:moose_core/repositories.dart';   // Repository interfaces
import 'package:moose_core/plugin.dart';         // Plugin system
import 'package:moose_core/widgets.dart';        // UI components
import 'package:moose_core/adapters.dart';       // Adapter pattern
import 'package:moose_core/cache.dart';          // Caching system
import 'package:moose_core/services.dart';       // Utilities & helpers
```

### Module Exports

| Module | Exports |
|--------|---------|
| **app.dart** | MooseAppContext, MooseScope, MooseBootstrapper, BootstrapReport, MooseContextExtension |
| **entities.dart** | Product, Cart, Order, Category, ProductTag, Collection, Post, PromoBanner, ProductReview, SearchResult, PaginatedResult, etc. |
| **repositories.dart** | ProductsRepository, CartRepository, ReviewRepository, SearchRepository, PostRepository, BannerRepository, PushNotificationRepository |
| **plugin.dart** | FeaturePlugin, PluginRegistry |
| **widgets.dart** | FeatureSection, WidgetRegistry, AddonRegistry, UnknownSectionWidget |
| **adapters.dart** | BackendAdapter, AdapterRegistry |
| **cache.dart** | CacheManager, MemoryCache, PersistentCache |
| **services.dart** | ActionRegistry, HookRegistry, EventBus, ApiClient, ConfigManager, AppLogger, ColorHelper, TextStyleHelper, VariationSelectorService |

## Core Classes

### FeaturePlugin

Abstract base class for all plugins.

```dart
abstract class FeaturePlugin {
  /// Unique identifier for the plugin
  String get name;

  /// Semantic version of the plugin
  String get version;

  /// JSON Schema for this plugin's configuration (optional; defaults to empty object schema)
  Map<String, dynamic> get configSchema;

  /// Default settings for this plugin.
  /// Registered automatically by PluginRegistry - no manual registration needed.
  Map<String, dynamic> getDefaultSettings();

  /// Access a plugin setting via ConfigManager (falls back to getDefaultSettings()).
  /// Path format: 'plugins:{name}:settings:{key}'
  T getSetting<T>(String key);

  /// Bottom navigation tabs provided by this plugin (empty by default)
  List<BottomTab> get bottomTabs;

  /// Called immediately after plugin registration
  /// Use this for registering hooks, actions, and other registries
  void onRegister();

  /// Called during app initialization
  /// Use this for async setup, registering sections, and routes
  Future<void> initialize();

  /// Return routes provided by this plugin
  Map<String, WidgetBuilder>? getRoutes();

  // Injected by PluginRegistry.register() before onRegister() is called:
  // late MooseAppContext appContext

  // Convenience getters (delegate to appContext — NOT singletons):
  // HookRegistry get hookRegistry => appContext.hookRegistry
  // AddonRegistry get addonRegistry => appContext.addonRegistry
  // WidgetRegistry get widgetRegistry => appContext.widgetRegistry
  // AdapterRegistry get adapterRegistry => appContext.adapterRegistry
  // ActionRegistry get actionRegistry => appContext.actionRegistry
  // EventBus get eventBus => appContext.eventBus
}
```

**Example:**
```dart
class ProductsPlugin extends FeaturePlugin {
  @override
  String get name => 'products';

  @override
  String get version => '1.0.0';

  @override
  void onRegister() {
    // Register hooks and actions
  }

  @override
  Future<void> initialize() async {
    // Register sections and routes
  }

  @override
  Map<String, WidgetBuilder>? getRoutes() {
    return {'/products': (context) => ProductsScreen()};
  }
}
```

### FeatureSection

Abstract base class for all configurable UI sections.

```dart
abstract class FeatureSection extends StatelessWidget {
  final Map<String, dynamic>? settings;

  const FeatureSection({super.key, this.settings});

  /// Access the scoped AdapterRegistry from the widget tree
  AdapterRegistry adaptersOf(BuildContext context) =>
      MooseScope.adapterRegistryOf(context);

  /// Define default settings for this section
  Map<String, dynamic> getDefaultSettings();

  /// Get a setting value with type safety
  T getSetting<T>(String key);
}
```

**Example:**
```dart
class FeaturedProductsSection extends FeatureSection {
  const FeaturedProductsSection({super.key, super.settings});

  @override
  Map<String, dynamic> getDefaultSettings() {
    return {
      'title': 'Featured Products',
      'perPage': 10,
    };
  }

  @override
  Widget build(BuildContext context) {
    final title = getSetting<String>('title');
    final perPage = getSetting<int>('perPage');
    // Build UI
  }
}
```

### BackendAdapter

Abstract base class for backend adapters.

```dart
abstract class BackendAdapter {
  /// Unique identifier for the adapter
  String get name;

  /// Semantic version of the adapter
  String get version;

  /// JSON Schema definition for this adapter's configuration (REQUIRED - must override)
  Map<String, dynamic> get configSchema;

  /// Default settings for this adapter.
  /// Registered automatically by AdapterRegistry - no manual registration needed.
  Map<String, dynamic> getDefaultSettings();

  /// Register a synchronous repository factory
  void registerRepositoryFactory<T extends CoreRepository>(
    T Function() factory,
  );

  /// Register an asynchronous repository factory
  void registerAsyncRepositoryFactory<T extends CoreRepository>(
    Future<T> Function() factory,
  );

  /// Get repository synchronously
  T getRepository<T extends CoreRepository>();

  /// Get repository asynchronously
  Future<T> getRepositoryAsync<T extends CoreRepository>();

  /// Check if repository factory is registered
  bool hasRepository<T extends CoreRepository>();

  /// Validate configuration against configSchema - throws AdapterConfigValidationException on failure
  void validateConfig(Map<String, dynamic> config);

  /// Initialize the adapter with validated configuration
  Future<void> initialize(Map<String, dynamic> config);

  /// Load config from ConfigManager and call initialize() - called automatically by AdapterRegistry
  Future<void> initializeFromConfig();
}
```

**Example:**
```dart
class WooCommerceAdapter extends BackendAdapter {
  @override
  String get name => 'woocommerce';

  @override
  String get version => '1.0.0';

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    registerRepositoryFactory<ProductsRepository>(
      () => WooProductsRepository(_client),
    );
  }
}
```

### CoreRepository

Base class for all repository interfaces.

```dart
abstract class CoreRepository {
  final HookRegistry hookRegistry;
  final EventBus eventBus;

  CoreRepository({required this.hookRegistry, required this.eventBus});

  /// Initialize the repository
  ///
  /// Called automatically after instantiation. Override to perform setup tasks.
  void initialize() {}
}
```

**Features:**
- **Automatic Initialization**: `initialize()` called by adapter after creation
- **HookRegistry Access**: Built-in access to hook system for transformations
- **EventBus Access**: Built-in access to event system for notifications

**Example:**
```dart
abstract class ProductsRepository extends CoreRepository {
  ProductsRepository({required super.hookRegistry, required super.eventBus});
  Future<List<Product>> getProducts(ProductFilters? filters);
  Future<Product> getProductById(String id);
}

class WooProductsRepository extends CoreRepository implements ProductsRepository {
  WooProductsRepository({required super.hookRegistry, required super.eventBus});

  @override
  void initialize() {
    // Called automatically - setup listeners, state, etc.
  }

  @override
  Future<List<Product>> getProducts(ProductFilters? filters) async {
    // Use hookRegistry for transformations
    // Use eventBus for analytics
  }
}
```

### BannerRepository

Handles marketing banners/hero promos that show up across the storefront.

```dart
abstract class BannerRepository extends CoreRepository {
  Future<List<PromoBanner>> fetchBanners({
    String? placement,
    String? locale,
    Map<String, dynamic>? filters,
  });

  Future<void> trackBannerView(
    String bannerId, {
    Map<String, dynamic>? metadata,
  });

  Future<void> trackBannerClick(
    String bannerId, {
    Map<String, dynamic>? metadata,
  });
}

class RestBannerRepository extends BannerRepository {
  RestBannerRepository(this._client);

  final Dio _client;

  @override
  Future<List<PromoBanner>> fetchBanners({
    String? placement,
    String? locale,
    Map<String, dynamic>? filters,
  }) async {
    final response = await _client.get<Map<String, dynamic>>(
      '/banners',
      queryParameters: {
        if (placement != null) 'placement': placement,
        if (locale != null) 'locale': locale,
        if (filters != null) ...filters,
      },
    );

    return (response.data?['items'] as List<dynamic>? ?? [])
        .whereType<Map<String, dynamic>>()
        .map(PromoBanner.fromJson)
        .toList();
  }

  @override
  Future<void> trackBannerView(String bannerId, {Map<String, dynamic>? metadata}) {
    return _client.post('/banner-events', data: {
      'bannerId': bannerId,
      'event': 'view',
      if (metadata != null) 'metadata': metadata,
    });
  }

  @override
  Future<void> trackBannerClick(String bannerId, {Map<String, dynamic>? metadata}) {
    return _client.post('/banner-events', data: {
      'bannerId': bannerId,
      'event': 'click',
      if (metadata != null) 'metadata': metadata,
    });
  }
}
```

## App Context Classes

### MooseAppContext

Central container that owns all registries. Create one per app.

```dart
class MooseAppContext {
  final PluginRegistry pluginRegistry;
  final WidgetRegistry widgetRegistry;
  final HookRegistry hookRegistry;
  final AddonRegistry addonRegistry;
  final ActionRegistry actionRegistry;
  final AdapterRegistry adapterRegistry;
  final ConfigManager configManager;
  final EventBus eventBus;
  final AppLogger logger;

  /// All fields are final; pass custom instances to override (useful for testing).
  MooseAppContext({
    PluginRegistry? pluginRegistry,
    WidgetRegistry? widgetRegistry,
    // ...
  });
}
```

**Example:**
```dart
final ctx = MooseAppContext();
// Use a mock registry in tests:
final testCtx = MooseAppContext(hookRegistry: MockHookRegistry());
```

### MooseScope

`InheritedWidget` that provides `MooseAppContext` to the widget tree.

```dart
class MooseScope extends InheritedWidget {
  final MooseAppContext appContext;

  const MooseScope({required this.appContext, required super.child, super.key});

  /// Get MooseAppContext from any descendant widget.
  static MooseAppContext of(BuildContext context);

  // Static convenience accessors:
  static PluginRegistry pluginRegistryOf(BuildContext ctx);
  static WidgetRegistry widgetRegistryOf(BuildContext ctx);
  static HookRegistry hookRegistryOf(BuildContext ctx);
  static AddonRegistry addonRegistryOf(BuildContext ctx);
  static ActionRegistry actionRegistryOf(BuildContext ctx);
  static AdapterRegistry adapterRegistryOf(BuildContext ctx);
  static ConfigManager configManagerOf(BuildContext ctx);
  static EventBus eventBusOf(BuildContext ctx);
}

// Extension for ergonomic access:
extension MooseContextExtension on BuildContext {
  MooseAppContext get moose => MooseScope.of(this);
}
```

**Example:**
```dart
// In any widget descendant of MooseScope:
final registry = context.moose.widgetRegistry;
// or:
final registry = MooseScope.widgetRegistryOf(context);
```

### MooseBootstrapper

Orchestrates config, adapter, and plugin initialization.

```dart
class MooseBootstrapper {
  final MooseAppContext appContext;
  MooseBootstrapper({required this.appContext});

  Future<BootstrapReport> run({
    required Map<String, dynamic> config,
    List<BackendAdapter> adapters = const [],
    List<FeaturePlugin Function()> plugins = const [],
  });
}

class BootstrapReport {
  final Duration totalTime;
  final Map<String, Duration> pluginTimings;
  final Map<String, Object> failures;
  bool get succeeded; // true if failures is empty
}
```

**Bootstrap order:**
1. `appContext.configManager.initialize(config)`
2. `AppNavigator.setEventBus(appContext.eventBus)`
3. Register each adapter via `appContext.adapterRegistry.registerAdapter()`
4. Register each plugin via `appContext.pluginRegistry.register(plugin, appContext:)`
5. `appContext.pluginRegistry.initializeAll()`

## Registry Classes

### PluginRegistry

Manages plugin registration and initialization.

```dart
class PluginRegistry {
  /// Register a plugin synchronously: inject appContext, call onRegister()
  void register(FeaturePlugin plugin, {required MooseAppContext appContext});

  /// Initialize all registered plugins asynchronously (calls initialize() on each)
  Future<void> initializeAll({Map<String, Duration>? timings});

  /// Get a registered plugin by name
  FeaturePlugin? getPlugin(String name);

  /// Check if a plugin is registered
  bool hasPlugin(String name);

  /// Get all registered plugins
  List<FeaturePlugin> getRegisteredPlugins();

  /// Get all routes from all plugins
  Map<String, WidgetBuilder> getAllRoutes();

  /// Plugin count
  int get pluginCount;

  /// Clear all plugins (for testing)
  void clearAll();
}
```

**Example — use `MooseBootstrapper` (preferred):**
```dart
final report = await MooseBootstrapper(appContext: ctx).run(
  config: myConfig,
  plugins: [() => ProductsPlugin(), () => CartPlugin()],
);
```

**Example — direct use (for testing):**
```dart
final ctx = MooseAppContext();
ctx.pluginRegistry.register(ProductsPlugin(), appContext: ctx);
await ctx.pluginRegistry.initializeAll();
```

### AdapterRegistry

Manages backend adapter registration.

```dart
class AdapterRegistry {
  /// Register an adapter using a factory (sync or async)
  Future<void> registerAdapter(
    dynamic Function() factory, {
    bool autoInitialize = true,
  });

  /// Get the repository implementation currently registered for type T
  T getRepository<T extends CoreRepository>();

  /// Check if repository is available
  bool hasRepository<T extends CoreRepository>();

  /// List all available repository types
  List<Type> getAvailableRepositories();

  /// List all initialized adapter names
  List<String> getInitializedAdapters();

  /// Access a specific adapter by name (advanced usage)
  T getAdapter<T extends BackendAdapter>(String name);

  /// Whether any adapters have been registered
  bool get isInitialized;

  /// Clear all adapters and repositories (for testing)
  void clearAll();
}
```

**Example:**
```dart
final appContext = MooseAppContext();
appContext.configManager.initialize({
  'adapters': {
    'shopify': {'storeUrl': 'https://mystore.com', 'token': 'shpat_xxx'},
  },
});
final adapterRegistry = appContext.adapterRegistry;

// Simplest path: let the registry load + validate config via initializeFromConfig()
await adapterRegistry.registerAdapter(
  () => ShopifyAdapter(),
  autoInitialize: true,
);

// Manual configuration still works
await adapterRegistry.registerAdapter(() async {
  final adapter = WooCommerceAdapter();
  await adapter.initialize({
    'baseUrl': 'https://mystore.com',
    'consumerKey': 'ck_xxx',
    'consumerSecret': 'cs_xxx',
  });
  return adapter;
}, autoInitialize: false);

final repo = adapterRegistry.getRepository<ProductsRepository>();
```

> ⚙️ Repository-Level Routing: there is no "active adapter" concept anymore. Each adapter registers the repository interfaces it implements; the most recently registered implementation for a given type is the one returned by `getRepository<T>()`.

### WidgetRegistry

Manages dynamic widget registration and building.

```dart
/// Section builder function type - returns a FeatureSection (not a plain Widget)
typedef SectionBuilderFn = FeatureSection Function(
  BuildContext context, {
  Map<String, dynamic>? data,
  void Function(String event, dynamic payload)? onEvent,
});

class WidgetRegistry {
  /// Register a section builder
  void register(String name, SectionBuilderFn builder);

  /// Build a single widget by name
  Widget build(
    String name,
    BuildContext context, {
    Map<String, dynamic>? data,
    void Function(String event, dynamic payload)? onEvent,
  });

  /// Build multiple widgets from a plugin's section group config (reads from environment.json)
  List<Widget> buildSectionGroup(
    BuildContext context, {
    required String pluginName,
    required String groupName,
    Map<String, dynamic>? data,
    void Function(String event, dynamic payload)? onEvent,
  });

  /// Get section configs for a plugin's group
  List<SectionConfig> getSections(String pluginName, String groupName);

  /// Check if widget is registered
  bool isRegistered(String name);

  /// Get all registered widget names
  List<String> getRegisteredWidgets();
}
```

**Example:**
```dart
final widgetRegistry = WidgetRegistry();

// Register
widgetRegistry.register(
  'products.featured',
  (context, {data, onEvent}) => FeaturedProductsSection(
    settings: data?['settings'] as Map<String, dynamic>?,
  ),
);

// Build
final widget = widgetRegistry.build('products.featured', context);
```

### HookRegistry

Manages hook registration and execution.

```dart
class HookRegistry {
  /// Register a hook callback
  void register(
    String hookName,
    dynamic Function(dynamic) callback, {
    int priority = 1,
  });

  /// Execute all registered hooks for a hook point
  T execute<T>(String hookName, T data);

  /// Remove a specific hook callback
  void removeHook(String hookName, dynamic Function(dynamic) callback);

  /// Clear all hooks for a hook point
  void clearHooks(String hookName);

  /// Check if a hook has any registered callbacks
  bool hasHook(String hookName);

  /// Get count of registered callbacks for a hook
  int getHookCount(String hookName);
}
```

**Example:**
```dart
final hookRegistry = HookRegistry();

// Register
hookRegistry.register('products:after_load', (products) {
  // Modify products
  return products;
}, priority: 10);

// Execute
final products = hookRegistry.execute('products:after_load', products);
```

### ActionRegistry

Manages user interaction handlers.

```dart
class ActionRegistry {
  /// Custom action handler function type
  typedef CustomActionHandler = void Function(
    BuildContext context,
    Map<String, dynamic>? parameters,
  );

  /// Register a custom action handler
  void registerCustomHandler(String actionId, CustomActionHandler handler);

  /// Handle a user interaction
  void handleInteraction(BuildContext context, UserInteraction? interaction);

  /// Check if custom handler is registered
  bool hasCustomHandler(String actionId);

  /// Get all registered custom action IDs
  List<String> getRegisteredActions();
}
```

**Example:**
```dart
final actionRegistry = ActionRegistry();

// Register
actionRegistry.registerCustomHandler('share', (context, params) {
  final content = params?['content'] as String?;
  Share.share(content ?? '');
});

// Use
final interaction = UserInteraction.custom(
  actionId: 'share',
  parameters: {'content': 'Check this out!'},
);
actionRegistry.handleInteraction(context, interaction);
```

## Cache Classes

### CacheManager

Central manager for all caching operations.

```dart
class CacheManager {
  /// Get the shared MemoryCache instance
  static MemoryCache memoryCacheInstance();

  /// Get the shared PersistentCache instance (must call initPersistentCache() first)
  static PersistentCache persistentCacheInstance();

  /// Initialize persistent cache - call in main() before use
  static Future<void> initPersistentCache() async;

  /// Clear both memory and persistent caches
  static Future<void> clearAll() async;

  /// Clear only memory cache
  static void clearMemoryCache();

  /// Clear only persistent cache
  static Future<bool> clearPersistentCache() async;
}
```

### MemoryCache

In-memory cache with TTL support.

```dart
class MemoryCache {
  /// Store value with optional TTL
  void set<T>(String key, T value, {Duration? ttl});

  /// Get value (returns null if expired or not found)
  T? get<T>(String key);

  /// Check if key exists and not expired
  bool has(String key);

  /// Remove specific key
  void remove(String key);

  /// Clear all cache
  void clear();
}
```

### PersistentCache

Disk-based cache using shared_preferences.

```dart
class PersistentCache {
  /// Initialize cache (must be called before use)
  Future<void> init() async;

  /// Store value
  Future<void> set<T>(String key, T value) async;

  /// Get value
  T? get<T>(String key);

  /// Check if key exists
  bool has(String key);

  /// Remove specific key
  Future<void> remove(String key) async;

  /// Clear all cache
  Future<void> clear() async;
}
```

## Configuration Classes

### ConfigManager

Manages application configuration.

```dart
class ConfigManager {
  /// Initialize with configuration map
  void initialize(Map<String, dynamic> config);

  /// Get configuration value by path (e.g., 'plugins:products:perPage')
  dynamic get(String path, {dynamic defaultValue});

  /// Get entire configuration
  Map<String, dynamic> getAll();

  /// Check if configuration path exists
  bool has(String path);
}
```

**Example:**
```dart
final configManager = ConfigManager();
configManager.initialize(config);

final perPage = configManager.get('plugins:products:perPage', defaultValue: 10);
```

## Entity Classes

### UserInteraction

Defines user interaction data.

```dart
enum UserInteractionType {
  internalNavigation,
  externalUrl,
  customAction,
  none,
}

class UserInteraction {
  final UserInteractionType interactionType;
  final String? route;
  final String? url;
  final Map<String, dynamic>? parameters;
  final String? customActionId;

  /// Factory constructors
  factory UserInteraction.navigate({
    required String route,
    Map<String, dynamic>? parameters,
  });

  factory UserInteraction.openUrl({required String url});

  factory UserInteraction.custom({
    required String actionId,
    Map<String, dynamic>? parameters,
  });

  factory UserInteraction.none();
}
```

## Exceptions

### RepositoryNotRegisteredException

Thrown when requested repository is not registered with any adapter.

```dart
class RepositoryNotRegisteredException implements Exception {
  final String message;
  RepositoryNotRegisteredException(this.message);
}
```

### AdapterConfigValidationException

Thrown when adapter configuration fails JSON schema validation.

```dart
class AdapterConfigValidationException implements Exception {
  final String message;
  AdapterConfigValidationException(this.message);
}
```

### RepositoryTypeMismatchException

Thrown when the repository factory returns an incompatible type.

```dart
class RepositoryTypeMismatchException implements Exception {
  final String message;
  RepositoryTypeMismatchException(this.message);
}
```

> **Note:** `FeatureSection.getSetting<T>()` throws a generic `Exception` (not a typed exception class) when a setting key is missing or the value type is incompatible.

## Usage Examples

### Complete App Setup

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final ctx = MooseAppContext(); // owns all registries

  runApp(
    MooseScope(
      appContext: ctx,            // provides ctx to the widget tree
      child: MaterialApp(
        home: _BootstrapScreen(appContext: ctx),
      ),
    ),
  );
}

class _BootstrapScreen extends StatefulWidget {
  final MooseAppContext appContext;
  const _BootstrapScreen({required this.appContext});
  @override State<_BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends State<_BootstrapScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final config = await loadConfiguration();

    final report = await MooseBootstrapper(appContext: widget.appContext).run(
      config: config,
      adapters: [WooCommerceAdapter()],
      plugins: [() => ProductsPlugin(), () => CartPlugin()],
    );

    if (mounted && report.succeeded) {
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => MooseScope(
          appContext: widget.appContext,
          child: const MainScreen(),
        ),
      ));
    }
  }

  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(child: CircularProgressIndicator()),
  );
}
```

## Related Documentation

- **[ARCHITECTURE.md](./ARCHITECTURE.md)** - Overall architecture
- **[PLUGIN_SYSTEM.md](./PLUGIN_SYSTEM.md)** - Plugin development
- **[FEATURE_SECTION.md](./FEATURE_SECTION.md)** - Section patterns
- **[ADAPTER_PATTERN.md](./ADAPTER_PATTERN.md)** - Adapter implementation
- **[REGISTRIES.md](./REGISTRIES.md)** - Registry systems
- **[CACHE_SYSTEM.md](./CACHE_SYSTEM.md)** - Caching system

---

**Last Updated:** 2026-02-22
**Version:** 2.0.0

### Changelog
- **2.0.0 (2026-02-22)** - Added `app.dart` module; added `MooseAppContext`, `MooseScope`, `MooseBootstrapper` API docs. Fixed `FeaturePlugin` registry getter comment (not singletons). Fixed `FeatureSection.adapters` → `adaptersOf(context)`. Fixed `CoreRepository` to show constructor params. Fixed `PluginRegistry` API (`register`/`initializeAll` split). Fixed "Complete App Setup" example to use `MooseBootstrapper`. Added `UnknownSectionWidget` to widgets module.
- **1.2.0 (2025-11-12)** - Added `BannerRepository` + `PromoBanner` coverage and refreshed module exports and repository samples.
- **1.1.0 (2025-11-10)** - Updated AdapterRegistry API docs to cover repository-level routing, auto-initialization, and adapter accessors.
