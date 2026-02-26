import 'package:moose_core/repositories.dart';
import 'package:moose_core/services.dart';
import 'package:json_schema/json_schema.dart';

/// BackendAdapter - Abstract base class for backend implementations
///
/// This class uses a **lazy repository manager pattern** with factory-based
/// registration. Repositories are only instantiated when first requested,
/// and then cached for subsequent use. All repositories must extend [CoreRepository].
///
/// ## Key Features:
/// - **Lazy Initialization**: Repositories created only when needed
/// - **Factory Registration**: Register factories instead of instances
/// - **Async Support**: Supports both sync and async factories
/// - **Repository Initialization**: Automatically calls synchronous `initialize()` on repositories
///   - Both `getRepository()` and `getRepositoryAsync()` call `initialize()` before caching
/// - **Caching**: Automatic caching after initialization
/// - **Type Safety**: Compile-time and runtime type checking
/// - **Testability**: Can clear cache for testing scenarios
///
/// ## Usage Example:
/// ```dart
/// class MyAdapter extends BackendAdapter {
///   @override
///   Future<void> initialize(Map<String, dynamic> config) async {
///     // Register synchronous factory
///     registerRepositoryFactory<ProductsRepository>(
///       () => WooProductsRepository(apiClient),
///     );
///
///     // Register asynchronous factory
///     registerAsyncRepositoryFactory<CartRepository>(
///       () async => WooCartRepository(await getApiClient()),
///     );
///   }
/// }
///
/// // Usage in code
/// final adapter = MyAdapter();
/// await adapter.initialize(config);
///
/// // Repository created on first access, cached for subsequent calls
/// final products = await adapter.getRepository<ProductsRepository>();
/// final cart = await adapter.getRepository<CartRepository>();
/// ```
///
/// ## Benefits:
/// - **Performance**: Repositories only created when needed
/// - **Memory Efficient**: No upfront initialization of unused repositories
/// - **Flexible**: Easy to add new repositories without modifying base class
/// - **Clean Code**: Separation of registration and instantiation logic
abstract class BackendAdapter {
  /// Adapter name (e.g., 'woocommerce', 'shopify')
  String get name;

  /// Adapter version (e.g., '1.0.0', '3.0')
  String get version;

  /// JSON Schema for validating adapter configuration.
  ///
  /// Subclasses must override this to provide their configuration schema.
  /// The schema will be validated automatically during initialization.
  ///
  /// **Returns:**
  /// - [Map<String, dynamic>]: JSON Schema definition
  ///
  /// **Example:**
  /// ```dart
  /// @override
  /// Map<String, dynamic> get configSchema => {
  ///   'type': 'object',
  ///   'required': ['baseUrl', 'apiKey'],
  ///   'properties': {
  ///     'baseUrl': {
  ///       'type': 'string',
  ///       'format': 'uri',
  ///       'description': 'Base URL of the API',
  ///     },
  ///     'apiKey': {
  ///       'type': 'string',
  ///       'minLength': 1,
  ///       'description': 'API authentication key',
  ///     },
  ///     'timeout': {
  ///       'type': 'integer',
  ///       'minimum': 0,
  ///       'default': 30,
  ///       'description': 'Request timeout in seconds',
  ///     },
  ///   },
  ///   'additionalProperties': false,
  /// };
  /// ```
  Map<String, dynamic> get configSchema;

  /// Returns default settings for this adapter.
  ///
  /// These defaults are used when:
  /// - The adapter is first registered and no configuration exists
  /// - A specific setting key is missing from environment.json
  ///
  /// Adapters should override this to provide sensible defaults for all
  /// configuration options defined in their configSchema.
  ///
  /// **Returns:**
  /// - [Map<String, dynamic>]: Default configuration values
  ///
  /// **Example:**
  /// ```dart
  /// @override
  /// Map<String, dynamic> getDefaultSettings() {
  ///   return {
  ///     'baseUrl': 'https://api.example.com',
  ///     'timeout': 30,
  ///     'retries': 3,
  ///     'enableLogging': false,
  ///   };
  /// }
  /// ```
  Map<String, dynamic> getDefaultSettings() => {};

  /// Scoped [HookRegistry] injected by [AdapterRegistry] before initialization.
  ///
  /// Concrete adapters can pass this to repository factories so repositories
  /// use the same scoped instance rather than a global singleton.
  late HookRegistry hookRegistry;

  /// Scoped [EventBus] injected by [AdapterRegistry] before initialization.
  late EventBus eventBus;

  /// Repository factories storage
  final Map<Type, Object> _factories = {};

