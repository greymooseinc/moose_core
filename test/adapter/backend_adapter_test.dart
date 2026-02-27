import 'package:flutter_test/flutter_test.dart';
import 'package:moose_core/adapters.dart';
import 'package:moose_core/repositories.dart';

/// Minimal mock repository for testing - only implements what's needed
class MockRepository extends CoreRepository {
  MockRepository();

  bool _initialized = false;

  @override
  void initialize() {
    _initialized = true;
  }

  bool get isInitialized => _initialized;
}

/// Another mock repository for testing multiple repository types
class AnotherMockRepository extends CoreRepository {
  AnotherMockRepository();

  @override
  void initialize() {}
}

/// Test adapter implementation
class TestAdapter extends BackendAdapter {
  @override
  String get name => 'test';

  @override
  String get version => '1.0.0';

  @override
  Map<String, dynamic> get configSchema => {
        'type': 'object',
        'required': ['apiKey'],
        'properties': {
          'apiKey': {
            'type': 'string',
            'minLength': 1,
            'description': 'API Key',
          },
          'timeout': {
            'type': 'integer',
            'minimum': 0,
            'description': 'Timeout in seconds',
          },
        },
        'additionalProperties': false,
      };

  bool _initializeCalled = false;
  Map<String, dynamic>? _receivedConfig;

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    _initializeCalled = true;
    _receivedConfig = config;
  }

  bool get isInitialized => _initializeCalled;
  Map<String, dynamic>? get receivedConfig => _receivedConfig;
}

