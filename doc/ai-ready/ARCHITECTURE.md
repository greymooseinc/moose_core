# Architecture

Complete architectural reference for AI agents building plugins, adapters, and sections with `moose_core`.

---

## System Overview

`moose_core` is a **plugin-based, backend-agnostic Flutter framework** for building modular e-commerce apps. Its core design principle is **strict layering**: each layer has a single responsibility and communicates only with the layer directly below it.

```
┌───────────────────────────────────────────────────────────────┐
│                     Presentation Layer                        │
│           Screens · FeatureSections · Widgets                 │
│           UI rendering only — no business logic               │
└────────────────────────┬──────────────────────────────────────┘
                         │  Events / States
┌────────────────────────▼──────────────────────────────────────┐
│                  Business Logic Layer (BLoC)                  │
│                  State management · Orchestration             │
│                  No API calls · No direct repo access         │
└────────────────────────┬──────────────────────────────────────┘
                         │  Repository calls
┌────────────────────────▼──────────────────────────────────────┐
│                     Repository Layer                          │
│              Abstract interfaces (CoreRepository)             │
│              Domain-entity return types only                  │
└────────────────────────┬──────────────────────────────────────┘
                         │  Implementation
┌────────────────────────▼──────────────────────────────────────┐
│                      Adapter Layer                            │
│         BackendAdapter · concrete repository impls            │
│         DTO ↔ Entity conversion · API clients                 │
└───────────────────────────────────────────────────────────────┘
```

Cross-cutting services (caching, events, hooks, navigation, config) are owned by `MooseAppContext` and accessed through it — never via singletons.

---

## Dependency Injection: MooseAppContext

`MooseAppContext` is the single DI container for a running app. It creates and owns every registry and service. There are **no global singletons** in `moose_core` — every component receives what it needs through `appContext`.

```dart
class MooseAppContext {
  final PluginRegistry  pluginRegistry;
  final WidgetRegistry  widgetRegistry;
  final HookRegistry    hookRegistry;
  final AddonRegistry   addonRegistry;
  final ActionRegistry  actionRegistry;
  final AdapterRegistry adapterRegistry;
  final ConfigManager   configManager;
  final EventBus        eventBus;
  final AppLogger       logger;
  final CacheManager    cache;          // field is 'cache', not 'cacheManager'

  // Shortcut: delegates to adapterRegistry.getRepository<T>()
  T getRepository<T extends CoreRepository>();
}
```

Create one `MooseAppContext` per app. In tests, create a new one per test — isolation is free.

```dart
// App
final ctx = MooseAppContext();

// Test — inject mocks for any component
final testCtx = MooseAppContext(hookRegistry: MockHookRegistry());
```

### MooseScope: DI to the Widget Tree

`MooseScope` is a `StatefulWidget` that wraps an `InheritedWidget` to provide `MooseAppContext` to every descendant widget. Wrap your `MaterialApp` with it.

```dart
runApp(
  MooseScope(
    appContext: ctx,
    child: MaterialApp(home: _BootstrapScreen(appContext: ctx)),
  ),
);

// In any descendant widget:
context.moose                                     // MooseAppContext (extension getter)
context.moose.widgetRegistry
context.moose.getRepository<ProductsRepository>()
MooseScope.adapterRegistryOf(context)             // static accessor
```

`MooseScope` also attaches `MooseLifecycleObserver`, which automatically forwards Flutter `AppLifecycleState` changes to all registered plugins via `pluginRegistry.notifyAppLifecycle()`.

---

## Bootstrap Sequence

`MooseBootstrapper.run()` orchestrates startup in exactly this order:

