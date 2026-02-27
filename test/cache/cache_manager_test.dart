import 'package:flutter_test/flutter_test.dart';
import 'package:moose_core/app.dart';
import 'package:moose_core/cache.dart';

void main() {
  // =========================================================================
  // CacheManager — instance-based, scoped
  // =========================================================================

  group('CacheManager', () {
    late CacheManager cm;

    setUp(() {
      cm = CacheManager();
    });

    tearDown(() {
      cm.dispose();
    });

    test('owns a MemoryCache instance', () {
      expect(cm.memory, isA<MemoryCache>());
    });

    test('owns a PersistentCache instance', () {
      expect(cm.persistent, isA<PersistentCache>());
    });

    test('two CacheManager instances have independent MemoryCache objects', () {
      final cm1 = CacheManager();
      final cm2 = CacheManager();

      expect(identical(cm1.memory, cm2.memory), isFalse);

      cm1.dispose();
      cm2.dispose();
    });

    test('two CacheManager instances have independent PersistentCache objects', () {
      final cm1 = CacheManager();
      final cm2 = CacheManager();

      expect(identical(cm1.persistent, cm2.persistent), isFalse);

      cm1.dispose();
      cm2.dispose();
    });

    test('clearMemory clears only the memory cache', () {
      cm.memory.set('key', 'value');
      expect(cm.memory.get<String>('key'), equals('value'));

      cm.clearMemory();

      expect(cm.memory.get<String>('key'), isNull);
    });

    test('accepts injected MemoryCache and PersistentCache for testing', () {
      final mem = MemoryCache();
      final pers = PersistentCache();
      final custom = CacheManager(memory: mem, persistent: pers);

      expect(identical(custom.memory, mem), isTrue);
      expect(identical(custom.persistent, pers), isTrue);

      custom.dispose();
    });
  });

  // =========================================================================
  // MooseAppContext — cache scoping
  // =========================================================================

  group('MooseAppContext cache scoping', () {
    test('each MooseAppContext owns an independent CacheManager', () {
      final ctx1 = MooseAppContext();
      final ctx2 = MooseAppContext();

      expect(identical(ctx1.cache, ctx2.cache), isFalse);
      expect(identical(ctx1.cache.memory, ctx2.cache.memory), isFalse);
      expect(identical(ctx1.cache.persistent, ctx2.cache.persistent), isFalse);

      ctx1.cache.dispose();
      ctx2.cache.dispose();
    });

    test('memory cache writes in ctx1 are NOT visible in ctx2', () {
      final ctx1 = MooseAppContext();
      final ctx2 = MooseAppContext();

      ctx1.cache.memory.set('shared_key', 'ctx1_value');

      expect(ctx1.cache.memory.get<String>('shared_key'), equals('ctx1_value'));
      expect(ctx2.cache.memory.get<String>('shared_key'), isNull);

      ctx1.cache.dispose();
      ctx2.cache.dispose();
    });

    test('clearing cache in ctx1 does NOT affect ctx2', () {
      final ctx1 = MooseAppContext();
      final ctx2 = MooseAppContext();

      ctx1.cache.memory.set('data', 'a');
      ctx2.cache.memory.set('data', 'b');

      ctx1.cache.clearMemory();

      expect(ctx1.cache.memory.get<String>('data'), isNull);
      expect(ctx2.cache.memory.get<String>('data'), equals('b'));

      ctx1.cache.dispose();
      ctx2.cache.dispose();
    });

    test('accepts injected CacheManager for testing', () {
      final customCache = CacheManager();
      final ctx = MooseAppContext(cache: customCache);

      expect(identical(ctx.cache, customCache), isTrue);

      customCache.dispose();
    });
  });

  // =========================================================================
  // Lazy repository instantiation (via MooseAppContext)
  // =========================================================================
}
