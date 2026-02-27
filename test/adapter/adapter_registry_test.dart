import 'package:flutter_test/flutter_test.dart';
import 'package:moose_core/adapters.dart';
import 'package:moose_core/app.dart';
import 'package:moose_core/repositories.dart';

/// Mock repository for testing
class MockRepository extends CoreRepository {
  MockRepository();

  bool _created = false;

  MockRepository.tracked() {
    _created = true;
  }

  bool get wasCreated => _created;

  @override
  void initialize() {}
}

/// Another mock for testing
class AnotherMockRepository extends CoreRepository {
  AnotherMockRepository();

  @override
  void initialize() {}
}

/// Test adapter that provides MockRepository
class TestAdapter1 extends BackendAdapter {
  int initializeCallCount = 0;

  @override
  String get name => 'test1';

  @override
  String get version => '1.0.0';

  @override
  Map<String, dynamic> get configSchema => {
        'type': 'object',
        'properties': {},
      };

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    initializeCallCount++;
    registerRepositoryFactory<MockRepository>(() => MockRepository());
  }
}

/// Another test adapter that provides AnotherMockRepository
class TestAdapter2 extends BackendAdapter {
  @override
  String get name => 'test2';

  @override
  String get version => '1.0.0';

  @override
  Map<String, dynamic> get configSchema => {
        'type': 'object',
        'properties': {},
      };

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    registerRepositoryFactory<AnotherMockRepository>(
      () => AnotherMockRepository(),
    );
  }
}

/// Adapter that overrides a repository from another adapter
class OverridingAdapter extends BackendAdapter {
  @override
  String get name => 'overriding';

  @override
  String get version => '1.0.0';

  @override
  Map<String, dynamic> get configSchema => {
        'type': 'object',
        'properties': {},
      };

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    // Registers the same repository type as TestAdapter1
    registerRepositoryFactory<MockRepository>(() => MockRepository());
  }
}