```
Step 1  configManager.initialize(config)
        ↓ loads environment.json / config map

Step 2  cache.initPersistent()
        ↓ initializes SharedPreferences layer

Step 3  AppNavigator.setEventBus(eventBus)
        ↓ wires navigation to scoped event bus

Step 4  adapterRegistry.registerAdapter() × N
        ↓ injects appContext → calls initializeFromConfig()
        ↓ → validates config → calls initialize() → registers lazy repo factories
        ↓ → registers adapter defaults in ConfigManager

Step 5  pluginRegistry.register(plugin, appContext:) × N   [sync]
        ↓ injects appContext into plugin, calls onRegister()
        ↓ → registers plugin defaults in ConfigManager

Step 6  pluginRegistry.initAll()   [async]
        ↓ calls onInit() on each registered plugin

Step 7  pluginRegistry.startAll()   [async]
        ↓ calls onStart() on each registered plugin
```

```dart
final report = await MooseBootstrapper(appContext: ctx).run(
  config: await loadConfig(),
  adapters: [WooCommerceAdapter()],
  plugins: [() => ProductsPlugin(), () => CartPlugin()],
);

if (!report.succeeded) {
  // report.failures keys: 'adapter:<name>' or 'plugin:<name>'
}
```

**`BootstrapReport` fields:**

| Field | Type | Description |
|-------|------|-------------|
| `totalTime` | `Duration` | Wall-clock time for entire sequence |
| `pluginTimings` | `Map<String, Duration>` | Per-plugin `onInit` elapsed time |
| `pluginStartTimings` | `Map<String, Duration>` | Per-plugin `onStart` elapsed time |
| `failures` | `Map<String, Object>` | Exceptions by key; empty = success |
| `succeeded` | `bool` | `failures.isEmpty` |

---

## Plugin System

### Full Plugin Lifecycle

| Step | Method | Caller | Sync/Async | Purpose |
|------|--------|--------|-----------|---------|
| 1 | `onRegister()` | `PluginRegistry.register()` | **sync** | Register hooks, widgets, addon slots, custom actions |
| 2 | `onInit()` | `PluginRegistry.initAll()` | **async** | Async setup — connect services, warm caches, register sections |
| 3 | `onStart()` | `PluginRegistry.startAll()` | **async** | Post-init work; all other plugins have completed `onInit` |
| 4 | `onAppLifecycle()` | `MooseLifecycleObserver` | **async** | React to Flutter foreground/background/detached states |
| 5 | `onStop()` | `PluginRegistry.stopAll()` | **async** | Teardown; called in **reverse** registration order |

`appContext` is injected by `PluginRegistry.register()` **before** `onRegister()` fires. Use the convenience getters — they delegate to `appContext` and are available from `onRegister()` onwards.

### FeaturePlugin Contract

```dart
abstract class FeaturePlugin {
  String get name;     // unique, kebab-case: 'products', 'shopping-cart'
  String get version;  // semantic: '1.0.0'

  // Injected before onRegister()
  late MooseAppContext appContext;

  // Convenience getters (delegate to appContext — NOT singletons)
  HookRegistry    get hookRegistry;
  AddonRegistry   get addonRegistry;
  WidgetRegistry  get widgetRegistry;
  AdapterRegistry get adapterRegistry;
  ActionRegistry  get actionRegistry;
  ConfigManager   get configManager;
  EventBus        get eventBus;
  AppLogger       get logger;
  CacheManager    get cache;

  Map<String, dynamic> get configSchema => {'type': 'object'};
  Map<String, dynamic> getDefaultSettings() => {};
  T getSetting<T>(String key); // reads 'plugins:<name>:settings:<key>'

  List<BottomTab> get bottomTabs => const []; // PluginRegistry auto-wires hook

  void onRegister();                                           // sync — required
  Future<void> onInit();                                       // async — required
  Future<void> onStart() async {}                             // async — optional
  Future<void> onAppLifecycle(AppLifecycleState state) async {} // async — optional
  Future<void> onStop() async {}                              // async — optional

  Map<String, WidgetBuilder>? getRoutes();
}
```

### Example Plugin

