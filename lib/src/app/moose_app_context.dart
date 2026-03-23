import 'dart:async';

import 'package:flutter/widgets.dart';

import '../actions/action_registry.dart';
import '../adapter/adapter_registry.dart';
import '../cache/cache_manager.dart';
import '../config/config_manager.dart';
import '../entities/user.dart';
import '../events/event_bus.dart';
import '../events/hook_registry.dart';
import '../plugin/plugin_registry.dart';
import '../repositories/auth_repository.dart';
import '../repositories/repository.dart';
import '../utils/logger.dart';
import '../widgets/widget_registry.dart';

/// The dependency-injection container for a running moose_core application.
///
/// [MooseAppContext] owns every registry, service, and cache layer used by
/// plugins, adapters, sections, and widgets. Each instance is fully isolated —
/// no state is shared between two [MooseAppContext] instances, which makes
/// per-test contexts trivially cheap and safe.
///
/// ## Lifecycle
///
/// Create one context per app, pass it to [MooseScope], then hand it to
/// [MooseBootstrapper.run] to complete the startup sequence:
///
/// ```dart
/// final ctx = MooseAppContext();
///
/// runApp(MooseScope(
///   appContext: ctx,
///   child: AppBootstrap(appContext: ctx),
/// ));
///
/// // Inside AppBootstrap.initState:
/// await MooseBootstrapper(appContext: ctx).run(
///   config: await loadEnvironmentJson(),
///   adapters: [WooCommerceAdapter()],
///   plugins: [() => ProductsPlugin(), () => CartPlugin()],
/// );
/// ```
///
/// ## Dependency injection for tests
///
/// Every field has a corresponding optional constructor parameter. Pass mock
/// or stub instances for the components under test; omit the rest to get
/// fresh defaults:
///
/// ```dart
/// final ctx = MooseAppContext(
///   hookRegistry: MockHookRegistry(),
///   configManager: MockConfigManager(),
/// );
/// ```
///
/// ## Cache access
///
/// ```dart
/// // In-memory — fast, session-scoped, lost on restart
/// ctx.cache.memory.set('key', value);
/// final cached = ctx.cache.memory.get<String>('key');
///
/// // Persistent — backed by SharedPreferences, survives restarts
/// await ctx.cache.persistent.setString('pref', 'value');
/// ```
///
/// ## Authenticated user
///
/// [currentUser] is the single source of truth for the signed-in user across
/// all plugins and widgets. It is populated in two ways:
///
/// - **Cold start** — [MooseBootstrapper] calls [restoreAuthState] after
///   initialising the persistent cache, so the UI has a user object on the
///   very first frame even before any adapter has connected.
/// - **Live stream** — the first call to [AdapterRegistry.getRepository] for
///   an [AuthRepository] (via any access path) automatically calls
///   [wireAuthRepository], which subscribes to `authStateChanges` and keeps
///   [currentUser] in sync for the lifetime of the app.
///
/// ```dart
/// // Synchronous read — safe anywhere
/// final user = ctx.currentUser.value;
///
/// // Reactive widget — rebuilds automatically on sign-in or sign-out
/// ValueListenableBuilder<User?>(
///   valueListenable: context.moose.currentUser,
///   builder: (context, user, _) {
///     return user != null
///       ? Text('Hello, ${user.displayName}')
///       : const LoginButton();
///   },
/// );
/// ```
///
/// See also:
///
///  * [MooseScope], which exposes this context to the widget tree via
///    `context.moose`.
///  * [MooseBootstrapper], which orchestrates the startup sequence.
///  * [currentUser], for reading and observing authentication state.
class MooseAppContext {
  /// Registry of all registered [FeaturePlugin] instances.
  ///
  /// Plugins are registered during bootstrap step 5 and initialised in
  /// steps 6–7. Prefer accessing plugin functionality through hooks,
  /// events, or the widget registry rather than through this registry
  /// directly.
  final PluginRegistry pluginRegistry;

  /// Registry mapping string keys to [FeatureSection] builders.
  ///
  /// Unified registry mapping string keys to widget builders.
  ///
  /// Plugins call `widgetRegistry.registerSection(key, builder)` for
  /// [FeatureSection]-based builders or `widgetRegistry.registerWidget(key, builder)`
  /// for plain widget builders. Multiple registrations per key are supported —
  /// use `widgetRegistry.build(key, context)` to get the first result or
  /// `widgetRegistry.buildAll(key, context)` to get all results.
  final WidgetRegistry widgetRegistry;