  /// Repository cache storage
  final Map<Type, Object> _cache = {};

  /// Register a synchronous factory for a repository type.
  ///
  /// The factory function will be called only when the repository is first
  /// requested. The result is cached for subsequent calls.
  ///
  /// **Type Parameter:**
  /// - [T]: Repository type, must extend [CoreRepository]
  ///
  /// **Parameters:**
  /// - [factory]: Function that creates the repository instance
  ///
  /// **Example:**
  /// ```dart
  /// registerRepositoryFactory<ProductsRepository>(
  ///   () => WooProductsRepository(apiClient),
  /// );
  /// ```
  void registerRepositoryFactory<T extends CoreRepository>(
    T Function() factory,
  ) {
    _factories[T] = factory;
  }

  /// Register an asynchronous factory for a repository type.
  ///
  /// Use this when repository initialization requires async operations
  /// (e.g., fetching configuration, initializing database connections).
  ///
  /// **Type Parameter:**
  /// - [T]: Repository type, must extend [CoreRepository]
  ///
  /// **Parameters:**
  /// - [factory]: Async function that creates the repository instance
  ///
  /// **Example:**
  /// ```dart
  /// registerAsyncRepositoryFactory<CartRepository>(
  ///   () async {
  ///     final client = await getApiClient();
  ///     return WooCartRepository(client);
  ///   },
  /// );
  /// ```
  void registerAsyncRepositoryFactory<T extends CoreRepository>(
    Future<T> Function() factory,
  ) {
    _factories[T] = factory;
  }

  /// Get repository synchronously and call its initialize method.
  ///
  /// This method only works with synchronous factories. After instantiating
  /// the repository, it calls the repository's synchronous `initialize()` method
  /// before caching and returning it.
  ///
  /// Use this method when:
  /// - You're in a synchronous context (e.g., FeatureSection build method)
  /// - Repository needs immediate initialization
  /// - Repository initialization is synchronous
  ///
  /// **Type Parameter:**
  /// - [T]: Repository type, must extend [CoreRepository]
  ///
  /// **Returns:**
  /// - [T]: The repository instance (initialization may still be in progress)
  ///
  /// **Throws:**
  /// - [RepositoryNotRegisteredException]: If repository was registered with async factory
  ///
  /// **Example:**
  /// ```dart
  /// // In FeatureSection build method (sync context)
  /// final adapter = AdapterRegistry().getActiveAdapter();
  /// final productsRepo = adapter.getRepository<ProductsRepository>();
  ///
  /// return BlocProvider(
  ///   create: (context) => ProductsBloc(productsRepo)
  ///     ..add(LoadProducts()),
  ///   child: ProductsList(),
  /// );
  /// ```
  T getRepository<T extends CoreRepository>() {
    // Check if already cached
    if (_cache.containsKey(T)) {
      final cached = _cache[T];

      // If cached value is a Future, await it
      if (cached is Future<T>) {
        throw RepositoryNotRegisteredException('Use getRepositoryAsync method');
      }

      // If cached value is already a repository instance, return it
      if (cached is T) {
        return cached;
      }

      // This should never happen if used correctly
      throw RepositoryTypeMismatchException(
        'Cached repository for $T has unexpected type: ${cached.runtimeType}',
      );
    }

    // Check if factory is registered
    if (!_factories.containsKey(T)) {
      throw RepositoryNotRegisteredException(
        'No factory registered for repository type: $T\n'
        'Available repositories: ${_factories.keys.join(", ")}\n'
        'Did you forget to call registerFactory<$T>() or registerAsyncFactory<$T>()?',
      );
    }

    final factory = _factories[T];

    // Handle async factory
    if (factory is Future<T> Function()) {
      throw RepositoryNotRegisteredException('Use getRepositoryAsync method');
    }

    // Handle sync factory
    if (factory is T Function()) {
      final instance = factory();

      // Call synchronous initialize method
      instance.initialize();

      _cache[T] = instance;
      return instance;
    }

    // This should never happen if types are correct
    throw RepositoryFactoryException(
      'Factory for $T has unexpected type: ${factory.runtimeType}',
    );
  }

