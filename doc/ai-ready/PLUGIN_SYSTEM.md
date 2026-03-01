# Plugin System Guide

> Complete guide to creating and managing plugins in moose_core

## Table of Contents
- [Overview](#overview)
- [FeaturePlugin Base Class](#featureplugin-base-class)
- [Plugin Lifecycle](#plugin-lifecycle)
- [Creating a Plugin](#creating-a-plugin)
- [Plugin Configuration](#plugin-configuration)
- [Accessing Plugin Settings](#accessing-plugin-settings)
- [Bottom Navigation Tabs](#bottom-navigation-tabs)
- [PluginRegistry API](#pluginregistry-api)
- [MooseScope and context.moose](#moosescope-and-contextmoose)
- [Inter-Plugin Communication](#inter-plugin-communication)
- [Best Practices](#best-practices)
- [Anti-Patterns](#anti-patterns)
- [Testing Plugins](#testing-plugins)
- [Plugin Documentation Standards](#plugin-documentation-standards)
- [Related Documentation](#related-documentation)

---

## Overview

Every feature in a moose_core app lives in a self-contained `FeaturePlugin`. Plugins are registered and initialized by `MooseBootstrapper`, receive a scoped `MooseAppContext` before any lifecycle method runs, and communicate with each other exclusively through `HookRegistry` and `EventBus`.

**Key design rules:**
- Plugins never import or directly reference other plugin classes.
- All registry access goes through `appContext` convenience getters — never construct a registry directly.
- No plugin is active until `PluginRegistry.register()` injects `appContext` and calls `onRegister()`.

---

## FeaturePlugin Base Class

```dart
abstract class FeaturePlugin {
  /// Unique identifier — must match the key used in environment.json plugins block.
  String get name;

  /// Semantic version string (e.g., '1.0.0').
  String get version;

  /// Injected by PluginRegistry.register() before onRegister() is called.
  late MooseAppContext appContext;

  // Convenience getters — all delegate to appContext:
  HookRegistry    get hookRegistry   => appContext.hookRegistry;
  AddonRegistry   get addonRegistry  => appContext.addonRegistry;
  WidgetRegistry  get widgetRegistry => appContext.widgetRegistry;
  AdapterRegistry get adapterRegistry => appContext.adapterRegistry;
  ActionRegistry  get actionRegistry => appContext.actionRegistry;
  ConfigManager   get configManager  => appContext.configManager;
  EventBus        get eventBus       => appContext.eventBus;
  AppLogger       get logger         => appContext.logger;
  CacheManager    get cache          => appContext.cache;

  /// JSON Schema describing this plugin's settings surface.
  /// Used to validate environment.json at registration time.
  Map<String, dynamic> get configSchema => {'type': 'object'};

  /// Default values for every key in configSchema.
  /// Registered with ConfigManager at registration time so getSetting<T>()
  /// falls back to these when environment.json omits a key.
  Map<String, dynamic> getDefaultSettings() => {};

  /// SYNC. Called immediately after appContext is injected.
  /// Register widgets, hooks, addons, and action handlers here.
  /// Do NOT do async I/O here.
  void onRegister();

  /// ASYNC. Called by PluginRegistry.initAll() after all plugins are registered.
  /// Perform async setup: fetch initial data, open DB connections, etc.
  Future<void> onInit();

  /// ASYNC. Called by PluginRegistry.startAll() after all plugins finish onInit().
  /// Use for work that requires other plugins to be fully initialized first.
  Future<void> onStart() async {}

  /// ASYNC. Called when Flutter app lifecycle changes (foreground/background/etc.).
  Future<void> onAppLifecycle(AppLifecycleState state) async {}

  /// ASYNC. Called during app teardown (MooseScope dispose or context swap).
  /// Cancel subscriptions, close streams, release resources here.
  Future<void> onStop() async {}

  /// Return named routes this plugin owns. Return null if the plugin owns none.
  Map<String, WidgetBuilder>? getRoutes();

  /// Bottom navigation tabs contributed by this plugin. Default: empty.
  List<BottomTab> get bottomTabs => const [];

  /// Reads a setting from the scoped ConfigManager.
  /// Path: plugins:<name>:settings:<key>
  /// Falls back to getDefaultSettings() values automatically.
  T getSetting<T>(String key);
}
```

### Convenience getters

All registry and service access goes through the getters above — never call `HookRegistry()`, `AdapterRegistry()`, etc. directly inside a plugin. They are instance-based (not singletons) and the correct scoped instances are only available via `appContext`.

---

## Plugin Lifecycle

`MooseBootstrapper.run()` drives the full lifecycle in order:

```
MooseBootstrapper.run()
│
├─ 1. configManager.initialize(config)
├─ 2. cache.initPersistent()
├─ 3. AppNavigator.setEventBus(appContext.eventBus)
├─ 4. Register adapters (adapterRegistry.registerAdapter per adapter)
│
├─ 5. For each plugin factory:
│       plugin = factory()
│       pluginRegistry.register(plugin, appContext: appContext)
│         ├─ registerPluginDefaults() in ConfigManager
│         ├─ Check active flag in environment.json
│         │    └─ active: false → skip silently
│         ├─ plugin.appContext = appContext  ← injected here
│         ├─ plugin.onRegister()            ← SYNC
│         └─ _registerBottomTabs(plugin)
│
├─ 6. pluginRegistry.initAll()
│       └─ plugin.onInit()  for each plugin  ← ASYNC, in registration order
│
└─ 7. pluginRegistry.startAll()
        └─ plugin.onStart()  for each plugin ← ASYNC, in registration order
```

**At runtime** (after bootstrap):
- `MooseLifecycleObserver` (attached by `MooseScope`) forwards `AppLifecycleState` changes to `pluginRegistry.notifyAppLifecycle(state)` → `plugin.onAppLifecycle(state)`.
- When `MooseScope` is disposed (app shutdown or context swap): `pluginRegistry.stopAll()` → `plugin.onStop()` on all plugins in **reverse** registration order.

### Lifecycle method responsibilities

| Method | Thread | When to use |
|---|---|---|
| `onRegister()` | Sync | Register widgets, hooks, addons, action handlers. No I/O. |
| `onInit()` | Async | Fetch initial data, open connections, warm caches. |
| `onStart()` | Async | Work that requires other plugins to be initialized first. |
| `onAppLifecycle()` | Async | Pause/resume background tasks on foreground/background transitions. |
| `onStop()` | Async | Cancel subscriptions, close streams, flush caches. |

---

## Creating a Plugin

### Step 1: Extend FeaturePlugin

```dart
import 'package:moose_core/plugin.dart';
import 'package:moose_core/repositories.dart';

class ProductsPlugin extends FeaturePlugin {
  @override
  String get name => 'products';

  @override
  String get version => '1.0.0';

  @override
  Map<String, dynamic> get configSchema => {
    'type': 'object',
    'properties': {
      'perPage': {'type': 'integer', 'minimum': 1},
      'enableReviews': {'type': 'boolean'},
      'cache': {
        'type': 'object',
        'properties': {
          'productsTTL': {'type': 'integer', 'minimum': 0},
          'categoriesTTL': {'type': 'integer', 'minimum': 0},
        },
      },
    },
  };

  @override
  Map<String, dynamic> getDefaultSettings() => {
    'perPage': 20,
    'enableReviews': true,
    'cache': {
      'productsTTL': 300,
      'categoriesTTL': 600,
    },
  };

  // Plugin-owned state (created in onInit, used at runtime)
  late ProductsBloc _productsBloc;

  @override
  void onRegister() {
    // Register UI sections
    widgetRegistry.register(
      'products.featured_section',
      (context, {data, onEvent}) => FeaturedProductsSection(
        settings: data?['settings'] as Map<String, dynamic>? ?? {},
      ),
    );

    widgetRegistry.register(
      'products.grid_section',
      (context, {data, onEvent}) => ProductsGridSection(
        settings: data?['settings'] as Map<String, dynamic>? ?? {},
      ),
    );

    // Register hooks so other plugins can extend product data
    hookRegistry.register('products:transform', (product) => product);

    // Register a custom action for navigation
    actionRegistry.registerCustomHandler('view_product', (context, params) {
      final id = params?['productId'] as String?;
      if (id != null) Navigator.pushNamed(context, '/product', arguments: id);
    });
  }

  @override
  Future<void> onInit() async {
    final repo = adapterRegistry.getRepository<ProductsRepository>();
    final perPage = getSetting<int>('perPage');
    _productsBloc = ProductsBloc(repo, perPage: perPage);
    // Optionally warm the cache
    await _productsBloc.prefetch();
  }

  @override
  Future<void> onStart() async {
    // Runs after ALL plugins have completed onInit().
    // Safe to call into other plugins via hooks here.
    final cartCount = hookRegistry.execute('cart:get_item_count', 0);
    logger.debug('Products started. Cart has $cartCount items.');
  }

  @override
  Future<void> onAppLifecycle(AppLifecycleState state) async {
    if (state == AppLifecycleState.paused) {
      _productsBloc.pausePolling();
    } else if (state == AppLifecycleState.resumed) {
      _productsBloc.resumePolling();
    }
  }

  @override
  Future<void> onStop() async {
    await _productsBloc.close();
  }

  @override
  Map<String, WidgetBuilder>? getRoutes() => {
    '/products': (_) => ProductsListScreen(bloc: _productsBloc),
    '/product': (ctx) => ProductDetailScreen(
      productId: ModalRoute.of(ctx)?.settings.arguments as String?,
    ),
  };

  @override
  List<BottomTab> get bottomTabs => const [
    BottomTab(
      id: 'products',
      label: 'Shop',
      icon: Icons.shopping_bag_outlined,
      activeIcon: Icons.shopping_bag,
      route: '/products',
    ),
  ];
}
```

### Step 2: Bootstrap with MooseBootstrapper

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final ctx = MooseAppContext();
  runApp(
    MooseScope(
      appContext: ctx,
      child: MaterialApp(home: BootstrapScreen(appContext: ctx)),
    ),
  );
}

// Inside BootstrapScreen (e.g. in initState or FutureBuilder):
final config = jsonDecode(await rootBundle.loadString('assets/environment.json'));

final report = await MooseBootstrapper(appContext: ctx).run(
  config: config,
  adapters: [WooCommerceAdapter()],
  plugins: [
    () => ProductsPlugin(),
    () => CartPlugin(),
    () => CheckoutPlugin(),
  ],
);

if (!report.succeeded) {
  // report.failures: Map<String, Object>
  // keys: "adapter:<name>" or "plugin:<name>" or "plugin:initAll" / "plugin:startAll"
  debugPrint('Bootstrap failures: ${report.failures}');
}
```

`BootstrapReport` fields:
- `succeeded` — `true` if `failures` is empty
- `totalTime` — wall-clock duration for the full sequence
- `pluginTimings` — per-plugin `onInit()` durations
- `pluginStartTimings` — per-plugin `onStart()` durations
- `failures` — map of component key → exception

---

## Plugin Configuration

### environment.json structure

```json
{
  "plugins": {
    "products": {
      "active": true,
      "settings": {
        "perPage": 20,
        "enableReviews": true,
        "cache": {
          "productsTTL": 300,
          "categoriesTTL": 600
        },
        "display": {
          "gridColumns": 2,
          "showOutOfStock": false
        }
      },
      "sections": {
        "home": [
          {
            "name": "products.featured_section",
            "active": true,
            "settings": {
              "title": "Featured",
              "limit": 8
            }
          }
        ]
      }
    },
    "analytics": {
      "active": false
    }
  }
}
```

### active flag behaviour

| Scenario | Result |
|---|---|
| `"active": true` | Plugin registers normally |
| `"active": false` | Plugin is silently skipped — `onRegister()`, `onInit()`, `onStart()` never called |
| Key absent from environment.json | Plugin is considered active by default |

When a plugin is inactive:
- Its routes are never added to the app.
- Its sections are never registered.
- `pluginRegistry.hasPlugin(name)` returns `false`.
- Requesting it via `pluginRegistry.getPlugin(name)` throws.

---

## Accessing Plugin Settings

`getSetting<T>(key)` reads from `plugins:<name>:settings:<key>` in the scoped `ConfigManager`. Dot-separated keys navigate nested maps.

```dart
// environment.json has:
// "products": { "settings": { "cache": { "productsTTL": 300 }, "perPage": 20 } }

final ttl    = getSetting<int>('cache.productsTTL'); // → 300, or default if absent
final perPage = getSetting<int>('perPage');          // → 20, or default if absent
final cols   = getSetting<int>('display.gridColumns'); // → default (2) if absent
```

`getDefaultSettings()` is registered with `ConfigManager` at plugin registration time, so any key absent from `environment.json` automatically falls back to the default. **Always declare a default for every optional setting.**

### Passing settings to internal layers

The plugin is the single owner of its configuration. Downstream BLoCs and widgets should receive settings as constructor arguments — they must not reach into `ConfigManager` themselves.

```dart
// ✅ Plugin reads settings and passes them down
@override
Future<void> onInit() async {
  final repo   = adapterRegistry.getRepository<ProductsRepository>();
  final perPage = getSetting<int>('perPage');
  final ttl     = Duration(seconds: getSetting<int>('cache.productsTTL'));
  _bloc = ProductsBloc(repo, perPage: perPage, cacheTTL: ttl);
}

// ✅ Widget receives data via section settings map — not ConfigManager
widgetRegistry.register('products.grid_section', (ctx, {data, onEvent}) {
  return ProductsGridSection(settings: data?['settings'] ?? {});
});
```

---

## Bottom Navigation Tabs

Declare tabs by overriding `bottomTabs`. `PluginRegistry` merges them automatically — you do not need to interact with `bottom_tabs:filter_tabs` manually.

```dart
@override
List<BottomTab> get bottomTabs => const [
  BottomTab(
    id: 'cart',
    label: 'Cart',
    icon: Icons.shopping_cart_outlined,
    activeIcon: Icons.shopping_cart,
    route: '/cart',
  ),
];
```

### Tab order and enablement via environment.json

Order and visibility are configuration, not code. Adjust them in environment.json without touching any plugin:

```json
{
  "plugins": {
    "bottom_tabs": {
      "settings": {
        "tabs": [
          { "id": "home",     "order": 10,  "enabled": true  },
          { "id": "products", "order": 30,  "enabled": true  },
          { "id": "search",   "order": 50,  "enabled": true  },
          { "id": "cart",     "order": 80,  "enabled": true  },
          { "id": "profile",  "order": 100, "enabled": false }
        ]
      }
    }
  }
}
```

### Runtime conditional tabs (using a hook)

For tabs that depend on runtime state (auth, feature flags), override `bottomTabs` to return `const []` and register a `bottom_tabs:filter_tabs` hook in `onRegister()`:

```dart
@override
List<BottomTab> get bottomTabs => const []; // nothing declared statically

@override
void onRegister() {
  hookRegistry.register(
    'bottom_tabs:filter_tabs',
    (tabs) {
      if (tabs is! List<BottomTab>) return tabs;
      final isAuth = hookRegistry.execute('auth:is_authenticated', false) as bool? ?? false;
      if (!isAuth) return tabs;
      return [
        ...tabs,
        const BottomTab(
          id: 'alerts',
          label: 'Alerts',
          icon: Icons.notifications_outlined,
          activeIcon: Icons.notifications,
          route: '/alerts',
        ),
      ];
    },
    priority: 10,
  );
}
```

---

## PluginRegistry API

`PluginRegistry` is owned by `MooseAppContext`. Never instantiate it directly.

```dart
// Registration (called by MooseBootstrapper — don't call manually)
pluginRegistry.register(plugin, appContext: appContext);

// Lifecycle (called by MooseBootstrapper — don't call manually)
await pluginRegistry.initAll(timings: timings);
await pluginRegistry.startAll(timings: timings);
await pluginRegistry.stopAll();                           // called by MooseScope on dispose
await pluginRegistry.notifyAppLifecycle(state);           // called by MooseLifecycleObserver

// Lookup
bool exists = pluginRegistry.hasPlugin('products');
ProductsPlugin p = pluginRegistry.getPlugin<ProductsPlugin>('products');
List<String> names = pluginRegistry.getRegisteredPlugins();
int count = pluginRegistry.pluginCount;

// Route collection (for MaterialApp.routes)
Map<String, WidgetBuilder> routes = pluginRegistry.getAllRoutes();
// Note: getAllRoutes() adds a fallback '/home' route if no plugin registers one.

// Test teardown only
pluginRegistry.clearAll();
```

---

## MooseScope and context.moose

`MooseScope` is an `InheritedWidget` placed at the root of the widget tree. It:
- Provides `MooseAppContext` to all descendants via `context.moose`.
- Attaches `MooseLifecycleObserver` to forward Flutter app lifecycle events to plugins.
- Calls `pluginRegistry.stopAll()` when disposed (app shutdown or context swap).

```dart
// Root setup
final ctx = MooseAppContext();
runApp(
  MooseScope(
    appContext: ctx,
    child: MaterialApp(
      routes: ctx.pluginRegistry.getAllRoutes(),
      home: BootstrapScreen(appContext: ctx),
    ),
  ),
);

// In any descendant widget:
final moose = context.moose;                  // MooseAppContext
final registry = context.moose.adapterRegistry;
final repo = context.moose.getRepository<ProductsRepository>();

// Static convenience accessors (same as context.moose.<registry>):
final hookReg  = MooseScope.hookRegistryOf(context);
final widgetReg = MooseScope.widgetRegistryOf(context);
final addonReg  = MooseScope.addonRegistryOf(context);
final actionReg = MooseScope.actionRegistryOf(context);
final adapterReg = MooseScope.adapterRegistryOf(context);
final configMgr  = MooseScope.configManagerOf(context);
final eventBus   = MooseScope.eventBusOf(context);
final cache      = MooseScope.cacheOf(context);
```

---

## Inter-Plugin Communication

Plugins are isolated — they must never import each other. Use `HookRegistry` for synchronous data transformation and `EventBus` for fire-and-forget notifications.

### HookRegistry (synchronous, data-transforming)

```dart
// CartPlugin fires a hook to let other plugins observe add-to-cart
hookRegistry.register('cart:add_item', (data) {
  if (data is Map<String, dynamic>) {
    _bloc.add(AddToCartEvent(
      productId: data['productId'] as String,
      quantity:  data['quantity']  as int? ?? 1,
    ));
  }
  return data; // pass through (hooks always return data)
});

// ProductsPlugin executes the hook
hookRegistry.execute('cart:add_item', {
  'productId': product.id,
  'quantity': 1,
});
```

### EventBus (async, fire-and-forget)

```dart
// Publisher (e.g., CheckoutPlugin fires after order placed)
eventBus.fire(OrderPlacedEvent(orderId: order.id));

// Subscriber (e.g., CartPlugin clears the cart)
@override
void onRegister() {
  eventBus.on<OrderPlacedEvent>((event) async {
    await _repo.clearCart();
  });
}
```

### Cross-plugin data access via hooks

```dart
// CheckoutPlugin needs the current cart without knowing CartPlugin:
final cart = hookRegistry.execute('cart:get_current_cart', null);
```

---

## Best Practices

```dart
// ✅ Register widgets and hooks synchronously in onRegister()
@override
void onRegister() {
  widgetRegistry.register('products.grid', (ctx, {data, onEvent}) => ProductGrid());
  hookRegistry.register('products:transform', (p) => p);
}

// ✅ Do async I/O in onInit()
@override
Future<void> onInit() async {
  final repo = adapterRegistry.getRepository<ProductsRepository>();
  _bloc = ProductsBloc(repo);
}

// ✅ Use onStart() for cross-plugin post-init work
@override
Future<void> onStart() async {
  // All plugins initialized — safe to call into other plugins via hooks
  final count = hookRegistry.execute('cart:get_item_count', 0);
}

// ✅ Clean up in onStop()
@override
Future<void> onStop() async {
  await _subscription?.cancel();
  await _bloc.close();
}

// ✅ Own your settings — pass them to internal layers via constructor
@override
Future<void> onInit() async {
  _bloc = ProductsBloc(
    adapterRegistry.getRepository<ProductsRepository>(),
    perPage: getSetting<int>('perPage'),
    cacheTTL: Duration(seconds: getSetting<int>('cache.productsTTL')),
  );
}

// ✅ Always provide defaults for every optional setting
@override
Map<String, dynamic> getDefaultSettings() => {
  'perPage': 20,
  'cache': {'productsTTL': 300},
};

// ✅ Use log via the logger getter (not print)
logger.info('Products plugin initialized');
logger.error('Failed to load categories', e);
```

---

## Anti-Patterns

```dart
// ❌ Never import another plugin class
import 'package:my_app/plugins/cart_plugin.dart'; // WRONG

// ❌ Never construct registries directly inside a plugin
final hooks = HookRegistry(); // WRONG — use hookRegistry getter
final cache = CacheManager(); // WRONG — use cache getter

// ❌ Never do async I/O in onRegister()
@override
void onRegister() {
  await _loadData(); // WRONG — onRegister is synchronous
}

// ❌ Never let BLoCs/widgets reach into ConfigManager
class ProductsBloc {
  ProductsBloc() {
    final ttl = ConfigManager().get('plugins:products:settings:cache:productsTTL'); // WRONG
  }
}

// ❌ Don't await in onAppLifecycle() for heavy work — it blocks the observer callback
@override
Future<void> onAppLifecycle(AppLifecycleState state) async {
  if (state == AppLifecycleState.paused) {
    await heavySync(); // WRONG — fire-and-forget or schedule
  }
}

// ❌ Don't compose plugins by calling lifecycle methods on each other
class EcommercePlugin extends FeaturePlugin {
  @override
  Future<void> onInit() async {
    final cart = CartPlugin();
    await cart.onInit(); // WRONG — register each plugin separately via MooseBootstrapper
  }
}

// ❌ Don't access adapterRegistry before onInit() (repositories need adapters initialized)
@override
void onRegister() {
  final repo = adapterRegistry.getRepository<ProductsRepository>(); // WRONG
}
```

---

## Testing Plugins

### Unit test (no Flutter)

```dart
void main() {
  group('ProductsPlugin', () {
    test('metadata', () {
      final plugin = ProductsPlugin();
      expect(plugin.name, 'products');
      expect(plugin.version, isNotEmpty);
    });

    test('getRoutes() returns expected paths', () {
      final plugin = ProductsPlugin();
      expect(plugin.getRoutes()?.keys, containsAll(['/products', '/product']));
    });

    test('getDefaultSettings() provides perPage default', () {
      expect(ProductsPlugin().getDefaultSettings()['perPage'], isA<int>());
    });
  });
}
```

### Integration test — onRegister() with scoped context

```dart
void main() {
  group('ProductsPlugin integration', () {
    late MooseAppContext ctx;

    setUp(() {
      ctx = MooseAppContext();
      ctx.configManager.initialize({
        'plugins': {'products': {'active': true, 'settings': {'perPage': 10}}},
      });
    });

    tearDown(() => ctx.pluginRegistry.clearAll());

    test('registers expected widget sections', () {
      ctx.pluginRegistry.register(ProductsPlugin(), appContext: ctx);

      expect(ctx.widgetRegistry.isRegistered('products.featured_section'), isTrue);
      expect(ctx.widgetRegistry.isRegistered('products.grid_section'), isTrue);
    });

    test('inactive plugin is skipped', () {
      ctx.configManager.initialize({
        'plugins': {'products': {'active': false}},
      });
      ctx.pluginRegistry.register(ProductsPlugin(), appContext: ctx);

      expect(ctx.pluginRegistry.hasPlugin('products'), isFalse);
    });

    test('getSetting() reads from config', () {
      ctx.pluginRegistry.register(ProductsPlugin(), appContext: ctx);
      final plugin = ctx.pluginRegistry.getPlugin<ProductsPlugin>('products');
      expect(plugin.getSetting<int>('perPage'), 10);
    });
  });
}
```

### Full bootstrap test

```dart
void main() {
  test('bootstrap initializes all plugins', () async {
    final ctx = MooseAppContext();
    final config = {
      'adapters': {'mock': {}},
      'plugins': {'products': {'active': true}},
    };

    final report = await MooseBootstrapper(appContext: ctx).run(
      config: config,
      adapters: [MockAdapter()],
      plugins: [() => ProductsPlugin()],
    );

    expect(report.succeeded, isTrue);
    expect(ctx.pluginRegistry.hasPlugin('products'), isTrue);
  });
}
```

---

## Plugin Documentation Standards

Every plugin should include a `README.md` in its plugin directory. Write it for AI agents first, humans second. Required sections:

1. Overview — what the plugin does and its role in the app
2. Configuration — full `environment.json` example with all settings explained
3. Widget Registry — table of all registered section names, settings, and expected data shape
4. Routes — all paths, arguments, and preconditions
5. Hook Points — all hooks registered and executed, with data shapes
6. Events — all `EventBus` events fired and subscribed to
7. Usage Examples — 3–5 concrete scenarios
8. Integration with Other Plugins — how to interact via hooks/events
9. Troubleshooting — common misconfiguration issues

Format each hook as:

```markdown
#### `hook:name`
What it does.

**Input**: type — description
**Output**: type — description

**Example**:
\`\`\`dart
hookRegistry.register('hook:name', (data) {
  // ...
  return modifiedData;
}, priority: 10);
\`\`\`
```

---

## Related Documentation

- [ARCHITECTURE.md](./ARCHITECTURE.md) — Overall system architecture
- [ADAPTER_SYSTEM.md](./ADAPTER_SYSTEM.md) — How plugins consume repositories
- [FEATURE_SECTION.md](./FEATURE_SECTION.md) — Building configurable UI sections
- [REGISTRIES.md](./REGISTRIES.md) — All registry APIs
- [EVENT_SYSTEM_GUIDE.md](./EVENT_SYSTEM_GUIDE.md) — HookRegistry and EventBus
- [ANTI_PATTERNS.md](./ANTI_PATTERNS.md) — Extended anti-patterns
- [PLUGIN_ADAPTER_CONFIG_GUIDE.md](./PLUGIN_ADAPTER_CONFIG_GUIDE.md) — Config deep-dive
- [PLUGIN_ADAPTER_MANIFEST.md](./PLUGIN_ADAPTER_MANIFEST.md) — moose.manifest.json reference for distributable plugin packages

---

**Last Updated:** 2026-03-01
**Version:** 4.0.0