  /// Synchronous filter-and-transform pipeline shared across plugins.
  ///
  /// Hooks execute in descending priority order. Each handler receives the
  /// output of the previous handler, allowing multiple plugins to enrich
  /// the same data without coupling to each other.
  ///
  /// ```dart
  /// // Register — typically inside FeaturePlugin.onRegister
  /// hookRegistry.register('products:after_load', (data) {
  ///   final products = data as List<Product>;
  ///   return products.where((p) => p.inStock).toList();
  /// }, priority: 10);
  ///
  /// // Execute — returns the final transformed value
  /// final filtered = hookRegistry.execute<List<Product>>(
  ///   'products:after_load',
  ///   rawProducts,
  /// );
  /// ```
  final HookRegistry hookRegistry;

  /// Registry for named [UserInteraction] handlers.
  ///
  /// Dispatches `internal`, `external`, `custom`, and `none` interaction
  /// types. Plugins register custom handlers inside [FeaturePlugin.onRegister].
  final ActionRegistry actionRegistry;

  /// Lazy repository factory registry backed by [BackendAdapter] instances.
  ///
  /// Repository instances are created on the first [AdapterRegistry.getRepository]
  /// call and cached permanently. Prefer the [getRepository] shortcut on this
  /// context, which additionally wires up [AuthRepository] automatically.
  final AdapterRegistry adapterRegistry;

  /// Flat key-value configuration store loaded from `environment.json`.
  ///
  /// Populated during bootstrap step 1. Paths use `:` or `.` as separators
  /// interchangeably. Plugin and adapter defaults are merged in automatically
  /// during registration.
  ///
  /// ```dart
  /// configManager.get('plugins:products:settings:display:itemsPerPage',
  ///     defaultValue: 20);
  /// ```
  final ConfigManager configManager;

  /// Async publish-subscribe bus for cross-plugin notifications.
  ///
  /// Use for fire-and-forget side-effects. For data transformation, prefer
  /// [hookRegistry]. Subscribe inside [FeaturePlugin.onInit] and cancel
  /// inside [FeaturePlugin.onStop] to avoid memory leaks.
  ///
  /// ```dart
  /// final sub = eventBus.on('cart.item.added', (event) {
  ///   cache.memory.remove('cart:summary');
  /// });
  ///
  /// // In onStop:
  /// await sub.cancel();
  /// ```
  final EventBus eventBus;

  /// Scoped logger for this context. Tag is `'MooseApp'` by default.
  final AppLogger logger;

  /// Scoped cache manager owning independent in-memory and persistent layers.
  ///
  /// Both layers are fully isolated — two [MooseAppContext] instances never
  /// share cache data. The persistent layer must be initialised before use;
  /// [MooseBootstrapper] does this automatically in bootstrap step 2.
  ///
  /// ```dart
  /// // Session-scoped, lost on restart
  /// cache.memory.set('token', value, ttl: const Duration(minutes: 5));
  ///
  /// // Persistent, survives restarts
  /// await cache.persistent.setBool('notifications_enabled', true);
  /// ```
  final CacheManager cache;

