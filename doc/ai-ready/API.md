# moose_core API Reference

Complete API reference for every class an AI agent needs to build plugins, adapters, sections, and repositories in `moose_core`.

---

## Package Modules

`moose_core` is organized into focused barrel files. Import only what you need.

```dart
// Import everything
import 'package:moose_core/moose_core.dart';

// Or import specific modules (preferred)
import 'package:moose_core/app.dart';         // MooseAppContext, MooseScope, MooseBootstrapper
import 'package:moose_core/entities.dart';    // Domain entities
import 'package:moose_core/repositories.dart'; // Repository interfaces
import 'package:moose_core/plugin.dart';      // FeaturePlugin, PluginRegistry
import 'package:moose_core/widgets.dart';     // FeatureSection, WidgetRegistry, AddonRegistry
import 'package:moose_core/adapters.dart';    // BackendAdapter, AdapterRegistry
import 'package:moose_core/cache.dart';       // CacheManager, MemoryCache, PersistentCache
import 'package:moose_core/services.dart';    // HookRegistry, EventBus, ActionRegistry, ConfigManager, AppNavigator, AppLogger, ApiClient, etc.
```

### Module Contents

| Module | Exports |
|--------|---------|
| **app.dart** | `MooseAppContext`, `MooseScope`, `MooseBootstrapper`, `BootstrapReport`, `MooseContextExtension` |
| **entities.dart** | `Product`, `Cart`, `CartItem`, `Order`, `Category`, `ProductTag`, `Collection`, `ProductFilters`, `SearchFilters`, `Post`, `PromoBanner`, `ProductReview`, `ProductReviewStats`, `SearchResult`, `PaginatedResult`, `UserInteraction`, `BottomTab`, `SectionConfig`, `AuthCredentials`, `AuthResult`, `User`, `Address`, `Country`, and more |
| **repositories.dart** | `CoreRepository`, `ProductsRepository`, `CartRepository`, `ReviewRepository`, `SearchRepository`, `PostRepository`, `AuthRepository`, `LocationRepository`, `PushNotificationRepository`, `ShortsRepository`, `StoreRepository`, `BannerRepository` |
| **plugin.dart** | `FeaturePlugin`, `PluginRegistry` |
| **widgets.dart** | `FeatureSection`, `WidgetRegistry`, `AddonRegistry`, `UnknownSectionWidget` |
| **adapters.dart** | `BackendAdapter`, `AdapterRegistry`, `AdapterConfigValidationException`, `RepositoryNotRegisteredException`, `RepositoryTypeMismatchException`, `RepositoryFactoryException` |
| **cache.dart** | `CacheManager`, `MemoryCache`, `PersistentCache`, `CacheStats`, `EvictionPolicy` |
| **services.dart** | `HookRegistry`, `EventBus`, `Event`, `EventSubscription`, `ActionRegistry`, `ConfigManager`, `AppNavigator`, `AppLogger`, `ApiClient`, `ColorHelper`, `TextStyleHelper`, `CurrencyFormatter`, `VariationSelectorService` |

---

## App Context & Bootstrap

### MooseAppContext

The central DI container. Create one per app (or per isolated test). Owns all registries — no singletons.

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
  final CacheManager cache;   // NOTE: field is 'cache', not 'cacheManager'

  // All fields are optional; default instances created if not provided.
  // Inject custom/mock instances for testing.
  MooseAppContext({
    PluginRegistry? pluginRegistry,
    WidgetRegistry? widgetRegistry,
    HookRegistry? hookRegistry,
    AddonRegistry? addonRegistry,
    ActionRegistry? actionRegistry,
    AdapterRegistry? adapterRegistry,
    ConfigManager? configManager,
    EventBus? eventBus,
    AppLogger? logger,
    CacheManager? cache,
  });

  // Convenience shortcut — delegates to adapterRegistry.getRepository<T>()
  T getRepository<T extends CoreRepository>();
}
```

**Usage:**

```dart
// Default — all registries created automatically
final ctx = MooseAppContext();

// Test isolation — inject custom instances
final testCtx = MooseAppContext(
  hookRegistry: MockHookRegistry(),
  configManager: MockConfigManager(),
);

// Access services
ctx.cache.memory.set('key', value);
ctx.eventBus.fire('cart.item.added', data: {'productId': '123'});
final repo = ctx.getRepository<ProductsRepository>();
```

---

### MooseScope

`InheritedWidget` (via `StatefulWidget`) that provides `MooseAppContext` to the widget tree. Wrap your `MaterialApp` with it.

Also manages `MooseLifecycleObserver` — which forwards Flutter app lifecycle changes to plugins automatically.

```dart
class MooseScope extends StatefulWidget {
  const MooseScope({
    super.key,
    required MooseAppContext appContext,
    required Widget child,
  });

