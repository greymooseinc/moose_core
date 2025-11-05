import 'dart:async';
import 'dart:collection';

/// Cache entry with metadata for memory management
class _CacheEntry {
  final dynamic value;
  final DateTime? expiresAt;
  final DateTime createdAt;
  DateTime lastAccessedAt;
  int accessCount;

  _CacheEntry(
    this.value, {
    this.expiresAt,
  })  : createdAt = DateTime.now(),
        lastAccessedAt = DateTime.now(),
        accessCount = 0;

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  void markAccessed() {
    lastAccessedAt = DateTime.now();
    accessCount++;
  }

  /// Estimate memory size of this entry (approximate)
  int get estimatedSize {
    int size = 0;

    // Add base object overhead
    size += 64; // Approximate object overhead

    if (value is String) {
      size += (value as String).length * 2; // UTF-16 encoding
    } else if (value is List) {
      size += (value as List).length * 8; // Pointer size
    } else if (value is Map) {
      size += (value as Map).length * 16; // Key-value pairs
    } else {
      size += 8; // Reference size
    }

    return size;
  }
}

/// Cache statistics for monitoring
class CacheStats {
  final int size;
  final int maxSize;
  final int hits;
  final int misses;
  final int evictions;
  final int expirations;
  final int estimatedMemoryBytes;

  const CacheStats({
    required this.size,
    required this.maxSize,
    required this.hits,
    required this.misses,
    required this.evictions,
    required this.expirations,
    required this.estimatedMemoryBytes,
  });

  double get hitRate => (hits + misses) > 0 ? hits / (hits + misses) : 0.0;

  String get estimatedMemoryMB => (estimatedMemoryBytes / (1024 * 1024)).toStringAsFixed(2);

  @override
  String toString() {
    return 'CacheStats(size: $size/$maxSize, hits: $hits, misses: $misses, '
        'hitRate: ${(hitRate * 100).toStringAsFixed(1)}%, '
        'memory: ${estimatedMemoryMB}MB, evictions: $evictions, expirations: $expirations)';
  }
}

/// Eviction policy for cache
enum EvictionPolicy {
  /// Least Recently Used - removes least recently accessed items
  lru,

  /// Least Frequently Used - removes least frequently accessed items
  lfu,

  /// First In First Out - removes oldest items
  fifo,
}

/// In-memory cache with memory management and leak prevention
///
/// Features:
/// - **Max size limits** - Prevents unbounded memory growth
/// - **LRU/LFU/FIFO eviction** - Automatic cleanup when full
/// - **TTL support** - Automatic expiration
/// - **Memory tracking** - Monitors memory usage
/// - **Auto-cleanup timer** - Periodic cleanup of expired entries
/// - **Statistics** - Monitor cache performance
///
/// Best Practices:
/// ```dart
/// // Configure with size limits
/// final cache = MemoryCache();
/// cache.configure(
///   maxSize: 1000,           // Max 1000 entries
///   maxMemoryBytes: 50 * 1024 * 1024,  // Max 50MB
///   cleanupInterval: Duration(minutes: 1),
/// );
///
/// // Use TTL for auto-expiration
/// cache.set('data', value, ttl: Duration(hours: 1));
///
/// // Monitor performance
/// print(cache.stats);
/// ```
class MemoryCache {
  // Singleton pattern
  MemoryCache._internal() {
    _startCleanupTimer();
  }

  static final MemoryCache _instance = MemoryCache._internal();
  factory MemoryCache() => _instance;

  // Configuration
  int _maxSize = 1000; // Default: max 1000 entries
  int _maxMemoryBytes = 50 * 1024 * 1024; // Default: 50MB
  EvictionPolicy _evictionPolicy = EvictionPolicy.lru;
  Duration _cleanupInterval = const Duration(minutes: 1);

  // Storage - using LinkedHashMap for insertion order
  final LinkedHashMap<String, _CacheEntry> _cache = LinkedHashMap();

  // Statistics
  int _hits = 0;
  int _misses = 0;
  int _evictions = 0;
  int _expirations = 0;

  // Cleanup timer
  Timer? _cleanupTimer;

  // =========================================================================
  // CONFIGURATION
  // =========================================================================

  /// Configure cache limits and behavior
  ///
  /// **Parameters:**
  /// - [maxSize] - Maximum number of entries (default: 1000)
  /// - [maxMemoryBytes] - Maximum memory usage in bytes (default: 50MB)
  /// - [evictionPolicy] - How to evict items when full (default: LRU)
  /// - [cleanupInterval] - How often to clean expired items (default: 5 minutes)
  ///
  /// **Example:**
  /// ```dart
  /// cache.configure(
  ///   maxSize: 500,
  ///   maxMemoryBytes: 20 * 1024 * 1024, // 20MB
  ///   evictionPolicy: EvictionPolicy.lru,
  ///   cleanupInterval: Duration(minutes: 2),
  /// );
  /// ```
  void configure({
    int? maxSize,
    int? maxMemoryBytes,
    EvictionPolicy? evictionPolicy,
    Duration? cleanupInterval,
  }) {
    if (maxSize != null) {
      _maxSize = maxSize;
      _enforceMaxSize(); // Apply immediately
    }

    if (maxMemoryBytes != null) {
      _maxMemoryBytes = maxMemoryBytes;
      _enforceMaxMemory(); // Apply immediately
    }

    if (evictionPolicy != null) {
      _evictionPolicy = evictionPolicy;
    }

    if (cleanupInterval != null) {
      _cleanupInterval = cleanupInterval;
      _restartCleanupTimer();
    }
  }