  /// The currently authenticated user, or `null` when unauthenticated.
  ///
  /// This is the single source of truth for authentication state across
  /// all plugins and widgets. Any part of the app can read or observe it
  /// without importing the auth plugin.
  ///
  /// **Population sources:**
  ///
  ///  1. [restoreAuthState] — called by [MooseBootstrapper] after the
  ///     persistent cache is ready. Immediately populates this notifier
  ///     from the last persisted user, giving the UI a user object on the
  ///     first frame before any adapter has connected.
  ///  2. [wireAuthRepository] — called automatically on the first
  ///     [getRepository] call for an [AuthRepository]. Subscribes to
  ///     `authStateChanges` and updates this notifier (and the persistent
  ///     cache) on every emission for the lifetime of the app.
  ///
  /// **Reading the current user:**
  ///
  /// ```dart
  /// // Synchronous — safe anywhere, including hook handlers
  /// final user = appContext.currentUser.value;
  /// final name = user?.displayName ?? 'Guest';
  /// ```
  ///
  /// **Reacting to changes in a widget:**
  ///
  /// ```dart
  /// ValueListenableBuilder<User?>(
  ///   valueListenable: context.moose.currentUser,
  ///   builder: (context, user, _) {
  ///     return user != null
  ///       ? Text('Hello, ${user.displayName}')
  ///       : const LoginButton();
  ///   },
  /// );
  /// ```
  ///
  /// **Reacting to changes in a plugin:**
  ///
  /// ```dart
  /// // Inside FeaturePlugin.onInit — read-after-add pattern is required
  /// // because restoreAuthState() runs before onInit(), so the value may
  /// // already be set before the listener is attached.
  /// appContext.currentUser.addListener(_onAuthChanged);
  /// _onAuthChanged(); // handle the current value immediately
  /// ```
  ///
  /// The [User] entity carries [User.accessToken] and [User.refreshToken].
  /// Both fields are persisted to the cache alongside the rest of the user
  /// data and can be read synchronously at any time.
  ///
  /// See also:
  ///
  ///  * [wireAuthRepository], which subscribes this notifier to an
  ///    [AuthRepository]'s `authStateChanges` stream.
  ///  * [restoreAuthState], which populates this notifier from the
  ///    persistent cache on cold start.
  final ValueNotifier<User?> currentUser = ValueNotifier(null);

  /// Routes generated from the `pages` object in `environment.json`.
  ///
  /// Populated by [MooseBootstrapper] after config is loaded, before any plugin
  /// is registered. These routes are merged into [PluginRegistry.getAllRoutes]
  /// so page-screen navigation works without any plugin owning the route table.
  final Map<String, WidgetBuilder> pagesRoutes = {};

  // Cache key under which the authenticated user is persisted.
  // Reserved — other plugins must not write to this key.
  static const _kCurrentUserCacheKey = 'moose:auth:current_user';

  // Active subscription to the wired AuthRepository's authStateChanges stream.
  // Cancelled and replaced on each wireAuthRepository call.
  StreamSubscription<User?>? _authStateSubscription;

  /// Creates a new, fully isolated [MooseAppContext].
  ///
  /// All parameters are optional. When omitted, fresh default instances are
  /// created. Pass custom instances to inject mocks or shared objects for
  /// testing:
  ///
  /// ```dart
  /// // Production
  /// final ctx = MooseAppContext();
  ///
  /// // Test — inject only what the test exercises
  /// final ctx = MooseAppContext(
  ///   configManager: preloadedConfigManager,
  ///   cache: CacheManager(persistent: MockPersistentCache()),
  /// );
  /// ```
  MooseAppContext({
    PluginRegistry? pluginRegistry,
    WidgetRegistry? widgetRegistry,
    HookRegistry? hookRegistry,
    ActionRegistry? actionRegistry,
    AdapterRegistry? adapterRegistry,
    ConfigManager? configManager,
    EventBus? eventBus,
    AppLogger? logger,
    CacheManager? cache,
  })  : configManager = configManager ?? ConfigManager(),
        hookRegistry = hookRegistry ?? HookRegistry(),
        actionRegistry = actionRegistry ?? ActionRegistry(),
        adapterRegistry = adapterRegistry ?? AdapterRegistry(),
        eventBus = eventBus ?? EventBus(),
        logger = logger ?? AppLogger('MooseApp'),
        pluginRegistry = pluginRegistry ?? PluginRegistry(),
        widgetRegistry = widgetRegistry ?? WidgetRegistry(),
        cache = cache ?? CacheManager() {
    // Wire WidgetRegistry to the scoped ConfigManager after construction to
    // avoid a circular dependency in the initializer list.
    this.widgetRegistry.setConfigManager(this.configManager);
    // Wire AdapterRegistry to this context so it can resolve scoped services
    // (config, cache, event bus) when initialising adapters.
    this.adapterRegistry.setDependencies(appContext: this);
  }