  // Get MooseAppContext from any descendant widget
  static MooseAppContext of(BuildContext context);

  // Per-registry static convenience accessors
  static PluginRegistry  pluginRegistryOf(BuildContext ctx);
  static WidgetRegistry  widgetRegistryOf(BuildContext ctx);
  static HookRegistry    hookRegistryOf(BuildContext ctx);
  static AddonRegistry   addonRegistryOf(BuildContext ctx);
  static ActionRegistry  actionRegistryOf(BuildContext ctx);
  static AdapterRegistry adapterRegistryOf(BuildContext ctx);
  static ConfigManager   configManagerOf(BuildContext ctx);
  static EventBus        eventBusOf(BuildContext ctx);
  static CacheManager    cacheOf(BuildContext ctx);
}

// Convenience extension — preferred in widget code
extension MooseContextExtension on BuildContext {
  MooseAppContext get moose => MooseScope.of(this);
}
```

**Usage in widgets:**

```dart
// Extension (preferred)
final registry = context.moose.widgetRegistry;
final repo = context.moose.getRepository<ProductsRepository>();

// Static accessor
final adapter = MooseScope.adapterRegistryOf(context);
```

---

### MooseBootstrapper

Orchestrates the full startup sequence against a `MooseAppContext`.

```dart
class MooseBootstrapper {
  MooseBootstrapper({required MooseAppContext appContext});

  Future<BootstrapReport> run({
    required Map<String, dynamic> config,
    List<BackendAdapter> adapters = const [],
    List<FeaturePlugin Function()> plugins = const [],
  });
}
```

**Bootstrap sequence (7 steps):**

1. `configManager.initialize(config)` — loads the config map
2. `cache.initPersistent()` — initializes `SharedPreferences` layer
3. `AppNavigator.setEventBus(eventBus)` — wires navigation to scoped event bus
4. Register each adapter via `adapterRegistry.registerAdapter()`
5. Register each plugin via `pluginRegistry.register()` (sync; injects `appContext`, calls `onRegister`)
6. `pluginRegistry.initAll()` — calls `onInit()` on all plugins (async)
7. `pluginRegistry.startAll()` — calls `onStart()` on all plugins (async)

**Usage:**

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final ctx = MooseAppContext();

  runApp(
    MooseScope(
      appContext: ctx,
      child: MaterialApp(home: _BootstrapScreen(appContext: ctx)),
    ),
  );
}

class _BootstrapScreenState extends State<_BootstrapScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final config = await loadConfig(); // load from assets/config/environment.json

    final report = await MooseBootstrapper(appContext: widget.appContext).run(
      config: config,
      adapters: [WooCommerceAdapter()],
      plugins: [() => ProductsPlugin(), () => CartPlugin()],
    );

    if (mounted && report.succeeded) {
      Navigator.pushReplacement(context, MaterialPageRoute(
        builder: (_) => const MainScreen(),
      ));
    }
  }

  @override
  Widget build(BuildContext context) =>
      const Scaffold(body: Center(child: CircularProgressIndicator()));
}
```

---

### BootstrapReport

```dart
class BootstrapReport {
  final Duration totalTime;
  final Map<String, Duration> pluginTimings;       // onInit timings per plugin
  final Map<String, Duration> pluginStartTimings;  // onStart timings per plugin
  final Map<String, Object> failures;              // key = 'adapter:<name>' or 'plugin:<name>'

  bool get succeeded => failures.isEmpty;

  @override
  String toString(); // 'BootstrapReport(OK, 3 plugins, 3 plugin starts, 0 failures, took 124ms)'
}
```

---

## Plugin System

### FeaturePlugin

Abstract base for all feature plugins. `appContext` is injected by `PluginRegistry.register()` **before** `onRegister()` is called.

