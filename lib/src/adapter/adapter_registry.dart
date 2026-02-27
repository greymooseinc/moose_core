// Central registry for managing backend adapters and their repository implementations.
//
// Features:
// - Register multiple backend adapters using factory functions
// - Repository-level registration (last registered wins)
// - True lazy repository instantiation — repos created only on first request
// - Type-safe repository retrieval
// - Support for multiple adapters contributing different repositories
//
// Usage:
// ```dart
// // Wired automatically by MooseAppContext / MooseBootstrapper:
// await appContext.adapterRegistry.registerAdapter(() => WooCommerceAdapter());
//
// // Get repository (created lazily on first call)
// final productsRepo = appContext.adapterRegistry.getRepository<ProductsRepository>();
// ```
// =============================================================================

import 'package:moose_core/repositories.dart';
import 'package:moose_core/services.dart';

import '../app/moose_app_context.dart';
import 'backend_adapter.dart';


/// Instance-based registry for managing backend adapters and repository implementations.
///
/// [AdapterRegistry] is owned by [MooseAppContext] — each context gets its own
/// independent registry, ensuring full isolation between app instances and tests.
///
/// ## Key Design:
/// - **No singleton** — every `AdapterRegistry()` call produces a fresh instance.
/// - **Lazy repositories** — repository factories are stored by type; instances
///   are created on the first [getRepository] call and cached afterwards.
/// - **Last registration wins** — if multiple adapters register the same
///   repository type, the last one takes precedence.
/// - **Scoped dependencies** — [ConfigManager], [HookRegistry], and [EventBus]
///   are injected by [MooseAppContext] before any adapter is registered.
///
/// ## Example:
/// ```dart
/// final ctx = MooseAppContext();
/// await MooseBootstrapper(appContext: ctx).run(
///   config: {...},
///   adapters: [WooCommerceAdapter(), FCMAdapter()],
/// );
///
/// // Repos are created lazily on first use:
/// final productsRepo = ctx.adapterRegistry.getRepository<ProductsRepository>();
/// ```
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

  /// Lazy repository factory registry
  ///
  /// Key: Repository type (e.g., ProductsRepository)
  /// Value: Zero-argument factory that delegates to the owning adapter's
  ///        internal cache — the adapter only creates the repo on first call.
  ///
  /// Note: If multiple adapters provide the same repository type,
  /// the last registered adapter wins (overwrites previous factory).
  final Map<Type, CoreRepository Function()> _factories = {};

  /// Resolved repository instance cache
  ///
  /// Populated on first [getRepository] call for a given type.
  final Map<Type, CoreRepository> _instances = {};

  /// Flag to track if at least one adapter has been registered.
  bool _initialized = false;

  /// Logger instance for the registry
  final _logger = AppLogger('AdapterRegistry');

  // Scoped context set by MooseAppContext after construction.
  MooseAppContext? _appContext;

  // =========================================================================
  // PUBLIC METHODS
  // =========================================================================

  /// Wires scoped dependencies into this registry.
  ///
  /// Called automatically by [MooseAppContext] immediately after construction.
  /// These are forwarded to each [BackendAdapter] before it is initialized.
  void setDependencies({
    required MooseAppContext appContext,
  }) {
    _appContext = appContext;
  }

  /// Registers and optionally initializes a backend adapter.
  ///
  /// The adapter is created from [factory] and its scoped dependencies are
  /// injected. If [autoInitialize] is true (the default), the adapter's
  /// configuration is loaded from the scoped [ConfigManager] and
  /// `initializeFromConfig()` is called.
  ///
  /// Repository factories are registered lazily — **no repository instances
  /// are created during this call**. Repos are only created on the first
  /// [getRepository] call.
  ///
  /// **Parameters:**
  /// - [factory]: Function that creates the adapter (sync or async).
  /// - [autoInitialize]: When true, calls `initializeFromConfig()` automatically
  ///   using the scoped [ConfigManager]. Requires [setDependencies] to have
  ///   been called first. Defaults to `true`.
  ///
  /// **Throws:**
  /// - [Exception]: If adapter creation or initialization fails.
  ///
  /// **Example (auto-initialize — typical usage):**
  /// ```dart
  /// await registry.registerAdapter(() => ShopifyAdapter());
  /// ```
  ///
  /// **Example (manual initialization):**
  /// ```dart
  /// await registry.registerAdapter(() async {
  ///   final adapter = WooCommerceAdapter();
  ///   await adapter.initialize({'baseUrl': '...', 'consumerKey': '...'});
  ///   return adapter;
  /// }, autoInitialize: false);
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

      // Inject scoped app context before initialization.
      if (_appContext != null) adapter.appContext = _appContext!;

      // Auto-initialize if requested — requires scoped ConfigManager.
      if (autoInitialize) {
        if (_appContext == null) {
          throw StateError(
            'Cannot auto-initialize adapter "${adapter.name}": '
            'MooseAppContext has not been injected. '
            'Call setDependencies() before registering adapters, or use '
            'autoInitialize: false and initialize the adapter manually.',
          );
        }
        await adapter.initializeFromConfig(configManager: _appContext!.configManager);
      }

      final adapterName = adapter.name;

      // Register adapter defaults in ConfigManager (scoped — no global fallback).
      if (_appContext != null) {
        final defaults = adapter.getDefaultSettings();
        if (defaults.isNotEmpty) {
          _appContext!.configManager.registerAdapterDefaults(adapterName, defaults);
          _logger.debug('Registered defaults for adapter: $adapterName');
        }
      }

      // Cache the adapter instance.
      _adapters[adapterName] = adapter;

      // Register lazy factories for each repository type the adapter provides.
      // No repository instances are created here.
      _registerLazyFactories(adapter);

      _initialized = true;
      _logger.debug(
        'Registered adapter: $adapterName (${adapter.version}) '
        'with ${adapter.registeredRepositoryTypes.length} repository types',
      );
    } catch (e) {
      _logger.error('Failed to register adapter', e);
      rethrow;
    }
  }

  /// Retrieves a repository by type.
  ///
  /// The repository is created from its factory on the **first call** for that
  /// type and cached for all subsequent calls. No repository is created until
  /// this method is invoked.
  ///
  /// **Type Parameters:**
  /// - [T]: The repository type (must extend [CoreRepository]).
  ///
  /// **Returns:**
  /// - [T]: The repository instance.
  ///
  /// **Throws:**
  /// - [StateError]: If no adapters have been registered yet.
  /// - [RepositoryNotRegisteredException]: If no adapter provides this type.
  ///
  /// **Example:**
  /// ```dart
  /// final products = appContext.adapterRegistry.getRepository<ProductsRepository>();
  /// ```
  T getRepository<T extends CoreRepository>() {
    if (!_initialized) {
      throw StateError(
        'AdapterRegistry not initialized. '
        'Register at least one adapter before requesting repositories.',
      );
    }

    // Return cached instance if available.
    if (_instances.containsKey(T)) {
      return _instances[T] as T;
    }

    if (!_factories.containsKey(T)) {
      throw RepositoryNotRegisteredException(
        'No adapter provides repository type: $T\n'
        'Available repositories: ${_factories.keys.join(", ")}\n'
        'Did you forget to register an adapter that provides $T?',
      );
    }

    // Create and cache the repository instance (lazy instantiation).
    final instance = _factories[T]!() as T;
    _instances[T] = instance;
    _logger.debug('Created repository: $T (first request)');
    return instance;
  }

  /// Checks if a repository type is available.
  ///
  /// Returns `true` if a factory for [T] has been registered, regardless of
  /// whether an instance has been created yet.
  ///
  /// **Example:**
  /// ```dart
  /// if (registry.hasRepository<PushNotificationRepository>()) {
  ///   final repo = registry.getRepository<PushNotificationRepository>();
  /// }
  /// ```
  bool hasRepository<T extends CoreRepository>() {
    return _factories.containsKey(T);
  }

  /// Returns list of all available repository types.
  ///
  /// **Returns:**
  /// - [List<Type>]: Repository types that can be retrieved via [getRepository].
  List<Type> getAvailableRepositories() {
    return _factories.keys.toList();
  }

  /// Returns list of all registered adapter names.
  List<String> getInitializedAdapters() {
    return _adapters.keys.toList();
  }

  /// Gets a specific adapter instance by name (advanced usage).
  ///
  /// Most code should use [getRepository] instead. This is for scenarios where
  /// adapter-specific functionality is needed beyond repository access.
  ///
  /// **Throws:**
  /// - [StateError]: If no adapters have been registered yet.
  /// - [Exception]: If the named adapter is not found.
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

  /// Whether at least one adapter has been registered.
  bool get isInitialized => _initialized;

  /// Total number of registered repository types (not instances created).
  int get repositoryCount => _factories.length;

  /// Total number of registered adapters.
  int get adapterCount => _adapters.length;

  // =========================================================================
  // PRIVATE HELPER METHODS
  // =========================================================================

  /// Registers a lazy factory in [_factories] for each repository type the
  /// adapter declares, without instantiating any repository.
  ///
  /// The factory closure captures [adapter] and delegates to
  /// [BackendAdapter.getRepositoryByType], which handles its own lazy
  /// instantiation and per-adapter caching.
  void _registerLazyFactories(BackendAdapter adapter) {
    for (final repoType in adapter.registeredRepositoryTypes) {
      if (_factories.containsKey(repoType)) {
        _logger.warning(
          'Overwriting factory for ${repoType.toString()} '
          '(previously registered by another adapter)',
        );
        // Remove any previously resolved instance so the new factory is used.
        _instances.remove(repoType);
      }

      _factories[repoType] = () => adapter.getRepositoryByType(repoType);
      _logger.debug('Registered lazy factory for ${repoType.toString()}');
    }
  }

  /// Clears all adapters, factories, and instances (for testing).
  ///
  /// **Warning:** Use only in tests — removes all state.
  void clearAll() {
    _adapters.clear();
    _factories.clear();
    _instances.clear();
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
