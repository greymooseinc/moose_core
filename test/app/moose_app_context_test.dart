import 'package:flutter_test/flutter_test.dart';
import 'package:moose_core/adapters.dart';
import 'package:moose_core/app.dart';
import 'package:moose_core/repositories.dart';
import 'package:moose_core/services.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class MockRepo extends CoreRepository {
  MockRepo() : super(hookRegistry: HookRegistry(), eventBus: EventBus());

  @override
  void initialize() {}
}

class AnotherMockRepo extends CoreRepository {
  AnotherMockRepo() : super(hookRegistry: HookRegistry(), eventBus: EventBus());

  @override
  void initialize() {}
}

class SimpleAdapter extends BackendAdapter {
  @override
  String get name => 'simple';

  @override
  String get version => '1.0.0';

  @override
  Map<String, dynamic> get configSchema => {'type': 'object', 'properties': {}};

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    registerRepositoryFactory<MockRepo>(() => MockRepo());
  }
}

class AnotherAdapter extends BackendAdapter {
  @override
  String get name => 'another';

  @override
  String get version => '1.0.0';

  @override
  Map<String, dynamic> get configSchema => {'type': 'object', 'properties': {}};

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    registerRepositoryFactory<AnotherMockRepo>(() => AnotherMockRepo());
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Creates a MooseAppContext with a pre-initialized ConfigManager and an
/// optional list of manually-initialized adapters (autoInitialize: false).
///
/// Each adapter is initialized before being passed to the registry so that
/// its repository factories are registered without needing ConfigManager lookup.
Future<MooseAppContext> _makeContext({
  Map<String, dynamic>? config,
  List<BackendAdapter> adapters = const [],
}) async {
  final ctx = MooseAppContext();
  ctx.configManager.initialize(config ?? {});
  for (final a in adapters) {
    await a.initialize({});
    await ctx.adapterRegistry.registerAdapter(() => a, autoInitialize: false);
  }
  return ctx;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('MooseAppContext', () {
    group('Instance isolation', () {
      test('two contexts own independent registries', () {
        final ctx1 = MooseAppContext();
        final ctx2 = MooseAppContext();

        expect(identical(ctx1.adapterRegistry, ctx2.adapterRegistry), isFalse);
        expect(identical(ctx1.configManager, ctx2.configManager), isFalse);
        expect(identical(ctx1.hookRegistry, ctx2.hookRegistry), isFalse);
        expect(identical(ctx1.eventBus, ctx2.eventBus), isFalse);
      });

      test('adapters registered in one context are not visible in another',
          () async {
        final ctx1 = await _makeContext(adapters: [SimpleAdapter()]);
        final ctx2 = MooseAppContext();

        expect(ctx1.adapterRegistry.hasRepository<MockRepo>(), true);
        expect(ctx2.adapterRegistry.hasRepository<MockRepo>(), false);
      });

      test('config initialized in one context does not affect another',
          () async {
        final ctx1 = MooseAppContext();
        ctx1.configManager.initialize({'key': 'value1'});

        final ctx2 = MooseAppContext();
        ctx2.configManager.initialize({'key': 'value2'});

        expect(ctx1.configManager.get('key'), 'value1');
        expect(ctx2.configManager.get('key'), 'value2');
      });
    });

    group('Scoped dependency wiring', () {
      test('AdapterRegistry receives the scoped ConfigManager', () async {
        final ctx = MooseAppContext();
        ctx.configManager.initialize({
          'adapters': {'simple': {}},
        });

        await ctx.adapterRegistry.registerAdapter(
          () => SimpleAdapter(),
          autoInitialize: true,
        );

        expect(ctx.adapterRegistry.isInitialized, true);
      });
    });

    group('Lazy repository access', () {
      test('getRepository creates instance only on first call', () async {
        int callCount = 0;
        final adapter = SimpleAdapter();
        // Register a tracked factory directly.
        adapter.registerRepositoryFactory<MockRepo>(() {
          callCount++;
          return MockRepo();
        });

        // Build context manually — do not call adapter.initialize() to avoid
        // overwriting the tracked factory.
        final ctx = MooseAppContext();
        ctx.configManager.initialize({});
        await ctx.adapterRegistry.registerAdapter(() => adapter, autoInitialize: false);

        expect(callCount, 0); // Not yet created

        ctx.getRepository<MockRepo>();
        expect(callCount, 1);

        ctx.getRepository<MockRepo>();
        ctx.getRepository<MockRepo>();
        expect(callCount, 1); // Still cached after first call
      });

      test('getRepository returns the same instance on repeated calls',
          () async {
        final ctx = await _makeContext(adapters: [SimpleAdapter()]);

        final repo1 = ctx.getRepository<MockRepo>();
        final repo2 = ctx.getRepository<MockRepo>();

        expect(identical(repo1, repo2), true);
      });

      test('getRepository delegates to adapterRegistry.getRepository',
          () async {
        final ctx = await _makeContext(adapters: [SimpleAdapter()]);

        final fromContext = ctx.getRepository<MockRepo>();
        final fromRegistry = ctx.adapterRegistry.getRepository<MockRepo>();

        // Both paths must return the same cached instance.
        expect(identical(fromContext, fromRegistry), true);
      });
    });

    group('Constructor injection (for testing)', () {
      test('accepts externally created ConfigManager', () {
        final cm = ConfigManager();
        cm.initialize({'theme': 'dark'});

        final ctx = MooseAppContext(configManager: cm);

        expect(identical(ctx.configManager, cm), true);
        expect(ctx.configManager.get('theme'), 'dark');
      });

      test('accepts externally created AdapterRegistry', () {
        final registry = AdapterRegistry();
        final ctx = MooseAppContext(adapterRegistry: registry);

        expect(identical(ctx.adapterRegistry, registry), true);
      });

      test('injected registry is still wired to scoped dependencies', () {
        final cm = ConfigManager();
        cm.initialize({'adapters': {}});
        final registry = AdapterRegistry();

        final ctx = MooseAppContext(configManager: cm, adapterRegistry: registry);

        // The constructor wires the registry to the context's scoped deps.
        // Verify by attempting autoInitialize — it should not throw StateError
        // about missing ConfigManager.
        expect(
          () async => await ctx.adapterRegistry.registerAdapter(
            () async {
              final a = SimpleAdapter();
              // No adapters key in config for 'simple', so will throw about
              // missing config — but NOT about missing ConfigManager.
              return a;
            },
            autoInitialize: true,
          ),
          // Throws because config has no 'simple' entry — not because
          // ConfigManager is null.
          throwsException,
        );
      });
    });
  });
}
