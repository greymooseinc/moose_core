# Cache Management Guide for AI Agents

## Overview

This application uses a unified cache management system with two types of caches:

1. **MemoryCache** - In-memory cache for temporary runtime data
2. **PersistentCache** - Persistent cache using SharedPreferences for data that survives app restarts

Both caches are accessed through the `CacheManager` class.

## Quick Reference

```dart
import 'package:ecommerce_ai/core/cache/cache_manager.dart';

// In-memory cache (temporary, fast)
CacheManager.memoryCacheInstance().set('key', 'value');
final value = CacheManager.memoryCacheInstance().get<String>('key');

// Persistent cache (survives app restarts)
await CacheManager.persistentCacheInstance().setString('key', 'value');
final value = await CacheManager.persistentCacheInstance().getString('key');
```

## MemoryCache (In-Memory)

### When to Use
- API response caching (with TTL)
- Computed values that are expensive to recalculate
- Session state (nonce, tokens that expire with session)
- Temporary UI state
- Cart IDs, temporary user preferences

### Features
- **Synchronous** - No `await` needed
- **Fast** - Instant access
- **TTL Support** - Auto-expiration of cached data
- **Non-persistent** - Data cleared on app restart
- **Type-safe** - Generic `get<T>()` method
- **Memory Management** - Prevents memory leaks with size and memory limits
- **Eviction Policies** - LRU, LFU, or FIFO when cache is full
- **Auto-cleanup** - Periodic removal of expired entries
- **Statistics** - Monitor cache performance (hit rate, memory usage)
- **Memory Tracking** - Estimates memory usage in real-time

### Configuration

**NEW**: Configure memory limits to prevent memory leaks:

```dart
final cache = CacheManager.memoryCacheInstance();

// Configure cache limits (recommended for production)
cache.configure(
  maxSize: 1000,                        // Max 1000 entries
  maxMemoryBytes: 50 * 1024 * 1024,     // Max 50MB
  evictionPolicy: EvictionPolicy.lru,   // Least Recently Used
  cleanupInterval: Duration(minutes: 1), // Auto-cleanup every minute
);
```

**Eviction Policies:**
- `EvictionPolicy.lru` - Least Recently Used (default, recommended)
- `EvictionPolicy.lfu` - Least Frequently Used
- `EvictionPolicy.fifo` - First In First Out

### Usage Examples

```dart
// Basic usage
final cache = CacheManager.memoryCacheInstance();
cache.set('user_token', 'abc123');
final token = cache.get<String>('user_token');

// With TTL (Time-To-Live)
cache.set('api_response', data, ttl: Duration(minutes: 5));

// Check if exists
if (cache.has('user_token')) {
  // Key exists and is not expired
}

// Remove
cache.remove('user_token');

// Clear all
cache.clear();

// Get with default value
final username = cache.getOrDefault<String>('username', 'Guest');

// Update (preserves existing TTL)
cache.update('counter', newValue);

// Pop (get and remove)
final value = cache.pop<String>('one_time_token');

// TTL management
final remaining = cache.getRemainingTTL('api_response');
cache.refreshTTL('api_response', Duration(minutes: 10));
```

### Memory Management (NEW)

```dart
final cache = CacheManager.memoryCacheInstance();

// Monitor cache statistics
final stats = cache.stats;
print(stats); // CacheStats(size: 150/1000, hits: 450, misses: 50, hitRate: 90.0%, memory: 2.34MB)

// Access individual stats
print('Cache hit rate: ${stats.hitRate * 100}%');
print('Memory usage: ${stats.estimatedMemoryMB} MB');
print('Evictions: ${stats.evictions}');
print('Expirations: ${stats.expirations}');

// Print detailed statistics
cache.printStats();
// Output:
// === Memory Cache Statistics ===
// CacheStats(size: 150/1000, hits: 450, misses: 50, hitRate: 90.0%, memory: 2.34MB, evictions: 5, expirations: 12)
// Eviction Policy: EvictionPolicy.lru
// Cleanup Interval: 0:01:00.000000
// ===============================

// Reset statistics
cache.resetStats();

// Manual cleanup (removes expired items and enforces limits)
cache.cleanup();

// Clean only expired items
cache.cleanExpired();

// Check memory usage
final memoryBytes = cache.stats.estimatedMemoryBytes;
if (memoryBytes > 40 * 1024 * 1024) { // 40MB
  cache.cleanup();
}
```

### Common Use Cases in This App

```dart
// Cache nonce for WooCommerce Store API
CacheManager.memoryCacheInstance().set('_nonce', nonceValue);

// Cache cart ID during session
CacheManager.memoryCacheInstance().set('cart_id', cartId);

// Cache API responses with expiration
CacheManager.memoryCacheInstance().set(
  'products_list',
  products,
  ttl: Duration(minutes: 5)
);
```

