# Cache System Guide

> Complete guide to caching in moose_core

## Overview

The moose_core package provides a flexible caching system with memory and persistent storage options.

## Cache Components

### CacheManager

Central manager for all caching operations:

```dart
class CacheManager {
  static MemoryCache memory = MemoryCache();
  static PersistentCache? persistent;

  /// Initialize persistent cache (call once on app start)
  static Future<void> initPersistentCache() async {
    persistent = PersistentCache();
    await persistent!.init();
  }
}
```

### MemoryCache

In-memory cache with TTL support:

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

Disk-based cache using shared_preferences:

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

## Usage Examples

### Basic Memory Caching

```dart
// Store in memory with 5 minute TTL
CacheManager.memory.set(
  'products:featured',
  products,
  ttl: Duration(minutes: 5),
);

// Retrieve from memory
final cached = CacheManager.memory.get<List<Product>>('products:featured');
if (cached != null) {
  return cached;  // Use cached data
}

// Data not in cache or expired - fetch fresh
final products = await repository.getProducts();
CacheManager.memory.set('products:featured', products);
return products;
```

### Persistent Caching

```dart
// Initialize on app start
await CacheManager.initPersistentCache();

// Store persistently
await CacheManager.persistent?.set('user:token', authToken);

// Retrieve from persistent storage
final token = CacheManager.persistent?.get<String>('user:token');
```

### Repository with Caching

```dart
class CachedProductsRepository implements ProductsRepository {
  final ProductsRepository _repository;

  CachedProductsRepository(this._repository);

  @override
  Future<List<Product>> getProducts(ProductFilters? filters) async {
    final cacheKey = 'products:${filters?.hashCode ?? "all"}';

    // Try memory cache first
    final cached = CacheManager.memory.get<List<Product>>(cacheKey);
    if (cached != null) {
      return cached;
    }

    // Fetch from repository
    final products = await _repository.getProducts(filters);

    // Cache for 5 minutes
    CacheManager.memory.set(
      cacheKey,
      products,
      ttl: Duration(minutes: 5),
    );

    return products;
  }
}
```

### Cache Invalidation

```dart
// Clear specific cache
CacheManager.memory.remove('products:featured');

// Clear all memory cache
CacheManager.memory.clear();

// Clear all persistent cache
await CacheManager.persistent?.clear();

// Clear cache on data mutation
class ProductsBloc extends Bloc<ProductsEvent, ProductsState> {
  Future<void> _onUpdateProduct(...) async {
    await repository.updateProduct(product);

    // Invalidate cache
    CacheManager.memory.remove('products:${product.id}');
    CacheManager.memory.remove('products:all');

    emit(ProductUpdated(product));
  }
}
```

## Configuration

Configure cache TTL in your configuration:

```json
{
  "plugins": {
    "products": {
      "cache": {
        "productsTTL": 300,
        "categoriesTTL": 600,
        "searchTTL": 120
      }
    }
  }
}
```

Access in code:

```dart
final ttl = ConfigManager().get(
  'plugins:products:settings:cache:productsTTL',
  defaultValue: 300,
) as int;

CacheManager.memory.set(
  'products:all',
  products,
  ttl: Duration(seconds: ttl),
);
```

## Best Practices

### DO

```dart
// ✅ Use memory cache for frequently accessed data
CacheManager.memory.set('categories', categories, ttl: Duration(minutes: 10));

// ✅ Use persistent cache for user data
await CacheManager.persistent?.set('user:preferences', preferences);

// ✅ Set appropriate TTLs
CacheManager.memory.set('data', value, ttl: Duration(minutes: 5));

// ✅ Invalidate cache on mutations
await repository.updateData(data);
CacheManager.memory.remove('data:key');

// ✅ Use consistent key naming
'plugin:resource:identifier'  // e.g., 'products:featured:home'
```

### DON'T

```dart
// ❌ Don't cache forever
CacheManager.memory.set('data', value);  // No TTL!

// ❌ Don't cache sensitive data in memory
CacheManager.memory.set('user:password', password);  // Use persistent + encryption

// ❌ Don't forget to initialize persistent cache
CacheManager.persistent?.set('key', value);  // May be null!

// ❌ Don't use inconsistent keys
'prod123'  // Use 'products:123'
'cat_featured'  // Use 'categories:featured'
```

## Cache Strategies

### Cache-Aside (Lazy Loading)

```dart
Future<Product> getProduct(String id) async {
  // Try cache first
  final cached = CacheManager.memory.get<Product>('products:$id');
  if (cached != null) return cached;

  // Load from source
  final product = await _repository.getProductById(id);

  // Store in cache
  CacheManager.memory.set('products:$id', product, ttl: Duration(minutes: 5));

  return product;
}
```

### Write-Through

```dart
Future<void> updateProduct(Product product) async {
  // Update in repository
  await _repository.updateProduct(product);

  // Update cache immediately
  CacheManager.memory.set('products:${product.id}', product);
}
```

### Cache Warming

```dart
Future<void> warmCache() async {
  // Preload frequently accessed data
  final featured = await _repository.getFeaturedProducts();
  CacheManager.memory.set('products:featured', featured);

  final categories = await _repository.getCategories();
  CacheManager.memory.set('categories:all', categories);
}
```

## Testing

### Mock Cache

```dart
class MockMemoryCache implements MemoryCache {
  final Map<String, dynamic> _cache = {};

  @override
  void set<T>(String key, T value, {Duration? ttl}) {
    _cache[key] = value;
  }

  @override
  T? get<T>(String key) {
    return _cache[key] as T?;
  }

  @override
  bool has(String key) => _cache.containsKey(key);

  @override
  void remove(String key) => _cache.remove(key);

  @override
  void clear() => _cache.clear();
}
```

### Test Cache Behavior

```dart
void main() {
  setUp(() {
    CacheManager.memory.clear();
  });

  test('caches products correctly', () {
    final products = [Product(id: '1', name: 'Test')];

    CacheManager.memory.set('products:all', products);

    final cached = CacheManager.memory.get<List<Product>>('products:all');
    expect(cached, equals(products));
  });

  test('respects TTL', () async {
    CacheManager.memory.set(
      'test:key',
      'value',
      ttl: Duration(milliseconds: 100),
    );

    expect(CacheManager.memory.get('test:key'), equals('value'));

    await Future.delayed(Duration(milliseconds: 150));

    expect(CacheManager.memory.get('test:key'), isNull);
  });
}
```

## Related Documentation

- **[ARCHITECTURE.md](./ARCHITECTURE.md)** - Overall architecture
- **[ADAPTER_PATTERN.md](./ADAPTER_PATTERN.md)** - Repository pattern

---

**Last Updated:** 2025-11-03
**Version:** 1.0.0