```dart
abstract class FeaturePlugin {
  // Required identity
  String get name;
  String get version;

  // Injected by PluginRegistry.register() — available in onRegister() and beyond
  late MooseAppContext appContext;

  // Convenience getters — all delegate to appContext (NOT singletons)
  HookRegistry    get hookRegistry;
  AddonRegistry   get addonRegistry;
  WidgetRegistry  get widgetRegistry;
  AdapterRegistry get adapterRegistry;
  ActionRegistry  get actionRegistry;
  ConfigManager   get configManager;
  EventBus        get eventBus;
  AppLogger       get logger;
  CacheManager    get cache;

  // Configuration
  Map<String, dynamic> get configSchema => {'type': 'object'}; // override to validate settings
  Map<String, dynamic> getDefaultSettings() => {};             // override to provide defaults

  // Settings access — reads 'plugins:<name>:settings:<key>' from ConfigManager
  T getSetting<T>(String key);

  // Bottom-navigation tabs this plugin provides (PluginRegistry auto-wires the hook)
  List<BottomTab> get bottomTabs => const [];

  // Lifecycle — see order below
  void onRegister();                                          // sync
  Future<void> onInit();                                      // async
  Future<void> onStart() async {}                            // async — all plugins done with onInit
  Future<void> onAppLifecycle(AppLifecycleState state) async {} // async — Flutter lifecycle
  Future<void> onStop() async {}                             // async — teardown (reverse order)

  // Routes
  Map<String, WidgetBuilder>? getRoutes();
}
```

**Lifecycle order:**

| Step | Method | Who calls it | When |
|------|--------|-------------|------|
| 1 | `onRegister()` | `PluginRegistry.register()` | Synchronous; called once per plugin at registration |
| 2 | `onInit()` | `PluginRegistry.initAll()` | Async; use for repository setup, section registration |
| 3 | `onStart()` | `PluginRegistry.startAll()` | After ALL plugins complete `onInit`; safe to depend on other plugins |
| 4 | `onAppLifecycle()` | `MooseLifecycleObserver` | Every Flutter `AppLifecycleState` change |
| 5 | `onStop()` | `PluginRegistry.stopAll()` | Reverse registration order; release resources |

**Example:**

```dart
class ProductsPlugin extends FeaturePlugin {
  @override
  String get name => 'products';

  @override
  String get version => '1.0.0';

  @override
  Map<String, dynamic> getDefaultSettings() => {
    'cache': {'productsTTL': 300, 'categoriesTTL': 600},
    'display': {'itemsPerPage': 20},
  };

  @override
  void onRegister() {
    widgetRegistry.register(
      'products.featured',
      (context, {data, onEvent}) => FeaturedProductsSection(
        settings: data?['settings'] as Map<String, dynamic>?,
      ),
    );
    hookRegistry.register('products:after_load', (products) {
      // Filter / transform
      return products;
    }, priority: 10);
  }

  @override
  Future<void> onInit() async {
    // Register sections, load config, warm up caches
  }

  @override
  Future<void> onStop() async {
    // Cancel subscriptions, flush caches
  }

  @override
  Map<String, WidgetBuilder>? getRoutes() => {
    '/products': (context) => const ProductsScreen(),
    '/product': (context) => const ProductDetailScreen(),
  };
}
```

---

### PluginRegistry

```dart
class PluginRegistry {
  // Register a plugin — injects appContext, calls onRegister()
  // Inactive plugins (active: false in config) are silently skipped
  void register(FeaturePlugin plugin, {required MooseAppContext appContext});

  // Lifecycle batch calls
  Future<void> initAll({Map<String, Duration>? timings});
  Future<void> startAll({Map<String, Duration>? timings});
  Future<void> stopAll({Map<String, Duration>? timings});  // reverse registration order

  // Forwards Flutter app lifecycle to all plugins
  Future<void> notifyAppLifecycle(AppLifecycleState state);

  // Lookup
  T getPlugin<T extends FeaturePlugin>(String name);  // throws if not registered
  bool hasPlugin(String name);
  List<String> getRegisteredPlugins();
  int get pluginCount;

  // Collects routes from all plugins; adds '/home' fallback if none provided
  Map<String, WidgetBuilder> getAllRoutes();

  void clearAll(); // tests only
}
```

---

## Adapter System

### BackendAdapter

Abstract base for all backend adapters. `appContext` is injected by `AdapterRegistry.registerAdapter()` **before** `initializeFromConfig()` is called.

