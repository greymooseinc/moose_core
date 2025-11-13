# moose_core API Reference

> Complete API reference for the moose_core package

## Package Modules

The moose_core package is organized into focused modules:

```dart
// Import everything
import 'package:moose_core/moose_core.dart';

// Or import specific modules
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
| **entities.dart** | Product, Cart, Order, Category, ProductTag, Collection, Post, ProductReview, SearchResult, PaginatedResult, etc. |
| **repositories.dart** | ProductsRepository, CartRepository, ReviewRepository, SearchRepository, PostRepository, PushNotificationRepository |
| **plugin.dart** | FeaturePlugin, PluginRegistry |
| **widgets.dart** | FeatureSection, WidgetRegistry, AddonRegistry |
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

  /// Called immediately after plugin registration
  /// Use this for registering hooks, actions, and other registries
  void onRegister();

  /// Called during app initialization
  /// Use this for async setup, registering sections, and routes
  Future<void> initialize();

  /// Return routes provided by this plugin
  Map<String, WidgetBuilder>? getRoutes();
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

  /// Convenient getter for accessing the AdapterRegistry instance
  AdapterRegistry get adapters => AdapterRegistry();

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

  /// Initialize the adapter with configuration
  Future<void> initialize(Map<String, dynamic> config);
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
  final HookRegistry hookRegistry = HookRegistry();
  final EventBus eventBus = EventBus();

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
  Future<List<Product>> getProducts(ProductFilters? filters);
  Future<Product> getProductById(String id);
}

class WooProductsRepository extends CoreRepository implements ProductsRepository {
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

## Registry Classes

### PluginRegistry

Manages plugin registration and initialization.

```dart
class PluginRegistry {
  /// Register a plugin using a factory function
  Future<void> registerPlugin(FeaturePlugin Function() factory);

  /// Get a registered plugin by name
  FeaturePlugin? getPlugin(String name);

  /// Check if a plugin is registered
  bool hasPlugin(String name);

  /// Get all registered plugins
  List<FeaturePlugin> getAllPlugins();

  /// Get all routes from all plugins
  Map<String, WidgetBuilder> getAllRoutes();
}
```

**Example:**
```dart
final pluginRegistry = PluginRegistry();
await pluginRegistry.registerPlugin(() => ProductsPlugin());
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

  /// Get a repository asynchronously
  Future<T> getRepositoryAsync<T extends CoreRepository>();

  /// Check if repository is available
  bool hasRepository<T extends CoreRepository>();

  /// Access a specific adapter by name (advanced usage)
  T getAdapter<T extends BackendAdapter>(String name);
}
```

**Example:**
```dart
final adapterRegistry = AdapterRegistry();

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
});

final repo = adapterRegistry.getRepository<ProductsRepository>();
```

> ⚙️ Repository-Level Routing: there is no "active adapter" concept anymore. Each adapter registers the repository interfaces it implements; the most recently registered implementation for a given type is the one returned by `getRepository<T>()`.

### WidgetRegistry

Manages dynamic widget registration and building.

```dart
class WidgetRegistry {
  /// Widget builder function type
  typedef WidgetBuilderFn = Widget Function(
    BuildContext context, {
    Map<String, dynamic>? data,
    Function(String, dynamic)? onEvent,
  });

  /// Register a widget builder
  void register(String name, WidgetBuilderFn builder);

  /// Build a single widget by name
  Widget build(
    String name,
    BuildContext context, {
    Map<String, dynamic>? data,
    Function(String, dynamic)? onEvent,
  });

  /// Build multiple widgets as a group
  List<Widget> buildSectionGroup(
    BuildContext context, {
    required String pluginName,
    required String groupName,
    Map<String, dynamic>? data,
    Function(String, dynamic)? onEvent,
  });

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
  /// In-memory cache
  static MemoryCache memory = MemoryCache();

  /// Persistent cache (requires initialization)
  static PersistentCache? persistent;

  /// Initialize persistent cache
  static Future<void> initPersistentCache() async;
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

### MissingSettingException

Thrown when a required setting is not found.

```dart
class MissingSettingException implements Exception {
  final String message;
  MissingSettingException(this.message);
}
```

### SettingTypeMismatchException

Thrown when a setting has wrong type.

```dart
class SettingTypeMismatchException implements Exception {
  final String message;
  SettingTypeMismatchException(this.message);
}
```

### RepositoryNotRegisteredException

Thrown when requested repository is not registered.

```dart
class RepositoryNotRegisteredException implements Exception {
  final String message;
  RepositoryNotRegisteredException(this.message);
}
```

### AdapterConfigurationException

Thrown when adapter configuration is invalid.

```dart
class AdapterConfigurationException implements Exception {
  final String message;
  AdapterConfigurationException(this.message);
}
```

## Usage Examples

### Complete App Setup

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load configuration
  final config = await loadConfiguration();

  // Initialize cache
  await CacheManager.initPersistentCache();

  // Initialize configuration
  ConfigManager().initialize(config);

  // Setup registries
  final adapterRegistry = AdapterRegistry();
  final pluginRegistry = PluginRegistry();

  // Register adapter
  await adapterRegistry.registerAdapter(() async {
    final adapter = WooCommerceAdapter();
    await adapter.initialize(config['woocommerce']);
    return adapter;
  });

  // Register plugins
  await pluginRegistry.registerPlugin(() => ProductsPlugin());
  await pluginRegistry.registerPlugin(() => CartPlugin());

  runApp(MyApp(
    pluginRegistry: pluginRegistry,
    adapterRegistry: adapterRegistry,
  ));
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

**Last Updated:** 2025-11-10
**Version:** 1.1.0

### Changelog
- **1.1.0 (2025-11-10)** – Updated AdapterRegistry API docs to cover repository-level routing, auto-initialization, and adapter accessors.