  /// Get repository asynchronously and call its initialize method.
  ///
  /// This method supports both synchronous and asynchronous factories.
  /// After instantiating the repository, it automatically calls the
  /// repository's synchronous `initialize()` method before caching and returning it.
  ///
  /// Use this method when:
  /// - You're in an async context (plugin initialization, async widgets)
  /// - You need to await async factory instantiation
  ///
  /// **Type Parameter:**
  /// - [T]: Repository type, must extend [CoreRepository]
  ///
  /// **Returns:**
  /// - [Future<T>]: The initialized repository instance
  ///
  /// **Example:**
  /// ```dart
  /// // In plugin initialization
  /// @override
  /// Future<void> initialize() async {
  ///   final cartRepo = await adapter.getRepositoryAsync<CartRepository>();
  ///   _cartBloc = CartBloc(cartRepo);
  /// }
  ///
  /// // Repository with synchronous initialization
  /// class WooCartRepository extends CoreRepository implements CartRepository {
  ///   @override
  ///   void initialize() {
  ///     _setupListeners();
  ///     _initializeState();
  ///     // Trigger async loading in background
  ///     _loadCachedCart();
  ///   }
  /// }
  /// ```
  Future<T> getRepositoryAsync<T extends CoreRepository>() async {
    // Check if already cached
    if (_cache.containsKey(T)) {
      final cached = _cache[T];

      // If cached value is a Future, await it
      if (cached is Future<T>) {
        return await cached;
      }

      // If cached value is already a repository instance, return it
      if (cached is T) {
        return cached;
      }

      // This should never happen if used correctly
      throw RepositoryTypeMismatchException(
        'Cached repository for $T has unexpected type: ${cached.runtimeType}',
      );
    }

    // Check if factory is registered
    if (!_factories.containsKey(T)) {
      throw RepositoryNotRegisteredException(
        'No factory registered for repository type: $T\n'
        'Available repositories: ${_factories.keys.join(", ")}\n'
        'Did you forget to call registerFactory<$T>() or registerAsyncFactory<$T>()?',
      );
    }

    final factory = _factories[T];

    // Handle async factory
    if (factory is Future<T> Function()) {
      // Cache the Future immediately to prevent duplicate calls
      final futureInstance = factory();
      _cache[T] = futureInstance;

      // Await and cache the resolved instance
      final instance = await futureInstance;

      // Call synchronous initialize method
      instance.initialize();

      _cache[T] = instance;
      return instance;
    }

    // Handle sync factory
    if (factory is T Function()) {
      final instance = factory();

      // Call synchronous initialize method
      instance.initialize();

      _cache[T] = instance;
      return instance;
    }

    // This should never happen if types are correct
    throw RepositoryFactoryException(
      'Factory for $T has unexpected type: ${factory.runtimeType}',
    );
  }

  /// Check if a factory is registered for a repository type.
  ///
  /// **Type Parameter:**
  /// - [T]: Repository type to check
  ///
  /// **Returns:**
  /// - [bool]: True if factory is registered, false otherwise
  ///
  /// **Example:**
  /// ```dart
  /// if (adapter.hasRepository<ProductsRepository>()) {
  ///   final products = await adapter.getRepository<ProductsRepository>();
  /// }
  /// ```
  bool hasRepository<T extends CoreRepository>() {
    return _factories.containsKey(T);
  }

  /// Check if a repository is currently cached.
  ///
  /// **Type Parameter:**
  /// - [T]: Repository type to check
  ///
  /// **Returns:**
  /// - [bool]: True if repository is cached, false otherwise
  ///
  /// **Example:**
  /// ```dart
  /// if (!adapter.isRepositoryCached<ProductsRepository>()) {
  ///   print('Repository will be created on first access');
  /// }
  /// ```
  bool isRepositoryCached<T extends CoreRepository>() {
    return _cache.containsKey(T);
  }

  /// Clear the cache for a specific repository type.
  ///
  /// The next call to [getRepository] for this type will recreate the instance.
  /// Useful for testing or forcing repository reinitialization.
  ///
  /// **Type Parameter:**
  /// - [T]: Repository type to clear from cache
  ///
  /// **Example:**
  /// ```dart
  /// // Clear specific repository cache
  /// adapter.clearRepositoryCache<ProductsRepository>();
  ///
  /// // Next call will create new instance
  /// final products = await adapter.getRepository<ProductsRepository>();
  /// ```
  void clearRepositoryCache<T extends CoreRepository>() {
    _cache.remove(T);
  }

  /// Clear all cached repository instances.
  ///
  /// Factories remain registered. Use this for testing or when you need
  /// to reinitialize all repositories.
  ///
  /// **Example:**
  /// ```dart
  /// // Clear all caches
  /// adapter.clearAllRepositoryCaches();
  ///
  /// // All repositories will be recreated on next access
  /// ```
  void clearAllRepositoryCaches() {
    _cache.clear();
  }

