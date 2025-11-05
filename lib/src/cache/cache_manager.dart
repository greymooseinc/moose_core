import 'memory_cache.dart';
import 'persistent_cache.dart';

/// Central cache manager providing access to both memory and persistent caches
///
/// This class provides a unified interface to access different cache implementations:
/// - MemoryCache: Fast in-memory storage for temporary runtime data
/// - PersistentCache: Persistent storage using SharedPreferences for data that survives app restarts
///
/// Usage:
/// ```dart
/// // For temporary runtime data (cleared on app restart)
/// CacheManager.memoryCacheInstance().set('temp_token', 'abc123');
/// final token = CacheManager.memoryCacheInstance().get<String>('temp_token');
///
/// // For persistent data (survives app restarts)
/// await CacheManager.persistentCacheInstance().set('user_id', '12345');
/// final userId = await CacheManager.persistentCacheInstance().getString('user_id');
/// ```
///
/// When to use each cache:
/// - Use MemoryCache for: API response caching, computed values, session state, temporary UI state
/// - Use PersistentCache for: User preferences, settings, authentication tokens, search history, favorites
class CacheManager {
  // Private constructor to prevent instantiation
  CacheManager._();

  /// Get the singleton instance of MemoryCache
  ///
  /// Use this for fast in-memory caching of temporary data that doesn't need
  /// to persist between app sessions.
  ///
  /// Example:
  /// ```dart
  /// CacheManager.memoryCacheInstance().set('api_response', data, ttl: Duration(minutes: 5));
  /// final cachedData = CacheManager.memoryCacheInstance().get('api_response');
  /// ```
  static MemoryCache memoryCacheInstance() {
    return MemoryCache();
  }

  /// Get the singleton instance of PersistentCache
  ///
  /// Use this for data that needs to persist between app sessions.
  ///
  /// IMPORTANT: Make sure to call `await CacheManager.initPersistentCache()`
  /// during app initialization before using this cache.
  ///
  /// Example:
  /// ```dart
  /// await CacheManager.persistentCacheInstance().setString('username', 'john_doe');
  /// final username = await CacheManager.persistentCacheInstance().getString('username');
  /// ```
  static PersistentCache persistentCacheInstance() {
    return PersistentCache();
  }

  /// Initialize the persistent cache
  ///
  /// Call this during app initialization (e.g., in main()) before using PersistentCache.
  ///
  /// Example:
  /// ```dart
  /// void main() async {
  ///   WidgetsFlutterBinding.ensureInitialized();
  ///   await CacheManager.initPersistentCache();
  ///   runApp(MyApp());
  /// }
  /// ```
  static Future<void> initPersistentCache() async {
    await PersistentCache().init();
  }

  /// Clear all caches (both memory and persistent)
  ///
  /// Use with caution as this will remove all cached data.
  static Future<void> clearAll() async {
    memoryCacheInstance().clear();
    await persistentCacheInstance().clear();
  }

  /// Clear only the memory cache
  static void clearMemoryCache() {
    memoryCacheInstance().clear();
  }

  /// Clear only the persistent cache
  static Future<bool> clearPersistentCache() async {
    return await persistentCacheInstance().clear();
  }
}
