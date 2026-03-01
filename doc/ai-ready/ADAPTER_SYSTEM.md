# Adapter System Guide

> Complete guide to implementing backend adapters in moose_core

## Table of Contents
- [Overview](#overview)
- [CoreRepository Base Class](#corerepository-base-class)
- [BackendAdapter Base Class](#backendadapter-base-class)
- [Step-by-Step: Creating an Adapter](#step-by-step-creating-an-adapter)
- [Repository Factory Pattern](#repository-factory-pattern)
- [AdapterRegistry](#adapterregistry)
- [Accessing Repositories in Widgets and Plugins](#accessing-repositories-in-widgets-and-plugins)
- [Repository Interface Catalog](#repository-interface-catalog)
- [Configuration: Schema and Defaults](#configuration-schema-and-defaults)
- [Convenience Services on BackendAdapter](#convenience-services-on-backendadapter)
- [Best Practices](#best-practices)
- [Anti-Patterns](#anti-patterns)
- [Testing Adapters](#testing-adapters)
- [Related Documentation](#related-documentation)

---

## Overview

The Adapter System decouples business logic from backend specifics. Each backend (WooCommerce, Shopify, a custom REST API, etc.) is wrapped in a `BackendAdapter` subclass. The adapter registers lazy factories for each repository type it supports. Plugins and UI sections access repositories through type-safe calls on `AdapterRegistry` — they never depend on any concrete adapter class.

**Core objects:**

| Class | Role |
|---|---|
| `CoreRepository` | Pure lifecycle base for all repository implementations |
| `BackendAdapter` | Abstract base that owns repository factories and exposes services |
| `AdapterRegistry` | Registry owned by `MooseAppContext`; resolves repositories by type |
| `MooseBootstrapper` | Orchestrates startup: wires registries, registers adapters, boots plugins |

---

## CoreRepository Base Class

```dart
abstract class CoreRepository {
  /// Called automatically after instantiation and before caching.
  /// Override for synchronous setup: listeners, hooks, local state.
  /// Never make this async — fire async work as fire-and-forget.
  void initialize() {}
}
```

**Key facts:**
- No constructor parameters. No injected fields.
- Concrete repository implementations declare their own dependencies as constructor arguments (e.g. an API client, a `CacheManager`, an `EventBus`). They receive them from the adapter's factory closure.
- `initialize()` is `void`. Do not override it as `Future<void>`. Fire async work with `_loadCache()` (without `await`) inside `initialize()`.

---

## BackendAdapter Base Class

```dart
abstract class BackendAdapter {
  /// Unique adapter identifier (e.g., 'woocommerce').
  String get name;

  /// Semantic version string (e.g., '1.0.0').
  String get version;

  /// JSON Schema that describes the adapter's configuration surface.
  /// Validated automatically before initialize() is called.
  Map<String, dynamic> get configSchema;

  /// Default settings merged into ConfigManager at registration time.
  /// Keys missing from environment.json fall back to these values.
  Map<String, dynamic> getDefaultSettings() => {};

  // --- Injected by AdapterRegistry before initialization ---
  // Access these from inside initialize() and repository factories.
  late MooseAppContext appContext;  // injected — do not set manually

  // Convenience getters (all delegate to appContext):
  HookRegistry    get hookRegistry   => appContext.hookRegistry;
  ActionRegistry  get actionRegistry => appContext.actionRegistry;
  ConfigManager   get configManager  => appContext.configManager;
  EventBus        get eventBus       => appContext.eventBus;
  AppLogger       get logger         => appContext.logger;
  CacheManager    get cache          => appContext.cache;
  CacheManager    get cacheManager   => appContext.cache; // backward-compat alias

  // --- Factory registration ---
  void registerRepositoryFactory<T extends CoreRepository>(T Function() factory);
  void registerAsyncRepositoryFactory<T extends CoreRepository>(Future<T> Function() factory);

  // --- Repository retrieval (used internally by AdapterRegistry) ---
  T getRepository<T extends CoreRepository>();
  Future<T> getRepositoryAsync<T extends CoreRepository>();
  CoreRepository getRepositoryByType(Type type);

  // --- Introspection ---
  bool hasRepository<T extends CoreRepository>();
  bool isRepositoryCached<T extends CoreRepository>();
  List<Type> get registeredRepositoryTypes;

  // --- Cache management ---
  void clearRepositoryCache<T extends CoreRepository>();
  void clearAllRepositoryCaches();

  // --- Lifecycle ---
  Future<void> initialize(Map<String, dynamic> config);

  /// Called automatically by AdapterRegistry (via MooseBootstrapper).
  /// Reads adapters.<name> from environment.json, validates against configSchema,
  /// then calls initialize(). The configManager parameter is required — no global fallback.
  Future<void> initializeFromConfig({required ConfigManager configManager});

  /// Validates config against configSchema. Called automatically inside
  /// initializeFromConfig(). You can also call it manually in tests.
  void validateConfig(Map<String, dynamic> config);
}
```

### What AdapterRegistry injects and when

Before calling `initializeFromConfig()`, `AdapterRegistry` injects `appContext` into the adapter. This means all convenience getters (`hookRegistry`, `eventBus`, `cache`, `configManager`, `logger`, `actionRegistry`) are available inside `initialize()` and inside factory closures registered during `initialize()`.

---

## Step-by-Step: Creating an Adapter

### Step 1: Implement repository classes

Repository classes extend the moose_core abstract interface and declare their own constructor dependencies. They do **not** pass anything to `super`.

```dart
class WooProductsRepository extends ProductsRepository {
  final WooApiClient _client;
  final CacheManager _cache;
  final EventBus _eventBus;
  final HookRegistry _hooks;

  WooProductsRepository(this._client, {
    required CacheManager cache,
    required EventBus eventBus,
    required HookRegistry hooks,
  })  : _cache = cache,
        _eventBus = eventBus,
        _hooks = hooks;

  @override
  void initialize() {
    // Synchronous setup only. Fire async work without awaiting.
    _prefetchFeaturedProducts(); // fire-and-forget
  }

  Future<void> _prefetchFeaturedProducts() async {
    try {
      final products = await _client.get('/products', {'featured': true});
      await _cache.memory.set('featured_products', products);
    } catch (_) {} // silent — cache miss is acceptable
  }

  @override
  Future<ProductListResult> getProducts({
    ProductFilters? filters,
    Duration? cacheTTL,
  }) async {
    final cacheKey = 'products:${filters?.toJson()}';
    final cached = _cache.memory.get<ProductListResult>(cacheKey);
    if (cached != null) return cached;

    final raw = await _client.get('/products', _buildParams(filters));
    final result = ProductListResult(
      products: raw.map(_toProduct).toList(),
      totalCount: raw.totalCount,
    );

    // Apply transformations registered by plugins
    final transformed = result.products.map((p) {
      return _hooks.execute('product:transform', p);
    }).toList();

    _eventBus.fire(ProductsLoadedEvent(count: transformed.length));

    if (cacheTTL != null) {
      _cache.memory.set(cacheKey, result, ttl: cacheTTL);
    }
    return ProductListResult(products: transformed, totalCount: result.totalCount);
  }

  @override
  Future<Product> getProductById(String id, {Duration? cacheTTL}) async {
    final cacheKey = 'product:$id';
    final cached = _cache.memory.get<Product>(cacheKey);
    if (cached != null) return cached;

    final raw = await _client.get('/products/$id');
    final product = _hooks.execute('product:transform', _toProduct(raw));
    if (cacheTTL != null) _cache.memory.set(cacheKey, product, ttl: cacheTTL);
    return product;
  }

  Product _toProduct(Map<String, dynamic> json) {
    return Product(
      id: json['id'].toString(),
      name: json['name'] as String,
      price: double.parse(json['price'] as String),
      imageUrl: (json['images'] as List?)?.isNotEmpty == true
          ? json['images'][0]['src'] as String?
          : null,
      description: json['description'] as String?,
      extensions: {'woo_status': json['status']},
    );
  }

  Map<String, dynamic> _buildParams(ProductFilters? f) {
    if (f == null) return {};
    return {
      if (f.categoryId != null) 'category': f.categoryId,
      if (f.minPrice != null) 'min_price': f.minPrice,
      if (f.maxPrice != null) 'max_price': f.maxPrice,
      if (f.search != null) 'search': f.search,
      'per_page': f.limit ?? 20,
      'page': f.page ?? 1,
    };
  }
}
```

### Step 2: Create the adapter class

```dart
class WooCommerceAdapter extends BackendAdapter {
  late WooApiClient _client;

  @override
  String get name => 'woocommerce';

  @override
  String get version => '1.0.0';

  @override
  Map<String, dynamic> get configSchema => {
    'type': 'object',
    'required': ['baseUrl', 'consumerKey', 'consumerSecret'],
    'properties': {
      'baseUrl': {
        'type': 'string',
        'format': 'uri',
        'description': 'WooCommerce store URL',
      },
      'consumerKey': {
        'type': 'string',
        'minLength': 1,
        'description': 'WooCommerce API consumer key',
      },
      'consumerSecret': {
        'type': 'string',
        'minLength': 1,
        'description': 'WooCommerce API consumer secret',
      },
      'apiVersion': {
        'type': 'string',
        'description': 'WooCommerce REST API version',
      },
      'timeout': {
        'type': 'integer',
        'minimum': 0,
        'description': 'Request timeout in seconds',
      },
    },
    'additionalProperties': false,
  };

  @override
  Map<String, dynamic> getDefaultSettings() => {
    'apiVersion': 'wc/v3',
    'timeout': 30,
  };

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    // config is already validated against configSchema — no manual checks needed.
    _client = WooApiClient(
      baseUrl: config['baseUrl'] as String,
      consumerKey: config['consumerKey'] as String,
      consumerSecret: config['consumerSecret'] as String,
      apiVersion: config['apiVersion'] as String,
      timeout: Duration(seconds: config['timeout'] as int),
    );

    // Register repository factories.
    // The factory closures capture `this` so they can pass shared services
    // (hookRegistry, eventBus, cache) to repository constructors.
    _registerRepositories();
  }

  void _registerRepositories() {
    registerRepositoryFactory<ProductsRepository>(
      () => WooProductsRepository(
        _client,
        cache: cache,
        eventBus: eventBus,
        hooks: hookRegistry,
      ),
    );

    registerRepositoryFactory<CartRepository>(
      () => WooCartRepository(_client, cache: cache, eventBus: eventBus),
    );

    registerRepositoryFactory<AuthRepository>(
      () => WooAuthRepository(_client, cache: cache),
    );

    // Use async factory when repository setup itself needs awaiting
    registerAsyncRepositoryFactory<ReviewRepository>(
      () async {
        final tokenCache = await cache.persistent.getString('review_token');
        return WooReviewRepository(_client, cachedToken: tokenCache);
      },
    );
  }
}
```

### Step 3: Register with MooseBootstrapper

Pass adapter **instances** directly to `adapters:`. The bootstrapper calls `adapterRegistry.registerAdapter(() => adapter)` internally, which injects `appContext` and calls `initializeFromConfig()`.

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final ctx = MooseAppContext();

  runApp(MooseScope(
    appContext: ctx,
    child: MaterialApp(home: BootstrapScreen(appContext: ctx)),
  ));
}

// Inside your BootstrapScreen.initState / FutureBuilder:
final config = await rootBundle.loadString('assets/environment.json');

final report = await MooseBootstrapper(appContext: ctx).run(
  config: jsonDecode(config),
  adapters: [
    WooCommerceAdapter(),
    FCMAdapter(),          // push notifications
  ],
  plugins: [
    () => ProductsPlugin(),
    () => CartPlugin(),
  ],
);

if (!report.succeeded) {
  // report.failures is Map<String, Object>
  // keys: "adapter:<name>" or "plugin:<name>"
  debugPrint('Bootstrap failures: ${report.failures}');
}
```

**Bootstrap sequence (executed by `MooseBootstrapper.run`):**

1. `configManager.initialize(config)` — loads `environment.json` map
2. `cache.initPersistent()` — opens SharedPreferences
3. `AppNavigator.setEventBus(appContext.eventBus)` — wires navigation
4. For each adapter: `adapterRegistry.registerAdapter(() => adapter)` — injects `appContext`, calls `initializeFromConfig()`
5. For each plugin factory: `pluginRegistry.register(plugin, appContext: appContext)` — injects `appContext`, calls `onRegister()`
6. `pluginRegistry.initAll()` — calls `initialize()` on all plugins
7. `pluginRegistry.startAll()` — calls `start()` on all plugins

### Step 4: Provide adapter configuration in environment.json

```json
{
  "adapters": {
    "woocommerce": {
      "baseUrl": "https://mystore.example.com",
      "consumerKey": "ck_xxxxxxxxxxxx",
      "consumerSecret": "cs_xxxxxxxxxxxx",
      "apiVersion": "wc/v3",
      "timeout": 30
    },
    "fcm": {
      "projectId": "my-firebase-project"
    }
  },
  "plugins": {
    "products": {
      "active": true,
      "settings": {}
    }
  }
}
```

The framework validates `adapters.woocommerce` against `WooCommerceAdapter.configSchema` automatically before calling `initialize()`.

---

## Repository Factory Pattern

### Lazy initialization

Repository instances are only created on the **first** `getRepository<T>()` call. Until that moment only the factory closure is stored.

```
registerRepositoryFactory() → stores factory (no instance created)
         |
         | (first getRepository<T>() call)
         ↓
factory() → creates instance
         ↓
instance.initialize() → synchronous setup
         ↓
instance cached in _cache[T]
         |
         | (all subsequent getRepository<T>() calls)
         ↓
returns cached instance (factory never called again)
```

### Synchronous factory (most common)

```dart
registerRepositoryFactory<ProductsRepository>(
  () => WooProductsRepository(_client, cache: cache, eventBus: eventBus, hooks: hookRegistry),
);

// Retrieval (synchronous)
final repo = adapter.getRepository<ProductsRepository>();
```

### Asynchronous factory

Use when the repository constructor itself needs awaiting (e.g., opens a database, fetches a token).

```dart
registerAsyncRepositoryFactory<ReviewRepository>(
  () async {
    final token = await _fetchAuthToken();
    return WooReviewRepository(_client, token: token);
  },
);

// Must be retrieved asynchronously
final repo = await adapter.getRepositoryAsync<ReviewRepository>();
```

> Calling `getRepository<T>()` (sync) on an async factory throws `RepositoryNotRegisteredException`. Always use `getRepositoryAsync<T>()` for async factories.

### Cache management

```dart
// Inspect state
adapter.hasRepository<ProductsRepository>();    // factory registered?
adapter.isRepositoryCached<ProductsRepository>(); // instance exists?

// Invalidate (forces re-creation on next access)
adapter.clearRepositoryCache<ProductsRepository>();

// Invalidate all
adapter.clearAllRepositoryCaches();

// Enumerate
List<Type> types = adapter.registeredRepositoryTypes;
```

---

## AdapterRegistry

`AdapterRegistry` is owned by `MooseAppContext` — never instantiated directly. It sits between `MooseAppContext` / `PluginRegistry` / `FeatureSection` and the concrete adapters.

### How it works

- **Last registration wins.** If two adapters register `ProductsRepository`, the last one provides the instance.
- **Double lazy.** The registry stores a closure that delegates to `adapter.getRepositoryByType(T)`. The adapter also lazily creates the instance. Both layers cache, so the repository is created exactly once.
- **No active-adapter concept.** There is no "the" adapter. Each repository type is resolved independently — you can mix adapters (WooCommerce for products, FCM for push notifications).

### Key API

```dart
// Typical: via MooseAppContext convenience shortcut
final repo = appContext.getRepository<ProductsRepository>();

// Direct registry access
final repo = appContext.adapterRegistry.getRepository<ProductsRepository>();

// Guard before accessing
if (appContext.adapterRegistry.hasRepository<PushNotificationRepository>()) {
  final repo = appContext.adapterRegistry.getRepository<PushNotificationRepository>();
}

// Introspection
List<Type>   available = appContext.adapterRegistry.getAvailableRepositories();
List<String> adapters  = appContext.adapterRegistry.getInitializedAdapters();
int repoCount    = appContext.adapterRegistry.repositoryCount;
int adapterCount = appContext.adapterRegistry.adapterCount;
bool ready       = appContext.adapterRegistry.isInitialized;

// Direct adapter access (advanced; prefer getRepository<T>())
final wooAdapter = appContext.adapterRegistry.getAdapter<WooCommerceAdapter>('woocommerce');

// Test teardown
appContext.adapterRegistry.clearAll();
```

### Manual registration (without MooseBootstrapper)

```dart
final ctx = MooseAppContext();
ctx.configManager.initialize(config);
await ctx.adapterRegistry.registerAdapter(() => WooCommerceAdapter());
// autoInitialize defaults to true — reads adapters.woocommerce from ConfigManager
```

To skip config loading and initialize the adapter manually:

```dart
await ctx.adapterRegistry.registerAdapter(
  () async {
    final adapter = WooCommerceAdapter();
    await adapter.initialize({'baseUrl': '...', 'consumerKey': '...', 'consumerSecret': '...'});
    return adapter;
  },
  autoInitialize: false,
);
```

---

## Accessing Repositories in Widgets and Plugins

### In a FeatureSection (synchronous)

```dart
class ProductGridSection extends FeatureSection {
  @override
  Widget build(BuildContext context) {
    final repo = adapters(context).getRepository<ProductsRepository>();

    return BlocProvider(
      create: (_) => ProductsBloc(repo)..add(LoadProducts()),
      child: const ProductGridView(),
    );
  }
}
```

`adapters(context)` returns the `AdapterRegistry` from the scoped `MooseAppContext`. Use `getRepository<T>()` synchronously in `build()`.

### In a FeaturePlugin (async)

```dart
class ProductsPlugin extends FeaturePlugin {
  @override
  String get name => 'products';

  @override
  Future<void> initialize() async {
    // Optionally pre-warm the repository
    final repo = appContext.getRepository<ProductsRepository>();
    await repo.getFeaturedProducts(limit: 5);
  }
}
```

### In BLoC / service classes

Pass the repository through the constructor — never call `AdapterRegistry` from inside BLoC or service classes directly.

```dart
class ProductsBloc extends Bloc<ProductsEvent, ProductsState> {
  final ProductsRepository _repo;

  ProductsBloc(this._repo) : super(ProductsInitial()) {
    on<LoadProducts>(_onLoad);
  }

  Future<void> _onLoad(LoadProducts event, Emitter emit) async {
    emit(ProductsLoading());
    try {
      final result = await _repo.getProducts(filters: event.filters);
      emit(ProductsLoaded(result.products));
    } catch (e) {
      emit(ProductsError(e.toString()));
    }
  }
}
```

---

## Repository Interface Catalog

All interfaces live in `lib/src/repositories/`. They all extend `CoreRepository` with no constructor parameters.

| Interface | Key responsibilities |
|---|---|
| `ProductsRepository` | Catalog browsing, PDP, categories, collections, variations, attributes, reviews, stock, related/upsell/cross-sell products |
| `CartRepository` | Cart CRUD, coupons, shipping methods, payment methods, checkout, orders, payments, refunds |
| `AuthRepository` | Login, registration, token refresh, logout, password reset |
| `SearchRepository` | Keyword search, suggestions, faceted results |
| `ReviewRepository` | Product review listing and submission |
| `PostRepository` | Blog / news listing and detail |
| `ShortsRepository` | Short-form video content |
| `BannerRepository` | Promotional banners by placement; view/click tracking |
| `StoreRepository` | Store info, policies, contact details |
| `PushNotificationRepository` | Device token registration, topic subscriptions |
| `LocationRepository` | Address lookup, shipping zone resolution |

Adapters only need to implement the repositories that their active plugins actually use. If a plugin requests a repository the adapter does not provide, `AdapterRegistry.getRepository<T>()` throws `RepositoryNotRegisteredException` at runtime.

### ProductsRepository signature highlights

```dart
abstract class ProductsRepository extends CoreRepository {
  Future<ProductListResult> getProducts({ProductFilters? filters, Duration? cacheTTL});
  Future<Product> getProductById(String id, {Duration? cacheTTL});
  Future<List<Product>> getProductsByIds(List<String> ids, {bool includeVariations = false, Duration? cacheTTL});
  Future<List<Category>> getCategories({String? parentId, bool hideEmpty = false, String? orderBy, Duration? cacheTTL});
  Future<List<Collection>> getCollections({CollectionFilters? filters, Duration? cacheTTL});
  Future<List<ProductVariation>> getProductVariations(String productId, {Duration? cacheTTL});
  Future<ProductStock> getProductStock(String productId, {String? variationId, Duration? cacheTTL});
  Future<ProductAvailability> validateProductAvailability({required String productId, required int quantity, String? variationId, Duration? cacheTTL});
  Future<List<Product>> getFeaturedProducts({int limit = 10, String? categoryId, Duration? cacheTTL});
  Future<List<Product>> getRelatedProducts(String productId, {int limit = 10, Duration? cacheTTL});
  Future<ProductReview> createReview(ProductReview review);
  // ... and more
}
```

### CartRepository signature highlights

```dart
abstract class CartRepository extends CoreRepository {
  Future<Cart> getCart({String? cartId, String? customerId});
  Future<Cart> addItem({required String productId, String? variationId, int quantity = 1, Map<String, dynamic>? metadata});
  Future<Cart> updateItemQuantity({required String itemId, required int quantity});
  Future<Cart> removeItem({required String itemId});
  Future<Cart> applyCoupon({required String couponCode});
  Future<Cart> calculateTotals({String? shippingMethodId, Address? shippingAddress});
  Future<List<ShippingMethod>> getShippingMethods({required Address shippingAddress});
  Future<List<PaymentMethod>> getPaymentMethods();
  Future<CartValidationResult> validateCart();
  Future<CheckoutResult> checkout({required CheckoutRequest checkoutRequest});
  Future<Order> getOrder({required String orderId});
  Future<PaymentResult> processPayment({required String orderId, required String paymentMethodId, Map<String, dynamic>? paymentData});
  Future<RefundResult> requestRefund({required String orderId, double? amount, String? reason});
  // ... and more
}
```

Always read the interface file in `lib/src/repositories/` for the authoritative method signatures before implementing.

---

## Configuration: Schema and Defaults

See [ADAPTER_SCHEMA_VALIDATION.md](./ADAPTER_SCHEMA_VALIDATION.md) for full schema reference and examples. Summary:

### configSchema

Override `configSchema` with a JSON Schema object. `initializeFromConfig()` calls `validateConfig()` automatically before your `initialize()` is called — you never receive invalid config.

```dart
@override
Map<String, dynamic> get configSchema => {
  'type': 'object',
  'required': ['baseUrl', 'apiKey'],
  'properties': {
    'baseUrl': {'type': 'string', 'format': 'uri'},
    'apiKey': {'type': 'string', 'minLength': 1},
    'timeout': {'type': 'integer', 'minimum': 0},
    'enableLogging': {'type': 'boolean'},
  },
  'additionalProperties': false, // reject unknown keys
};
```

Use `'additionalProperties': false` to prevent silent misconfiguration from typos in environment.json.

### getDefaultSettings

Override to provide fallback values for optional config keys. These are registered in `ConfigManager` when the adapter is registered — before `initialize()` is called.

```dart
@override
Map<String, dynamic> getDefaultSettings() => {
  'timeout': 30,
  'enableLogging': false,
};
```

### environment.json structure

```json
{
  "adapters": {
    "<adapter.name>": {
      /* fields validated against configSchema */
    }
  }
}
```

The key must exactly match `adapter.name`.

---

## Convenience Services on BackendAdapter

After `AdapterRegistry` injects `appContext`, the following getters are available inside `initialize()` and factory closures:

| Getter | Type | Common use |
|---|---|---|
| `hookRegistry` | `HookRegistry` | Pass to repositories for data transformation hooks |
| `eventBus` | `EventBus` | Pass to repositories for analytics / cross-plugin events |
| `cache` | `CacheManager` | Pass to repositories for memory and persistent caching |
| `cacheManager` | `CacheManager` | Alias for `cache` (backward compat) |
| `configManager` | `ConfigManager` | Read additional config keys during initialization |
| `actionRegistry` | `ActionRegistry` | Register deep-link / custom action handlers |
| `logger` | `AppLogger` | Log adapter initialization progress |
| `appContext` | `MooseAppContext` | Full context — use sparingly; prefer specific getters |

Example — using services in a factory:

```dart
registerRepositoryFactory<ProductsRepository>(
  () => WooProductsRepository(
    _client,
    cache: cache,           // from BackendAdapter getter
    eventBus: eventBus,     // from BackendAdapter getter
    hooks: hookRegistry,    // from BackendAdapter getter
  ),
);
```

---

## Best Practices

```dart
// ✅ Use configSchema — let the framework validate
@override
Map<String, dynamic> get configSchema => {
  'type': 'object',
  'required': ['apiKey'],
  'properties': {'apiKey': {'type': 'string', 'minLength': 1}},
  'additionalProperties': false,
};

// ✅ Return domain entities, never DTOs
@override
Future<Product> getProductById(String id, {Duration? cacheTTL}) async {
  final raw = await _client.get('/products/$id');
  return _toProduct(raw); // mapped to domain entity
}

// ✅ Keep initialize() synchronous; fire async work
@override
void initialize() {
  _subscribeToEvents();    // sync
  _prefetchData();         // async, fire-and-forget
}

// ✅ Use HookRegistry for plugin-extensible transformations
final product = hookRegistry.execute('product:transform', _toProduct(raw));

// ✅ Use EventBus for observable side effects
eventBus.fire(ProductViewedEvent(productId: id));

// ✅ Cache with TTL when the caller requests it
if (cacheTTL != null) cache.memory.set(cacheKey, result, ttl: cacheTTL);

// ✅ Use additionalProperties: false in configSchema
'additionalProperties': false,

// ✅ Provide sensible defaults in getDefaultSettings()
@override
Map<String, dynamic> getDefaultSettings() => {'timeout': 30, 'retries': 3};
```

---

## Anti-Patterns

```dart
// ❌ Do NOT pass hookRegistry/eventBus via CoreRepository constructor
// CoreRepository has NO constructor parameters.
class BadRepo extends CoreRepository {
  BadRepo({required this.hookRegistry});  // WRONG — will not compile
  final HookRegistry hookRegistry;
}

// ❌ Do NOT make initialize() async
@override
Future<void> initialize() async {  // WRONG
  await _loadData();
}

// ❌ Do NOT call AdapterRegistry inside a BLoC or service
class ProductsBloc extends Bloc<...> {
  ProductsBloc(BuildContext context) {
    final repo = context.moose.adapterRegistry.getRepository<ProductsRepository>(); // WRONG
  }
}

// ❌ Do NOT perform manual config validation when using configSchema
@override
Future<void> initialize(Map<String, dynamic> config) async {
  if (!config.containsKey('apiKey')) throw Exception('...'); // WRONG — schema handles this
}

// ❌ Do NOT store repositories as adapter fields
class BadAdapter extends BackendAdapter {
  late ProductsRepository _productsRepo;  // WRONG — use factory pattern

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    _productsRepo = WooProductsRepository(_client); // bypasses lazy caching
  }
}

// ❌ Do NOT instantiate repositories directly — use factories
registerRepositoryFactory<ProductsRepository>(
  () => WooProductsRepository(_client),
);
// NOT: _productsRepo = WooProductsRepository(_client);

// ❌ Do NOT use getRepository<T>() (sync) on an async factory
registerAsyncRepositoryFactory<ReviewRepository>(() async => WooReviewRepository());
adapter.getRepository<ReviewRepository>(); // WRONG — throws RepositoryNotRegisteredException
// CORRECT:
await adapter.getRepositoryAsync<ReviewRepository>();

// ❌ Do NOT put business logic in repositories
@override
Future<List<Product>> getProducts({ProductFilters? filters, Duration? cacheTTL}) async {
  final all = await _client.getProducts();
  return all.where((p) => p.price > 10).toList(); // WRONG — filtering is business logic
}
```

---

## Testing Adapters

### Minimal mock adapter

```dart
class MockAdapter extends BackendAdapter {
  @override String get name => 'mock';
  @override String get version => '1.0.0';
  @override Map<String, dynamic> get configSchema => {
    'type': 'object',
    'properties': {},
  };

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    registerRepositoryFactory<ProductsRepository>(
      () => MockProductsRepository(),
    );
    registerRepositoryFactory<CartRepository>(
      () => MockCartRepository(),
    );
  }
}

class MockProductsRepository extends ProductsRepository {
  bool initializeCalled = false;

  @override
  void initialize() {
    initializeCalled = true;
  }

  @override
  Future<ProductListResult> getProducts({
    ProductFilters? filters,
    Duration? cacheTTL,
  }) async {
    return ProductListResult(
      products: [Product(id: '1', name: 'Test Product', price: 9.99)],
      totalCount: 1,
    );
  }

  // implement remaining abstract methods...
}
```

### Unit-testing an adapter

```dart
void main() {
  group('WooCommerceAdapter', () {
    late WooCommerceAdapter adapter;

    setUp(() {
      adapter = WooCommerceAdapter();
    });

    test('configSchema rejects missing required fields', () {
      expect(
        () => adapter.validateConfig({'timeout': 30}), // missing baseUrl, keys, secret
        throwsA(isA<AdapterConfigValidationException>()),
      );
    });

    test('configSchema rejects additional properties', () {
      expect(
        () => adapter.validateConfig({
          'baseUrl': 'https://example.com',
          'consumerKey': 'ck_x',
          'consumerSecret': 'cs_x',
          'unknown': 'value',
        }),
        throwsA(isA<AdapterConfigValidationException>()),
      );
    });

    test('initialize registers expected repositories', () async {
      await adapter.initialize({
        'baseUrl': 'https://example.com',
        'consumerKey': 'ck_x',
        'consumerSecret': 'cs_x',
        'apiVersion': 'wc/v3',
        'timeout': 30,
      });

      expect(adapter.hasRepository<ProductsRepository>(), isTrue);
      expect(adapter.hasRepository<CartRepository>(), isTrue);
      expect(adapter.isRepositoryCached<ProductsRepository>(), isFalse); // lazy
    });

    test('repositories are lazy — not created until getRepository()', () async {
      await adapter.initialize({...});

      expect(adapter.isRepositoryCached<ProductsRepository>(), isFalse);
      adapter.getRepository<ProductsRepository>();
      expect(adapter.isRepositoryCached<ProductsRepository>(), isTrue);
    });

    test('getRepository() returns same instance on repeated calls', () async {
      await adapter.initialize({...});

      final r1 = adapter.getRepository<ProductsRepository>();
      final r2 = adapter.getRepository<ProductsRepository>();
      expect(identical(r1, r2), isTrue);
    });

    test('clearRepositoryCache() forces re-creation', () async {
      await adapter.initialize({...});

      final r1 = adapter.getRepository<ProductsRepository>();
      adapter.clearRepositoryCache<ProductsRepository>();
      final r2 = adapter.getRepository<ProductsRepository>();
      expect(identical(r1, r2), isFalse);
    });
  });
}
```

### Integration test with MooseAppContext

```dart
void main() {
  group('WooCommerceAdapter integration', () {
    late MooseAppContext ctx;

    setUp(() {
      ctx = MooseAppContext();
      ctx.configManager.initialize({
        'adapters': {
          'woocommerce': {
            'baseUrl': 'https://example.com',
            'consumerKey': 'ck_test',
            'consumerSecret': 'cs_test',
          },
        },
      });
    });

    tearDown(() {
      ctx.adapterRegistry.clearAll();
    });

    test('repository available after adapter registration', () async {
      await ctx.adapterRegistry.registerAdapter(() => WooCommerceAdapter());

      expect(ctx.adapterRegistry.hasRepository<ProductsRepository>(), isTrue);
      expect(ctx.getRepository<ProductsRepository>(), isA<ProductsRepository>());
    });
  });
}
```

---

## Related Documentation

- [ARCHITECTURE.md](./ARCHITECTURE.md) — Overall system architecture
- [ADAPTER_SCHEMA_VALIDATION.md](./ADAPTER_SCHEMA_VALIDATION.md) — Full JSON schema reference
- [PLUGIN_SYSTEM.md](./PLUGIN_SYSTEM.md) — How plugins consume repositories
- [PLUGIN_ADAPTER_CONFIG_GUIDE.md](./PLUGIN_ADAPTER_CONFIG_GUIDE.md) — Plugin and adapter configuration deep-dive
- [PLUGIN_ADAPTER_MANIFEST.md](./PLUGIN_ADAPTER_MANIFEST.md) — moose.manifest.json reference for distributable adapter packages
- [REGISTRIES.md](./REGISTRIES.md) — All registry APIs
- [EVENT_SYSTEM_GUIDE.md](./EVENT_SYSTEM_GUIDE.md) — EventBus and HookRegistry usage
- [ANTI_PATTERNS.md](./ANTI_PATTERNS.md) — Expanded anti-patterns list

---

**Last Updated:** 2026-03-01
**Version:** 5.0.0

**Changelog:**
- **v5.0.0 (2026-03-01)**: Full rewrite against actual source. `CoreRepository` is now a pure no-arg lifecycle base — no `hookRegistry`/`eventBus` fields. `BackendAdapter` convenience getters documented (`hookRegistry`, `eventBus`, `cache`, `configManager`, `logger`, `actionRegistry`). `AdapterRegistry` API documented (`getAdapter`, `getAvailableRepositories`, `getInitializedAdapters`, `clearAll`). Repository interface catalog expanded with real method signatures. Mock testing patterns corrected. Anti-patterns and bootstrap sequence updated.
- **v4.0.0 (2026-02-26)**: `initializeFromConfig()` requires `configManager:` named param. `AdapterRegistry` lazy factory design documented. `MooseAppContext.getRepository<T>()` shortcut added.
- **v3.0.0 (2026-02-22)**: `CoreRepository` required `hookRegistry`/`eventBus` constructor params (now removed).
