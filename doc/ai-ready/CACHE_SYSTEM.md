# Cache System

## Overview

`moose_core` provides a two-tier cache system through `CacheManager`:

- **`MemoryCache`** — In-process, in-memory cache with TTL, eviction policies, and statistics. Fast; cleared on app restart.
- **`PersistentCache`** — `SharedPreferences`-backed persistent storage. Survives app restarts; must be initialized before use.

`CacheManager` is owned by `MooseAppContext`. There is no global singleton — two `MooseAppContext` instances never share cache data.

---

## Accessing the Cache

```dart
// From a FeaturePlugin or BackendAdapter (via injected appContext)
final cacheManager = appContext.cache;          // CacheManager
final memory = appContext.cache.memory;         // MemoryCache
final disk = appContext.cache.persistent;       // PersistentCache

// From a BackendAdapter (convenience getter on BackendAdapter base class)
cacheManager.memory.set('key', value);

// From a widget
final cache = context.moose.cache;             // via MooseScope
final cache = MooseScope.cacheOf(context);     // static accessor
```

---

## CacheManager API

```dart
class CacheManager {
  MemoryCache get memory;
  PersistentCache get persistent;

  /// Initialize persistent cache. Must be called before using persistent.get<T>().
  Future<void> initPersistent();

  /// Clears both caches.
  Future<void> clearAll();

  /// Clears only the in-memory cache.
  void clearMemory();

  /// Clears only the persistent cache.
  Future<void> clearPersistent();

  /// Disposes the memory cache (stops auto-cleanup timer).
  void dispose();
}
```

`MooseBootstrapper.run()` calls `initPersistent()` automatically. In tests or custom setups, call it manually before using `persistent.get<T>()`.

---

## MemoryCache

### Configuration

```dart
// Default configuration (applied automatically by MooseAppContext)
memory.configure(
  maxSize: 1000,                        // max entries
  maxMemoryBytes: 50 * 1024 * 1024,    // 50 MB
  evictionPolicy: EvictionPolicy.lru,
  cleanupInterval: Duration(minutes: 1),
);
```

Reconfigure at any time with `configure()`. All previously cached entries remain.

### Core API

```dart
// Store with optional TTL
void set<T>(String key, T value, {Duration? ttl});

// Retrieve (returns null if absent or expired)
T? get<T>(String key);

// Check existence (without triggering eviction stats)
bool has(String key);

// Remove an entry
void remove(String key);

// Remove all entries
void clear();

// Get with fallback default (does not cache the default)
T getOrDefault<T>(String key, T defaultValue);

// Get or compute and cache (atomic fetch-or-store)
T getOrSet<T>(String key, T Function() compute, {Duration? ttl});
```

#### `getOrSet` — preferred pattern for expensive lookups

```dart
final products = cacheManager.memory.getOrSet(
  'products:featured',
  () => _fetchProductsFromApi(),
  ttl: const Duration(minutes: 5),
);
```

If `key` exists and is not expired, returns the cached value. Otherwise calls `compute()`, stores the result, and returns it.

### Bulk Operations

```dart
void setAll(Map<String, dynamic> entries, {Duration? ttl});
void removeAll(List<String> keys);
Map<String, dynamic> getAll(List<String> keys); // returns only present, non-expired entries
```

### TTL Management

```dart
// Remaining TTL for a key; null if no TTL or key absent
Duration? getRemainingTTL(String key);

// Reset TTL to original value; returns false if key not found
bool refreshTTL(String key);
```

### Evict and Return

```dart
// Remove a key and return its value (null if absent)
T? pop<T>(String key);
```

### Updating Entries

```dart
// Update an existing entry in-place; no-op if key is absent
void update<T>(String key, T Function(T current) updater);
```

### Maintenance

```dart
// Remove all expired entries immediately
void cleanExpired();

// Manually trigger cleanup (same as cleanExpired but also resets the timer)
void cleanup();

// Stop the background auto-cleanup timer
void stopAutoCleanup();

// Dispose the cache (calls stopAutoCleanup)
void dispose();
```

### Statistics

```dart
CacheStats get stats;
void resetStats();
void printStats(); // prints to debug console
```

`CacheStats` fields:

```dart
class CacheStats {
  int size;               // current entry count
  int maxSize;            // configured max entries
  int hits;
  int misses;
  int evictions;
  int expirations;
  int estimatedMemoryBytes;
  double hitRate;          // hits / (hits + misses)
  double estimatedMemoryMB;
}
```

### Introspection Getters

```dart
int get size;
bool get isEmpty;
bool get isNotEmpty;
int get maxSize;
int get maxMemoryBytes;
EvictionPolicy get evictionPolicy;
List<String> get keys; // snapshot of current keys
```

### Eviction Policies

| Policy | Description | Best For |
|--------|-------------|----------|
| `EvictionPolicy.lru` | Evicts least recently used | General purpose (default) |
| `EvictionPolicy.lfu` | Evicts least frequently used | Data with a stable hot set |
| `EvictionPolicy.fifo` | Evicts oldest inserted entry | Time-ordered data |

```dart
memory.configure(evictionPolicy: EvictionPolicy.lfu);
```

---

## PersistentCache

Backed by `SharedPreferences`. All write operations are async. The generic `get<T>()` is **synchronous** — it reads from an in-memory snapshot loaded during `init()`. Always call `initPersistent()` (or `await persistent.init()`) before calling `get<T>()`.

### Initialization

```dart
// Done automatically by MooseBootstrapper. In tests or custom setups:
await appContext.cache.initPersistent();
// or directly:
await appContext.cache.persistent.init();
```

### Generic Read (Synchronous)

