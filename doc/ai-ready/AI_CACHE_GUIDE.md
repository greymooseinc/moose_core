# Cache Management Guide for AI Agents

## Overview

moose_core uses a **scoped, instance-based** caching system. Every
`MooseAppContext` owns an independent `CacheManager` containing a
`MemoryCache` and a `PersistentCache`. There is **no global or static state**.

## Quick Reference

```dart
import 'package:moose_core/app.dart';
import 'package:moose_core/cache.dart';

// From MooseAppContext
appContext.cache.memory.set('key', value);
appContext.cache.memory.get<String>('key');

await appContext.cache.persistent.setString('pref', 'value');
await appContext.cache.persistent.getString('pref');

// From widget tree
context.moose.cache.memory.set('key', value);
```

## MemoryCache

### When to Use
- API response caching (with TTL)
- Computed values expensive to recalculate
- Session state (tokens that expire with the process)
- Temporary UI state

### Features
- **Synchronous** — no `await` needed
- **TTL Support** — auto-expiration
- **Eviction Policies** — LRU (default), LFU, FIFO
- **Memory Limits** — configurable max size and bytes
- **Auto-cleanup timer** — periodic removal of expired entries
- **Statistics** — hit rate, memory usage, evictions
- **Instance-scoped** — no singleton, owned by `MooseAppContext`

### Configuration

```dart
appContext.cache.memory.configure(
  maxSize: 1000,
  maxMemoryBytes: 50 * 1024 * 1024,      // 50MB
  evictionPolicy: EvictionPolicy.lru,
  cleanupInterval: const Duration(minutes: 1),
);
```

### Usage Examples

```dart
final mem = appContext.cache.memory;

// Store with TTL
mem.set('api_response', data, ttl: const Duration(minutes: 5));

// Retrieve (null if missing or expired)
final cached = mem.get<List<Product>>('api_response');

// Check existence
if (mem.has('user_token')) { ... }

// Remove / clear
mem.remove('user_token');
mem.clear();

// Get with default
final username = mem.getOrDefault<String>('username', 'Guest');

// Update preserving TTL
mem.update('counter', newValue);

// Pop (get and remove)
final token = mem.pop<String>('one_time_token');

// TTL management
final remaining = mem.getRemainingTTL('api_response');
mem.refreshTTL('api_response', const Duration(minutes: 10));

// Statistics
final stats = mem.stats;
print('Hit rate: ${stats.hitRate * 100}%');
print('Memory: ${stats.estimatedMemoryMB} MB');
```

## PersistentCache

### When to Use
- User preferences and settings
- Authentication tokens that survive restarts
- Search history
- Favourites / wishlist
- App theme / language

### Features
- **Asynchronous** — use `await` for all operations
- **Persistent** — survives app restarts
- **Type-specific methods** — `setString()`, `setInt()`, `setBool()`, etc.
- **JSON support** — store complex objects
- **Instance-scoped** — no singleton

### Initialization

`MooseBootstrapper` calls `appContext.cache.initPersistent()` automatically.
No manual initialization in `main()` is required.

### Usage Examples

```dart
final pers = appContext.cache.persistent;

// String
await pers.setString('username', 'john_doe');
final username = await pers.getString('username');

// Int / double / bool
await pers.setInt('user_id', 12345);
await pers.setBool('notifications', true);

// String list
await pers.setStringList('search_history', ['q1', 'q2']);
final history = await pers.getStringList('search_history');

// JSON
await pers.setJson('profile', {'name': 'John', 'age': 30});
final profile = await pers.getJson<Map<String, dynamic>>('profile');

// Check / remove / clear
if (await pers.has('username')) { ... }
await pers.remove('username');
await pers.clear();

// Default
final theme = await pers.getOrDefault<String>('theme', 'light');
```

## Bootstrap

```dart
// MooseBootstrapper handles init automatically:
final report = await MooseBootstrapper(appContext: appContext).run(
  config: config,
  adapters: [MyAdapter()],
  plugins: [() => MyPlugin()],
);

// ❌ Do NOT manually call CacheManager.initPersistentCache() — removed
```

## Decision Matrix

| Scenario | Cache |
|---|---|
| API response caching | `memory` |
| Session token / nonce | `memory` |
| User preferences | `persistent` |
| Search history | `persistent` |
| Shopping cart ID (session) | `memory` |
| Auth token (survive restarts) | `persistent` |
| Computed values | `memory` |
| App theme / language | `persistent` |

## Best Practices

### 1. Always Access via `appContext.cache`

```dart
// ✅ Scoped access
appContext.cache.memory.set('key', value);
context.moose.cache.persistent.setString('pref', 'v');

// ❌ Do NOT construct directly (bypasses DI)
final cache = MemoryCache();           // outside tests
final cache = CacheManager.memoryCacheInstance(); // removed
```

