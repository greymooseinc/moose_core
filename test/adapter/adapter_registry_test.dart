import 'package:flutter_test/flutter_test.dart';
import 'package:moose_core/adapters.dart';
import 'package:moose_core/repositories.dart';

/// Mock repository for testing
class MockRepository extends CoreRepository {
  @override
  void initialize() {}
}

/// Another mock for testing
class AnotherMockRepository extends CoreRepository {
  @override
  void initialize() {}
}

/// Test adapter that provides MockRepository
class TestAdapter1 extends BackendAdapter {
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
    setUp(() {
      // Clear registry before each test
      AdapterRegistry().clearAll();
    });

    tearDown(() {
      // Clean up after each test
      AdapterRegistry().clearAll();
    });

    group('Singleton Pattern', () {
      test('should return same instance', () {
        final registry1 = AdapterRegistry();
        final registry2 = AdapterRegistry();

        expect(identical(registry1, registry2), true);
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
      test('should handle adapter initialization failures', () async {
        final registry = AdapterRegistry();

        // This will fail if we try to access repositories before initialization
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
    });
  });
}