```dart
// Synchronous after init(); returns null if key is absent
T? get<T>(String key);
```

### Typed Async Reads

These read directly from `SharedPreferences` and return a `Future`:

```dart
Future<String?>           getString(String key);
Future<int?>              getInt(String key);
Future<double?>           getDouble(String key);
Future<bool?>             getBool(String key);
Future<List<String>?>     getStringList(String key);
Future<Map<String, dynamic>?> getJson(String key);
```

### Generic Write

```dart
// Auto-detects type: String, int, double, bool, List<String>, Map<String, dynamic>
Future<void> set(String key, dynamic value);
```

### Typed Async Writes

```dart
Future<void> setString(String key, String value);
Future<void> setInt(String key, int value);
Future<void> setDouble(String key, double value);
Future<void> setBool(String key, bool value);
Future<void> setStringList(String key, List<String> value);
Future<void> setJson(String key, Map<String, dynamic> value);
```

### Bulk Operations

```dart
Future<void> setAll(Map<String, dynamic> entries);
Future<void> removeAll(List<String> keys);
```

### Other Operations

```dart
// Get with fallback; does not persist the default
Future<T?> getOrDefault<T>(String key, T defaultValue);

bool has(String key);               // synchronous, reads from snapshot
Future<void> remove(String key);
Future<void> clear();
List<String> get keys;             // synchronous snapshot of current keys

// Re-load in-memory snapshot from SharedPreferences
Future<void> reload();
```

---

## Decision Matrix

| Scenario | Cache Type |
|----------|------------|
| API response caching | `memory` |
| Session tokens | `memory` |
| Computed / derived values | `memory` |
| Cart ID (session-scoped) | `memory` |
| User preferences / settings | `persistent` |
| App theme / language | `persistent` |
| Search history | `persistent` |
| Favourites / wishlist | `persistent` |

---

## Common Patterns

### Cache-aside in a BackendAdapter

```dart
class MyAdapter extends BackendAdapter {
  @override
  Future<List<Product>> fetchProducts() async {
    const key = 'products:all';
    final cached = cacheManager.memory.get<List<Product>>(key);
    if (cached != null) return cached;

    final products = await apiClient.get('/products');
    cacheManager.memory.set(key, products, ttl: const Duration(minutes: 5));
    return products;
  }
}
```

Or concisely with `getOrSet`:

```dart
return cacheManager.memory.getOrSet(
  'products:all',
  () => apiClient.get('/products'),
  ttl: const Duration(minutes: 5),
);
```

### User preferences in PersistentCache

```dart
// Write
await cacheManager.persistent.setBool('notifications_enabled', true);

// Synchronous read (requires prior initPersistent())
final enabled = cacheManager.persistent.get<bool>('notifications_enabled') ?? true;
```

### Invalidate on mutation

```dart
Future<void> updateProduct(Product product) async {
  await apiClient.put('/products/${product.id}', product.toJson());
  cacheManager.memory.remove('products:all');
  cacheManager.memory.remove('product:${product.id}');
}
```

### Namespace keys by adapter

```dart
// Prefix keys with the adapter name to avoid collisions across adapters
final key = '${name}:catalog:$categoryId';
cacheManager.memory.set(key, data, ttl: const Duration(minutes: 10));
```

### Clear cache on user sign-out

```dart
Future<void> onUserSignOut() async {
  await appContext.cache.clearAll();
}
```

### Debug monitoring

```dart
assert(() {
  cacheManager.memory.printStats();
  return true;
}());
```

---

## Lifecycle Integration

- `MooseBootstrapper.run()` calls `cacheManager.initPersistent()` automatically — no manual call needed.
- `MooseScope.dispose()` calls `cacheManager.dispose()`, which stops the memory auto-cleanup timer.
- `BackendAdapter` receives `cacheManager` via `appContext` injected by `AdapterRegistry` during `initializeFromConfig()`.
- `FeaturePlugin` receives `appContext` (including `appContext.cache`) after `PluginRegistry.register()` injects it.

---

## Testing

`MemoryCache` is a plain Dart class with no Flutter binding dependency. For `PersistentCache`, use `SharedPreferences.setMockInitialValues({})`.

```dart
setUp(() async {
  SharedPreferences.setMockInitialValues({});
  final ctx = MooseAppContext();
  await ctx.cache.initPersistent();
});

tearDown(() {
  appContext.cache.memory.clear();
  appContext.cache.memory.stopAutoCleanup();
});
```

Shrink limits in unit tests:

```dart
appContext.cache.memory.configure(
  maxSize: 10,
  cleanupInterval: const Duration(seconds: 1),
);
```

---

## Architecture Notes

- `CacheManager` is instantiated by `MooseAppContext`; one instance per app context — never construct it directly in production code.
- Never store `CacheManager` in a static field. Always access through `appContext.cache` or the convenience getter on `BackendAdapter`/`FeaturePlugin`.
- Cache keys are plain strings. Use a consistent naming convention (e.g., `<adapter>:<entity>:<id>`) to prevent collisions between adapters or plugins.
- `MemoryCache.dispose()` is called by `CacheManager.dispose()` — do not call it directly.

---

## Related Documentation

- [ADAPTER_SYSTEM.md](ADAPTER_SYSTEM.md)
- [PLUGIN_SYSTEM.md](PLUGIN_SYSTEM.md)
- [PLUGIN_ADAPTER_CONFIG_GUIDE.md](PLUGIN_ADAPTER_CONFIG_GUIDE.md)
- [ADAPTER_SCHEMA_VALIDATION.md](ADAPTER_SCHEMA_VALIDATION.md)
