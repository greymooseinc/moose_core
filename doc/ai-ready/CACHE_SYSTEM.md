# Cache System Guide

> Complete guide to caching in moose_core

## Overview

The moose_core package provides a scoped, fully instance-based caching system.
Every `MooseAppContext` owns its own `CacheManager`, which in turn owns
independent `MemoryCache` and `PersistentCache` instances.

**There is no static or singleton state.** Two `MooseAppContext` instances never
share cache data.

## Cache Components

### CacheManager

Owned by `MooseAppContext`. Exposes two properties:

| Property | Type | Description |
|---|---|---|
| `memory` | `MemoryCache` | Fast in-memory, session-scoped storage |
| `persistent` | `PersistentCache` | SharedPreferences-backed, survives restarts |

Access via `appContext.cache` or `context.moose.cache` in widgets.

```dart
// Direct access
appContext.cache.memory.set('key', value);
await appContext.cache.persistent.setString('pref', 'value');

// Widget tree
context.moose.cache.memory.get<String>('key');
```

### MemoryCache

In-memory cache with TTL support, eviction policies, and statistics.

```dart
void set(String key, dynamic value, {Duration? ttl})
T? get<T>(String key)
bool has(String key)
void remove(String key)
void clear()
void dispose()  // stops the cleanup timer
```

### PersistentCache

Disk-based cache using SharedPreferences.

```dart
Future<void> init()
Future<bool> setString(String key, String value)
Future<String?> getString(String key)
Future<bool> has(String key)
Future<bool> remove(String key)
Future<bool> clear()
```

## Accessing the Cache

### From a widget

```dart
// via BuildContext
final cache = context.moose.cache;
cache.memory.set('api_response', data, ttl: const Duration(minutes: 5));
final data = cache.memory.get<List<Product>>('api_response');

// static accessor
final cache = MooseScope.cacheOf(context);
```

### From MooseAppContext directly

```dart
appContext.cache.memory.set('key', value);
await appContext.cache.persistent.setString('theme', 'dark');
```

## Bootstrap Initialization

`MooseBootstrapper.run()` automatically calls `appContext.cache.initPersistent()`
before adapters are registered. No manual initialization is needed.

```dart
// ✅ No manual CacheManager.initPersistentCache() call needed
final report = await MooseBootstrapper(appContext: appContext).run(
  config: config,
  adapters: [MyAdapter()],
  plugins: [() => MyPlugin()],
);
```

## Usage Examples

### Basic Memory Caching

```dart
final cache = appContext.cache;

// Store with 5-minute TTL
cache.memory.set('products:featured', products, ttl: const Duration(minutes: 5));

// Retrieve
final cached = cache.memory.get<List<Product>>('products:featured');
if (cached != null) {
  return cached;
}

// Miss — fetch and store
final products = await repository.getProducts();
cache.memory.set('products:featured', products, ttl: const Duration(minutes: 5));
return products;
```

### Persistent Caching

```dart
final cache = appContext.cache;

// Store user preference
await cache.persistent.setString('theme', 'dark');

// Retrieve
final theme = await cache.persistent.getString('theme') ?? 'light';
```

### Cache Invalidation

```dart
// Remove specific key
appContext.cache.memory.remove('products:featured');

// Clear all memory
appContext.cache.clearMemory();

// Clear all persistent
await appContext.cache.clearPersistent();

// Clear both
await appContext.cache.clearAll();
```

### Repository with Caching

```dart
class CachedProductsRepository implements ProductsRepository {
  final ProductsRepository _source;
  final MemoryCache _cache;

  CachedProductsRepository(this._source, this._cache);

  @override
  Future<List<Product>> getProducts(ProductFilters? filters) async {
    final key = 'products:${filters?.hashCode ?? "all"}';
    final cached = _cache.get<List<Product>>(key);
    if (cached != null) return cached;

    final products = await _source.getProducts(filters);
    _cache.set(key, products, ttl: const Duration(minutes: 5));
    return products;
  }
}
```

## MemoryCache Configuration

```dart
appContext.cache.memory.configure(
  maxSize: 1000,
  maxMemoryBytes: 50 * 1024 * 1024, // 50MB
  evictionPolicy: EvictionPolicy.lru,
  cleanupInterval: const Duration(minutes: 1),
);
```

**Eviction Policies:**
- `EvictionPolicy.lru` — Least Recently Used (default, recommended)
- `EvictionPolicy.lfu` — Least Frequently Used
- `EvictionPolicy.fifo` — First In First Out

## Cache Statistics

```dart
final stats = appContext.cache.memory.stats;
print(stats.hitRate);           // 0.0 – 1.0
print(stats.estimatedMemoryMB); // "2.34"
print(stats.evictions);
```

## Best Practices

```dart
// ✅ Use memory cache for session-scoped data
appContext.cache.memory.set('api_temp', data, ttl: const Duration(minutes: 5));

// ✅ Use persistent cache for user preferences
await appContext.cache.persistent.setString('theme', 'dark');

// ✅ Always dispose cache when context is torn down
appContext.cache.dispose();

// ❌ Do not use old static API
CacheManager.memoryCacheInstance(); // removed
CacheManager.persistentCacheInstance(); // removed

// ❌ Do not construct MemoryCache() / PersistentCache() directly outside tests
final cache = MemoryCache(); // bypass DI — use appContext.cache.memory instead
```

## Decision Matrix

| Scenario | Cache Type |
|---|---|
| API response caching | `memory` |
| Session tokens | `memory` |
| User preferences / settings | `persistent` |
| Search history | `persistent` |
| App theme / language | `persistent` |
| Computed values | `memory` |
| Cart ID (session) | `memory` |
| Favourites / wishlist | `persistent` |

## Testing

Inject a custom `CacheManager` or individual caches for full isolation:

```dart
final customCache = CacheManager(
  memory: MemoryCache(),
  persistent: PersistentCache(),
);
final ctx = MooseAppContext(cache: customCache);

// Each test context is fully isolated — no shared state
```

## Related Documentation

- [ARCHITECTURE.md](./ARCHITECTURE.md) — Overall architecture
- [ADAPTER_SYSTEM.md](./ADAPTER_SYSTEM.md) — Repository pattern
- [AI_CACHE_GUIDE.md](./AI_CACHE_GUIDE.md) — AI agent quick reference

---

**Last Updated:** 2026-02-26
**Version:** 1.2.0