  /// Get list of all registered repository types.
  ///
  /// Useful for debugging or logging.
  ///
  /// **Returns:**
  /// - [List<Type>]: List of all registered repository types
  ///
  /// **Example:**
  /// ```dart
  /// print('Registered: ${adapter.registeredRepositoryTypes}');
  /// ```
  List<Type> get registeredRepositoryTypes {
    return _factories.keys.toList();
  }

  /// Get a repository by its runtime type.
  ///
  /// This method allows the AdapterRegistry to extract repositories
  /// from adapters using runtime type information.
  ///
  /// **Parameters:**
  /// - [type]: The runtime Type of the repository to retrieve
  ///
  /// **Returns:**
  /// - [CoreRepository]: The repository instance
  ///
  /// **Throws:**
  /// - [RepositoryNotRegisteredException]: If repository type not registered
  ///
  /// **Example:**
  /// ```dart
  /// final repoType = ProductsRepository;
  /// final repo = adapter.getRepositoryByType(repoType);
  /// ```
  CoreRepository getRepositoryByType(Type type) {
    // Check if already cached
    if (_cache.containsKey(type)) {
      final cached = _cache[type];

      // If cached value is a Future, throw error (should use async method)
      if (cached is Future) {
        throw RepositoryNotRegisteredException(
          'Repository for $type is async. This should not happen in normal usage.',
        );
      }

      // If cached value is already a repository instance, return it
      if (cached is CoreRepository) {
        return cached;
      }

      // Unexpected type
      throw RepositoryTypeMismatchException(
        'Cached repository for $type has unexpected type: ${cached.runtimeType}',
      );
    }

    // Check if factory is registered
    if (!_factories.containsKey(type)) {
      throw RepositoryNotRegisteredException(
        'No factory registered for repository type: $type\n'
        'Available repositories: ${_factories.keys.join(", ")}\n'
        'Did you forget to call registerFactory<$type>() or registerAsyncFactory<$type>()?',
      );
    }

    final factory = _factories[type];

    // Handle async factory (should have been initialized already)
    if (factory is Future Function()) {
      throw RepositoryNotRegisteredException(
        'Repository for $type has async factory but was not initialized.\n'
        'This indicates a bug in adapter initialization.',
      );
    }

    // Handle sync factory
    if (factory is CoreRepository Function()) {
      final instance = factory();

      // Call synchronous initialize method
      instance.initialize();

      _cache[type] = instance;
      return instance;
    }

    // Unexpected factory type
    throw RepositoryFactoryException(
      'Factory for $type has unexpected type: ${factory.runtimeType}',
    );
  }

  /// Validates configuration against the adapter's JSON schema.
  ///
  /// This method is called automatically before initialize() to ensure
  /// configuration meets requirements. It uses the configSchema getter
  /// to validate the provided configuration.
  ///
  /// **Parameters:**
  /// - [config]: Configuration map to validate
  ///
  /// **Throws:**
  /// - [AdapterConfigValidationException]: If configuration is invalid
  ///
  /// **Example:**
  /// ```dart
  /// // This is called automatically, but you can call it manually if needed
  /// try {
  ///   validateConfig({'baseUrl': 'https://api.example.com'});
  /// } catch (e) {
  ///   print('Configuration error: $e');
  /// }
  /// ```
  void validateConfig(Map<String, dynamic> config) {
    try {
      final schema = JsonSchema.create(configSchema);
      final validationResult = schema.validate(config);

      if (!validationResult.isValid) {
        final errors = validationResult.errors.map((error) {
          return '  - ${error.instancePath.isEmpty ? 'root' : error.instancePath}: ${error.message}';
        }).join('\n');

        throw AdapterConfigValidationException(
          'Configuration validation failed for adapter "$name":\n$errors\n\n'
          'Schema: ${_formatSchema(configSchema)}\n'
          'Provided config: $config',
        );
      }
    } catch (e) {
      if (e is AdapterConfigValidationException) {
        rethrow;
      }
      throw AdapterConfigValidationException(
        'Failed to validate configuration for adapter "$name": $e',
      );
    }
  }

  /// Format schema for error messages
  String _formatSchema(Map<String, dynamic> schema) {
    final required = schema['required'] as List? ?? [];
    final properties = schema['properties'] as Map<String, dynamic>? ?? {};

    if (required.isEmpty && properties.isEmpty) {
      return schema.toString();
    }

    final buffer = StringBuffer();
    buffer.writeln('Required fields: ${required.join(", ")}');
    buffer.writeln('Available fields:');

    properties.forEach((key, value) {
      final prop = value as Map<String, dynamic>;
      final type = prop['type'] ?? 'any';
      final description = prop['description'] ?? '';
      final isRequired = required.contains(key);
      buffer.writeln('  - $key ($type)${isRequired ? ' [REQUIRED]' : ''}: $description');
    });

    return buffer.toString();
  }