```dart
class ProductsPlugin extends FeaturePlugin {
  late EventSubscription _cartSub;

  @override
  String get name => 'products';

  @override
  String get version => '1.0.0';

  @override
  Map<String, dynamic> getDefaultSettings() => {
    'cache': {'productsTTL': 300, 'categoriesTTL': 600},
    'display': {'itemsPerPage': 20, 'showOutOfStock': false},
  };

  @override
  void onRegister() {
    // Register section builder
    widgetRegistry.register(
      'products.featured',
      (context, {data, onEvent}) => FeaturedProductsSection(
        settings: data?['settings'] as Map<String, dynamic>?,
      ),
    );

    // Hook: transform products after load
    hookRegistry.register('products:after_load', (data) {
      final products = data as List<Product>;
      return products.where((p) => p.inStock).toList();
    }, priority: 10);

    // Custom action
    actionRegistry.registerCustomHandler('share_product', (context, params) {
      Share.share('Check out: ${params?['url']}');
    });
  }

  @override
  Future<void> onInit() async {
    // Subscribe to cross-plugin events (no direct import of other plugin)
    _cartSub = eventBus.on('cart.item.added', (event) {
      cache.memory.remove('products:featured'); // invalidate cache on cart change
    });
  }

  @override
  Future<void> onStop() async {
    await _cartSub.cancel();
  }

  @override
  Map<String, WidgetBuilder>? getRoutes() => {
    '/products': (_) => const ProductsScreen(),
    '/product':  (_) => const ProductDetailScreen(),
  };
}
```

### Plugin Configuration (environment.json)

```json
{
  "plugins": {
    "products": {
      "active": true,
      "settings": {
        "cache": { "productsTTL": 600 },
        "display": { "itemsPerPage": 12 }
      },
      "sections": {
        "home": [
          {
            "name": "products.featured",
            "active": true,
            "settings": { "title": "Hot Picks", "itemsPerPage": 6 }
          }
        ]
      }
    }
  }
}
```

Inactive plugins (`"active": false`) are silently skipped during `register()`.

---

## Adapter System

### Full Adapter Lifecycle

```
AdapterRegistry.registerAdapter(() => MyAdapter())
  │
  ├── creates adapter instance from factory
  ├── injects appContext  (adapter.appContext = appContext)
  ├── calls adapter.initializeFromConfig(configManager:)
  │     ├── reads adapters.<name> from ConfigManager
  │     ├── calls validateConfig(config)    ← throws AdapterConfigValidationException on fail
  │     └── calls initialize(config)        ← adapter registers repo factories here
  ├── calls adapter.getDefaultSettings()
  ├── registers defaults in ConfigManager
  └── registers lazy repo factories in AdapterRegistry._factories
        └── NO repository instances created yet
```

Repositories are created **lazily** on the first `getRepository<T>()` call and cached afterwards. The factory is called exactly once per repository type.

### BackendAdapter Contract

```dart
abstract class BackendAdapter {
  String get name;    // unique: 'woocommerce', 'shopify'
  String get version;

  // REQUIRED — abstract — omitting causes compile error
  Map<String, dynamic> get configSchema;

  // Optional defaults; registered in ConfigManager AFTER initialize()
  Map<String, dynamic> getDefaultSettings() => {};

  // Injected by AdapterRegistry before initializeFromConfig()
  late MooseAppContext appContext;

  // Convenience getters (delegate to appContext — NOT singletons)
  HookRegistry   get hookRegistry;
  ActionRegistry get actionRegistry;
  ConfigManager  get configManager;
  EventBus       get eventBus;
  AppLogger      get logger;
  CacheManager   get cache;        // preferred
  CacheManager   get cacheManager; // alias for cache

  // Register repo factories inside initialize()
  void registerRepositoryFactory<T extends CoreRepository>(T Function() factory);
  void registerAsyncRepositoryFactory<T extends CoreRepository>(Future<T> Function() factory);

  // Validation — called automatically before initialize(); can be called manually
  void validateConfig(Map<String, dynamic> config); // throws AdapterConfigValidationException

  // REQUIRED — parse config, set up API client, register repo factories
  Future<void> initialize(Map<String, dynamic> config);

  // Called automatically by AdapterRegistry (autoInitialize: true)
  Future<void> initializeFromConfig({required ConfigManager configManager});
}
```

### configSchema — Required

