import 'package:flutter_test/flutter_test.dart';
import 'package:moose_core/cache.dart';

void main() {
  group('MemoryCache', () {
    late MemoryCache cache;

    setUp(() {
      cache = MemoryCache();
      cache.configure(
        maxSize: 1000,
        evictionPolicy: EvictionPolicy.lru,
      );
    });

    tearDown(() {
      cache.dispose();
    });

    // =========================================================================
    // Instance isolation — no singleton
    // =========================================================================

    group('Instance isolation', () {
      test('two MemoryCache instances are independent objects', () {
        final a = MemoryCache();
        final b = MemoryCache();
        expect(identical(a, b), isFalse);
        a.dispose();
        b.dispose();
      });

      test('writes to one instance are not visible in another', () {
        final a = MemoryCache();
        final b = MemoryCache();

        a.set('key', 'from_a');

        expect(a.get<String>('key'), equals('from_a'));
        expect(b.get<String>('key'), isNull);

        a.dispose();
        b.dispose();
      });

      test('clearing one instance does not affect another', () {
        final a = MemoryCache();
        final b = MemoryCache();

        a.set('x', 1);
        b.set('x', 2);
        a.clear();

        expect(a.get<int>('x'), isNull);
        expect(b.get<int>('x'), equals(2));

        a.dispose();
        b.dispose();
      });
    });

    // =========================================================================
    // set / get
    // =========================================================================

    group('set / get', () {
      test('should store and retrieve a String value', () {
        cache.set('key', 'hello');
        expect(cache.get<String>('key'), equals('hello'));
      });

      test('should store and retrieve an int value', () {
        cache.set('num', 42);
        expect(cache.get<int>('num'), equals(42));
      });

      test('should store and retrieve a Map value', () {
        cache.set('map', {'a': 1, 'b': 2});
        expect(cache.get<Map>('map'), equals({'a': 1, 'b': 2}));
      });

      test('should store and retrieve a List value', () {
        cache.set('list', [1, 2, 3]);
        expect(cache.get<List>('list'), equals([1, 2, 3]));
      });

      test('should return null for missing key', () {
        expect(cache.get<String>('missing'), isNull);
      });

      test('should return null for type mismatch', () {
        cache.set('key', 'string_value');
        expect(cache.get<int>('key'), isNull);
      });

      test('should overwrite existing key', () {
        cache.set('key', 'first');
        cache.set('key', 'second');
        expect(cache.get<String>('key'), equals('second'));
      });

      test('should return null after TTL expires', () async {
        cache.set('temp', 'value', ttl: const Duration(milliseconds: 50));
        expect(cache.get<String>('temp'), equals('value'));

        await Future.delayed(const Duration(milliseconds: 100));
        expect(cache.get<String>('temp'), isNull);
      });

      test('should return value before TTL expires', () async {
        cache.set('short', 'alive', ttl: const Duration(seconds: 5));
        expect(cache.get<String>('short'), equals('alive'));
      });

      test('should store value with no TTL (permanent)', () {
        cache.set('permanent', 'always here');
        expect(cache.get<String>('permanent'), equals('always here'));
      });
    });

    // =========================================================================
    // has
    // =========================================================================

    group('has', () {
      test('should return true for existing key', () {
        cache.set('exists', 'yes');
        expect(cache.has('exists'), isTrue);
      });

      test('should return false for missing key', () {
        expect(cache.has('missing'), isFalse);
      });

      test('should return false for expired key', () async {
        cache.set('temp', 'val', ttl: const Duration(milliseconds: 30));
        await Future.delayed(const Duration(milliseconds: 60));
        expect(cache.has('temp'), isFalse);
      });
    });

    // =========================================================================
    // remove
    // =========================================================================

    group('remove', () {
      test('should remove an existing key', () {
        cache.set('key', 'value');
        cache.remove('key');
        expect(cache.get<String>('key'), isNull);
        expect(cache.has('key'), isFalse);
      });

      test('should do nothing for non-existent key', () {
        expect(() => cache.remove('nonexistent'), returnsNormally);
      });
    });

    // =========================================================================
    // clear
    // =========================================================================

    group('clear', () {
      test('should remove all entries', () {
        cache.set('a', 1);
        cache.set('b', 2);
        cache.set('c', 3);

        cache.clear();

        expect(cache.size, equals(0));
        expect(cache.isEmpty, isTrue);
      });
    });

    // =========================================================================
    // getOrDefault
    // =========================================================================

    group('getOrDefault', () {
      test('should return cached value when present', () {
        cache.set('key', 'cached');
        expect(cache.getOrDefault<String>('key', 'default'), equals('cached'));
      });

      test('should return default value when key is missing', () {
        expect(cache.getOrDefault<String>('missing', 'default'), equals('default'));
      });

      test('should return default when entry is expired', () async {
        cache.set('temp', 'value', ttl: const Duration(milliseconds: 30));
        await Future.delayed(const Duration(milliseconds: 60));
        expect(cache.getOrDefault<String>('temp', 'fallback'), equals('fallback'));
      });
    });

    // =========================================================================
    // getOrSet
    // =========================================================================

    group('getOrSet', () {
      test('should return cached value without calling compute', () async {
        cache.set('key', 'cached');
        bool computed = false;

        final result = await cache.getOrSet<String>('key', () async {
          computed = true;
          return 'computed';
        });

        expect(result, equals('cached'));
        expect(computed, isFalse);
      });

      test('should compute and cache value when key is missing', () async {
        final result = await cache.getOrSet<String>('new_key', () async => 'computed');

        expect(result, equals('computed'));
        expect(cache.get<String>('new_key'), equals('computed'));
      });
    });

    // =========================================================================
    // Bulk operations
    // =========================================================================

    group('setAll / removeAll / getAll', () {
      test('setAll should store multiple values at once', () {
        cache.setAll({'x': 1, 'y': 2, 'z': 3});

        expect(cache.get<int>('x'), equals(1));
        expect(cache.get<int>('y'), equals(2));
        expect(cache.get<int>('z'), equals(3));
      });

      test('removeAll should remove multiple keys', () {
        cache.setAll({'a': 1, 'b': 2, 'c': 3});
        cache.removeAll(['a', 'b']);

        expect(cache.has('a'), isFalse);
        expect(cache.has('b'), isFalse);
        expect(cache.has('c'), isTrue);
      });

      test('getAll should return all non-expired entries', () {
        cache.set('p', 'one');
        cache.set('q', 'two');

        final all = cache.getAll();
        expect(all['p'], equals('one'));
        expect(all['q'], equals('two'));
      });

      test('getAll should exclude expired entries', () async {
        cache.set('fresh', 'value', ttl: const Duration(seconds: 5));
        cache.set('stale', 'expired', ttl: const Duration(milliseconds: 30));

        await Future.delayed(const Duration(milliseconds: 60));

        final all = cache.getAll();
        expect(all.containsKey('fresh'), isTrue);
        expect(all.containsKey('stale'), isFalse);
      });
    });

    // =========================================================================
    // TTL Management
    // =========================================================================

    group('TTL Management', () {
      test('update should change value while preserving TTL', () async {
        cache.set('key', 'original', ttl: const Duration(seconds: 5));
        cache.update('key', 'updated');

        expect(cache.get<String>('key'), equals('updated'));
        expect(cache.getRemainingTTL('key'), isNotNull);
      });

      test('update should do nothing for non-existent key', () {
        cache.update('nonexistent', 'value');
        expect(cache.has('nonexistent'), isFalse);
      });

      test('getRemainingTTL should return non-null for entries with TTL', () {
        cache.set('timed', 'val', ttl: const Duration(seconds: 60));
        expect(cache.getRemainingTTL('timed'), isNotNull);
      });

      test('getRemainingTTL should return null for entries without TTL', () {
        cache.set('permanent', 'val');
        expect(cache.getRemainingTTL('permanent'), isNull);
      });

      test('getRemainingTTL should return null for expired entries', () async {
        cache.set('short', 'val', ttl: const Duration(milliseconds: 30));
        await Future.delayed(const Duration(milliseconds: 60));
        expect(cache.getRemainingTTL('short'), isNull);
      });

      test('refreshTTL should extend TTL of existing entry', () {
        cache.set('key', 'val', ttl: const Duration(milliseconds: 50));
        final refreshed = cache.refreshTTL('key', const Duration(seconds: 60));

        expect(refreshed, isTrue);
        final remaining = cache.getRemainingTTL('key');
        expect(remaining, isNotNull);
        expect(remaining!.inSeconds, greaterThan(50));
      });

      test('refreshTTL should return false for non-existent key', () {
        final result = cache.refreshTTL('missing', const Duration(seconds: 10));
        expect(result, isFalse);
      });

      test('pop should return and remove value', () {
        cache.set('key', 'value');
        final result = cache.pop<String>('key');

        expect(result, equals('value'));
        expect(cache.has('key'), isFalse);
      });

      test('pop should return null for missing key', () {
        expect(cache.pop<String>('missing'), isNull);
      });
    });

    // =========================================================================
    // Eviction
    // =========================================================================

    group('Eviction', () {
      test('LRU eviction removes least recently used when maxSize exceeded', () {
        cache.configure(maxSize: 3, evictionPolicy: EvictionPolicy.lru);

        cache.set('a', 1);
        cache.set('b', 2);
        cache.set('c', 3);

        // Access 'a' to make it recently used
        cache.get<int>('a');

        // Adding a 4th entry should evict LRU (which is 'b' since 'a' was just accessed)
        cache.set('d', 4);

        expect(cache.size, equals(3));
        expect(cache.has('a'), isTrue);
        expect(cache.has('d'), isTrue);
      });

      test('FIFO eviction removes oldest entry when maxSize exceeded', () {
        cache.configure(maxSize: 3, evictionPolicy: EvictionPolicy.fifo);

        cache.set('first', 1);
        cache.set('second', 2);
        cache.set('third', 3);
        cache.set('fourth', 4); // Should evict 'first'

        expect(cache.size, equals(3));
        expect(cache.has('first'), isFalse);
        expect(cache.has('fourth'), isTrue);
      });

      test('LFU eviction removes least frequently used entry', () {
        cache.configure(maxSize: 3, evictionPolicy: EvictionPolicy.lfu);

        cache.set('frequent', 1);
        cache.set('rare', 2);
        cache.set('medium', 3);

        // Access 'frequent' multiple times, 'medium' once
        cache.get<int>('frequent');
        cache.get<int>('frequent');
        cache.get<int>('frequent');
        cache.get<int>('medium');

        // 'rare' has 0 accesses so should be evicted
        cache.set('newcomer', 4);

        expect(cache.has('frequent'), isTrue);
        expect(cache.has('medium'), isTrue);
        expect(cache.has('newcomer'), isTrue);
        expect(cache.has('rare'), isFalse);
      });
    });

    // =========================================================================
    // cleanExpired
    // =========================================================================

    group('cleanExpired', () {
      test('should remove all expired entries', () async {
        cache.set('stale1', 'a', ttl: const Duration(milliseconds: 30));
        cache.set('stale2', 'b', ttl: const Duration(milliseconds: 30));
        cache.set('fresh', 'c', ttl: const Duration(seconds: 60));

        await Future.delayed(const Duration(milliseconds: 60));

        cache.cleanExpired();

        expect(cache.has('stale1'), isFalse);
        expect(cache.has('stale2'), isFalse);
        expect(cache.has('fresh'), isTrue);
      });
    });

    // =========================================================================
    // Statistics
    // =========================================================================

    group('Statistics', () {
      test('should track hits correctly', () {
        cache.set('key', 'value');
        cache.get<String>('key');
        cache.get<String>('key');

        expect(cache.stats.hits, equals(2));
      });

      test('should track misses correctly', () {
        cache.get<String>('nonexistent');
        cache.get<String>('alsoMissing');

        expect(cache.stats.misses, equals(2));
      });

      test('hitRate should be 1.0 with only hits', () {
        cache.set('key', 'value');
        cache.get<String>('key');

        expect(cache.stats.hitRate, equals(1.0));
      });

      test('hitRate should be 0.0 with only misses', () {
        cache.get<String>('missing');

        expect(cache.stats.hitRate, equals(0.0));
      });

      test('hitRate should be 0.0 when no accesses', () {
        expect(cache.stats.hitRate, equals(0.0));
      });

      test('should track expirations', () async {
        cache.set('temp', 'val', ttl: const Duration(milliseconds: 30));
        await Future.delayed(const Duration(milliseconds: 60));
        cache.get<String>('temp'); // triggers expiration detection

        expect(cache.stats.expirations, greaterThanOrEqualTo(1));
      });

      test('resetStats should zero all stats', () {
        cache.set('key', 'value');
        cache.get<String>('key');
        cache.get<String>('missing');

        cache.resetStats();

        expect(cache.stats.hits, equals(0));
        expect(cache.stats.misses, equals(0));
      });

      test('stats toString should include key information', () {
        final statsStr = cache.stats.toString();
        expect(statsStr, contains('hits'));
        expect(statsStr, contains('misses'));
      });
    });

    // =========================================================================
    // Getters
    // =========================================================================

    group('Getters', () {
      test('keys returns list of active keys', () {
        cache.set('one', 1);
        cache.set('two', 2);

        expect(cache.keys, containsAll(['one', 'two']));
      });

      test('size returns count of non-expired entries', () {
        cache.set('a', 1);
        cache.set('b', 2);
        expect(cache.size, equals(2));
      });

      test('isEmpty returns true when no entries', () {
        expect(cache.isEmpty, isTrue);
      });

      test('isNotEmpty returns true when entries exist', () {
        cache.set('x', 1);
        expect(cache.isNotEmpty, isTrue);
      });

      test('maxSize getter returns configured max', () {
        cache.configure(maxSize: 250);
        expect(cache.maxSize, equals(250));
      });

      test('evictionPolicy getter returns configured policy', () {
        cache.configure(evictionPolicy: EvictionPolicy.fifo);
        expect(cache.evictionPolicy, equals(EvictionPolicy.fifo));
      });
    });
  });

  // =========================================================================
  // CacheStats
  // =========================================================================

  group('CacheStats', () {
    test('hitRate is 0 when no hits or misses', () {
      const stats = CacheStats(
        size: 0,
        maxSize: 100,
        hits: 0,
        misses: 0,
        evictions: 0,
        expirations: 0,
        estimatedMemoryBytes: 0,
      );
      expect(stats.hitRate, equals(0.0));
    });

    test('hitRate calculates correctly with hits and misses', () {
      const stats = CacheStats(
        size: 10,
        maxSize: 100,
        hits: 3,
        misses: 1,
        evictions: 0,
        expirations: 0,
        estimatedMemoryBytes: 100,
      );
      expect(stats.hitRate, equals(0.75));
    });

    test('estimatedMemoryMB formats correctly', () {
      const stats = CacheStats(
        size: 0,
        maxSize: 100,
        hits: 0,
        misses: 0,
        evictions: 0,
        expirations: 0,
        estimatedMemoryBytes: 1024 * 1024, // 1MB
      );
      expect(stats.estimatedMemoryMB, equals('1.00'));
    });
  });
}