## PersistentCache (SharedPreferences)

### When to Use
- User preferences and settings
- Authentication tokens that should survive app restarts
- Search history
- Favorites, wishlists
- User profile data
- App configuration
- Last viewed items

### Features
- **Asynchronous** - Use `await` for all operations
- **Persistent** - Survives app restarts and device reboots
- **Type-specific methods** - `setString()`, `setInt()`, `setBool()`, etc.
- **JSON support** - Store complex objects as JSON
- **SharedPreferences backend** - Industry-standard persistence

### Initialization

**IMPORTANT**: Initialize persistent cache in `main()` before using it:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CacheManager.initPersistentCache();
  runApp(MyApp());
}
```

### Usage Examples

```dart
final cache = CacheManager.persistentCacheInstance();

// String values
await cache.setString('username', 'john_doe');
final username = await cache.getString('username');

// Int values
await cache.setInt('user_id', 12345);
final userId = await cache.getInt('user_id');

// Bool values
await cache.setBool('notifications_enabled', true);
final enabled = await cache.getBool('notifications_enabled');

// String lists
await cache.setStringList('search_history', ['query1', 'query2']);
final history = await cache.getStringList('search_history');

// JSON objects (for complex data)
await cache.setJson('user_profile', {
  'name': 'John',
  'email': 'john@example.com',
  'age': 30,
});
final profile = await cache.getJson<Map<String, dynamic>>('user_profile');

// Generic set (auto-detects type)
await cache.set('key', 'value');  // Works with String, int, bool, double, List<String>

// Check if exists
if (await cache.has('username')) {
  // Key exists
}

// Remove
await cache.remove('username');

// Clear all
await cache.clear();

// Get with default
final theme = await cache.getOrDefault<String>('theme', 'light');

// Reload from disk (if modified externally)
await cache.reload();
```

### Common Use Cases in This App

```dart
// Save search history (from WooSearchRepository)
final cache = CacheManager.persistentCacheInstance();
final history = await cache.getStringList('search_history') ?? [];
history.insert(0, searchQuery);
await cache.setStringList('search_history', history);

// Get recent searches
final history = await cache.getStringList('search_history') ?? [];
final recentSearches = history.take(10).toList();

// Clear search history
await cache.remove('search_history');

// Save user preferences
await cache.setString('preferred_currency', 'USD');
await cache.setBool('dark_mode', true);
await cache.setInt('items_per_page', 20);
```

## Decision Matrix: Which Cache to Use?

| Scenario | Cache Type | Reason |
|----------|-----------|--------|
| API response caching | MemoryCache | Fast access, auto-expiration with TTL |
| User login token (session) | MemoryCache | Should not persist after app restart for security |
| User preferences | PersistentCache | Should survive app restarts |
| Search history | PersistentCache | Users expect to see history across sessions |
| Computed expensive values | MemoryCache | Fast access, recalculated each session |
| Shopping cart ID (session) | MemoryCache | New cart per session |
| Favorites/Wishlist | PersistentCache | Should persist across sessions |
| Form draft data | PersistentCache | Users expect drafts to be saved |
| WooCommerce nonce | MemoryCache | New nonce each session |
| Last viewed products | PersistentCache | Enhance user experience across sessions |
| App theme/language | PersistentCache | User settings should persist |

## Best Practices for AI Agents

### 1. Configure MemoryCache Limits (NEW - IMPORTANT)

**Prevent memory leaks** by configuring cache limits in your app initialization:

```dart
// In main.dart or app initialization
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Configure memory cache to prevent leaks
  CacheManager.memoryCacheInstance().configure(
    maxSize: 1000,                        // Limit entries
    maxMemoryBytes: 50 * 1024 * 1024,     // Limit memory (50MB)
    evictionPolicy: EvictionPolicy.lru,   // LRU eviction
    cleanupInterval: Duration(minutes: 1), // Auto-cleanup
  );

  await CacheManager.initPersistentCache();
  runApp(MyApp());
}
```

### 2. Always Initialize Persistent Cache

```dart
// In main.dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CacheManager.initPersistentCache();
  runApp(MyApp());
}
```

### 3. Use Appropriate Cache Type

```dart
// ❌ BAD: Using persistent cache for temporary data
await CacheManager.persistentCacheInstance().setString('api_temp', data);

// ✅ GOOD: Using memory cache for temporary data
CacheManager.memoryCacheInstance().set('api_temp', data, ttl: Duration(minutes: 5));

// ❌ BAD: Using memory cache for user preferences
CacheManager.memoryCacheInstance().set('theme', 'dark');