`configSchema` is **abstract** — every concrete `BackendAdapter` must override it. A missing override is a **compile error**. Schema validation uses `json_schema: >=5.2.2 <6.0.0`.

```dart
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
```

### Example Adapter

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
      'timeout':        {'type': 'integer', 'minimum': 0},
    },
    'additionalProperties': false,
  };

  @override
  Map<String, dynamic> getDefaultSettings() => {'timeout': 30};

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    // config is already validated against configSchema — safe to read directly
    _client = ApiClient(baseUrl: config['baseUrl'] as String);

    // Pass appContext-scoped services to repo constructors
    registerRepositoryFactory<ProductsRepository>(
      () => WooProductsRepository(_client, hookRegistry, cache),
    );
    registerRepositoryFactory<CartRepository>(
      () => WooCartRepository(_client, eventBus),
    );
    registerAsyncRepositoryFactory<ReviewRepository>(() async {
      final cfg = await _fetchReviewConfig();
      return WooReviewRepository(_client, cfg);
    });
  }
}
```

**Adapter configuration in `environment.json`:**

```json
{
  "adapters": {
    "woocommerce": {
      "baseUrl": "https://mystore.com/wp-json/wc/v3",
      "consumerKey": "ck_xxx",
      "consumerSecret": "cs_xxx"
    }
  }
}
```

### AdapterRegistry Key Rules

- **No active-adapter concept** — each adapter registers repository types by calling `registerRepositoryFactory<T>()`. The registry stores a lazy factory per type.
- **Last registration wins** — if two adapters both register `ProductsRepository`, the second one's factory is used.
- **Lazy instantiation** — no repo instances are created at `registerAdapter()` time. The instance is created on the first `getRepository<T>()` call and cached for all subsequent calls.
- `autoInitialize: true` (default) reads config from `ConfigManager`. Requires `MooseBootstrapper` (or manual `setDependencies()`) to have been called first.

---

## Repository Layer

### CoreRepository — No Constructor Params

```dart
abstract class CoreRepository {
  // Called automatically after factory instantiation, before the instance is cached.
  // Synchronous only. For async work, fire-and-forget from here.
  void initialize() {}
}
```

`CoreRepository` has **no constructor parameters** — no `hookRegistry`, no `eventBus`, no `cache`. Concrete repositories declare their own fields and receive services through the adapter's factory closure.

```dart
// CORRECT
class WooProductsRepository extends CoreRepository implements ProductsRepository {
  final ApiClient _client;
  final HookRegistry _hooks;
  final CacheManager _cache;

  WooProductsRepository(this._client, this._hooks, this._cache);

  @override
  void initialize() {
    // Synchronous setup; fire-and-forget any async work here if needed
  }
}

// WRONG — CoreRepository has no such constructor params
class BadRepository extends CoreRepository {
  BadRepository({required super.hookRegistry, required super.eventBus}); // COMPILE ERROR
}
```

### Repository Rules

- **Abstract interfaces** live in `moose_core/repositories.dart` — they define the contract.
- **Concrete implementations** live in the adapter package — they implement the contract for a specific backend.
- Interfaces return **domain entities** (from `moose_core/entities.dart`), never backend DTOs.
- Interfaces do not contain platform-specific code or business logic.
- All implementations extend `CoreRepository`.

### Available Repository Interfaces

Exported from `package:moose_core/repositories.dart`:

| Interface | Domain |
|-----------|--------|
| `ProductsRepository` | Product catalog, categories, attributes, variations |
| `CartRepository` | Cart management, checkout, payment, refund |
| `ReviewRepository` | Product reviews and ratings |
| `SearchRepository` | Full-text and filtered search |
| `PostRepository` | Blog posts, content |
| `AuthRepository` | Authentication, session management |
| `LocationRepository` | Countries, postal codes, shipping zones |
| `PushNotificationRepository` | Push notification registration |
| `ShortsRepository` | Short-form video content |
| `StoreRepository` | Store settings, metadata |
| `BannerRepository` | Promotional banners, hero images |

---

## Presentation Layer

### FeatureSection Pattern

`FeatureSection` is the base for all configurable, data-driven UI sections. It is a `StatelessWidget`. **All state management uses BLoC — no exceptions**.

```dart
abstract class FeatureSection extends StatelessWidget {
  final Map<String, dynamic>? settings;
  const FeatureSection({super.key, this.settings});