  // =========================================================================
  // CORE OPERATIONS
  // =========================================================================

  /// Store a value in cache with optional TTL
  ///
  /// Automatically evicts items if cache is full.
  ///
  /// **Example:**
  /// ```dart
  /// cache.set('token', 'abc123', ttl: Duration(hours: 1));
  /// cache.set('permanent_data', 'value'); // No expiry
  /// ```
  void set(String key, dynamic value, {Duration? ttl}) {
    final expiresAt = ttl != null ? DateTime.now().add(ttl) : null;

    // Remove existing entry if it exists
    _cache.remove(key);

    // Add new entry
    _cache[key] = _CacheEntry(value, expiresAt: expiresAt);

    // Enforce limits
    _enforceMaxSize();
    _enforceMaxMemory();
  }

  /// Get a value from cache
  ///
  /// Returns null if key doesn't exist or has expired.
  /// Automatically removes expired entries.
  T? get<T>(String key) {
    final entry = _cache[key];

    if (entry == null) {
      _misses++;
      return null;
    }

    // Check if expired
    if (entry.isExpired) {
      _cache.remove(key);
      _expirations++;
      _misses++;
      return null;
    }

    // Mark as accessed (for LRU/LFU)
    entry.markAccessed();

    // Move to end for LRU (LinkedHashMap maintains insertion order)
    if (_evictionPolicy == EvictionPolicy.lru) {
      final value = entry.value;
      final expiresAt = entry.expiresAt;
      _cache.remove(key);
      _cache[key] = _CacheEntry(value, expiresAt: expiresAt);
    }

    _hits++;

    final value = entry.value;
    if (value is T) {
      return value;
    }
    return null;
  }

  /// Get a value with a default fallback
  T getOrDefault<T>(String key, T defaultValue) {
    final value = get<T>(key);
    return value ?? defaultValue;
  }

  /// Get a value or compute it if not exists
  ///
  /// **Example:**
  /// ```dart
  /// final data = cache.getOrSet('user:123', () async {
  ///   return await api.fetchUser(123);
  /// }, ttl: Duration(minutes: 30));
  /// ```
  Future<T> getOrSet<T>(
    String key,
    Future<T> Function() compute, {
    Duration? ttl,
  }) async {
    final existing = get<T>(key);
    if (existing != null) return existing;

    final value = await compute();
    set(key, value, ttl: ttl);
    return value;
  }

  /// Check if a key exists in cache and is not expired
  bool has(String key) {
    final entry = _cache[key];
    if (entry == null) return false;

    if (entry.isExpired) {
      _cache.remove(key);
      _expirations++;
      return false;
    }

    return true;
  }

  /// Remove a value from cache
  void remove(String key) {
    _cache.remove(key);
  }

  /// Clear all cache
  void clear() {
    _cache.clear();
    _resetStats();
  }

  // =========================================================================
  // BULK OPERATIONS
  // =========================================================================

  /// Set multiple values at once with optional TTL
  void setAll(Map<String, dynamic> values, {Duration? ttl}) {
    values.forEach((key, value) {
      set(key, value, ttl: ttl);
    });
  }

  /// Remove multiple keys at once
  void removeAll(List<String> keys) {
    for (final key in keys) {
      _cache.remove(key);
    }
  }

  /// Get all cached values (excluding expired ones)
  Map<String, dynamic> getAll() {
    cleanExpired();
    final result = <String, dynamic>{};
    _cache.forEach((key, entry) {
      result[key] = entry.value;
    });
    return Map.unmodifiable(result);
  }

  // =========================================================================
  // TTL MANAGEMENT
  // =========================================================================

  /// Update a value if it exists, preserving TTL
  void update(String key, dynamic value) {
    final existing = _cache[key];
    if (existing == null) return;

    final expiresAt = existing.expiresAt;
    _cache[key] = _CacheEntry(value, expiresAt: expiresAt);
  }

  /// Get the remaining TTL for a cache entry
  Duration? getRemainingTTL(String key) {
    final entry = _cache[key];
    if (entry == null) return null;
    if (entry.expiresAt == null) return null;
    if (entry.isExpired) {
      _cache.remove(key);
      _expirations++;
      return null;
    }

    return entry.expiresAt!.difference(DateTime.now());
  }

  /// Refresh the TTL for an existing cache entry
  bool refreshTTL(String key, Duration ttl) {
    final entry = _cache[key];
    if (entry == null) return false;

    final expiresAt = DateTime.now().add(ttl);
    _cache[key] = _CacheEntry(entry.value, expiresAt: expiresAt);
    return true;
  }

