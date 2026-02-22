// Central registry for managing backend adapters and their repository implementations
//
// This class implements the Singleton pattern to ensure only one registry
// exists throughout the application lifecycle.
//
// Features:
// - Register multiple backend adapters using factory functions
// - Repository-level registration (last registered wins)
// - Type-safe repository retrieval
// - Support for multiple adapters contributing different repositories
//
// Usage:
// ```dart
// // Register adapters with factory functions
// AdapterRegistry().registerAdapter(() => WooCommerceAdapter());
// AdapterRegistry().registerAdapter(() => FCMNotificationAdapter());
//
// // Get repository (automatically uses correct adapter)
// final productsRepo = AdapterRegistry().getRepository<ProductsRepository>();
// final notificationRepo = AdapterRegistry().getRepository<PushNotificationRepository>();
// ```
// =============================================================================

import 'package:moose_core/repositories.dart';
import 'package:moose_core/services.dart';

import 'backend_adapter.dart';


/// Singleton registry for managing backend adapters and repository implementations.
///
/// The AdapterRegistry provides centralized management of repository implementations
/// from multiple adapters. Unlike the previous version that managed "active adapters",
/// this version works at the **repository level** - each adapter registers the
/// repositories it provides, and the last registration wins.
///
/// ## Key Features:
/// - **Singleton Pattern**: Only one registry instance exists
/// - **Factory-Based Registration**: Adapters registered via factory functions (lazy initialization)
/// - **Repository-Level Management**: No "active adapter" concept - repositories are registered directly
/// - **Last Registration Wins**: If multiple adapters provide the same repository, last one wins
/// - **Type Safety**: Generic methods for type-safe repository retrieval
/// - **Mixed Adapters**: Can use WooCommerce for products, FCM for notifications, etc.
///
/// ## Example Usage:
/// ```dart
/// // 1. Register adapters (initialization happens at registration time)
/// final registry = AdapterRegistry();
///
/// await registry.registerAdapter(() async {
///   final adapter = WooCommerceAdapter();
///   await adapter.initialize(config['woocommerce']);
///   return adapter;
/// });
///
/// await registry.registerAdapter(() async {
///   final adapter = FCMNotificationAdapter();
///   await adapter.initialize(config['fcm']);
///   return adapter;
/// });
///
/// // 2. Get repositories from anywhere in the app
/// final productsRepo = AdapterRegistry().getRepository<ProductsRepository>();
/// final notificationRepo = AdapterRegistry().getRepository<PushNotificationRepository>();
/// ```
///
/// ## How It Works:
/// 1. Adapters are registered via factory functions
/// 2. Each adapter is instantiated and initialized immediately when registered
/// 3. Repositories are extracted and cached during registration
/// 4. If two adapters provide the same repository type, the last one wins
/// 5. Repositories are retrieved by type, no need to know which adapter provides them
///
/// ## Architecture:
/// - Plugins depend on repository interfaces (e.g., ProductsRepository)
/// - Adapters implement these interfaces for specific platforms
/// - Registry manages repository lifecycle and provides access
/// - No coupling between plugins and specific adapters
class AdapterRegistry {
  AdapterRegistry();

  // =========================================================================
  // PRIVATE PROPERTIES
  // =========================================================================

  /// Instantiated adapters cache
  ///
  /// Key: Adapter name
  /// Value: Initialized BackendAdapter instance
  final Map<String, BackendAdapter> _adapters = {};

  /// Repository implementations registry
  ///
  /// Key: Repository type (e.g., ProductsRepository)
  /// Value: Repository instance from an adapter
  ///
  /// Note: If multiple adapters provide the same repository type,
  /// the last registered adapter wins (overwrites previous).
  final Map<Type, CoreRepository> _repositories = {};

  /// Flag to track if adapters have been initialized
  bool _initialized = false;

  /// Logger instance for the registry
  final _logger = AppLogger('AdapterRegistry');

  // Scoped dependencies set by MooseAppContext after construction.
  ConfigManager? _configManager;
  HookRegistry? _hookRegistry;
  EventBus? _eventBus;

  // =========================================================================
  // PUBLIC METHODS
  // =========================================================================

  /// Wires scoped dependencies into this registry.
  ///
  /// Called automatically by [MooseAppContext] immediately after construction.
  /// These are forwarded to each [BackendAdapter] before it is initialized.
  void setDependencies({
    required ConfigManager configManager,
    required HookRegistry hookRegistry,
    required EventBus eventBus,
  }) {
    _configManager = configManager;
    _hookRegistry = hookRegistry;
    _eventBus = eventBus;
  }