// ✅ GOOD: Using persistent cache for user preferences
await CacheManager.persistentCacheInstance().setString('theme', 'dark');
```

### 4. Handle Async Operations Correctly

```dart
// ❌ BAD: Forgetting await
CacheManager.persistentCacheInstance().setString('key', 'value');

// ✅ GOOD: Using await
await CacheManager.persistentCacheInstance().setString('key', 'value');
```

### 5. Use TTL for Time-Sensitive Data

```dart
// ✅ GOOD: Cache API responses with expiration
CacheManager.memoryCacheInstance().set(
  'product_list',
  products,
  ttl: Duration(minutes: 5),
);
```

### 6. Check for Existence Before Use

```dart
// ✅ GOOD: Check before getting
if (await CacheManager.persistentCacheInstance().has('user_token')) {
  final token = await CacheManager.persistentCacheInstance().getString('user_token');
}

// OR use default values
final token = await CacheManager.persistentCacheInstance().getOrDefault('user_token', '');
```

### 7. Monitor Cache Performance (NEW)

```dart
// Periodically check cache health
void monitorCache() {
  final cache = CacheManager.memoryCacheInstance();
  final stats = cache.stats;

  // Warn if hit rate is low
  if (stats.hitRate < 0.5) {
    print('Warning: Low cache hit rate: ${stats.hitRate * 100}%');
  }

  // Warn if memory usage is high
  if (stats.estimatedMemoryBytes > 45 * 1024 * 1024) {
    print('Warning: High memory usage: ${stats.estimatedMemoryMB} MB');
    cache.cleanup();
  }

  // Print stats in debug builds
  if (kDebugMode) {
    cache.printStats();
  }
}
```

### 8. Never Store Sensitive Data in Persistent Cache

```dart
// ❌ BAD: Storing passwords or credit cards
await CacheManager.persistentCacheInstance().setString('password', userPassword);

// ✅ GOOD: Use secure storage for sensitive data (not implemented yet)
// Use flutter_secure_storage or similar for sensitive data
```

## Code Examples from This App

### Example 1: Search History (WooSearchRepository)

```dart
// Get recent searches
Future<List<String>> getRecentSearches({int limit = 10}) async {
  try {
    final cache = CacheManager.persistentCacheInstance();
    final history = await cache.getStringList('search_history') ?? [];
    return history.take(limit).toList();
  } catch (e) {
    print('Error getting recent searches: $e');
    return [];
  }
}

// Save search to history
Future<void> saveSearchToHistory(String query) async {
  try {
    final cache = CacheManager.persistentCacheInstance();
    final history = await cache.getStringList('search_history') ?? [];

    history.remove(query);  // Remove if exists
    history.insert(0, query);  // Add to beginning

    if (history.length > 20) {
      history.removeRange(20, history.length);  // Keep only 20
    }

    await cache.setStringList('search_history', history);
  } catch (e) {
    print('Error saving search: $e');
  }
}
```

### Example 2: WooCommerce Nonce Caching (WooCommerceAdapter)

```dart
// Store nonce in memory cache (not persistent)
CacheManager.memoryCacheInstance().set('_nonce', nonceValue);

// Retrieve nonce
String? nonce = CacheManager.memoryCacheInstance().get<String>('_nonce');
```

### Example 3: Cart ID Caching (WooCartRepository)

```dart
final cache = CacheManager.memoryCacheInstance();

// Get cart ID (falls back to default if not cached)
String cartId = cache.get<String>('cart_id') ?? 'woo_cart_session';

// Store cart ID for the session
cache.set('cart_id', cartId);
```

## API Reference

### CacheManager Static Methods

```dart
// Get memory cache instance
MemoryCache memoryCacheInstance()

// Get persistent cache instance
PersistentCache persistentCacheInstance()

// Initialize persistent cache (call in main())
Future<void> initPersistentCache()

// Clear all caches
Future<void> clearAll()

// Clear only memory cache
void clearMemoryCache()