  // Call inside build() to get AdapterRegistry from the widget tree
  AdapterRegistry adaptersOf(BuildContext context);

  // Must implement — every supported key with its default value
  Map<String, dynamic> getDefaultSettings();

  // Type-safe setting access; merges settings over defaults
  // Supports auto num→double and num→int conversion; parses Color from hex string
  // Throws Exception on missing key or type mismatch (fail-fast)
  T getSetting<T>(String key);
}
```

**Settings priority:** constructor `settings` > `getDefaultSettings()`.

```dart
class FeaturedProductsSection extends FeatureSection {
  const FeaturedProductsSection({super.key, super.settings});

  @override
  Map<String, dynamic> getDefaultSettings() => {
    'title': 'Featured Products',
    'itemsPerPage': 10,
    'horizontalPadding': 20.0, // always double for layout values
    'showPrices': true,
  };

  @override
  Widget build(BuildContext context) {
    // Get repository from AdapterRegistry via MooseScope
    final repo = adaptersOf(context).getRepository<ProductsRepository>();

    return BlocProvider(
      create: (_) => FeaturedProductsBloc(repo)..add(LoadFeaturedProducts()),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: getSetting<double>('horizontalPadding'),
        ),
        child: BlocBuilder<FeaturedProductsBloc, FeaturedProductsState>(
          builder: (context, state) {
            if (state is FeaturedProductsLoaded) return _buildList(state.products);
            if (state is FeaturedProductsError) return Text(state.message);
            return const CircularProgressIndicator();
          },
        ),
      ),
    );
  }
}
```

### BLoC Pattern (Mandatory)

Every `FeatureSection` and screen uses BLoC for state management.

```
User interaction → Event → BLoC handler → emits State → BlocBuilder rebuilds UI
```

```dart
// Event
class LoadFeaturedProducts extends Equatable {
  const LoadFeaturedProducts();
  @override List<Object?> get props => [];
}

// States
class FeaturedProductsLoading extends Equatable { ... }
class FeaturedProductsLoaded extends Equatable {
  final List<Product> products;
  const FeaturedProductsLoaded(this.products);
  @override List<Object?> get props => [products];
}
class FeaturedProductsError extends Equatable {
  final String message;
  const FeaturedProductsError(this.message);
  @override List<Object?> get props => [message];
}

// BLoC
class FeaturedProductsBloc
    extends Bloc<FeaturedProductsEvent, FeaturedProductsState> {
  final ProductsRepository _repo;

  FeaturedProductsBloc(this._repo) : super(FeaturedProductsLoading()) {
    on<LoadFeaturedProducts>((event, emit) async {
      emit(FeaturedProductsLoading());
      try {
        final result = await _repo.getProducts(perPage: 10);
        emit(FeaturedProductsLoaded(result.items));
      } catch (e) {
        emit(FeaturedProductsError(e.toString()));
      }
    });
  }
}
```

### Dynamic Section Composition

Sections are composed at runtime from `environment.json`:

```dart
// Plugin registers builder in onRegister()
widgetRegistry.register(
  'products.featured',
  (context, {data, onEvent}) => FeaturedProductsSection(
    settings: data?['settings'] as Map<String, dynamic>?,
  ),
);

// Screen renders all sections in a named group
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

`buildSectionGroup` reads `plugins:home:sections:main` from `ConfigManager`, filters to `active: true` items, and invokes each registered builder with that section's `settings`.

### AddonRegistry: UI Extension Points

`AddonRegistry` allows plugins to inject widgets into named zones owned by other plugins — with no direct import dependency.