  /// Registers and initializes a backend adapter.
  ///
  /// The adapter is created and initialized immediately when this method is called.
  /// All repositories from the adapter are extracted and registered.
  ///
  /// **Parameters:**
  /// - [factory]: Function that creates the adapter (can be sync or async)
  /// - [autoInitialize]: If true, automatically calls `initializeFromConfig()` (default: true)
  ///
  /// **Behavior:**
  /// - Calls the factory function to create the adapter
  /// - If autoInitialize is true, calls `initializeFromConfig()` automatically
  /// - Extracts all repository implementations from the adapter
  /// - Registers repositories (last registered wins for duplicate types)
  /// - Caches the adapter instance
  ///
  /// **Example (Auto-initialize):**
  /// ```dart
  /// // Simplest approach - automatic config loading
  /// await AdapterRegistry().registerAdapter(
  ///   () => ShopifyAdapter(),
  ///   autoInitialize: true,
  /// );
  ///
  /// await AdapterRegistry().registerAdapter(
  ///   () => JudgemeAdapter(),
  ///   autoInitialize: true,
  /// );
  /// ```
  ///
  /// **Example (Manual initialization):**
  /// ```dart
  /// // Manual config passing
  /// await AdapterRegistry().registerAdapter(() async {
  ///   final adapter = WooCommerceAdapter();
  ///   await adapter.initialize({
  ///     'baseUrl': 'https://mystore.com',
  ///     'consumerKey': 'ck_xxx',
  ///     'consumerSecret': 'cs_xxx',
  ///   });
  ///   return adapter;
  /// });
  /// ```
  Future<void> registerAdapter(
    dynamic Function() factory, {
    bool autoInitialize = true,
  }) async {
    try {
      BackendAdapter adapter;

      // Handle both sync and async factories
      final result = factory();
      if (result is Future<BackendAdapter>) {
        adapter = await result;
      } else if (result is BackendAdapter) {
        adapter = result;
      } else {
        throw Exception(
          'Factory must return BackendAdapter or Future<BackendAdapter>, '
          'got ${result.runtimeType}'
        );
      }

      // Inject scoped dependencies before initialization so the adapter and the
      // repositories it creates can use the app-scoped hook/event instances.
      if (_hookRegistry != null) adapter.hookRegistry = _hookRegistry!;
      if (_eventBus != null) adapter.eventBus = _eventBus!;

      // Auto-initialize if requested
      if (autoInitialize) {
        await adapter.initializeFromConfig(configManager: _configManager);
      }

      final adapterName = adapter.name;

      // Register adapter defaults in ConfigManager
      final defaults = adapter.getDefaultSettings();
      if (defaults.isNotEmpty) {
        (_configManager ?? ConfigManager()).registerAdapterDefaults(adapterName, defaults);
        _logger.debug('Registered defaults for adapter: $adapterName');
      }

      // Cache the adapter instance
      _adapters[adapterName] = adapter;

      // Extract and register all repositories from this adapter
      _extractRepositoriesFromAdapter(adapter);

      _initialized = true;
      _logger.debug('Registered adapter: $adapterName (${adapter.version}) with ${adapter.registeredRepositoryTypes.length} repositories');
    } catch (e) {
      _logger.error('Failed to register adapter', e);
      rethrow;
    }
  }

  /// Retrieves a repository by type.
  ///
  /// This is the primary method for getting repository implementations.
  /// The registry automatically returns the correct repository instance
  /// regardless of which adapter provides it.
  ///
  /// **Type Parameters:**
  /// - [T]: The repository type (must extend [CoreRepository])
  ///
  /// **Returns:**
  /// - [T]: The repository instance
  ///
  /// **Throws:**
  /// - [RepositoryNotRegisteredException]: If no adapter provides this repository type
  /// - [StateError]: If registry not initialized (call initializeAllAdapters first)
  ///
  /// **Example:**
  /// ```dart
  /// // In BLoC or screen
  /// class ProductsBloc {
  ///   final ProductsRepository repository;
  ///
  ///   ProductsBloc() : repository = AdapterRegistry().getRepository<ProductsRepository>();
  /// }
  ///
  /// // In notification plugin
  /// class NotificationsPlugin {
  ///   late final PushNotificationRepository notificationRepo;
  ///
  ///   @override
  ///   Future<void> initialize() async {
  ///     notificationRepo = AdapterRegistry().getRepository<PushNotificationRepository>();
  ///   }
  /// }
  /// ```
  ///
  /// **Common Usage:**
  /// ```dart
  /// // Get any repository
  /// final products = AdapterRegistry().getRepository<ProductsRepository>();
  /// final cart = AdapterRegistry().getRepository<CartRepository>();
  /// final notifications = AdapterRegistry().getRepository<PushNotificationRepository>();
  /// ```
  T getRepository<T extends CoreRepository>() {
    if (!_initialized) {
      throw StateError(
        'AdapterRegistry not initialized. Call initializeAllAdapters() first.',
      );
    }

    if (!_repositories.containsKey(T)) {
      throw RepositoryNotRegisteredException(
        'No adapter provides repository type: $T\n'
        'Available repositories: ${_repositories.keys.join(", ")}\n'
        'Did you forget to register an adapter that provides $T?',
      );
    }

    return _repositories[T] as T;
  }

