import 'package:flutter_test/flutter_test.dart';
import 'package:moose_core/app.dart';

void main() {
  group('Multi-context isolation', () {
    late MooseAppContext ctx1;
    late MooseAppContext ctx2;

    setUp(() {
      ctx1 = MooseAppContext();
      ctx2 = MooseAppContext();
    });

    tearDown(() {
      ctx1.dispose();
      ctx2.dispose();
    });

    // -------------------------------------------------------------------------
    // HookRegistry isolation
    // -------------------------------------------------------------------------

    test('two contexts have separate hook registries', () {
      expect(ctx1.hookRegistry, isNot(same(ctx2.hookRegistry)));
    });

    test('hook registered in ctx1 is not visible in ctx2', () {
      ctx1.hookRegistry.register('test.hook', (data) => '${data}_ctx1');

      // ctx2 has no hook for 'test.hook' — execute returns the input unchanged
      expect(
        ctx2.hookRegistry.execute<String>('test.hook', 'input'),
        equals('input'),
      );
    });

    test('hook registered in ctx1 works correctly in ctx1', () {
      ctx1.hookRegistry.register('test.hook', (data) => '${data}_ctx1');

      expect(
        ctx1.hookRegistry.execute<String>('test.hook', 'input'),
        equals('input_ctx1'),
      );
    });

    test('hook state mutations in ctx1 do not affect ctx2', () {
      ctx1.hookRegistry.register('shared.hook', (data) => (data as int) + 10);
      ctx2.hookRegistry.register('shared.hook', (data) => (data as int) + 20);

      expect(ctx1.hookRegistry.execute<int>('shared.hook', 0), equals(10));
      expect(ctx2.hookRegistry.execute<int>('shared.hook', 0), equals(20));
    });

    // -------------------------------------------------------------------------
    // EventBus isolation
    // -------------------------------------------------------------------------

    test('two contexts have separate event buses', () {
      expect(ctx1.eventBus, isNot(same(ctx2.eventBus)));
    });

    test('event fired on ctx1 bus is not received by ctx2 subscriber', () async {
      final received = <String>[];
      ctx2.eventBus.on('test.event', (e) => received.add(e.name));

      ctx1.eventBus.fire('test.event');
      await Future.delayed(Duration.zero);

      expect(received, isEmpty);
    });

    // -------------------------------------------------------------------------
    // Cache isolation
    // -------------------------------------------------------------------------

    test('two contexts have separate cache instances', () {
      expect(ctx1.cache, isNot(same(ctx2.cache)));
    });

    test('in-memory cache entries set in ctx1 are not visible in ctx2', () {
      ctx1.cache.memory.set('my_key', 'ctx1_value');

      expect(ctx2.cache.memory.get<String>('my_key'), isNull);
    });

    // -------------------------------------------------------------------------
    // WidgetRegistry isolation
    // -------------------------------------------------------------------------

    test('two contexts have separate widget registries', () {
      expect(ctx1.widgetRegistry, isNot(same(ctx2.widgetRegistry)));
    });

    // -------------------------------------------------------------------------
    // ConfigManager isolation
    // -------------------------------------------------------------------------

    test('two contexts have separate config managers', () {
      expect(ctx1.configManager, isNot(same(ctx2.configManager)));
    });

    // -------------------------------------------------------------------------
    // ActionRegistry isolation
    // -------------------------------------------------------------------------

    test('two contexts have separate action registries', () {
      expect(ctx1.actionRegistry, isNot(same(ctx2.actionRegistry)));
    });

    // -------------------------------------------------------------------------
    // PluginRegistry isolation
    // -------------------------------------------------------------------------

    test('two contexts have separate plugin registries', () {
      expect(ctx1.pluginRegistry, isNot(same(ctx2.pluginRegistry)));
    });
  });
}