  /// Get and remove a value (pop operation)
  T? pop<T>(String key) {
    final value = get<T>(key);
    remove(key);
    return value;
  }

  // =========================================================================
  // MEMORY MANAGEMENT
  // =========================================================================

  /// Remove all expired entries from cache
  void cleanExpired() {
    final expiredKeys = <String>[];
    _cache.forEach((key, entry) {
      if (entry.isExpired) {
        expiredKeys.add(key);
      }
    });

    for (final key in expiredKeys) {
      _cache.remove(key);
      _expirations++;
    }
  }

  /// Force cleanup to free memory
  ///
  /// Removes expired items and enforces size/memory limits.
  void cleanup() {
    cleanExpired();
    _enforceMaxSize();
    _enforceMaxMemory();
  }

  /// Enforce maximum number of entries
  void _enforceMaxSize() {
    while (_cache.length > _maxSize) {
      _evictOne();
    }
  }

  /// Enforce maximum memory usage
  void _enforceMaxMemory() {
    while (_estimatedMemoryUsage > _maxMemoryBytes && _cache.isNotEmpty) {
      _evictOne();
    }
  }

  /// Evict one entry based on eviction policy
  void _evictOne() {
    if (_cache.isEmpty) return;

    String? keyToRemove;

    switch (_evictionPolicy) {
      case EvictionPolicy.lru:
        // Remove first (oldest access)
        keyToRemove = _cache.keys.first;
        break;

      case EvictionPolicy.lfu:
        // Remove least frequently used
        int minAccessCount = -1;
        _cache.forEach((key, entry) {
          if (minAccessCount == -1 || entry.accessCount < minAccessCount) {
            minAccessCount = entry.accessCount;
            keyToRemove = key;
          }
        });
        break;

      case EvictionPolicy.fifo:
        // Remove first (oldest creation)
        DateTime? oldestTime;
        _cache.forEach((key, entry) {
          if (oldestTime == null || entry.createdAt.isBefore(oldestTime!)) {
            oldestTime = entry.createdAt;
            keyToRemove = key;
          }
        });
        break;
    }

    if (keyToRemove != null) {
      _cache.remove(keyToRemove);
      _evictions++;
    }
  }

  /// Get estimated memory usage in bytes
  int get _estimatedMemoryUsage {
    int total = 0;
    _cache.forEach((key, entry) {
      total += key.length * 2; // Key string
      total += entry.estimatedSize; // Value
    });
    return total;
  }

  // =========================================================================
  // AUTOMATIC CLEANUP
  // =========================================================================

  /// Start automatic cleanup timer
  void _startCleanupTimer() {
    _cleanupTimer?.cancel();
    _cleanupTimer = Timer.periodic(_cleanupInterval, (_) {
      cleanExpired();
    });
  }

  /// Restart cleanup timer with new interval
  void _restartCleanupTimer() {
    _cleanupTimer?.cancel();
    _startCleanupTimer();
  }

  /// Stop automatic cleanup
  void stopAutoCleanup() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
  }

  // =========================================================================
  // STATISTICS & MONITORING
  // =========================================================================

  /// Get cache statistics
  CacheStats get stats => CacheStats(
        size: _cache.length,
        maxSize: _maxSize,
        hits: _hits,
        misses: _misses,
        evictions: _evictions,
        expirations: _expirations,
        estimatedMemoryBytes: _estimatedMemoryUsage,
      );

  /// Reset statistics
  void _resetStats() {
    _hits = 0;
    _misses = 0;
    _evictions = 0;
    _expirations = 0;
  }

  /// Reset statistics manually
  void resetStats() {
    _resetStats();
  }

  /// Print cache statistics to console
  void printStats() {
    print('=== Memory Cache Statistics ===');
    print(stats.toString());
    print('Eviction Policy: $_evictionPolicy');
    print('Cleanup Interval: $_cleanupInterval');
    print('===============================');
  }

  // =========================================================================
  // GETTERS
  // =========================================================================

  /// Get all keys in cache (excluding expired ones)
  List<String> get keys {
    cleanExpired();
    return _cache.keys.toList();
  }

  /// Get cache size (excluding expired entries)
  int get size {
    cleanExpired();
    return _cache.length;
  }

  /// Check if cache is empty
  bool get isEmpty {
    cleanExpired();
    return _cache.isEmpty;
  }

  /// Check if cache has items
  bool get isNotEmpty {
    cleanExpired();
    return _cache.isNotEmpty;
  }

  /// Get current max size
  int get maxSize => _maxSize;

  /// Get current max memory
  int get maxMemoryBytes => _maxMemoryBytes;

  /// Get current eviction policy
  EvictionPolicy get evictionPolicy => _evictionPolicy;

  // =========================================================================
  // DISPOSE
  // =========================================================================

  /// Dispose cache and stop cleanup timer
  ///
  /// Call this when you're done with the cache to prevent memory leaks.
  void dispose() {
    _cleanupTimer?.cancel();
    _cleanupTimer = null;
    _cache.clear();
    _resetStats();
  }
}