```dart
// Plugin B injects a wishlist button into Plugin A's product card zone
addonRegistry.register('product_card.footer', (context, {data, onEvent}) {
  final productId = data?['productId'] as String?;
  return WishlistButton(productId: productId);
}, priority: 10);

// Plugin A renders its zone (no knowledge of who provides addons)
final addons = context.moose.addonRegistry.build<Widget>(
  'product_card.footer',
  context,
  data: {'productId': product.id},
);
```

Higher priority renders first. Builders returning `null` are filtered out.

---

## Cross-Cutting Services

### HookRegistry vs EventBus

| | HookRegistry | EventBus |
|--|-------------|---------|
| **Style** | Synchronous data pipeline | Async pub/sub notifications |
| **Return value** | Transforms and returns modified data | Fire-and-forget — no return |
| **Use case** | Filter/modify/enrich data | Notify side effects across plugins |
| **Execution** | Priority-ordered chain; each handler receives output of previous | All listeners receive the same event independently |
| **Error handling** | Individual hook errors are caught; chain continues | Errors in handlers are caught per subscription |

**HookRegistry — use for data transformation:**

```dart
// Register: filter and enrich products
hookRegistry.register('products:after_load', (data) {
  final products = data as List<Product>;
  return products.where((p) => p.inStock).toList();
}, priority: 10);

// Execute: in the repository (returns transformed data)
final filtered = hookRegistry.execute<List<Product>>('products:after_load', rawProducts);
```

**EventBus — use for notifications and side effects:**

```dart
// Subscribe in onInit()
_sub = eventBus.on('cart.item.added', (event) {
  final productId = event.data['productId'] as String;
  cache.memory.remove('cart:summary');
});

// Async handler
eventBus.onAsync('order.placed', (event) async {
  await sendConfirmationEmail(event.data['orderId'] as String);
});

// Publish: fire-and-forget
eventBus.fire('cart.item.added', data: {'productId': 'p-123', 'quantity': 2});

// Cancel in onStop()
await _sub.cancel();
```

**Event naming convention:** dot notation `<domain>.<action>[.<detail>]`

```
cart.item.added       cart.item.removed     cart.cleared
order.placed          payment.completed     user.signed_in
notification.received products.refreshed
```

### CacheManager

Owned by `MooseAppContext`. Field name is `cache` (not `cacheManager`). `BackendAdapter` exposes both `cache` and `cacheManager` as an alias.

```
MooseAppContext.cache (CacheManager)
  ├── .memory      (MemoryCache)      — in-process; cleared on restart
  └── .persistent  (PersistentCache)  — SharedPreferences; survives restarts
```

`MooseBootstrapper` calls `cache.initPersistent()` in step 2. `PersistentCache.get<T>()` is **synchronous** after init.

```dart
// Cache API responses in adapters/repos
cache.memory.set('products:featured', products, ttl: const Duration(minutes: 5));
final cached = cache.memory.get<List<Product>>('products:featured');

// Preferred: atomic fetch-or-store
return cache.memory.getOrSet(
  'products:featured',
  () => _fetchFromApi(),
  ttl: const Duration(minutes: 5),
);

// User preferences (persistent)
await cache.persistent.setBool('notifications_enabled', true);
final enabled = cache.persistent.get<bool>('notifications_enabled') ?? true;
```

### ConfigManager

Loaded from `environment.json` by `configManager.initialize(config)` in bootstrap step 1. Paths use `:` or `.` interchangeably.

**Path resolution order:**
1. Raw config (from `environment.json`)
2. Registered plugin/adapter defaults (via `getDefaultSettings()`)
3. `defaultValue` argument

```dart
configManager.get('adapters:woocommerce:baseUrl');
configManager.get('plugins:products:settings:display:itemsPerPage', defaultValue: 20);
configManager.has('plugins:cart:active');
```

Defaults are registered automatically:
- Plugin: `PluginRegistry.register()` → `configManager.registerPluginDefaults()`
- Adapter: `AdapterRegistry.registerAdapter()` → `configManager.registerAdapterDefaults()`

### AppNavigator

Static navigation service. Routes navigation events through `EventBus` so plugins can intercept. Falls back to standard `Navigator` if no plugin handles the event.