  /// Checks if a repository type is available.
  ///
  /// **Type Parameters:**
  /// - [T]: The repository type to check
  ///
  /// **Returns:**
  /// - [bool]: true if a repository of this type is registered, false otherwise
  ///
  /// **Example:**
  /// ```dart
  /// if (AdapterRegistry().hasRepository<PushNotificationRepository>()) {
  ///   final notificationRepo = AdapterRegistry().getRepository<PushNotificationRepository>();
  ///   await notificationRepo.requestPermission();
  /// } else {
  ///   print('Push notifications not available');
  /// }
  /// ```
  bool hasRepository<T extends CoreRepository>() {
    return _repositories.containsKey(T);
  }

  /// Returns list of all available repository types.
  ///
  /// **Returns:**
  /// - [List<Type>]: List of repository types that can be retrieved
  ///
  /// **Example:**
  /// ```dart
  /// final availableRepos = AdapterRegistry().getAvailableRepositories();
  /// print('Available repositories: $availableRepos');
  /// // Output: Available repositories: [ProductsRepository, CartRepository, PushNotificationRepository]
  /// ```
  List<Type> getAvailableRepositories() {
    return _repositories.keys.toList();
  }

  /// Returns list of all initialized adapter names.
  ///
  /// **Returns:**
  /// - [List<String>]: Names of all initialized adapters
  ///
  /// **Example:**
  /// ```dart
  /// final adapters = AdapterRegistry().getInitializedAdapters();
  /// print('Initialized adapters: $adapters');
  /// // Output: Initialized adapters: [woocommerce, fcm_notifications]
  /// ```
  List<String> getInitializedAdapters() {
    return _adapters.keys.toList();
  }

  /// Gets a specific adapter by name (advanced usage).
  ///
  /// Most code should use [getRepository] instead. This method is for
  /// advanced scenarios where you need adapter-specific functionality.
  ///
  /// **Type Parameters:**
  /// - [T]: The adapter type (must extend [BackendAdapter])
  ///
  /// **Parameters:**
  /// - [name]: The name of the adapter
  ///
  /// **Returns:**
  /// - [T]: The adapter instance
  ///
  /// **Throws:**
  /// - [Exception]: If adapter not found or not initialized
  ///
  /// **Example:**
  /// ```dart
  /// // Get WooCommerce-specific adapter for custom operations
  /// final wooAdapter = AdapterRegistry().getAdapter<WooCommerceAdapter>('woocommerce');
  /// await wooAdapter.customWooCommerceOperation();
  /// ```
  T getAdapter<T extends BackendAdapter>(String name) {
    if (!_initialized) {
      throw StateError('AdapterRegistry not initialized');
    }

    if (!_adapters.containsKey(name)) {
      throw Exception(
        'Adapter "$name" not found.\n'
        'Available adapters: ${_adapters.keys.join(", ")}',
      );
    }

    return _adapters[name] as T;
  }

  /// Checks if adapter registry has been initialized.
  ///
  /// **Returns:**
  /// - [bool]: true if initialized, false otherwise
  bool get isInitialized => _initialized;

  /// Returns the total number of registered repositories.
  ///
  /// **Returns:**
  /// - [int]: Count of available repositories
  int get repositoryCount => _repositories.length;

  /// Returns the total number of initialized adapters.
  ///
  /// **Returns:**
  /// - [int]: Count of initialized adapters
  int get adapterCount => _adapters.length;

  // =========================================================================
  // PRIVATE HELPER METHODS
  // =========================================================================

  /// Extracts all repository implementations from an adapter.
  ///
  /// This method iterates through all registered repository types in the adapter
  /// and adds them to the registry. If a repository type was already registered
  /// by a previous adapter, it will be overwritten (last one wins).
  void _extractRepositoriesFromAdapter(BackendAdapter adapter) {
    // Get all repository types registered in this adapter
    final repositoryTypes = adapter.registeredRepositoryTypes;

    for (final repoType in repositoryTypes) {
      try {
        // Get repository instance from adapter
        // We use a helper to invoke getRepository<T> with runtime type
        final repository = _getRepositoryFromAdapter(adapter, repoType);

        // Register or overwrite in global registry
        if (_repositories.containsKey(repoType)) {
          _logger.warning('Overwriting ${repoType.toString()} (previously registered)');
        }

        _repositories[repoType] = repository;
        _logger.debug('Registered ${repoType.toString()}');
      } catch (e) {
        _logger.warning('Failed to extract ${repoType.toString()}: $e');
      }
    }
  }

  /// Helper method to get repository from adapter using runtime type.
  ///
  /// Uses the adapter's getRepositoryByType() method which handles the
  /// runtime type retrieval and caching.
  CoreRepository _getRepositoryFromAdapter(BackendAdapter adapter, Type repoType) {
    return adapter.getRepositoryByType(repoType);
  }

  /// Clears all adapters and repositories (for testing).
  ///
  /// **Warning:** Use with caution - this will remove all adapters and repositories.
  ///
  /// **Example:**
  /// ```dart
  /// // For testing
  /// setUp(() {
  ///   AdapterRegistry().clearAll();
  /// });
  /// ```
  void clearAll() {
    _adapters.clear();
    _repositories.clear();
    _initialized = false;
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