  /// Initialize the adapter with configuration.
  ///
  /// Configuration is automatically validated against configSchema before
  /// this method is called. Subclasses should implement this to:
  /// 1. Parse configuration (already validated)
  /// 2. Initialize API clients, connections, etc.
  /// 3. Register repository factories
  ///
  /// **Parameters:**
  /// - [config]: Configuration map (baseUrl, apiKey, etc.) - already validated
  ///
  /// **Example:**
  /// ```dart
  /// @override
  /// Future<void> initialize(Map<String, dynamic> config) async {
  ///   // No need to validate - already done by base class
  ///   _apiClient = await createApiClient(config);
  ///
  ///   registerRepositoryFactory<ProductsRepository>(
  ///     () => WooProductsRepository(_apiClient),
  ///   );
  /// }
  /// ```
  Future<void> initialize(Map<String, dynamic> config);

  /// Automatically loads configuration from ConfigManager and initializes the adapter.
  ///
  /// This method reads the adapter's configuration from the `adapters` section
  /// of the config using the adapter's name as the key.
  ///
  /// A scoped [ConfigManager] **must** be provided — there is no global fallback.
  /// [AdapterRegistry] passes the app-scoped instance automatically when
  /// `autoInitialize: true` (the default).
  ///
  /// **Parameters:**
  /// - [configManager]: The scoped [ConfigManager] that holds the app configuration.
  ///
  /// **Throws:**
  /// - [ArgumentError]: If [configManager] is null.
  /// - [Exception]: If configuration is not found or validation fails.
  ///
  /// **Example:**
  /// ```dart
  /// // In environment.json:
  /// // {
  /// //   "adapters": {
  /// //     "shopify": { "storeUrl": "...", "token": "..." },
  /// //   }
  /// // }
  ///
  /// // Called automatically by AdapterRegistry when autoInitialize: true:
  /// await adapter.initializeFromConfig(configManager: appContext.configManager);
  /// ```
  Future<void> initializeFromConfig({required ConfigManager configManager}) async {
    try {
      // Get the adapters configuration — use a safe cast to handle maps whose
      // generic parameters may be inferred as dynamic at runtime.
      final rawAdapters = configManager.get('adapters');
      if (rawAdapters == null) {
        throw Exception(
          'No adapters configuration found in environment.json.\n'
          'Expected "adapters" key at root level.'
        );
      }
      final adaptersConfig = Map<String, dynamic>.from(rawAdapters as Map);

      // Get this adapter's specific configuration using its name
      final rawAdapterConfig = adaptersConfig[name];

      if (rawAdapterConfig == null) {
        throw Exception(
          'No configuration found for adapter "$name".\n'
          'Expected "adapters.$name" in environment.json.\n'
          'Available adapters: ${adaptersConfig.keys.join(", ")}'
        );
      }
      final adapterConfig = Map<String, dynamic>.from(rawAdapterConfig as Map);

      // Validate configuration against schema
      validateConfig(adapterConfig);

      // Call the initialize method with the adapter's configuration
      await initialize(adapterConfig);
    } catch (e) {
      throw Exception('Failed to initialize adapter "$name" from config: $e');
    }
  }
}

// =============================================================================
// EXCEPTIONS
// =============================================================================

/// Exception thrown when attempting to get a repository that hasn't been registered.
class RepositoryNotRegisteredException implements Exception {
  final String message;

  RepositoryNotRegisteredException(this.message);

  @override
  String toString() => 'RepositoryNotRegisteredException: $message';
}

/// Exception thrown when a cached repository has an unexpected type.
class RepositoryTypeMismatchException implements Exception {
  final String message;

  RepositoryTypeMismatchException(this.message);

  @override
  String toString() => 'RepositoryTypeMismatchException: $message';
}

/// Exception thrown when a factory function has an unexpected type.
class RepositoryFactoryException implements Exception {
  final String message;

  RepositoryFactoryException(this.message);

  @override
  String toString() => 'RepositoryFactoryException: $message';
}

/// Exception thrown when adapter configuration validation fails.
class AdapterConfigValidationException implements Exception {
  final String message;

  AdapterConfigValidationException(this.message);

  @override
  String toString() => 'AdapterConfigValidationException: $message';
}