`MooseBootstrapper` calls `AppNavigator.setEventBus(eventBus)` in step 3. In tests, call `AppNavigator.setEventBus(EventBus())` in `setUp`.

```dart
AppNavigator.pushNamed(context, '/product', arguments: {'id': 'p-123'});
AppNavigator.switchToTab(context, 'cart');
AppNavigator.pop(context);
```

**Always check `context.mounted`** after any `await` in navigation-related code. `AppNavigator` uses `await Future.delayed(Duration.zero)` internally to allow listeners to mark events as handled.

---

## Configuration File Structure

```json
{
  "adapters": {
    "woocommerce": {
      "baseUrl": "https://mystore.com/wp-json/wc/v3",
      "consumerKey": "ck_xxx",
      "consumerSecret": "cs_xxx",
      "timeout": 30
    }
  },
  "plugins": {
    "products": {
      "active": true,
      "settings": {
        "cache": { "productsTTL": 300 },
        "display": { "itemsPerPage": 20, "showOutOfStock": false }
      },
      "sections": {
        "home": [
          {
            "name": "products.featured",
            "active": true,
            "settings": {
              "title": "Featured",
              "itemsPerPage": 6,
              "horizontalPadding": 20.0
            }
          }
        ]
      }
    },
    "cart": {
      "active": true,
      "settings": {}
    }
  }
}
```

---

## Complete End-to-End Example

All four layers working together:

```dart
// ── LAYER 4: ADAPTER ──────────────────────────────────────────────────────────

class WooProductsRepository extends CoreRepository implements ProductsRepository {
  final ApiClient _client;
  final HookRegistry _hooks;
  final CacheManager _cache;

  // No CoreRepository constructor params — adapter factory closure provides deps
  WooProductsRepository(this._client, this._hooks, this._cache);

  @override
  Future<PaginatedResult<Product>> getProducts({
    ProductFilters? filters,
    int page = 1,
    int perPage = 20,
  }) async {
    final cacheKey = 'products:${filters.hashCode}:$page:$perPage';
    return _cache.memory.getOrSet(cacheKey, () async {
      final raw = await _client.get('/products', params: {'page': page});
      final products = raw.map(Product.fromJson).toList();
      final filtered = _hooks.execute<List<Product>>('products:after_load', products);
      return PaginatedResult(items: filtered, page: page, total: raw.length);
    }, ttl: const Duration(minutes: 5));
  }
}

class WooCommerceAdapter extends BackendAdapter {
  @override String get name => 'woocommerce';
  @override String get version => '1.0.0';

  @override
  Map<String, dynamic> get configSchema => {
    'type': 'object',
    'required': ['baseUrl'],
    'properties': {'baseUrl': {'type': 'string', 'format': 'uri'}},
  };

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    final client = ApiClient(baseUrl: config['baseUrl'] as String);
    registerRepositoryFactory<ProductsRepository>(
      () => WooProductsRepository(client, hookRegistry, cache),
    );
  }
}

// ── LAYER 3: REPOSITORY INTERFACE (in moose_core) ────────────────────────────
// Already defined in repositories.dart — no changes needed

// ── LAYER 2: BLOC ─────────────────────────────────────────────────────────────

class ProductsBloc extends Bloc<ProductsEvent, ProductsState> {
  final ProductsRepository _repo;
  ProductsBloc(this._repo) : super(ProductsLoading()) {
    on<LoadProducts>((event, emit) async {
      emit(ProductsLoading());
      try {
        final result = await _repo.getProducts(perPage: event.perPage);
        emit(ProductsLoaded(result.items));
      } catch (e) {
        emit(ProductsError(e.toString()));
      }
    });
  }
}

// ── LAYER 1: SECTION (Presentation) ──────────────────────────────────────────

class FeaturedProductsSection extends FeatureSection {
  const FeaturedProductsSection({super.key, super.settings});

  @override
  Map<String, dynamic> getDefaultSettings() => {
    'title': 'Featured',
    'itemsPerPage': 10,
    'horizontalPadding': 20.0,
  };

  @override
  Widget build(BuildContext context) {
    // Get repo from widget tree — section never holds a reference to it
    final repo = adaptersOf(context).getRepository<ProductsRepository>();

    return BlocProvider(
      create: (_) => ProductsBloc(repo)
        ..add(LoadProducts(perPage: getSetting<int>('itemsPerPage'))),
      child: BlocBuilder<ProductsBloc, ProductsState>(
        builder: (context, state) {
          if (state is ProductsLoaded) return _buildGrid(state.products);
          if (state is ProductsError) return Text(state.message);
          return const CircularProgressIndicator();
        },
      ),
    );
  }
}

// ── PLUGIN + BOOTSTRAP ────────────────────────────────────────────────────────

class ProductsPlugin extends FeaturePlugin {
  @override String get name => 'products';
  @override String get version => '1.0.0';

  @override
  void onRegister() {
    widgetRegistry.register(
      'products.featured',
      (context, {data, onEvent}) => FeaturedProductsSection(
        settings: data?['settings'] as Map<String, dynamic>?,
      ),
    );
  }

  @override Future<void> onInit() async {}

  @override
  Map<String, WidgetBuilder>? getRoutes() => {
    '/products': (_) => const ProductsScreen(),
  };
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final ctx = MooseAppContext();

  runApp(MooseScope(
    appContext: ctx,
    child: MaterialApp(home: _BootstrapScreen(appContext: ctx)),
  ));
}

// In _BootstrapScreen.initState:
final report = await MooseBootstrapper(appContext: ctx).run(
  config: await loadConfig(),
  adapters: [WooCommerceAdapter()],
  plugins: [() => ProductsPlugin()],
);
```