```dart
abstract class BackendAdapter {
  // Required identity
  String get name;    // e.g. 'woocommerce'
  String get version; // e.g. '1.0.0'

  // REQUIRED — compile error if not overridden
  Map<String, dynamic> get configSchema;

  // Override to provide fallback config values
  Map<String, dynamic> getDefaultSettings() => {};

  // Injected by AdapterRegistry — available inside initialize() and beyond
  late MooseAppContext appContext;

  // Convenience getters — all delegate to appContext
  HookRegistry  get hookRegistry;
  ActionRegistry get actionRegistry;
  ConfigManager get configManager;
  EventBus      get eventBus;
  AppLogger     get logger;
  CacheManager  get cache;        // preferred
  CacheManager  get cacheManager; // alias for cache

  // Repository factory registration — call inside initialize()
  void registerRepositoryFactory<T extends CoreRepository>(T Function() factory);
  void registerAsyncRepositoryFactory<T extends CoreRepository>(Future<T> Function() factory);

  // Repository access on the adapter itself (AdapterRegistry delegates here)
  T getRepository<T extends CoreRepository>();                    // sync factory only
  Future<T> getRepositoryAsync<T extends CoreRepository>();       // sync or async factory
  bool hasRepository<T extends CoreRepository>();
  bool isRepositoryCached<T extends CoreRepository>();
  void clearRepositoryCache<T extends CoreRepository>();
  void clearAllRepositoryCaches();
  List<Type> get registeredRepositoryTypes;

  // Config validation — called automatically; can be called manually
  void validateConfig(Map<String, dynamic> config);  // throws AdapterConfigValidationException

  // REQUIRED — implement to parse config and register repository factories
  Future<void> initialize(Map<String, dynamic> config);

  // Called automatically by AdapterRegistry (autoInitialize: true)
  // Reads adapters.<name> from ConfigManager, validates, then calls initialize()
  Future<void> initializeFromConfig({required ConfigManager configManager});
}
```

**Example:**

```dart
class WooCommerceAdapter extends BackendAdapter {
  late ApiClient _client;

  @override
  String get name => 'woocommerce';

  @override
  String get version => '1.0.0';

  @override
  Map<String, dynamic> get configSchema => {
    'type': 'object',
    'required': ['baseUrl', 'consumerKey', 'consumerSecret'],
    'properties': {
      'baseUrl':        {'type': 'string', 'format': 'uri'},
      'consumerKey':    {'type': 'string', 'minLength': 1},
      'consumerSecret': {'type': 'string', 'minLength': 1},
      'timeout':        {'type': 'integer', 'minimum': 0, 'default': 30},
    },
    'additionalProperties': false,
  };

  @override
  Map<String, dynamic> getDefaultSettings() => {'timeout': 30};

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    // config is already validated against configSchema
    _client = ApiClient(baseUrl: config['baseUrl'] as String);

    registerRepositoryFactory<ProductsRepository>(
      () => WooProductsRepository(_client, hookRegistry, cache),
    );
    registerRepositoryFactory<CartRepository>(
      () => WooCartRepository(_client, eventBus),
    );
  }
}
```

**Configuration in `environment.json`:**

```json
{
  "adapters": {
    "woocommerce": {
      "baseUrl": "https://mystore.com",
      "consumerKey": "ck_xxx",
      "consumerSecret": "cs_xxx"
    }
  }
}
```

---

### AdapterRegistry

```dart
class AdapterRegistry {
  // Called automatically by MooseAppContext during construction
  void setDependencies({required MooseAppContext appContext});

  // Register an adapter (sync or async factory)
  // autoInitialize: true (default) — calls initializeFromConfig() automatically
  // autoInitialize: false — adapter must be pre-initialized in the factory
  Future<void> registerAdapter(
    dynamic Function() factory, {
    bool autoInitialize = true,
  });

  // Get a repository — lazy creation on first call, cached thereafter
  // Throws StateError if no adapters registered; RepositoryNotRegisteredException if type not found
  T getRepository<T extends CoreRepository>();

  bool hasRepository<T extends CoreRepository>();
  List<Type> getAvailableRepositories();
  List<String> getInitializedAdapters();
  int get repositoryCount;
  int get adapterCount;
  bool get isInitialized;

  // Get a specific adapter instance by name (advanced use only)
  T getAdapter<T extends BackendAdapter>(String name);

  void clearAll(); // tests only
}
```

**Key design rules:**
- **No active-adapter concept** — each adapter registers repository types; last registration wins.
- **Lazy factories** — no repository instances are created during `registerAdapter()`; repos are created on first `getRepository<T>()` call.
- **Last registration wins** — if two adapters register `ProductsRepository`, the second one is used.

---

### CoreRepository

Base class for all repository implementations.

```dart
abstract class CoreRepository {
  // Called automatically by BackendAdapter after instantiation, before caching.
  // Synchronous only — for async setup, fire-and-forget from here.
  void initialize() {}  // no-op by default; override as needed
}
```