void main() {
  group('AdapterRegistry', () {
    group('Instance Isolation', () {
      test('each AdapterRegistry() creates an independent instance', () {
        final registry1 = AdapterRegistry();
        final registry2 = AdapterRegistry();

        expect(identical(registry1, registry2), isFalse);
      });

      test('two registries do not share state', () async {
        final registry1 = AdapterRegistry();
        final registry2 = AdapterRegistry();

        await registry1.registerAdapter(
          () async {
            final adapter = TestAdapter1();
            await adapter.initialize({});
            return adapter;
          },
          autoInitialize: false,
        );

        // registry2 has not had any adapters registered
        expect(registry1.adapterCount, 1);
        expect(registry2.adapterCount, 0);
        expect(registry2.isInitialized, false);
      });

      test('repositories from one registry are not visible in another', () async {
        final registry1 = AdapterRegistry();
        final registry2 = AdapterRegistry();

        await registry1.registerAdapter(
          () async {
            final adapter = TestAdapter1();
            await adapter.initialize({});
            return adapter;
          },
          autoInitialize: false,
        );

        expect(registry1.hasRepository<MockRepository>(), true);
        expect(registry2.hasRepository<MockRepository>(), false);
      });
    });

    group('Adapter Registration', () {
      test('should register adapter with sync factory', () async {
        final registry = AdapterRegistry();

        await registry.registerAdapter(
          () => TestAdapter1(),
          autoInitialize: false,
        );

        expect(registry.getInitializedAdapters(), contains('test1'));
      });

      test('should register adapter with async factory', () async {
        final registry = AdapterRegistry();

        await registry.registerAdapter(
          () async => TestAdapter1(),
          autoInitialize: false,
        );

        expect(registry.getInitializedAdapters(), contains('test1'));
      });

      test('should auto-initialize adapter when autoInitialize is true',
          () async {
        // This test would require ConfigManager to be set up
        // Skipping for now as it requires environment.json
      }, skip: 'Requires ConfigManager setup');

      test('should not auto-initialize when autoInitialize is false', () async {
        final registry = AdapterRegistry();

        await registry.registerAdapter(
          () => TestAdapter1(),
          autoInitialize: false,
        );

        expect(registry.isInitialized, true);
      });

      test('should throw when factory returns wrong type', () {
        final registry = AdapterRegistry();

        expect(
          () async => await registry.registerAdapter(
            () => 'not-an-adapter',
            autoInitialize: false,
          ),
          throwsException,
        );
      });

      test('should register multiple adapters', () async {
        final registry = AdapterRegistry();

        await registry.registerAdapter(
          () => TestAdapter1(),
          autoInitialize: false,
        );
        await registry.registerAdapter(
          () => TestAdapter2(),
          autoInitialize: false,
        );

        expect(registry.adapterCount, 2);
        expect(registry.getInitializedAdapters(), contains('test1'));
        expect(registry.getInitializedAdapters(), contains('test2'));
      });
    });

    group('Lazy Repository Instantiation', () {
      test('no repository instance is created during registration', () async {
        // We verify this by registering with autoInitialize: false and
        // checking that hasRepository returns true (factory registered) but
        // getRepository has not been called, so the instance count before
        // calling getRepository is zero (tracked via factory call count).
        int factoryCallCount = 0;
        final registry = AdapterRegistry();

        // Build adapter manually so we control the factory
        final adapter = TestAdapter1();
        await adapter.initialize({});
        // Replace the factory with a tracked one
        adapter.registerRepositoryFactory<MockRepository>(() {
          factoryCallCount++;
          return MockRepository();
        });

        await registry.registerAdapter(
          () => adapter,
          autoInitialize: false,
        );

        // Factory must NOT have been called during registration
        expect(factoryCallCount, 0);
        expect(registry.hasRepository<MockRepository>(), true);
      });

      test('repository factory is called on first getRepository', () async {
        int factoryCallCount = 0;
        final registry = AdapterRegistry();

        final adapter = TestAdapter1();
        await adapter.initialize({});
        adapter.registerRepositoryFactory<MockRepository>(() {
          factoryCallCount++;
          return MockRepository();
        });

        await registry.registerAdapter(() => adapter, autoInitialize: false);

        expect(factoryCallCount, 0);

        registry.getRepository<MockRepository>();

        expect(factoryCallCount, 1);
      });

      test('repository is cached after first getRepository call', () async {
        int factoryCallCount = 0;
        final registry = AdapterRegistry();

        final adapter = TestAdapter1();
        await adapter.initialize({});
        adapter.registerRepositoryFactory<MockRepository>(() {
          factoryCallCount++;
          return MockRepository();
        });

        await registry.registerAdapter(() => adapter, autoInitialize: false);

        final repo1 = registry.getRepository<MockRepository>();
        final repo2 = registry.getRepository<MockRepository>();
        final repo3 = registry.getRepository<MockRepository>();

        // Factory called exactly once
        expect(factoryCallCount, 1);
        // Same instance returned every time
        expect(identical(repo1, repo2), true);
        expect(identical(repo2, repo3), true);
      });
    });

    group('Repository Access', () {
      test('should get repository from registered adapter', () async {
        final registry = AdapterRegistry();

        await registry.registerAdapter(
          () async {
            final adapter = TestAdapter1();
            await adapter.initialize({});
            return adapter;
          },
          autoInitialize: false,
        );

        final repo = registry.getRepository<MockRepository>();

        expect(repo, isA<MockRepository>());
      });

      test('should throw when repository not registered', () async {
        final registry = AdapterRegistry();

        await registry.registerAdapter(
          () async {
            final adapter = TestAdapter1();
            await adapter.initialize({});
            return adapter;
          },
          autoInitialize: false,
        );

        try {
          registry.getRepository<AnotherMockRepository>();
          fail('Should have thrown');
        } catch (e) {
          expect(e.runtimeType.toString(), 'RepositoryNotRegisteredException');
        }
      });

      test('should provide helpful error message for missing repository',
          () async {
        final registry = AdapterRegistry();

        await registry.registerAdapter(
          () async {
            final adapter = TestAdapter1();
            await adapter.initialize({});
            return adapter;
          },
          autoInitialize: false,
        );

        try {
          registry.getRepository<AnotherMockRepository>();
          fail('Should have thrown');
        } catch (e) {
          expect(e.runtimeType.toString(), 'RepositoryNotRegisteredException');
          expect(e.toString(), contains('No adapter provides repository type'));
          expect(e.toString(), contains('Available repositories'));
        }
      });

      test('should return false for unregistered repository', () async {
        final registry = AdapterRegistry();

        await registry.registerAdapter(
          () async {
            final adapter = TestAdapter1();
            await adapter.initialize({});
            return adapter;
          },
          autoInitialize: false,
        );

        expect(registry.hasRepository<MockRepository>(), true);
        expect(registry.hasRepository<AnotherMockRepository>(), false);
      });
    });

    group('Last Registration Wins', () {
      test('should use last registered adapter for duplicate repository',
          () async {
        final registry = AdapterRegistry();

        await registry.registerAdapter(
          () async {
            final adapter = TestAdapter1();
            await adapter.initialize({});
            return adapter;
          },
          autoInitialize: false,
        );

        await registry.registerAdapter(
          () async {
            final adapter = OverridingAdapter();
            await adapter.initialize({});
            return adapter;
          },
          autoInitialize: false,
        );

        // Both adapters provide MockRepository, last one should win
        final repo = registry.getRepository<MockRepository>();
        expect(repo, isA<MockRepository>());
      });

      test('overriding an existing type clears the previously cached instance',
          () async {
        final registry = AdapterRegistry();

        await registry.registerAdapter(
          () async {
            final a = TestAdapter1();
            await a.initialize({});
            return a;
          },
          autoInitialize: false,
        );

        // Resolve repo from first adapter — this caches the instance.
        final repo1 = registry.getRepository<MockRepository>();

        // Register an overriding adapter for the same type.
        await registry.registerAdapter(
          () async {
            final a = OverridingAdapter();
            await a.initialize({});
            return a;
          },
          autoInitialize: false,
        );

        // The new getRepository call must use the new factory, not the
        // previously cached instance.
        final repo2 = registry.getRepository<MockRepository>();
        expect(identical(repo1, repo2), isFalse);
      });
    });

    group('Multiple Adapters', () {
      test('should support repositories from different adapters', () async {
        final registry = AdapterRegistry();

        await registry.registerAdapter(
          () async {
            final adapter = TestAdapter1();
            await adapter.initialize({});
            return adapter;
          },
          autoInitialize: false,
        );

        await registry.registerAdapter(
          () async {
            final adapter = TestAdapter2();
            await adapter.initialize({});
            return adapter;
          },
          autoInitialize: false,
        );

        final repo1 = registry.getRepository<MockRepository>();
        final repo2 = registry.getRepository<AnotherMockRepository>();

        expect(repo1, isA<MockRepository>());
        expect(repo2, isA<AnotherMockRepository>());
      });
    });

    group('Metadata', () {
      test('should return available repository types', () async {
        final registry = AdapterRegistry();

        await registry.registerAdapter(
          () async {
            final adapter = TestAdapter1();
            await adapter.initialize({});
            return adapter;
          },
          autoInitialize: false,
        );
        await registry.registerAdapter(
          () async {
            final adapter = TestAdapter2();
            await adapter.initialize({});
            return adapter;
          },
          autoInitialize: false,
        );

        final repos = registry.getAvailableRepositories();

        expect(repos, contains(MockRepository));
        expect(repos, contains(AnotherMockRepository));
        expect(repos.length, 2);
      });

      test('should return initialized adapter names', () async {
        final registry = AdapterRegistry();

        await registry.registerAdapter(
          () => TestAdapter1(),
          autoInitialize: false,
        );
        await registry.registerAdapter(
          () => TestAdapter2(),
          autoInitialize: false,
        );

        final adapters = registry.getInitializedAdapters();

        expect(adapters, contains('test1'));
        expect(adapters, contains('test2'));
        expect(adapters.length, 2);
      });

      test('should return repository count', () async {
        final registry = AdapterRegistry();

        expect(registry.repositoryCount, 0);

        await registry.registerAdapter(
          () async {
            final adapter = TestAdapter1();
            await adapter.initialize({});
            return adapter;
          },
          autoInitialize: false,
        );

        expect(registry.repositoryCount, 1);

        await registry.registerAdapter(
          () async {
            final adapter = TestAdapter2();
            await adapter.initialize({});
            return adapter;
          },
          autoInitialize: false,
        );

        expect(registry.repositoryCount, 2);
      });

      test('should return adapter count', () async {
        final registry = AdapterRegistry();

        expect(registry.adapterCount, 0);

        await registry.registerAdapter(
          () => TestAdapter1(),
          autoInitialize: false,
        );

        expect(registry.adapterCount, 1);

        await registry.registerAdapter(
          () => TestAdapter2(),
          autoInitialize: false,
        );

        expect(registry.adapterCount, 2);
      });

      test('should track initialization state', () {
        final registry = AdapterRegistry();

        expect(registry.isInitialized, false);
      });

      test('should mark as initialized after registering adapter', () async {
        final registry = AdapterRegistry();

        await registry.registerAdapter(
          () => TestAdapter1(),
          autoInitialize: false,
        );

        expect(registry.isInitialized, true);
      });
    });

    group('Adapter Access', () {
      test('should get adapter by name', () async {
        final registry = AdapterRegistry();

        await registry.registerAdapter(
          () => TestAdapter1(),
          autoInitialize: false,
        );

        final adapter = registry.getAdapter<TestAdapter1>('test1');

        expect(adapter, isA<TestAdapter1>());
      });

      test('should throw when adapter not found', () async {
        final registry = AdapterRegistry();

        expect(
          () => registry.getAdapter<TestAdapter1>('nonexistent'),
          throwsA(isA<StateError>()),
        );
      });

      test('should provide helpful error for missing adapter', () async {
        final registry = AdapterRegistry();

        await registry.registerAdapter(
          () => TestAdapter1(),
          autoInitialize: false,
        );

        try {
          registry.getAdapter<TestAdapter2>('nonexistent');
          fail('Should have thrown');
        } catch (e) {
          expect(e.toString(), contains('Adapter "nonexistent" not found'));
          expect(e.toString(), contains('Available adapters'));
        }
      });
    });

    group('Cleanup', () {
      test('should clear all adapters and repositories', () async {
        final registry = AdapterRegistry();

        await registry.registerAdapter(
          () async {
            final adapter = TestAdapter1();
            await adapter.initialize({});
            return adapter;
          },
          autoInitialize: false,
        );
        await registry.registerAdapter(
          () async {
            final adapter = TestAdapter2();
            await adapter.initialize({});
            return adapter;
          },
          autoInitialize: false,
        );

        expect(registry.adapterCount, 2);
        expect(registry.repositoryCount, 2);

        registry.clearAll();

        expect(registry.adapterCount, 0);
        expect(registry.repositoryCount, 0);
        expect(registry.isInitialized, false);
      });
    });

    group('Error Handling', () {
      test('should throw StateError when not initialized', () async {
        final registry = AdapterRegistry();

        expect(
          () => registry.getRepository<MockRepository>(),
          throwsA(isA<StateError>()),
        );
      });

      test('should provide clear error when not initialized', () {
        final registry = AdapterRegistry();

        try {
          registry.getRepository<MockRepository>();
          fail('Should have thrown');
        } catch (e) {
          expect(e, isA<StateError>());
          expect(
            e.toString(),
            contains('AdapterRegistry not initialized'),
          );
        }
      });

      test('autoInitialize without scoped ConfigManager throws StateError',
          () async {
        final registry = AdapterRegistry();
        // Do NOT call setDependencies — no ConfigManager injected.

        expect(
          () async => await registry.registerAdapter(
            () => TestAdapter1(),
            autoInitialize: true,
          ),
          throwsA(isA<StateError>()),
        );
      });

      test('autoInitialize with scoped ConfigManager loads adapter config',
          () async {
        final registry = AdapterRegistry();
        final appContext = MooseAppContext();
        appContext.configManager.initialize({
          'adapters': {
            'test1': {},
          },
        });
        registry.setDependencies(
          appContext: appContext,
        );

        // TestAdapter1 has an empty configSchema (no required fields),
        // so this should succeed.
        await registry.registerAdapter(() => TestAdapter1());

        expect(registry.isInitialized, true);
        expect(registry.hasRepository<MockRepository>(), true);
      });
    });
  });
}