---

## Architectural Rules

| Rule | Consequence if violated |
|------|------------------------|
| `CoreRepository` has **no constructor params** | Compile error — `CoreRepository` has no such fields |
| `configSchema` must be overridden in every `BackendAdapter` | Compile error — `configSchema` is abstract |
| `appContext` is `late` — only access from `onRegister()` / `initialize()` onwards | `LateInitializationError` at runtime |
| `MooseAppContext.cache` is the field name (not `cacheManager`) | `NoSuchMethodError` at runtime |
| `PersistentCache.get<T>()` is synchronous — requires prior `initPersistent()` | Throws `StateError` if called before init |
| `AppNavigator.setEventBus()` must be called before any navigation | Assertion error — `MooseBootstrapper` does this automatically |
| Always check `context.mounted` after `await` in navigation handlers | Widget tree errors if context is unmounted |
| Repositories return **domain entities** only — never DTOs | Architecture breaks; BLoCs would depend on backend types |
| Sections extend `FeatureSection` and use BLoC — no direct repo calls | Breaks layer separation; business logic leaks into UI |
| No singletons — every registry is per-`MooseAppContext` | Shared state across app instances; breaks test isolation |

---

## Related Documentation

- [API.md](API.md) — Complete class and method reference
- [ADAPTER_SYSTEM.md](ADAPTER_SYSTEM.md) — Adapter implementation guide
- [ADAPTER_SCHEMA_VALIDATION.md](ADAPTER_SCHEMA_VALIDATION.md) — JSON Schema validation
- [PLUGIN_SYSTEM.md](PLUGIN_SYSTEM.md) — Plugin development guide
- [PLUGIN_ADAPTER_CONFIG_GUIDE.md](PLUGIN_ADAPTER_CONFIG_GUIDE.md) — Config patterns
- [CACHE_SYSTEM.md](CACHE_SYSTEM.md) — Caching system
- [FEATURE_SECTION.md](FEATURE_SECTION.md) — FeatureSection pattern
- [REGISTRIES.md](REGISTRIES.md) — Registry systems
- [EVENT_SYSTEM_GUIDE.md](EVENT_SYSTEM_GUIDE.md) — HookRegistry vs EventBus
- [ANTI_PATTERNS.md](ANTI_PATTERNS.md) — What NOT to do
