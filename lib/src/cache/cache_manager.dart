import 'memory_cache.dart';
import 'persistent_cache.dart';

/// Scoped cache manager that owns independent [MemoryCache] and [PersistentCache]
/// instances for a single [MooseAppContext].
///
/// [CacheManager] is created and owned by [MooseAppContext]. There is no global
/// or static state — each context has its own isolated cache. Two
/// [MooseAppContext] instances never share cache data.
///
/// Access via the widget tree:
/// ```dart
/// // From a widget
/// final cache = context.moose.cache;
/// cache.memory.set('temp_token', 'abc123');
/// final token = cache.memory.get<String>('temp_token');
///
/// // Persistent (survives app restarts)
/// await cache.persistent.set('user_id', '12345');
/// final userId = await cache.persistent.getString('user_id');
/// ```
///
/// Or directly on [MooseAppContext]:
/// ```dart
/// appContext.cache.memory.set('key', value);
/// appContext.cache.persistent.setString('pref', 'value');
/// ```
///
/// Initialise the persistent layer during bootstrap (done automatically by
/// [MooseBootstrapper]):
/// ```dart
/// await appContext.cache.initPersistent();
/// ```
class CacheManager {
  /// In-memory cache for fast, session-scoped storage.
  ///
  /// Use for API response caching, computed values, session state, and
  /// temporary UI state. Data is lost when the app process ends.
  final MemoryCache memory;

  /// Persistent cache backed by SharedPreferences.
  ///
  /// Use for user preferences, settings, authentication tokens, search
  /// history, and favourites. Data survives app restarts.
  final PersistentCache persistent;

  CacheManager({
    MemoryCache? memory,
    PersistentCache? persistent,
  })  : memory = memory ?? MemoryCache(),
        persistent = persistent ?? PersistentCache();

  /// Initialise the persistent cache layer.
  ///
  /// Called automatically by [MooseBootstrapper]. Must complete before any
  /// [persistent] operations are attempted.
  Future<void> initPersistent() async {
    await persistent.init();
  }

  /// Clear both memory and persistent caches.
  ///
  /// Use with caution — this removes all cached data for this context.
  Future<void> clearAll() async {
    memory.clear();
    await persistent.clear();
  }

  /// Clear only the in-memory cache.
  void clearMemory() {
    memory.clear();
  }

  /// Clear only the persistent cache.
  Future<bool> clearPersistent() async {
    return await persistent.clear();
  }

  /// Dispose the memory cache and stop its cleanup timer.
  ///
  /// Call when the owning [MooseAppContext] is being torn down.
  void dispose() {
    memory.dispose();
  }
}