### 2. Configure Memory Limits

```dart
appContext.cache.memory.configure(
  maxSize: 1000,
  maxMemoryBytes: 50 * 1024 * 1024,
  evictionPolicy: EvictionPolicy.lru,
);
```

### 3. Use Appropriate TTLs

```dart
// ✅ Frequently-changing data — short TTL
mem.set('product_prices', prices, ttl: const Duration(minutes: 2));

// ✅ Rarely-changing data — longer TTL
mem.set('product_details', details, ttl: const Duration(hours: 1));

// ❌ No TTL for volatile data
mem.set('prices', prices); // stays forever until evicted
```

### 4. Await Async Operations

```dart
// ❌
appContext.cache.persistent.setString('key', 'value');

// ✅
await appContext.cache.persistent.setString('key', 'value');
```

### 5. Dispose Cache in Tests

```dart
final ctx = MooseAppContext();
// ... test code ...
ctx.cache.dispose(); // stops the MemoryCache cleanup timer
```

### 6. Use Two Contexts to Prove Isolation

```dart
final ctx1 = MooseAppContext();
final ctx2 = MooseAppContext();

ctx1.cache.memory.set('key', 'a');
ctx2.cache.memory.get<String>('key'); // null — fully isolated
```

## Monitoring

```dart
final stats = appContext.cache.memory.stats;

if (stats.hitRate < 0.5) {
  print('Low hit rate: ${stats.hitRate * 100}%');
}
if (stats.estimatedMemoryBytes > 45 * 1024 * 1024) {
  appContext.cache.memory.cleanup();
}
```

## Testing with Injected Cache

```dart
final mem = MemoryCache();
final pers = PersistentCache();
final customCache = CacheManager(memory: mem, persistent: pers);
final ctx = MooseAppContext(cache: customCache);

// Full isolation — no shared state between tests
```

## API Reference

### CacheManager

```dart
CacheManager({MemoryCache? memory, PersistentCache? persistent})

MemoryCache memory
PersistentCache persistent

Future<void> initPersistent()
Future<void> clearAll()
void clearMemory()
Future<bool> clearPersistent()
void dispose()
```

### MemoryCache

```dart
void set(String key, dynamic value, {Duration? ttl})
T? get<T>(String key)
T getOrDefault<T>(String key, T defaultValue)
bool has(String key)
void remove(String key)
void clear()
void update(String key, dynamic value)
T? pop<T>(String key)
Duration? getRemainingTTL(String key)
bool refreshTTL(String key, Duration ttl)
void cleanExpired()
void cleanup()
void configure({int? maxSize, int? maxMemoryBytes, EvictionPolicy? evictionPolicy, Duration? cleanupInterval})
CacheStats get stats
void resetStats()
void dispose()
```

### PersistentCache

```dart
Future<void> init()
Future<bool> set(String key, dynamic value)
T? get<T>(String key)
Future<String?> getString(String key)
Future<int?> getInt(String key)
Future<double?> getDouble(String key)
Future<bool?> getBool(String key)
Future<List<String>?> getStringList(String key)
Future<T?> getJson<T>(String key)
Future<bool> setString(String key, String value)
Future<bool> setInt(String key, int value)
Future<bool> setDouble(String key, double value)
Future<bool> setBool(String key, bool value)
Future<bool> setStringList(String key, List<String> value)
Future<bool> setJson(String key, dynamic value)
Future<T> getOrDefault<T>(String key, T defaultValue)
Future<bool> has(String key)
Future<bool> remove(String key)
Future<bool> clear()
Future<List<String>> get keys
Future<void> setAll(Map<String, dynamic> values)
Future<void> removeAll(List<String> keys)
Future<void> reload()
```

## File Locations

- `lib/src/cache/cache_manager.dart`
- `lib/src/cache/memory_cache.dart`
- `lib/src/cache/persistent_cache.dart`
- `lib/src/app/moose_app_context.dart` — owns `CacheManager`
- Public import: `import 'package:moose_core/cache.dart';`

## Migration from v1.x (Breaking Changes)

| Old (removed) | New |
|---|---|
| `CacheManager.memoryCacheInstance()` | `appContext.cache.memory` |
| `CacheManager.persistentCacheInstance()` | `appContext.cache.persistent` |
| `CacheManager.initPersistentCache()` | Handled by `MooseBootstrapper` |
| `CacheManager.clearAll()` | `appContext.cache.clearAll()` |
| `CacheManager.clearMemoryCache()` | `appContext.cache.clearMemory()` |
| `CacheManager.clearPersistentCache()` | `appContext.cache.clearPersistent()` |
| `MemoryCache()` singleton | `appContext.cache.memory` |
| `PersistentCache()` singleton | `appContext.cache.persistent` |

---

**Last Updated:** 2026-02-26
**Version:** 1.2.0
