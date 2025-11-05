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

  /// Initialize the adapter with configuration
  Future<void> initialize(Map<String, dynamic> config);
}
```

### CoreRepository Base Class

All repository interfaces must extend `CoreRepository`:

```dart
/// Base class for all repositories
/// Ensures consistent contract across all repositories
abstract class CoreRepository {
  /// Dispose resources when repository is no longer needed
  void dispose() {}
}
```

## Creating a Custom Adapter

### Step 1: Define Repository Interfaces

```dart
// In core package
abstract class ProductsRepository extends CoreRepository {
  Future<List<Product>> getProducts(ProductFilters? filters);
  Future<Product> getProductById(String id);
  Future<List<Category>> getCategories();
}

abstract class CartRepository extends CoreRepository {
  Future<Cart> getCart();
  Future<Cart> addToCart(String productId, int quantity);
  Future<Cart> updateCartItem(String itemId, int quantity);
  Future<void> clearCart();
}
```

### Step 2: Implement Repository Classes

```dart
// In your adapter package/directory
class WooProductsRepository implements ProductsRepository {
  final WooCommerceApiClient _apiClient;

  WooProductsRepository(this._apiClient);

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
  void dispose() {
    // Clean up resources if needed
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

### Step 4: Register with AdapterRegistry

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Load configuration
  final config = await loadConfiguration();

  final adapterRegistry = AdapterRegistry();

  // Register WooCommerce adapter
  await adapterRegistry.registerAdapter(() async {
    final adapter = WooCommerceAdapter();
    await adapter.initialize(config['woocommerce']);
    return adapter;
  });

  runApp(MyApp(adapterRegistry: adapterRegistry));
}
```

## Repository Factory Pattern

### Lazy Initialization

Repositories are only created when first accessed:

```dart
// First access - repository is created
final productsRepo = adapter.getRepository<ProductsRepository>();

// Second access - cached repository is returned
final productsRepo2 = adapter.getRepository<ProductsRepository>();

assert(identical(productsRepo, productsRepo2));  // Same instance
```

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

## Adapter Registry

### Registering Multiple Adapters

You can register multiple adapters for different purposes:

```dart
final adapterRegistry = AdapterRegistry();

// Register WooCommerce for e-commerce operations
await adapterRegistry.registerAdapter(() async {
  final adapter = WooCommerceAdapter();
  await adapter.initialize(config['woocommerce']);
  return adapter;
});

// Register OneSignal for push notifications
await adapterRegistry.registerAdapter(() async {
  final adapter = OneSignalAdapter();
  await adapter.initialize(config['onesignal']);
  return adapter;
});

// Register Stripe for payments
await adapterRegistry.registerAdapter(() async {
  final adapter = StripeAdapter();
  await adapter.initialize(config['stripe']);
  return adapter;
});
```

### Getting Repositories

```dart
// Get repository from active adapter
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

class MockProductsRepository implements ProductsRepository {
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

  @override
  void dispose() {}
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
  String get version => '1.0.0';

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    final client = ShopifyApiClient(
      storeUrl: config['storeUrl'],
      accessToken: config['accessToken'],
    );

    registerRepositoryFactory<ProductsRepository>(
      () => ShopifyProductsRepository(client),
    );

    registerRepositoryFactory<CartRepository>(
      () => ShopifyCartRepository(client),
    );
  }
}
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

**Last Updated:** 2025-11-03
**Version:** 1.0.0
