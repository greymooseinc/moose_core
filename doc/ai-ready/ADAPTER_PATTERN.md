# Adapter Pattern Guide

> Complete guide to implementing backend adapters in moose_core

## Table of Contents
- [Overview](#overview)
- [BackendAdapter Architecture](#backendadapter-architecture)
- [Creating a Custom Adapter](#creating-a-custom-adapter)
- [Repository Factory Pattern](#repository-factory-pattern)
- [Adapter Registry](#adapter-registry)
- [Best Practices](#best-practices)

## Overview

The Adapter Pattern enables support for multiple e-commerce backends (WooCommerce, Shopify, custom APIs, etc.) without changing business logic. Adapters provide backend-specific implementations of core repository interfaces.

## BackendAdapter Architecture

### BackendAdapter Base Class

```dart
abstract class BackendAdapter {
  /// Unique identifier for the adapter
  String get name;

  /// Semantic version of the adapter
  String get version;

  /// JSON Schema that describes the adapter's configuration surface
  Map<String, dynamic> get configSchema;

  /// Default configuration merged with environment.json (registered automatically)
  Map<String, dynamic> getDefaultSettings() => const {};

  /// Repository factories storage
  final Map<Type, Object> _factories = {};

  /// Repository cache storage
  final Map<Type, Object> _cache = {};

  /// Register a synchronous factory for a repository type
  void registerRepositoryFactory<T extends CoreRepository>(
    T Function() factory,
  ) {
    _factories[T] = factory;
  }

  /// Register an asynchronous factory for a repository type
  void registerAsyncRepositoryFactory<T extends CoreRepository>(
    Future<T> Function() factory,
  ) {
    _factories[T] = factory;
  }

  /// Get repository synchronously (for sync factories)
  T getRepository<T extends CoreRepository>() {
    // Check cache first, then instantiate from factory
  }

  /// Get repository asynchronously (supports both sync and async factories)
  Future<T> getRepositoryAsync<T extends CoreRepository>() async {
    // Check cache first, then instantiate from factory
  }

  /// Check if a factory is registered
  bool hasRepository<T extends CoreRepository>() {
    return _factories.containsKey(T);
  }

  /// Check if a repository is currently cached
  bool isRepositoryCached<T extends CoreRepository>() {
    return _cache.containsKey(T);
  }

  /// Clear the cache for a specific repository type
  void clearRepositoryCache<T extends CoreRepository>() {
    _cache.remove(T);
  }

  /// Clear all cached repository instances
  void clearAllRepositoryCaches() {
    _cache.clear();
  }

  /// Get list of all registered repository types
  List<Type> get registeredRepositoryTypes {
    return _factories.keys.toList();
  }

  /// Get a repository by its runtime type (for AdapterRegistry)
  CoreRepository getRepositoryByType(Type type) {
    // Returns cached instance or creates new one
  }

  /// Initialize the adapter with configuration (already validated)
  Future<void> initialize(Map<String, dynamic> config);

  /// Loads, validates, and applies config from the scoped ConfigManager.
  /// [configManager] is required — no global fallback exists.
  Future<void> initializeFromConfig({required ConfigManager configManager});
}
```

#### Configuration Schema & Defaults

- Override `configSchema` with a JSON Schema definition. The framework automatically validates `environment.json.adapters.{adapterName}` against this schema before your adapter boots.
- Override `getDefaultSettings()` with sensible defaults. `ConfigManager` registers these so missing keys in `environment.json` fall back to your code-defined values.
- Access merged settings via the scoped `ConfigManager`: `appContext.configManager.get('adapters:$name:some:key')`.

#### `initializeFromConfig()` Shortcut

`MooseBootstrapper` calls this automatically (passing the scoped `ConfigManager`) when `autoInitialize: true`. It:

1. Reads `environment.json.adapters.{adapterName}`
2. Validates the map against `configSchema`
3. Calls your adapter's `initialize()` with the validated map

The `configManager` parameter is **required** — there is no global fallback.

### CoreRepository Base Class

All repository interfaces must extend `CoreRepository`:

```dart
/// Base class for all repository implementations
///
/// Provides common functionality and lifecycle management for repositories.
abstract class CoreRepository {
  final HookRegistry hookRegistry;
  final EventBus eventBus;

  CoreRepository({required this.hookRegistry, required this.eventBus});

  /// Initialize the repository
  ///
  /// This method is called automatically after the repository is instantiated
  /// but before it's cached. Override this method to perform synchronous
  /// initialization tasks such as:
  /// - Setting up listeners
  /// - Initializing local variables
  /// - Registering hooks
  /// - Configuring internal state
  ///
  /// **Note:** This method is synchronous. For async initialization (loading
  /// data, network calls, etc.), trigger those operations here but don't await
  /// them, or handle them in your repository methods as needed.
  ///
  /// The default implementation does nothing.
  void initialize() {}
}
```

**Key Features:**
- **Automatic Initialization**: `initialize()` is called automatically by the adapter
- **HookRegistry Access**: Injected via constructor; available as `hookRegistry` field
- **EventBus Access**: Injected via constructor; available as `eventBus` field
- **Injected by AdapterRegistry**: `AdapterRegistry.setDependencies()` provides the scoped `HookRegistry` and `EventBus` before any adapter is registered. Factories close over adapter's own fields.

## Creating a Custom Adapter

### Step 1: Define Repository Interfaces

All concrete repository subclasses must pass `hookRegistry` and `eventBus` up to `CoreRepository`:

```dart
// In core package
abstract class ProductsRepository extends CoreRepository {
  ProductsRepository({required super.hookRegistry, required super.eventBus});
  Future<List<Product>> getProducts(ProductFilters? filters);
  Future<Product> getProductById(String id);
  Future<List<Category>> getCategories();
}

abstract class CartRepository extends CoreRepository {
  CartRepository({required super.hookRegistry, required super.eventBus});
  Future<Cart> getCart();
  Future<Cart> addToCart(String productId, int quantity);
  Future<Cart> updateCartItem(String itemId, int quantity);
  Future<void> clearCart();
}
```

### Step 2: Implement Repository Classes

```dart
// In your adapter package/directory
class WooProductsRepository extends ProductsRepository {
  final WooCommerceApiClient _apiClient;

  WooProductsRepository(this._apiClient, {required super.hookRegistry, required super.eventBus});

  @override
  Future<List<Product>> getProducts(ProductFilters? filters) async {
    try {
      final response = await _apiClient.get(
        '/products',
        params: _buildQueryParams(filters),
      );

      return response
          .map((json) => _convertToProduct(json))
          .toList();
    } catch (e) {
      throw RepositoryException('Failed to load products: $e');
    }
  }

  @override
  Future<Product> getProductById(String id) async {
    try {
      final response = await _apiClient.get('/products/$id');
      return _convertToProduct(response);
    } catch (e) {
      throw RepositoryException('Failed to load product: $e');
    }
  }

  @override
  Future<List<Category>> getCategories() async {
    try {
      final response = await _apiClient.get('/products/categories');
      return response
          .map((json) => _convertToCategory(json))
          .toList();
    } catch (e) {
      throw RepositoryException('Failed to load categories: $e');
    }
  }

  // Convert DTO to domain entity
  Product _convertToProduct(Map<String, dynamic> json) {
    return Product(
      id: json['id'].toString(),
      name: json['name'],
      price: (json['price'] as String).toDouble(),
      imageUrl: json['images']?[0]?['src'],
      description: json['description'],
      // ... other fields
    );
  }

  Category _convertToCategory(Map<String, dynamic> json) {
    return Category(
      id: json['id'].toString(),
      name: json['name'],
      slug: json['slug'],
      imageUrl: json['image']?['src'],
    );
  }

  Map<String, dynamic> _buildQueryParams(ProductFilters? filters) {
    if (filters == null) return {};

    return {
      if (filters.categoryId != null) 'category': filters.categoryId,
      if (filters.minPrice != null) 'min_price': filters.minPrice,
      if (filters.maxPrice != null) 'max_price': filters.maxPrice,
      if (filters.search != null) 'search': filters.search,
      'per_page': filters.limit ?? 10,
      'page': filters.page ?? 1,
    };
  }

  @override
  void initialize() {
    // Called automatically after instantiation
    // Setup listeners, initialize state, etc.
    _setupListeners();
  }

  void _setupListeners() {
    // Setup any event listeners or hooks
  }
}
```

### Step 3: Create the Adapter

```dart
class WooCommerceAdapter extends BackendAdapter {
  late WooCommerceApiClient _apiClient;

  @override
  String get name => 'woocommerce';

  @override
  String get version => '1.0.0';

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    // Validate configuration
    _validateConfig(config);

    // Initialize API client
    _apiClient = WooCommerceApiClient(
      baseUrl: config['baseUrl'],
      consumerKey: config['consumerKey'],
      consumerSecret: config['consumerSecret'],
      version: config['apiVersion'] ?? 'wc/v3',
    );

    // Test connection
    await _testConnection();

    // Register repositories
    _registerRepositories();
  }

  void _validateConfig(Map<String, dynamic> config) {
    final required = ['baseUrl', 'consumerKey', 'consumerSecret'];
    for (final key in required) {
      if (!config.containsKey(key) || config[key] == null) {
        throw AdapterConfigurationException(
          'Missing required configuration: $key',
        );
      }
    }
  }

  Future<void> _testConnection() async {
    try {
      await _apiClient.get('/system_status');
    } catch (e) {
      throw AdapterInitializationException(
        'Failed to connect to WooCommerce: $e',
      );
    }
  }

  void _registerRepositories() {
    // Synchronous repositories
    registerRepositoryFactory<ProductsRepository>(
      () => WooProductsRepository(_apiClient),
    );

    registerRepositoryFactory<CartRepository>(
      () => WooCartRepository(_apiClient),
    );

    registerRepositoryFactory<CategoryRepository>(
      () => WooCategoryRepository(_apiClient),
    );

    // Asynchronous repositories (if initialization requires async operations)
    registerAsyncRepositoryFactory<ReviewRepository>(
      () async {
        final config = await _loadReviewConfig();
        return WooReviewRepository(_apiClient, config);
      },
    );
  }

  Future<ReviewConfig> _loadReviewConfig() async {
    // Load additional configuration if needed
    return ReviewConfig(enableModeration: true);
  }
}
```

### Step 4: Register with AdapterRegistry via MooseBootstrapper

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CacheManager.initPersistentCache();

  final ctx = MooseAppContext();

  runApp(MooseScope(
    appContext: ctx,
    child: MaterialApp(home: _BootstrapScreen(appContext: ctx)),
  ));
}

// In bootstrap screen:
final report = await MooseBootstrapper(appContext: ctx).run(
  config: await loadConfiguration(),
  // Pass adapter instances directly — MooseBootstrapper registers them:
  adapters: [WooCommerceAdapter()],
  plugins: [() => ProductsPlugin()],
);
```

> **Note:** `MooseBootstrapper` calls `appContext.adapterRegistry.registerAdapter(() => adapter)` internally after calling `setDependencies()` so adapters receive the scoped `HookRegistry`/`EventBus`. For manual registration outside a bootstrapper, call `appContext.adapterRegistry.registerAdapter(factory)` directly.

## Repository Factory Pattern

### Lazy Initialization

Repositories are only created when first accessed, and their `initialize()` method is automatically called:

```dart
// First access - repository is created and initialized
final productsRepo = adapter.getRepository<ProductsRepository>();
// Behind the scenes:
// 1. Factory creates instance
// 2. initialize() method is called
// 3. Instance is cached

// Second access - cached repository is returned
final productsRepo2 = adapter.getRepository<ProductsRepository>();

assert(identical(productsRepo, productsRepo2));  // Same instance
```

**Initialization Flow:**
1. Factory function creates repository instance
2. Adapter automatically calls `repository.initialize()`
3. Repository is cached for subsequent access
4. Cached instance is returned on future calls

### Synchronous vs Asynchronous Factories

**Synchronous Factory** (most common):
```dart
registerRepositoryFactory<ProductsRepository>(
  () => WooProductsRepository(_apiClient),
);

// Get synchronously
final repo = adapter.getRepository<ProductsRepository>();
```

**Asynchronous Factory** (for async initialization):
```dart
registerAsyncRepositoryFactory<ReviewRepository>(
  () async {
    final config = await loadConfig();
    return WooReviewRepository(_apiClient, config);
  },
);

// Must get asynchronously
final repo = await adapter.getRepositoryAsync<ReviewRepository>();
```

### Type Safety

All repositories must extend `CoreRepository`:

```dart
// ✅ Correct - extends CoreRepository
class ProductsRepository extends CoreRepository {
  // ...
}

// ❌ Wrong - doesn't extend CoreRepository
class ProductsService {  // Won't compile!
  // ...
}
```

### Using HookRegistry and EventBus in Repositories

Every repository has access to `hookRegistry` and `eventBus`:

```dart
class WooProductsRepository extends CoreRepository implements ProductsRepository {
  final WooCommerceApiClient _apiClient;

  WooProductsRepository(this._apiClient);

  @override
  Future<List<Product>> getProducts(ProductFilters? filters) async {
    try {
      final response = await _apiClient.get('/products', ...);
      final products = response.map(_convertToProduct).toList();

      // Use HookRegistry for transformations (e.g., apply pricing rules)
      final transformedProducts = products.map((product) {
        return hookRegistry.execute('product:transform', product);
      }).toList();

      // Fire EventBus events for analytics
      eventBus.fire(AppProductSearchedEvent(
        searchQuery: filters?.search ?? '',
        resultCount: transformedProducts.length,
        productIds: transformedProducts.map((p) => p.id).toList(),
      ));

      return transformedProducts;
    } catch (e) {
      // Fire error event
      eventBus.fire(AppApplicationErrorEvent(
        errorMessage: 'Failed to load products',
        error: e,
        context: 'WooProductsRepository.getProducts',
      ));
      throw RepositoryException('Failed to load products: $e');
    }
  }
}
```

## Repository Catalog & Samples

### Interface Overview

| Interface | Primary Entities | Responsibilities | Common Placements |
|-----------|------------------|------------------|-------------------|
| `ProductsRepository` | `Product`, `ProductFilters`, `PaginatedResult<Product>` | Catalog browsing, PDP data, merchandising feeds | Home grids, PDP |
| `CartRepository` | `Cart`, `CartItem` | Cart CRUD, promo codes, shipping costs | Cart drawer, checkout |
| `PostRepository` | `Post` | Blog/news listings and detail pages | Blog plugin |
| `ReviewRepository` | `ProductReview`, `ProductReviewStats` | Product reviews, rating summaries | PDP reviews tab |
| `SearchRepository` | `SearchResult`, `SearchFilters` | Search suggestions, keyword results, facets | Search screens |
| `BannerRepository` | `PromoBanner` | Hero banners, placement-aware promos, view/click tracking | Hero carousel, category headers |
| `PushNotificationRepository` | `PushNotification` | Device registration, topic subscriptions | Notification settings |

Adapters should register implementations for every interface that the active plugins rely on. When in doubt, inspect `widgetRegistry` registrations or plugin READMEs to see which sections pull from which repositories.

### Sample: Registering `BannerRepository`

```dart
class MarketingAdapter extends BackendAdapter {
  @override
  String get name => 'marketing';

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    final dio = Dio(BaseOptions(
      baseUrl: config['baseUrl'] as String,
      headers: {'Authorization': 'Bearer ${config['token']}'},
    ));

    registerRepositoryFactory<BannerRepository>(
      () => MarketingBannerRepository(dio),
    );
  }
}

class MarketingBannerRepository extends BannerRepository {
  MarketingBannerRepository(this._client);

  final Dio _client;

  @override
  Future<List<PromoBanner>> fetchBanners({
    String? placement,
    String? locale,
    Map<String, dynamic>? filters,
  }) async {
    final response = await _client.get<List<dynamic>>(
      '/banners',
      queryParameters: {
        if (placement != null) 'placement': placement,
        if (locale != null) 'locale': locale,
        if (filters != null) ...filters,
      },
    );

    return (response.data ?? const [])
        .whereType<Map<String, dynamic>>()
        .map(PromoBanner.fromJson)
        .toList();
  }

  @override
  Future<void> trackBannerView(String bannerId, {Map<String, dynamic>? metadata}) {
    return _client.post('/banner-events', data: {
      'event': 'view',
      'bannerId': bannerId,
      if (metadata != null) 'metadata': metadata,
    });
  }

  @override
  Future<void> trackBannerClick(String bannerId, {Map<String, dynamic>? metadata}) {
    return _client.post('/banner-events', data: {
      'event': 'click',
      'bannerId': bannerId,
      if (metadata != null) 'metadata': metadata,
    });
  }
}
```

The Flutter `BannerSection` now passes a `sectionKey` (from `settings.key`) so adapters can fetch placement-specific creatives (e.g., `home_hero`, `cart_footer`). Returning `PromoBanner` keeps plugins backend-agnostic while exposing structured `UserInteraction` data, subtitles, metadata, and scheduling info for analytics.

## Adapter Registry

### Registering Multiple Adapters

You can register multiple adapters for different purposes:

```dart
// Pass all adapters to MooseBootstrapper — it registers them with the scoped AdapterRegistry
final report = await MooseBootstrapper(appContext: ctx).run(
  config: config,
  adapters: [
    WooCommerceAdapter(),   // e-commerce operations
    OneSignalAdapter(),     // push notifications
    StripeAdapter(),        // payments
  ],
  plugins: [...],
);
```

### Getting Repositories

```dart
// Get repository (whichever adapter registered it last will supply the instance)
final productsRepo = adapterRegistry.getRepository<ProductsRepository>();

// Check if repository is available
if (adapterRegistry.hasRepository<ProductsRepository>()) {
  final repo = adapterRegistry.getRepository<ProductsRepository>();
}
```

## Best Practices

### DO

```dart
// ✅ Extend CoreRepository
abstract class ProductsRepository extends CoreRepository {
  Future<List<Product>> getProducts();
}

// ✅ Return domain entities
@override
Future<List<Product>> getProducts() async {
  final dtos = await _apiClient.getProducts();
  return dtos.map(_convertToProduct).toList();
}

// ✅ Handle errors gracefully
@override
Future<Product> getProductById(String id) async {
  try {
    final dto = await _apiClient.getProduct(id);
    return _convertToProduct(dto);
  } catch (e) {
    throw RepositoryException('Failed to load product: $e');
  }
}

// ✅ Validate configuration
void _validateConfig(Map<String, dynamic> config) {
  if (!config.containsKey('apiKey')) {
    throw AdapterConfigurationException('Missing apiKey');
  }
}

// ✅ Use factory pattern for registration
registerRepositoryFactory<ProductsRepository>(
  () => MyProductsRepository(_client),
);

// ✅ Override initialize() for setup tasks
@override
void initialize() {
  _setupEventListeners();
  _loadCachedData();  // Fire-and-forget async operation
}

// ✅ Use hookRegistry for transformations
@override
Future<Product> getProductById(String id) async {
  final product = await _apiClient.getProduct(id);
  return hookRegistry.execute('product:transform', product);
}

// ✅ Use eventBus for analytics and notifications
@override
Future<Cart> addToCart(String productId) async {
  final cart = await _apiClient.addToCart(productId);
  eventBus.fire(AppCartItemAddedEvent(...));
  return cart;
}
```

### DON'T

```dart
// ❌ Don't return DTOs
@override
Future<List<ProductDTO>> getProducts() async {  // Wrong!
  return await _apiClient.getProducts();
}

// ❌ Don't put business logic in repositories
@override
Future<List<Product>> getProducts() async {
  final products = await _apiClient.getProducts();
  // ❌ Don't filter or sort here - that's business logic!
  return products.where((p) => p.price > 10).toList();
}

// ❌ Don't directly instantiate - use factories
class BadAdapter extends BackendAdapter {
  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    // ❌ Don't do this
    _productsRepo = WooProductsRepository(_client);
  }
}

// ❌ Don't skip CoreRepository
abstract class ProductsService {  // ❌ Doesn't extend CoreRepository
  Future<List<Product>> getProducts();
}

// ❌ Don't make initialize() async
@override
Future<void> initialize() async {  // ❌ Should be synchronous
  await _loadData();  // This will block the adapter initialization
}

// ❌ Don't await in initialize() - use fire-and-forget
@override
void initialize() {
  _loadData();  // ✅ Correct - triggers async operation without awaiting
}
```

### Error Handling

Define custom exceptions for better error handling:

```dart
class RepositoryException implements Exception {
  final String message;
  RepositoryException(this.message);

  @override
  String toString() => 'RepositoryException: $message';
}

class AdapterConfigurationException implements Exception {
  final String message;
  AdapterConfigurationException(this.message);

  @override
  String toString() => 'AdapterConfigurationException: $message';
}

class AdapterInitializationException implements Exception {
  final String message;
  AdapterInitializationException(this.message);

  @override
  String toString() => 'AdapterInitializationException: $message';
}
```

### Documentation

Document your adapter:

```dart
/// WooCommerce Backend Adapter
///
/// Provides integration with WooCommerce REST API.
///
/// **Required Configuration:**
/// - `baseUrl`: WooCommerce store URL (e.g., 'https://example.com')
/// - `consumerKey`: WooCommerce API consumer key
/// - `consumerSecret`: WooCommerce API consumer secret
///
/// **Optional Configuration:**
/// - `apiVersion`: API version (default: 'wc/v3')
/// - `timeout`: Request timeout in seconds (default: 30)
///
/// **Provided Repositories:**
/// - `ProductsRepository`: Product catalog operations
/// - `CartRepository`: Shopping cart operations
/// - `OrderRepository`: Order management
/// - `CategoryRepository`: Category management
///
/// **Example:**
/// ```dart
/// final adapter = WooCommerceAdapter();
/// await adapter.initialize({
///   'baseUrl': 'https://store.example.com',
///   'consumerKey': 'ck_xxx',
///   'consumerSecret': 'cs_xxx',
/// });
/// ```
class WooCommerceAdapter extends BackendAdapter {
  // ...
}
```

## Testing

### Mock Adapter for Testing

```dart
class MockAdapter extends BackendAdapter {
  @override
  String get name => 'mock';

  @override
  String get version => '1.0.0';

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

class MockProductsRepository extends CoreRepository implements ProductsRepository {
  MockProductsRepository() : super(hookRegistry: HookRegistry(), eventBus: EventBus());

  bool _initialized = false;

  @override
  void initialize() {
    _initialized = true;
  }

  @override
  Future<List<Product>> getProducts(ProductFilters? filters) async {
    return [
      Product(id: '1', name: 'Test Product', price: 10.0),
    ];
  }

  @override
  Future<Product> getProductById(String id) async {
    return Product(id: id, name: 'Test Product', price: 10.0);
  }

  bool get isInitialized => _initialized;
}
```

### Unit Test Adapter

```dart
void main() {
  group('WooCommerceAdapter', () {
    late WooCommerceAdapter adapter;

    setUp(() {
      adapter = WooCommerceAdapter();
    });

    test('initializes successfully with valid config', () async {
      final config = {
        'baseUrl': 'https://test.com',
        'consumerKey': 'ck_test',
        'consumerSecret': 'cs_test',
      };

      await adapter.initialize(config);

      expect(adapter.name, equals('woocommerce'));
      expect(adapter.hasRepository<ProductsRepository>(), isTrue);
    });

    test('throws on missing configuration', () async {
      final config = {'baseUrl': 'https://test.com'};

      expect(
        () => adapter.initialize(config),
        throwsA(isA<AdapterConfigurationException>()),
      );
    });

    test('provides ProductsRepository', () async {
      final config = {
        'baseUrl': 'https://test.com',
        'consumerKey': 'ck_test',
        'consumerSecret': 'cs_test',
      };

      await adapter.initialize(config);

      final repo = adapter.getRepository<ProductsRepository>();
      expect(repo, isA<ProductsRepository>());
    });

    test('repository initialize is called automatically', () async {
      final config = {
        'baseUrl': 'https://test.com',
        'consumerKey': 'ck_test',
        'consumerSecret': 'cs_test',
      };

      await adapter.initialize(config);

      final repo = adapter.getRepository<MockProductsRepository>();
      expect(repo.isInitialized, isTrue);
    });

    test('cached repositories are not re-initialized', () async {
      final config = {
        'baseUrl': 'https://test.com',
        'consumerKey': 'ck_test',
        'consumerSecret': 'cs_test',
      };

      await adapter.initialize(config);

      final repo1 = adapter.getRepository<ProductsRepository>();
      final repo2 = adapter.getRepository<ProductsRepository>();

      expect(identical(repo1, repo2), isTrue);
    });
  });
}
```

## Example Adapters

### Shopify Adapter

```dart
class ShopifyAdapter extends BackendAdapter {
  @override
  String get name => 'shopify';

  @override
  String get version => '1.1.0';

  @override
  Map<String, dynamic> get configSchema => {
        'type': 'object',
        'required': ['storeUrl', 'storefrontAccessToken'],
        'properties': {
          'storeUrl': {'type': 'string', 'format': 'uri'},
          'storefrontAccessToken': {'type': 'string', 'minLength': 1},
          'apiVersion': {'type': 'string', 'default': '2024-01'},
        },
      };

  @override
  Map<String, dynamic> getDefaultSettings() => {
        'apiVersion': '2024-01',
      };

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    final client = ShopifyApiClient(
      storeUrl: config['storeUrl'] as String,
      accessToken: config['storefrontAccessToken'] as String,
      apiVersion: config['apiVersion'] as String,
    );

    registerRepositoryFactory<ProductsRepository>(
      () => ShopifyProductsRepository(client),
    );

    registerRepositoryFactory<CartRepository>(
      () => ShopifyCartRepository(client),
    );
  }
}

// main.dart — pass via MooseBootstrapper
final report = await MooseBootstrapper(appContext: ctx).run(
  config: config,
  adapters: [ShopifyAdapter()],  // initializeFromConfig() called automatically
  plugins: [...],
);
```

### Custom REST API Adapter

```dart
class CustomApiAdapter extends BackendAdapter {
  @override
  String get name => 'custom_api';

  @override
  String get version => '1.0.0';

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    final client = HttpClient(
      baseUrl: config['apiUrl'],
      headers: {
        'Authorization': 'Bearer ${config['apiToken']}',
      },
    );

    registerRepositoryFactory<ProductsRepository>(
      () => CustomProductsRepository(client),
    );
  }
}
```

## Related Documentation

- **[ARCHITECTURE.md](./ARCHITECTURE.md)** - Overall architecture
- **[PLUGIN_SYSTEM.md](./PLUGIN_SYSTEM.md)** - Creating plugins
- **[ANTI_PATTERNS.md](./ANTI_PATTERNS.md)** - What to avoid

---

**Last Updated:** 2026-02-26
**Version:** 4.0.0

**Changelog:**
- **v4.0.0 (2026-02-26)**: `initializeFromConfig()` now requires `configManager:` (named, required) — no global fallback. `AdapterRegistry` registers lazy factories only; no repo instances created during adapter registration. `MooseAppContext.getRepository<T>()` convenience shortcut added.
- **v3.0.0 (2026-02-22)**: `CoreRepository` requires `hookRegistry`/`eventBus` constructor params. `AdapterRegistry()` singleton removed — use `MooseBootstrapper` or `appContext.adapterRegistry`.