  /// Returns a repository of type [T], creating it on the first call.
  ///
  /// Delegates to [AdapterRegistry.getRepository]. The instance is created
  /// lazily from the registered factory and cached permanently — subsequent
  /// calls return the same object.
  ///
  /// When [T] is [AuthRepository], [wireAuthRepository] is called automatically
  /// inside [AdapterRegistry.getRepository] on the first access, regardless of
  /// whether the repository is accessed via this shortcut or directly through
  /// [adapterRegistry]. This subscribes [currentUser] to the repository's
  /// `authStateChanges` stream and keeps it in sync for the lifetime of the app.
  ///
  /// ```dart
  /// final products = appContext.getRepository<ProductsRepository>();
  /// final auth    = appContext.getRepository<AuthRepository>(); // also wires currentUser
  /// ```
  ///
  /// See also:
  ///
  ///  * [AdapterRegistry.getRepository], the underlying implementation.
  ///  * [AdapterRegistry.hasRepository], to guard against unregistered types.
  T getRepository<T extends CoreRepository>([String? name]) {
    return adapterRegistry.getRepository<T>(name);
  }

  /// Subscribes [currentUser] to [repo]'s `authStateChanges` stream.
  ///
  /// Called automatically by [getRepository] on the first [AuthRepository]
  /// access. It is safe to call multiple times — the previous subscription is
  /// cancelled before a new one is opened, so only one subscription is active
  /// at any given time.
  ///
  /// On each stream emission:
  ///
  ///  - [currentUser] is updated synchronously, notifying all listeners
  ///    and [ValueListenableBuilder] widgets immediately.
  ///  - If the emitted user is non-null, it is persisted to the persistent
  ///    cache under [_kCurrentUserCacheKey] so it survives app restarts.
  ///  - If the emitted value is `null` (sign-out), the cache entry is removed.
  ///
  /// See also:
  ///
  ///  * [restoreAuthState], which reads the persisted user back on cold start.
  ///  * [getRepository], which calls this method automatically.
  void wireAuthRepository(AuthRepository repo) {
    _authStateSubscription?.cancel();
    _authStateSubscription = repo.authStateChanges.listen((user) {
      currentUser.value = user;
      if (user != null) {
        cache.persistent.setJson(_kCurrentUserCacheKey, user.toJson());
      } else {
        cache.persistent.remove(_kCurrentUserCacheKey);
      }
    });
  }

  /// Restores the last-known authenticated user from the persistent cache.
  ///
  /// Called automatically by [MooseBootstrapper] immediately after the
  /// persistent cache is initialised (bootstrap step 2b), before any adapter
  /// or plugin is registered. Populating [currentUser] this early means the
  /// UI can render user-specific content on the very first frame, without
  /// waiting for the live `authStateChanges` stream to confirm the session.
  ///
  /// Once the [AuthRepository] is first accessed and [wireAuthRepository] is
  /// called, the live stream takes over and will correct or confirm the cached
  /// value as soon as the adapter connects to its backend.
  ///
  /// This method is a no-op when no user has been persisted (e.g. first
  /// launch or after sign-out).
  Future<void> restoreAuthState() async {
    final data = await cache.persistent
        .getJson<Map<String, dynamic>>(_kCurrentUserCacheKey);
    if (data != null) {
      currentUser.value = User.fromJson(data);
    }
  }

  /// Signs out from every registered auth provider and clears all local state.
  ///
  /// 1. Calls [AuthRepository.signOut] on every already-instantiated auth repo
  ///    (deduplicated) to revoke server-side sessions and clear their internal state.
  /// 2. Unconditionally clears [currentUser] and the persistent user cache —
  ///    this handles the cold-start case where no auth repo has been instantiated
  ///    yet but the user is still shown as signed in from [restoreAuthState].
  ///
  /// Use this instead of calling [getRepository<AuthRepository>().signOut()]
  /// directly — the unnamed lookup may resolve to a different provider than the
  /// one that was used to sign in.
  Future<void> signOut() async {
    await adapterRegistry.signOutAll();
    currentUser.value = null;
    await cache.persistent.remove(_kCurrentUserCacheKey);
  }

  /// Releases all resources owned by this context.
  ///
  /// Cancels the active [AuthRepository] stream subscription and disposes
  /// the [currentUser] notifier. Call this when the context is permanently
  /// torn down — for example, at the end of a test or when replacing the
  /// root context.
  ///
  /// [MooseScope] calls [PluginRegistry.stopAll] on its own dispose; this
  /// method handles only the resources owned directly by [MooseAppContext].
  void dispose() {
    _authStateSubscription?.cancel();
    currentUser.dispose();
  }
}