**Critical rules:**
- `CoreRepository` has **no constructor parameters** — no `hookRegistry`, no `eventBus`.
- Concrete repos declare their own dependencies as constructor fields.
- Dependency injection happens in the adapter's `initialize()` method when calling `registerRepositoryFactory`.

```dart
// CORRECT — no-arg base class; deps passed by adapter
class WooProductsRepository extends CoreRepository implements ProductsRepository {
  final ApiClient _client;
  final HookRegistry _hooks;
  final CacheManager _cache;

  WooProductsRepository(this._client, this._hooks, this._cache);

  @override
  void initialize() {
    // Synchronous setup; fire-and-forget async work if needed
  }

  @override
  Future<List<Product>> getProducts(ProductFilters? filters) async {
    return _cache.memory.getOrSet(
      'products:${filters.hashCode}',
      () => _fetchFromApi(filters),
      ttl: const Duration(minutes: 5),
    );
  }
}

// WRONG — CoreRepository does NOT have hookRegistry/eventBus constructor params
class BadRepository extends CoreRepository {
  BadRepository({required super.hookRegistry, required super.eventBus}); // COMPILE ERROR
}
```

---

## Widget System

### FeatureSection

Abstract base for configurable UI sections. All sections use the BLoC pattern.

```dart
abstract class FeatureSection extends StatelessWidget {
  final Map<String, dynamic>? settings;

  const FeatureSection({super.key, this.settings});

  // Access AdapterRegistry from the widget tree — call inside build()
  AdapterRegistry adaptersOf(BuildContext context);

  // Must implement — all supported keys + defaults
  Map<String, dynamic> getDefaultSettings();

  // Type-safe setting access. Merges settings (higher priority) with defaults.
  // Supports automatic num→double and num→int conversions; parses Color from hex.
  // Throws Exception if key missing or type mismatch.
  T getSetting<T>(String key);
}
```

**Settings priority:** constructor `settings` > `getDefaultSettings()`.

**Example:**

```dart
class FeaturedProductsSection extends FeatureSection {
  const FeaturedProductsSection({super.key, super.settings});

  @override
  Map<String, dynamic> getDefaultSettings() => {
    'title': 'Featured Products',
    'itemsPerPage': 10,
    'horizontalPadding': 20.0, // use double for layout values
    'showPrices': true,
  };

  @override
  Widget build(BuildContext context) {
    final repo = adaptersOf(context).getRepository<ProductsRepository>();

    return BlocProvider(
      create: (_) => FeaturedProductsBloc(repo)..add(LoadFeaturedProducts()),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: getSetting<double>('horizontalPadding'),
        ),
        child: Column(
          children: [
            Text(getSetting<String>('title')),
            BlocBuilder<FeaturedProductsBloc, FeaturedProductsState>(
              builder: (context, state) {
                if (state is FeaturedProductsLoaded) return _buildList(state.products);
                return const CircularProgressIndicator();
              },
            ),
          ],
        ),
      ),
    );
  }
}
```

**Configuration in `environment.json`:**

```json
{
  "plugins": {
    "home": {
      "sections": {
        "main": [
          {
            "name": "products.featured",
            "active": true,
            "settings": {
              "title": "Hot Picks",
              "itemsPerPage": 6
            }
          }
        ]
      }
    }
  }
}
```

---

### WidgetRegistry

Manages dynamic section registration and builds.

```dart
typedef SectionBuilderFn = FeatureSection Function(
  BuildContext context, {
  Map<String, dynamic>? data,
  void Function(String event, dynamic payload)? onEvent,
});

class WidgetRegistry {
  void register(String name, SectionBuilderFn builder);
  void unregister(String name);

  // Build a single section by registered name
  // Debug: renders UnknownSectionWidget if not registered
  // Release: renders SizedBox.shrink() if not registered
  Widget build(
    String name,
    BuildContext context, {
    Map<String, dynamic>? data,
    void Function(String event, dynamic payload)? onEvent,
  });

  // Build all active sections in a named group from environment.json
  // Reads 'plugins:<pluginName>:sections:<groupName>' from ConfigManager
  // Passes each section's settings under data['settings']
  List<Widget> buildSectionGroup(
    BuildContext context, {
    required String pluginName,
    required String groupName,
    Map<String, dynamic>? data,
    void Function(String event, dynamic payload)? onEvent,
  });

  // Get section configs for a group
  List<SectionConfig> getSections(String pluginName, String groupName);

  bool isRegistered(String name);
  List<String> getRegisteredWidgets();
}
```