// Clear only persistent cache
Future<bool> clearPersistentCache()
```

### MemoryCache Methods

**Core Operations:**
```dart
void set(String key, dynamic value, {Duration? ttl})
T? get<T>(String key)
T getOrDefault<T>(String key, T defaultValue)
bool has(String key)
void remove(String key)
void clear()
void update(String key, dynamic value)
T? pop<T>(String key)
```

**TTL Management:**
```dart
Duration? getRemainingTTL(String key)
bool refreshTTL(String key, Duration ttl)
void cleanExpired()
```

**Bulk Operations:**
```dart
Map<String, dynamic> getAll()
void setAll(Map<String, dynamic> values, {Duration? ttl})
void removeAll(List<String> keys)
```

**Configuration (NEW):**
```dart
void configure({
  int? maxSize,
  int? maxMemoryBytes,
  EvictionPolicy? evictionPolicy,
  Duration? cleanupInterval,
})
```

**Memory Management (NEW):**
```dart
void cleanup()                  // Force cleanup (expired + limits)
void stopAutoCleanup()          // Stop automatic cleanup timer
```

**Statistics (NEW):**
```dart
CacheStats get stats            // Get cache statistics
void resetStats()               // Reset statistics counters
void printStats()               // Print detailed statistics
```

**CacheStats Properties (NEW):**
```dart
int size                        // Current number of entries
int maxSize                     // Maximum entries allowed
int hits                        // Cache hits count
int misses                      // Cache misses count
int evictions                   // Number of evictions
int expirations                 // Number of expirations
int estimatedMemoryBytes        // Estimated memory usage in bytes
double hitRate                  // Hit rate (0.0 to 1.0)
String estimatedMemoryMB        // Memory usage in MB string
```

**Getters:**
```dart
List<String> get keys
int get size
bool get isEmpty
bool get isNotEmpty
```

### PersistentCache Methods

```dart
Future<void> init()
Future<bool> set(String key, dynamic value)
T? get<T>(String key)  // Note: Synchronous but limited, prefer specific methods
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

- **CacheManager**: `lib/core/cache/cache_manager.dart`
- **MemoryCache**: `lib/core/cache/memory_cache.dart`
- **PersistentCache**: `lib/core/cache/persistent_cache.dart`
- **This Guide**: `lib/core/cache/AI_CACHE_GUIDE.md`

## Advanced Features (NEW)

### Eviction Policies Explained

**LRU (Least Recently Used)** - Recommended for most use cases
- Removes items that haven't been accessed recently
- Good for general caching where recent data is more valuable
- Example: API responses, computed values

**LFU (Least Frequently Used)**
- Removes items that are accessed infrequently
- Good when frequently-used data should stay cached
- Example: User preferences, common queries

**FIFO (First In First Out)**
- Removes oldest items regardless of usage
- Simplest policy, predictable behavior
- Example: Sequential data processing

### Performance Tips

1. **Set appropriate limits based on your app's needs:**
```dart
// Mobile app (conservative)
cache.configure(
  maxSize: 500,
  maxMemoryBytes: 20 * 1024 * 1024, // 20MB
);

// Desktop app (generous)
cache.configure(
  maxSize: 5000,
  maxMemoryBytes: 200 * 1024 * 1024, // 200MB
);
```

2. **Monitor in development, optimize for production:**
```dart
if (kDebugMode) {
  // Check cache health during development
  Timer.periodic(Duration(minutes: 5), (_) {
    final cache = CacheManager.memoryCacheInstance();
    cache.printStats();

    if (cache.stats.hitRate < 0.6) {
      print('⚠️ Consider adjusting cache configuration');
    }
  });
}
```

3. **Use shorter TTL for frequently-changing data:**
```dart
// Product prices (change often) - short TTL
cache.set('product_prices', prices, ttl: Duration(minutes: 2));

// Product details (change rarely) - longer TTL
cache.set('product_details', details, ttl: Duration(hours: 1));
```

4. **Manually trigger cleanup before memory-intensive operations:**
```dart
// Before loading large images or processing data
CacheManager.memoryCacheInstance().cleanup();
```

### Anti-Patterns to Avoid

❌ **Don't cache everything without TTL:**
```dart
// BAD: Unlimited caching without expiration
cache.set('data', largeData); // No TTL, stays forever until evicted
```

❌ **Don't ignore cache statistics:**
```dart
// BAD: Never checking if cache is effective
cache.set('key', value);
cache.get('key');
// ... never check stats.hitRate
```

❌ **Don't set unrealistic memory limits:**
```dart
// BAD: Too small, causes constant evictions
cache.configure(maxMemoryBytes: 1024 * 1024); // 1MB is too small

// BAD: Too large, risks OOM crashes
cache.configure(maxMemoryBytes: 500 * 1024 * 1024); // 500MB is too much
```

✅ **Do this instead:**
```dart
// GOOD: Reasonable limits with monitoring
cache.configure(
  maxSize: 1000,
  maxMemoryBytes: 50 * 1024 * 1024, // 50MB
  cleanupInterval: Duration(minutes: 1),
);

// Periodically check performance
if (kDebugMode) {
  cache.printStats();
}
```

## Migration Notes

The old `CacheManager` class has been refactored:
- Old `CacheManager()` → Now `CacheManager.memoryCacheInstance()`
- SharedPreferences usage → Now `CacheManager.persistentCacheInstance()`

**NEW v2 Changes:**
- Added memory management features to prevent leaks
- Added `configure()` method for setting limits
- Added `stats` property for monitoring
- Added eviction policies (LRU/LFU/FIFO)
- Added automatic cleanup timer
- All existing code continues to work (backward compatible)

All existing code has been updated to use the new API.
