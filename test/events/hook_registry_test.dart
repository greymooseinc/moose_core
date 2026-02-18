import 'package:flutter_test/flutter_test.dart';
import 'package:moose_core/services.dart';

void main() {
  group('HookRegistry', () {
    late HookRegistry registry;

    setUp(() {
      registry = HookRegistry();
      registry.clearAllHooks();
    });

    tearDown(() {
      registry.clearAllHooks();
    });

    // =========================================================================
    // Singleton
    // =========================================================================

    group('Singleton Pattern', () {
      test('should return the same instance', () {
        final a = HookRegistry();
        final b = HookRegistry();
        final c = HookRegistry.instance;

        expect(identical(a, b), isTrue);
        expect(identical(b, c), isTrue);
      });
    });

    // =========================================================================
    // Registration
    // =========================================================================

    group('register', () {
      test('should register a hook', () {
        registry.register('my.hook', (data) => data);
        expect(registry.hasHook('my.hook'), isTrue);
      });

      test('should register multiple hooks on the same name', () {
        registry.register('my.hook', (data) => data);
        registry.register('my.hook', (data) => data);
        expect(registry.getHookCount('my.hook'), equals(2));
      });

      test('should register hooks on different names independently', () {
        registry.register('hook.a', (data) => data);
        registry.register('hook.b', (data) => data);

        expect(registry.hasHook('hook.a'), isTrue);
        expect(registry.hasHook('hook.b'), isTrue);
        expect(registry.getHookCount('hook.a'), equals(1));
        expect(registry.getHookCount('hook.b'), equals(1));
      });

      test('should sort hooks by priority descending on registration', () {
        final callOrder = <int>[];

        registry.register('my.hook', (data) {
          callOrder.add(1);
          return data;
        }, priority: 1);

        registry.register('my.hook', (data) {
          callOrder.add(10);
          return data;
        }, priority: 10);

        registry.register('my.hook', (data) {
          callOrder.add(5);
          return data;
        }, priority: 5);

        registry.execute<int>('my.hook', 0);

        expect(callOrder, equals([10, 5, 1]));
      });

      test('default priority is 1', () {
        int callCount = 0;
        registry.register('my.hook', (data) {
          callCount++;
          return data;
        });
        registry.execute<int>('my.hook', 0);
        expect(callCount, equals(1));
      });
    });

    // =========================================================================
    // execute
    // =========================================================================

    group('execute', () {
      test('should return data unchanged when no hooks registered', () {
        final result = registry.execute<String>('no.hook', 'original');
        expect(result, equals('original'));
      });

      test('should transform data through a single hook', () {
        registry.register('double.hook', (data) => (data as int) * 2);
        final result = registry.execute<int>('double.hook', 5);
        expect(result, equals(10));
      });

      test('should chain transformations through multiple hooks', () {
        registry.register('chain.hook', (data) => (data as int) + 1, priority: 2);
        registry.register('chain.hook', (data) => (data as int) * 3, priority: 1);

        // priority 2 runs first: 10 + 1 = 11, then * 3 = 33
        final result = registry.execute<int>('chain.hook', 10);
        expect(result, equals(33));
      });

      test('should continue executing remaining hooks when one throws', () {
        bool secondHookRan = false;

        registry.register('error.hook', (data) {
          throw Exception('hook error');
        }, priority: 2);

        registry.register('error.hook', (data) {
          secondHookRan = true;
          return data;
        }, priority: 1);

        expect(() => registry.execute<int>('error.hook', 0), returnsNormally);
        expect(secondHookRan, isTrue);
      });

      test('should work with String data type', () {
        registry.register('str.hook', (data) => '${data}_suffix');
        final result = registry.execute<String>('str.hook', 'prefix');
        expect(result, equals('prefix_suffix'));
      });

      test('should work with Map data type', () {
        registry.register('map.hook', (data) {
          final map = Map<String, dynamic>.from(data as Map);
          map['extra'] = 'added';
          return map;
        });

        final result = registry.execute<Map<String, dynamic>>('map.hook', {'key': 'value'});
        expect(result['key'], equals('value'));
        expect(result['extra'], equals('added'));
      });

      test('should work with List data type', () {
        registry.register('list.hook', (data) {
          final list = List<int>.from(data as List);
          list.add(99);
          return list;
        });

        final result = registry.execute<List<int>>('list.hook', [1, 2, 3]);
        expect(result, equals([1, 2, 3, 99]));
      });

      test('should return original value when hook throws and no other hooks exist', () {
        registry.register('fail.hook', (data) => throw Exception('fail'));
        final result = registry.execute<int>('fail.hook', 42);
        expect(result, equals(42));
      });
    });

    // =========================================================================
    // removeHook
    // =========================================================================

    group('removeHook', () {
      test('should remove a specific hook by callback reference', () {
        dynamic myCallback(dynamic data) => data;

        registry.register('my.hook', myCallback);
        expect(registry.getHookCount('my.hook'), equals(1));

        registry.removeHook('my.hook', myCallback);
        expect(registry.getHookCount('my.hook'), equals(0));
        expect(registry.hasHook('my.hook'), isFalse);
      });

      test('should only remove the matching callback', () {
        dynamic cb1(dynamic data) => data;
        dynamic cb2(dynamic data) => data;

        registry.register('my.hook', cb1);
        registry.register('my.hook', cb2);

        registry.removeHook('my.hook', cb1);

        expect(registry.getHookCount('my.hook'), equals(1));
        expect(registry.hasHook('my.hook'), isTrue);
      });

      test('should do nothing when hook name does not exist', () {
        expect(
          () => registry.removeHook('nonexistent', (data) => data),
          returnsNormally,
        );
      });
    });

    // =========================================================================
    // clearHooks
    // =========================================================================

    group('clearHooks', () {
      test('should clear all hooks for a specific name', () {
        registry.register('my.hook', (data) => data);
        registry.register('my.hook', (data) => data);

        registry.clearHooks('my.hook');

        expect(registry.getHookCount('my.hook'), equals(0));
        expect(registry.hasHook('my.hook'), isFalse);
      });

      test('should not affect other hook names', () {
        registry.register('hook.a', (data) => data);
        registry.register('hook.b', (data) => data);

        registry.clearHooks('hook.a');

        expect(registry.hasHook('hook.a'), isFalse);
        expect(registry.hasHook('hook.b'), isTrue);
      });

      test('should do nothing for non-existent hook name', () {
        expect(() => registry.clearHooks('nonexistent'), returnsNormally);
      });
    });

    // =========================================================================
    // clearAllHooks
    // =========================================================================

    group('clearAllHooks', () {
      test('should clear all registered hooks', () {
        registry.register('hook.a', (data) => data);
        registry.register('hook.b', (data) => data);
        registry.register('hook.c', (data) => data);

        registry.clearAllHooks();

        expect(registry.getRegisteredHooks(), isEmpty);
        expect(registry.hasHook('hook.a'), isFalse);
        expect(registry.hasHook('hook.b'), isFalse);
        expect(registry.hasHook('hook.c'), isFalse);
      });

      test('should do nothing on empty registry', () {
        expect(() => registry.clearAllHooks(), returnsNormally);
        expect(registry.getRegisteredHooks(), isEmpty);
      });
    });

    // =========================================================================
    // getRegisteredHooks / hasHook / getHookCount
    // =========================================================================

    group('Metadata', () {
      test('getRegisteredHooks returns empty list when none registered', () {
        expect(registry.getRegisteredHooks(), isEmpty);
      });

      test('getRegisteredHooks returns all hook names', () {
        registry.register('hook.a', (data) => data);
        registry.register('hook.b', (data) => data);

        final hooks = registry.getRegisteredHooks();
        expect(hooks, containsAll(['hook.a', 'hook.b']));
        expect(hooks.length, equals(2));
      });

      test('hasHook returns false for unregistered hook', () {
        expect(registry.hasHook('not.registered'), isFalse);
      });

      test('hasHook returns false after all hooks are cleared', () {
        registry.register('my.hook', (data) => data);
        registry.clearHooks('my.hook');
        expect(registry.hasHook('my.hook'), isFalse);
      });

      test('getHookCount returns 0 for unknown hook', () {
        expect(registry.getHookCount('unknown'), equals(0));
      });

      test('getHookCount reflects registered count accurately', () {
        registry.register('my.hook', (data) => data);
        registry.register('my.hook', (data) => data);
        registry.register('my.hook', (data) => data);
        expect(registry.getHookCount('my.hook'), equals(3));
      });
    });

    // =========================================================================
    // Real-world use cases
    // =========================================================================

    group('Real-world Use Cases', () {
      test('cart item count hook returns value from state', () {
        registry.register('cart:get_item_count', (data) => 5);
        final count = registry.execute<int>('cart:get_item_count', 0);
        expect(count, equals(5));
      });

      test('multiple plugins can modify the same data pipeline', () {
        // Plugin A adds tax
        registry.register('order:total', (data) => (data as double) * 1.1, priority: 2);
        // Plugin B adds shipping
        registry.register('order:total', (data) => (data as double) + 10.0, priority: 1);

        // tax applied first (priority 2): 100 * 1.1 = 110, then +10 = 120
        final total = registry.execute<double>('order:total', 100.0);
        expect(total, closeTo(120.0, 0.01));
      });
    });
  });
}