**Usage in a plugin:**

```dart
@override
void onRegister() {
  widgetRegistry.register(
    'products.featured',
    (context, {data, onEvent}) => FeaturedProductsSection(
      settings: data?['settings'] as Map<String, dynamic>?,
    ),
  );
}
```

**Usage in a screen:**

```dart
@override
Widget build(BuildContext context) {
  return Column(
    children: context.moose.widgetRegistry.buildSectionGroup(
      context,
      pluginName: 'home',
      groupName: 'main',
    ),
  );
}
```

---

### AddonRegistry

UI extension points — allows plugins to inject widgets into named zones defined by other plugins.

```dart
typedef WidgetBuilderFn = Widget? Function(
  BuildContext context, {
  Map<String, dynamic>? data,
  void Function(String event, dynamic payload)? onEvent,
});

class AddonRegistry {
  // Register a widget builder for a zone (higher priority renders first)
  void register(String name, WidgetBuilderFn builder, {int priority = 1});
  void removeAddon(String name, WidgetBuilderFn builder);
  void clearAddons(String name);
  void clearAllAddons();

  // Build all registered addons for a zone; null return values are filtered out
  List<Widget> build<T>(
    String name,
    BuildContext context, {
    Map<String, dynamic>? data,
    void Function(String event, dynamic payload)? onEvent,
  });

  bool hasAddon(String name);
  int getAddonCount(String name);
  List<String> getRegisteredAddons();
}
```

**Usage:**

```dart
// Plugin A registers a badge addon for the cart icon zone
addonRegistry.register('cart.icon.badge', (context, {data, onEvent}) {
  return BlocBuilder<CartBloc, CartState>(
    builder: (ctx, state) => state.itemCount > 0
      ? CartBadge(count: state.itemCount)
      : null,
  );
}, priority: 10);

// In a widget that owns the cart icon zone
final badges = context.moose.addonRegistry.build<Widget>('cart.icon.badge', context);
```

---

## Event Systems

### HookRegistry

Synchronous, priority-ordered callback pipeline for **data transformation**. Use when you need to modify or filter data before it is used.

```dart
class HookRegistry {
  // Register a callback — higher priority runs first
  void register(
    String hookName,
    dynamic Function(dynamic) callback,
    {int priority = 1},
  );

  // Execute all registered callbacks in priority order
  // Each callback receives the output of the previous one (pipeline)
  T execute<T>(String hookName, T data);

  void removeHook(String hookName, dynamic Function(dynamic) callback);
  void clearHooks(String hookName);
  void clearAllHooks();

  bool hasHook(String hookName);
  int getHookCount(String hookName);
  List<String> getRegisteredHooks();
}
```

**Usage:**

```dart
// Register — modifies products before they're returned
hookRegistry.register('products:after_load', (data) {
  final products = data as List<Product>;
  return products.where((p) => p.inStock).toList();
}, priority: 10);

// Execute — in the adapter/repository
final filtered = hookRegistry.execute<List<Product>>('products:after_load', rawProducts);
```

---

### EventBus

Async pub/sub system for **fire-and-forget notifications** and side effects. Uses `dart:async` `StreamController.broadcast`. Fully instance-based — no static state.

```dart
class Event {
  final String name;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;
}

class EventSubscription {
  Future<void> cancel();
  void pause([Future<void>? resumeSignal]);
  void resume();
  bool get isActive;
}

class EventBus {
  // Subscribe (sync handler)
  EventSubscription on(
    String eventName,
    void Function(Event event) onEvent, {
    Function? onError,
    void Function()? onDone,
  });

  // Subscribe (async handler — errors are caught and passed to onError)
  EventSubscription onAsync(
    String eventName,
    Future<void> Function(Event event) onEvent, {
    Function? onError,
    void Function()? onDone,
  });

  // Publish (fire-and-forget)
  void fire(String eventName, {Map<String, dynamic>? data, Map<String, dynamic>? metadata});

  // Publish and wait one microtask for handlers to complete
  Future<void> fireAndWait(String eventName, {Map<String, dynamic>? data, Map<String, dynamic>? metadata});

  // Get raw stream for stream operators
  Stream<Event> stream(String eventName);

  Future<void> cancelSubscriptionsForEvent(String eventName);
  Future<void> cancelAllSubscriptions();
  Future<void> destroy();
  Future<void> reset(); // alias for destroy — use in tests

  bool hasSubscribers(String eventName);
  int get activeSubscriptionCount;
  int get registeredEventCount;
  List<String> getRegisteredEvents();
}
```