void main() {
  group('BackendAdapter', () {
    late TestAdapter adapter;

    setUp(() {
      adapter = TestAdapter();
    });

    group('Repository Factory Registration', () {
      test('should register sync repository factory', () {
        adapter.registerRepositoryFactory<MockRepository>(
          () => MockRepository(),
        );

        expect(adapter.hasRepository<MockRepository>(), true);
        expect(adapter.isRepositoryCached<MockRepository>(), false);
      });

      test('should register async repository factory', () {
        adapter.registerAsyncRepositoryFactory<AnotherMockRepository>(
          () async => AnotherMockRepository(),
        );

        expect(adapter.hasRepository<AnotherMockRepository>(), true);
        expect(adapter.isRepositoryCached<AnotherMockRepository>(), false);
      });

      test('should return false for unregistered repository', () {
        expect(adapter.hasRepository<MockRepository>(), false);
      });
    });

    group('Repository Retrieval', () {
      test('should get repository from sync factory', () {
        adapter.registerRepositoryFactory<MockRepository>(
          () => MockRepository(),
        );

        final repo = adapter.getRepository<MockRepository>();

        expect(repo, isA<MockRepository>());
        expect(adapter.isRepositoryCached<MockRepository>(), true);
      });

      test('should call initialize on repository after creation', () {
        adapter.registerRepositoryFactory<MockRepository>(
          () => MockRepository(),
        );

        final repo = adapter.getRepository<MockRepository>();

        expect(repo.isInitialized, true);
      });

      test('should cache repository after first retrieval', () {
        adapter.registerRepositoryFactory<MockRepository>(
          () => MockRepository(),
        );

        final repo1 = adapter.getRepository<MockRepository>();
        final repo2 = adapter.getRepository<MockRepository>();

        expect(identical(repo1, repo2), true);
      });

      test('should get repository from async factory', () async {
        adapter.registerAsyncRepositoryFactory<AnotherMockRepository>(
          () async => AnotherMockRepository(),
        );

        final repo = await adapter.getRepositoryAsync<AnotherMockRepository>();

        expect(repo, isA<AnotherMockRepository>());
        expect(adapter.isRepositoryCached<AnotherMockRepository>(), true);
      });

      test('should throw when getting unregistered repository', () {
        expect(
          () => adapter.getRepository<MockRepository>(),
          throwsA(isA<RepositoryNotRegisteredException>()),
        );
      });

      test('should throw when getting async factory with sync method', () {
        adapter.registerAsyncRepositoryFactory<AnotherMockRepository>(
          () async => AnotherMockRepository(),
        );

        expect(
          () => adapter.getRepository<AnotherMockRepository>(),
          throwsA(isA<RepositoryNotRegisteredException>()),
        );
      });

      test('should support getting async factory with async method', () async {
        adapter.registerAsyncRepositoryFactory<AnotherMockRepository>(
          () async => AnotherMockRepository(),
        );

        final repo = await adapter.getRepositoryAsync<AnotherMockRepository>();
        expect(repo, isA<AnotherMockRepository>());
      });

      test('should support getting sync factory with async method', () async {
        adapter.registerRepositoryFactory<MockRepository>(
          () => MockRepository(),
        );

        final repo = await adapter.getRepositoryAsync<MockRepository>();
        expect(repo, isA<MockRepository>());
      });
    });

    group('Cache Management', () {
      test('should clear specific repository cache', () {
        adapter.registerRepositoryFactory<MockRepository>(
          () => MockRepository(),
        );

        final repo1 = adapter.getRepository<MockRepository>();
        expect(adapter.isRepositoryCached<MockRepository>(), true);

        adapter.clearRepositoryCache<MockRepository>();
        expect(adapter.isRepositoryCached<MockRepository>(), false);

        final repo2 = adapter.getRepository<MockRepository>();
        expect(identical(repo1, repo2), false);
      });

      test('should clear all repository caches', () {
        adapter.registerRepositoryFactory<MockRepository>(
          () => MockRepository(),
        );
        adapter.registerRepositoryFactory<AnotherMockRepository>(
          () => AnotherMockRepository(),
        );

        adapter.getRepository<MockRepository>();
        adapter.getRepository<AnotherMockRepository>();

        expect(adapter.isRepositoryCached<MockRepository>(), true);
        expect(adapter.isRepositoryCached<AnotherMockRepository>(), true);

        adapter.clearAllRepositoryCaches();

        expect(adapter.isRepositoryCached<MockRepository>(), false);
        expect(adapter.isRepositoryCached<AnotherMockRepository>(), false);
      });
    });

    group('Metadata', () {
      test('should return registered repository types', () {
        adapter.registerRepositoryFactory<MockRepository>(
          () => MockRepository(),
        );
        adapter.registerRepositoryFactory<AnotherMockRepository>(
          () => AnotherMockRepository(),
        );

        final types = adapter.registeredRepositoryTypes;

        expect(types, contains(MockRepository));
        expect(types, contains(AnotherMockRepository));
        expect(types.length, 2);
      });
    });

    group('Config Validation', () {
      test('should validate valid configuration', () {
        final config = {'apiKey': 'test-key', 'timeout': 30};

        expect(() => adapter.validateConfig(config), returnsNormally);
      });

      test('should accept valid config without optional fields', () {
        final config = {'apiKey': 'test-key'};

        expect(() => adapter.validateConfig(config), returnsNormally);
      });

      test('should reject missing required fields', () {
        final config = {'timeout': 30}; // Missing apiKey

        expect(
          () => adapter.validateConfig(config),
          throwsA(isA<AdapterConfigValidationException>()),
        );
      });

      test('should reject invalid types', () {
        final config = {'apiKey': 'test-key', 'timeout': 'not-a-number'};

        expect(
          () => adapter.validateConfig(config),
          throwsA(isA<AdapterConfigValidationException>()),
        );
      });

      test('should reject additional properties', () {
        final config = {'apiKey': 'test-key', 'unknown': 'value'};

        expect(
          () => adapter.validateConfig(config),
          throwsA(isA<AdapterConfigValidationException>()),
        );
      });

      test('should reject values below minimum', () {
        final config = {'apiKey': 'test-key', 'timeout': -1};

        expect(
          () => adapter.validateConfig(config),
          throwsA(isA<AdapterConfigValidationException>()),
        );
      });

      test('should reject empty required string', () {
        final config = {'apiKey': ''};

        expect(
          () => adapter.validateConfig(config),
          throwsA(isA<AdapterConfigValidationException>()),
        );
      });

      test('should include helpful error message', () {
        final config = <String, dynamic>{}; // Missing required apiKey

        try {
          adapter.validateConfig(config);
          fail('Should have thrown');
        } catch (e) {
          expect(e, isA<AdapterConfigValidationException>());
          expect(e.toString(), contains('apiKey'));
          expect(e.toString(), contains('Required fields'));
        }
      });

      test('should include schema information in error message', () {
        final config = <String, dynamic>{};

        try {
          adapter.validateConfig(config);
          fail('Should have thrown');
        } catch (e) {
          expect(e.toString(), contains('API Key'));
          expect(e.toString(), contains('Available fields'));
        }
      });
    });

    group('Initialization', () {
      test('should call initialize with config', () async {
        final config = {'apiKey': 'test-key'};

        await adapter.initialize(config);

        expect(adapter.isInitialized, true);
        expect(adapter.receivedConfig, equals(config));
      });

      test('should handle initialization without validation', () async {
        final config = {'apiKey': 'test-key', 'timeout': 30};

        // initialize() should not validate - that's done by initializeFromConfig()
        await adapter.initialize(config);

        expect(adapter.isInitialized, true);
      });
    });

    group('Repository By Type', () {
      test('should get repository by runtime type', () {
        adapter.registerRepositoryFactory<MockRepository>(
          () => MockRepository(),
        );

        final repo = adapter.getRepositoryByType(MockRepository);

        expect(repo, isA<MockRepository>());
      });

      test('should throw for unregistered type', () {
        expect(
          () => adapter.getRepositoryByType(MockRepository),
          throwsA(isA<RepositoryNotRegisteredException>()),
        );
      });

      test('should cache repository retrieved by type', () {
        adapter.registerRepositoryFactory<MockRepository>(
          () => MockRepository(),
        );

        final repo1 = adapter.getRepositoryByType(MockRepository);
        final repo2 = adapter.getRepositoryByType(MockRepository);

        expect(identical(repo1, repo2), true);
      });
    });

    group('Multiple Repositories', () {
      test('should support multiple repository types', () {
        adapter.registerRepositoryFactory<MockRepository>(
          () => MockRepository(),
        );
        adapter.registerRepositoryFactory<AnotherMockRepository>(
          () => AnotherMockRepository(),
        );

        final repo1 = adapter.getRepository<MockRepository>();
        final repo2 = adapter.getRepository<AnotherMockRepository>();

        expect(repo1, isA<MockRepository>());
        expect(repo2, isA<AnotherMockRepository>());
        expect(identical(repo1, repo2), false);
      });

      test('should cache each repository type independently', () {
        adapter.registerRepositoryFactory<MockRepository>(
          () => MockRepository(),
        );
        adapter.registerRepositoryFactory<AnotherMockRepository>(
          () => AnotherMockRepository(),
        );

        adapter.getRepository<MockRepository>();
        adapter.getRepository<AnotherMockRepository>();

        expect(adapter.isRepositoryCached<MockRepository>(), true);
        expect(adapter.isRepositoryCached<AnotherMockRepository>(), true);

        adapter.clearRepositoryCache<MockRepository>();

        expect(adapter.isRepositoryCached<MockRepository>(), false);
        expect(adapter.isRepositoryCached<AnotherMockRepository>(), true);
      });
    });
  });
}