**Event naming convention:** dot notation — `<domain>.<action>[.<detail>]`

```
cart.item.added       user.profile.updated
payment.completed     notification.received
```

**Usage:**

```dart
// Subscribe in onRegister() or onInit()
final _sub = eventBus.on('cart.item.added', (event) {
  final productId = event.data['productId'] as String;
  cache.memory.remove('cart:total');
});

// Async handler
eventBus.onAsync('order.placed', (event) async {
  await sendConfirmationEmail(event.data['orderId'] as String);
});

// Publish
eventBus.fire('cart.item.added', data: {'productId': 'p-123', 'quantity': 2});

// Cancel in onStop()
await _sub.cancel();
```

---

## Action System

### ActionRegistry

Handles `UserInteraction` dispatch — routes `internal` navigations, `external` URLs, and `custom` actions.

```dart
typedef CustomActionHandler = void Function(
  BuildContext context,
  Map<String, dynamic>? parameters,
);

class ActionRegistry {
  void registerCustomHandler(String actionId, CustomActionHandler handler);
  void registerMultipleHandlers(Map<String, CustomActionHandler> handlers);
  void unregisterCustomHandler(String actionId);

  // Dispatches UserInteraction:
  //   internal → AppNavigator.pushNamed()
  //   external → URL handling (url_launcher in production)
  //   custom   → registered handler lookup
  //   none     → no-op
  void handleInteraction(BuildContext context, UserInteraction? interaction);

  bool hasCustomHandler(String actionId);
  List<String> getRegisteredHandlers();
  void clearCustomHandlers();
}
```

---

### UserInteraction

Represents what should happen when a user taps a UI element.

```dart
enum UserInteractionType { internal, external, custom, none }

class UserInteraction {
  final UserInteractionType interactionType;
  final String? route;
  final String? url;
  final Map<String, dynamic>? parameters;
  final String? customActionId;

  // Factory constructors
  factory UserInteraction.internal({required String route, Map<String, dynamic>? parameters});
  factory UserInteraction.external({required String url, Map<String, dynamic>? parameters});
  factory UserInteraction.custom({required String actionId, Map<String, dynamic>? parameters});
  factory UserInteraction.none();
  factory UserInteraction.fromJson(Map<String, dynamic> json);

  Map<String, dynamic> toJson();
  UserInteraction copyWith({...});
  bool get isValid;
  String get description;
}
```

**Usage:**

```dart
// Register a custom action in a plugin's onRegister()
actionRegistry.registerCustomHandler('share_product', (context, params) {
  final productId = params?['productId'] as String?;
  Share.share('Check out product $productId');
});

// Dispatch from a section
final interaction = UserInteraction.custom(
  actionId: 'share_product',
  parameters: {'productId': product.id},
);
actionRegistry.handleInteraction(context, interaction);
```

---

## Navigation

### AppNavigator

Static navigation service. Fires navigation events through `EventBus` so plugins can intercept. Falls back to standard `Navigator` if no listener handles it.

**Must be initialized before use** — `MooseBootstrapper.run()` calls `AppNavigator.setEventBus(appContext.eventBus)` automatically.

```dart
class AppNavigator {
  // Called automatically by MooseBootstrapper
  static void setEventBus(EventBus eventBus);

  static Future<T?> pushNamed<T>(BuildContext context, String routeName, {Object? arguments});
  static Future<T?> pushReplacementNamed<T, TO>(BuildContext context, String routeName, {TO? result, Object? arguments});
  static Future<T?> push<T>(BuildContext context, Route<T> route);
  static void pop<T>(BuildContext context, [T? result]);
  static bool canPop(BuildContext context);

  // Tab switching — intercepted by BottomTabbedHomePlugin if active
  static Future<void> switchToTab(BuildContext context, String tabId);
  static Future<void> switchToTabIndex(BuildContext context, int index);

  // Advanced: access the wired EventBus
  static EventBus get eventBus;
}
```

**Navigation events fired on the EventBus:**

| Event | Data keys |
|-------|-----------|
| `navigation.push_named` | `routeName`, `arguments`, `context`, `_markHandled`, `onSwitched` |
| `navigation.push_replacement_named` | `routeName`, `arguments`, `result`, `context`, `_markHandled`, `onSwitched` |
| `navigation.push` | `route`, `context`, `_markHandled`, `onSwitched` |
| `navigation.pop` | `result`, `context`, `_markHandled`, `onSwitched` |
| `navigation.switch_to_tab` | `tabId`, `context`, `_markHandled` |
| `navigation.switch_to_tab_index` | `index`, `context`, `_markHandled` |

Call `_markHandled(result)` in your listener to prevent the default `Navigator` fallback.

**Important:** Check `context.mounted` after every `await` in navigation handlers — `AppNavigator` uses `await Future.delayed(Duration.zero)` internally.

---

## Configuration

### ConfigManager

Manages a flat-nested config map loaded from `environment.json`. Supports dot (`.`) and colon (`:`) separators interchangeably.

```dart
class ConfigManager {
  void initialize(Map<String, dynamic> config);

  // Get a value by dotted/colon path; falls back to plugin/adapter defaults then defaultValue
  dynamic get(String path, {dynamic defaultValue});

  Map<String, dynamic> get config; // entire raw config map

  // Check if path exists in the raw config (not defaults)
  bool has(String path);

  // Called automatically by PluginRegistry — no manual call needed
  void registerPluginDefaults(String pluginName, Map<String, dynamic> defaults);

  // Called automatically by AdapterRegistry — no manual call needed
  void registerAdapterDefaults(String adapterName, Map<String, dynamic> defaults);
}
```

**Path resolution order:**

1. Raw config (from `environment.json`)
2. Registered plugin/adapter defaults
3. Provided `defaultValue`

**Path examples:**

```dart
configManager.get('adapters:woocommerce:baseUrl');
configManager.get('plugins:products:settings:cache:productsTTL', defaultValue: 300);
configManager.get('plugins:home:sections:main'); // returns List
```

---

## Logging

### AppLogger

Debug-only logger backed by `dart:developer`. Silent in release builds.

```dart
class AppLogger {
  AppLogger(String name);

  void debug(String message);
  void info(String message);
  void warning(String message);
  void error(String message, [Object? error, StackTrace? stackTrace]);
  void success(String message); // info with ✅ prefix
}
```

Accessible from plugins and adapters via `logger` convenience getter on `FeaturePlugin` and `BackendAdapter`.

---

## Exceptions

| Exception | Thrown When | Import |
|-----------|------------|--------|
| `AdapterConfigValidationException` | Config fails JSON schema validation | `adapters.dart` |
| `RepositoryNotRegisteredException` | `getRepository<T>()` called for unregistered type | `adapters.dart` |
| `RepositoryTypeMismatchException` | Cached repo has unexpected type | `adapters.dart` |
| `RepositoryFactoryException` | Factory has unexpected type | `adapters.dart` |

All implement `Exception`. `toString()` includes the class name and a descriptive message.

---

## Architectural Rules

These rules are enforced by the design. Violating them causes compile errors, runtime exceptions, or broken DI.

1. **No singletons** — every registry is instance-based. Never access via static state.
2. **`CoreRepository` has no constructor params** — inject deps in the adapter factory closure.
3. **`configSchema` is abstract** — omitting it in a `BackendAdapter` subclass is a compile error.
4. **`appContext` is `late`** — don't access it before the registry injects it (before `onRegister` for plugins, before `initialize` for adapters).
5. **`cache` not `cacheManager`** — `MooseAppContext` field is `.cache`; `BackendAdapter` exposes both `.cache` and `.cacheManager` (alias).
6. **PersistentCache.get\<T\>() is synchronous** — requires `initPersistent()` to be called first (done by `MooseBootstrapper`).
7. **`context.mounted` after every `await`** — especially in `AppNavigator` handlers that use `Future.delayed(Duration.zero)`.
8. **`AppNavigator.setEventBus()` before use** — `MooseBootstrapper.run()` does this; in tests call `AppNavigator.setEventBus(EventBus())` in `setUp`.

---

## Related Documentation

- [ARCHITECTURE.md](ARCHITECTURE.md)
- [ADAPTER_SYSTEM.md](ADAPTER_SYSTEM.md)
- [ADAPTER_SCHEMA_VALIDATION.md](ADAPTER_SCHEMA_VALIDATION.md)
- [PLUGIN_SYSTEM.md](PLUGIN_SYSTEM.md)
- [PLUGIN_ADAPTER_CONFIG_GUIDE.md](PLUGIN_ADAPTER_CONFIG_GUIDE.md)
- [CACHE_SYSTEM.md](CACHE_SYSTEM.md)
- [FEATURE_SECTION.md](FEATURE_SECTION.md)
- [REGISTRIES.md](REGISTRIES.md)
