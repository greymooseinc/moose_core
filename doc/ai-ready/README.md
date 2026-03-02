# moose_core — AI-Ready Documentation

> Reference documentation for AI agents building plugins, adapters, and sections on the `moose_core` Flutter framework.

---

## What is moose_core?

`moose_core` is a modular, backend-agnostic Flutter framework for e-commerce and content applications. It provides the architectural skeleton — registries, lifecycle, configuration, caching, events — so that features (plugins) and backends (adapters) can be developed independently and composed at runtime.

---

## Quick Start

A fresh moose_core app can be initialized in two ways: using the official `moose_cli` tool (recommended — scaffolds the full project structure, wires dependencies, and can install plugins and adapters in one command), or by manually adding the package and writing the bootstrap code yourself.

### 1. Using moose_cli

`moose_cli` is the official command-line scaffolding tool for moose_core projects. It handles Flutter project creation, adds the `moose_core` git dependency, generates the `environment.json` configuration file, and can install plugins and adapters directly from git repositories or local paths. For AI agents generating new projects or extending existing ones, `moose_cli` is the fastest and least error-prone path.

Activate it globally once with:

```bash
dart pub global activate moose_cli
```

```bash
# activate moose_cli tool globally once
dart pub global activate moose_cli

# initialize an empty app with core dependencies
moose init my_app
```

### 2. Wire up manually 

Add to `pubspec.yaml`:

```yaml
dependencies:
  moose_core: 'latest'
```

Bootstrap the framework in `main.dart`:

```dart
import 'package:moose_core/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final appContext = MooseAppContext();

  runApp(MooseScope(
    appContext: appContext,
    child: AppBootstrap(appContext: appContext),
  ));
}

class AppBootstrap extends StatefulWidget {
  final MooseAppContext appContext;
  const AppBootstrap({super.key, required this.appContext});

  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final config = await loadEnvironmentJson(); // Map<String, dynamic>

    final report = await MooseBootstrapper(appContext: widget.appContext).run(
      config: config,
      adapters: [WooCommerceAdapter()],
      plugins: [() => ProductsPlugin(), () => CartPlugin()],
    );

    if (!report.succeeded) {
      // report.failures: Map<String, Object>
      // keys are 'adapter:<name>' or 'plugin:<name>'
    }
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
```

---

## Architecture at a Glance

```
┌─────────────────────────────────────────────────────┐
│              Presentation Layer                     │
│    Screens · FeatureSection · Widgets               │
└──────────────────────┬──────────────────────────────┘
                       │ events / states
┌──────────────────────▼──────────────────────────────┐
│           Business Logic Layer (BLoC)               │
│    Blocs receive repositories via constructor       │
└──────────────────────┬──────────────────────────────┘
                       │ repository calls
┌──────────────────────▼──────────────────────────────┐
│           Repository Layer (abstract)               │
│    ProductsRepository, CartRepository, ...          │
└──────────────────────┬──────────────────────────────┘
                       │ concrete implementation
┌──────────────────────▼──────────────────────────────┐
│           Adapter Layer (BackendAdapter)            │
│    WooCommerceAdapter, ShopifyAdapter, ...          │
└─────────────────────────────────────────────────────┘
```

**Key classes:**

| Class | Role |
|---|---|
| `MooseAppContext` | Owns all registries and services for one app instance |
| `MooseScope` | `InheritedWidget` serving `MooseAppContext` to the widget tree |
| `MooseBootstrapper` | Orchestrates the 7-step startup sequence |
| `FeaturePlugin` | Base class for feature modules |
| `BackendAdapter` | Base class for backend implementations |
| `FeatureSection` | Base class for configurable UI sections |
| `CoreRepository` | Base class for all repository interfaces |

---

## MooseAppContext — The DI Container

`MooseAppContext` is the single dependency-injection container. It owns every registry and service:

```dart
final ctx = MooseAppContext();

// All registries are independent instances — no global state
ctx.pluginRegistry    // PluginRegistry
ctx.widgetRegistry    // WidgetRegistry
ctx.addonRegistry     // AddonRegistry
ctx.hookRegistry      // HookRegistry
ctx.actionRegistry    // ActionRegistry
ctx.adapterRegistry   // AdapterRegistry
ctx.configManager     // ConfigManager
ctx.eventBus          // EventBus
ctx.cache             // CacheManager (memory + persistent)
ctx.logger            // AppLogger

// Shortcut for repository access
ctx.getRepository<ProductsRepository>()
```

In widgets, access via `context.moose`:

```dart
final ctx = context.moose;
final products = ctx.adapterRegistry.getRepository<ProductsRepository>();
```

Custom or mock instances can be injected via constructor — useful for testing:

```dart
final ctx = MooseAppContext(
  hookRegistry: MockHookRegistry(),
  configManager: MockConfigManager(),
);
```

---

## Bootstrap Sequence

`MooseBootstrapper.run()` executes these steps in order:

1. `ConfigManager.initialize(config)` — loads `environment.json` map
2. `CacheManager.initPersistent()` — opens persistent cache
3. `AppNavigator.setEventBus(eventBus)` — wires navigation to scoped event bus
4. Register each adapter — `AdapterRegistry.registerAdapter()` → validates config schema → calls `adapter.initialize(config)`
5. Register each plugin (sync) — injects `MooseAppContext`, calls `plugin.onRegister()`
6. Initialize all plugins (async) — calls `plugin.onInit()` in registration order
7. Start all plugins (async) — calls `plugin.onStart()` in registration order

Returns a `BootstrapReport` with per-plugin timings and a `failures` map (empty means success).

---

## Module Imports

```dart
import 'package:moose_core/app.dart';          // MooseAppContext, MooseScope, MooseBootstrapper
import 'package:moose_core/entities.dart';      // Domain entities (Product, Cart, Order, ...)
import 'package:moose_core/repositories.dart';  // Repository interfaces
import 'package:moose_core/plugin.dart';        // FeaturePlugin, PluginRegistry
import 'package:moose_core/widgets.dart';       // FeatureSection, WidgetRegistry, AddonRegistry
import 'package:moose_core/adapters.dart';      // BackendAdapter, AdapterRegistry
import 'package:moose_core/cache.dart';         // CacheManager, MemoryCache, PersistentCache
import 'package:moose_core/services.dart';      // EventBus, HookRegistry, ActionRegistry, AppLogger, ApiClient
```

---

## Plugin System

A plugin is a self-contained feature module. It extends `FeaturePlugin` and follows this lifecycle:

```
onRegister() [sync] → onInit() [async] → onStart() [async] → onAppLifecycle() → onStop()
```

```dart
class ProductsPlugin extends FeaturePlugin {
  @override
  String get name => 'products';    // must match environment.json key

  @override
  String get version => '1.0.0';

  @override
  Map<String, dynamic> get configSchema => {
    'type': 'object',
    'properties': {
      'display': {
        'type': 'object',
        'properties': {
          'itemsPerPage': {'type': 'integer', 'minimum': 1},
        },
      },
    },
  };

  @override
  Map<String, dynamic> getDefaultSettings() => {
    'display': {'itemsPerPage': 20},
  };

  @override
  void onRegister() {
    // Sync: register widgets, routes, addons, hooks
    widgetRegistry.register(
      'products.featured_section',
      (context, {data, onEvent}) => FeaturedProductsSection(
        settings: data?['settings'] as Map<String, dynamic>?,
      ),
    );
  }

  @override
  Future<void> onInit() async {
    // Async: warm caches, subscribe to events
    final perPage = getSetting<int>('display:itemsPerPage');
  }

  @override
  Map<String, WidgetBuilder>? getRoutes() => {
    '/products': (_) => const ProductsScreen(),
    '/product/detail': (_) => const ProductDetailScreen(),
  };
}
```

**Read plugin config with `getSetting<T>(key)`** — resolves `plugins:<name>:settings:<key>` automatically:

```dart
final perPage = getSetting<int>('display:itemsPerPage');
```

**Activate/deactivate via `environment.json`:**

```json
{
  "plugins": {
    "products": { "active": true, "settings": { "display": { "itemsPerPage": 24 } } },
    "reviews":  { "active": false }
  }
}
```

---

## Adapter System

An adapter connects `moose_core` to a specific backend. It extends `BackendAdapter`, declares a `configSchema`, and registers repository factories inside `initialize()`.

```dart
class WooCommerceAdapter extends BackendAdapter {
  @override
  String get name => 'woocommerce';   // must match environment.json key

  @override
  String get version => '1.0.0';

  // Required — compile error if omitted. Validated before initialize() is called.
  @override
  Map<String, dynamic> get configSchema => {
    'type': 'object',
    'required': ['baseUrl', 'consumerKey', 'consumerSecret'],
    'properties': {
      'baseUrl':        {'type': 'string', 'format': 'uri'},
      'consumerKey':    {'type': 'string', 'minLength': 1},
      'consumerSecret': {'type': 'string', 'minLength': 1},
      'timeout':        {'type': 'integer', 'minimum': 0},
    },
    'additionalProperties': false,
  };

  @override
  Map<String, dynamic> getDefaultSettings() => {'timeout': 30};

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    // config is already validated — read directly
    final client = WooApiClient(
      baseUrl: config['baseUrl'] as String,
      consumerKey: config['consumerKey'] as String,
      consumerSecret: config['consumerSecret'] as String,
      timeout: Duration(seconds: config['timeout'] as int),
    );

    registerRepositoryFactory<ProductsRepository>(
      () => WooProductsRepository(client, cache: cache, eventBus: eventBus),
    );
    registerRepositoryFactory<CartRepository>(
      () => WooCartRepository(client, cache: cache, eventBus: eventBus),
    );
  }
}
```

**Adapter config in `environment.json`:**

```json
{
  "adapters": {
    "woocommerce": {
      "baseUrl": "https://mystore.example.com",
      "consumerKey": "ck_xxxx",
      "consumerSecret": "cs_xxxx"
    }
  }
}
```

---

## Repository System

Repositories are abstract interfaces. Adapters implement them. Plugins and sections consume them through `AdapterRegistry`.

```dart
// From a plugin
final products = adapterRegistry.getRepository<ProductsRepository>();

// From a FeatureSection (inside build() only)
final products = adaptersOf(context).getRepository<ProductsRepository>();

// Guard for optional repositories
if (adapterRegistry.hasRepository<PushNotificationRepository>()) {
  final push = adapterRegistry.getRepository<PushNotificationRepository>();
}
```

All repositories extend `CoreRepository` and override `initialize()` for synchronous setup. Repository instances are created lazily on first `getRepository<T>()` call and cached permanently.

| Repository | Key responsibility |
|---|---|
| `ProductsRepository` | Catalog, categories, collections, variations, reviews, stock |
| `CartRepository` | Cart, checkout, orders, payments, refunds |
| `AuthRepository` | Sign-in/up, profile, tokens, MFA, account linking |
| `SearchRepository` | Full-text search, suggestions, history |
| `ReviewRepository` | Entity-agnostic reviews (products, posts, any type) |
| `PostRepository` | CMS posts, pages, articles |
| `BannerRepository` | Promotional banners with click tracking |
| `PushNotificationRepository` | Device tokens, topics, notification streams |
| `ShortsRepository` | Short-form video/story content |
| `StoreRepository` | Store metadata, policies, locations, hours |
| `LocationRepository` | Geocoding, autocomplete, country/address data |

---

## FeatureSection Pattern

`FeatureSection` extends `StatelessWidget`. It is the standard unit of configurable UI. Settings merge constructor-supplied values over `getDefaultSettings()`. Use `getSetting<T>(key)` to read them.

```dart
class FeaturedProductsSection extends FeatureSection {
  const FeaturedProductsSection({super.key, super.settings});

  @override
  Map<String, dynamic> getDefaultSettings() => {
    'title': 'Featured',
    'limit': 10,
    'columns': 2,
  };

  @override
  Widget build(BuildContext context) {
    final title   = getSetting<String>('title');
    final limit   = getSetting<int>('limit');
    final columns = getSetting<int>('columns');

    // adaptersOf(context) must be called inside build()
    final products = adaptersOf(context).getRepository<ProductsRepository>();

    return BlocProvider(
      create: (_) => ProductsBloc(products)..add(LoadFeatured(limit: limit)),
      child: ProductGrid(title: title, columns: columns),
    );
  }
}
```

**Automatic type coercions in `getSetting<T>`:**

| Requested `T` | Accepted source type | Conversion |
|---|---|---|
| `double` | `num` | `.toDouble()` |
| `int` | `num` | `.toInt()` |
| `Color` | `String` | `ColorHelper.parse()` — supports `#RGB`, `#RRGGBB`, `#AARRGGBB`, named colors, `rgba(...)` |

---

## Registry Overview

| Registry | Purpose |
|---|---|
| `WidgetRegistry` | Maps string keys → `FeatureSection` builders; `buildSectionGroup()` renders a group |
| `AddonRegistry` | Priority-ordered widget slots; multiple builders per slot; null = skip |
| `HookRegistry` | Synchronous filter pipelines; descending priority; errors skipped |
| `ActionRegistry` | `UserInteraction` dispatch by type (`internal`, `external`, `custom`, `none`) |
| `AdapterRegistry` | Lazy repository factory management; last registered adapter wins |
| `EventBus` | Async pub/sub; string-named events; `Map<String, dynamic>` payload |

---

## Configuration System

Configuration flows from `environment.json` through `ConfigManager` with a three-tier fallback:

```
environment.json  →  getDefaultSettings() defaults  →  call-site defaultValue
```

```dart
// Plugin settings — has 'settings' segment
configManager.get('plugins:products:settings:display:itemsPerPage')

// Adapter settings — NO 'settings' segment
configManager.get('adapters:woocommerce:timeout')

// Check if explicitly set in environment.json (not from defaults)
configManager.has('plugins:products:settings:display:itemsPerPage')

// Inline fallback
configManager.get('plugins:products:settings:display:itemsPerPage', defaultValue: 20)
```

Both `.` and `:` work as path separators — they are interchangeable.

---

## moose_cli Reference

`moose_cli` scaffolds apps, installs plugins, and installs adapters from git repos, local paths, or custom manifest files.

### Installation

```bash
dart pub global activate moose_cli
moose version   # verify
```

### Commands

| Command | Description |
|---|---|
| `moose version` | Print CLI version |
| `moose init <name>` | Scaffold a new Flutter app |
| `moose init <name> --template <name>` | Scaffold from a built-in template |
| `moose init <name> --manifest <path\|url>` | Scaffold from a manifest file or HTTPS URL |
| `moose plugin add <name>` | Install a plugin into `lib/plugins/<name>` |
| `moose adapter add <name>` | Install an adapter into `lib/adapters/<name>` |
| `moose locale add <localeCode>` | Create a new ARB localization file |
| `moose help <command>` | Show detailed usage for a command |

### Flags — `moose init`

| Flag | Description |
|---|---|
| `--template <name>` | Built-in template (mutually exclusive with `--manifest`) |
| `--manifest <path\|url>` | Custom manifest file or HTTPS URL |
| `--configurations <path=value>` | Pre-fill `environment.json` values (repeatable) |
| `--verbose` | Stream git output during cloning |

### Flags — `moose plugin add` / `moose adapter add`

| Flag | Description |
|---|---|
| `--git <repo>` | Install from a remote git repository |
| `--path <dir>` | Install from a local directory |

### Examples

```bash
# New app from built-in template, pre-fill store URL
moose init my_app --template shopify \
  --configurations adapters.shopify.storeUrl=mystore.myshopify.com

# Add a plugin from the official extensions repo
moose plugin add loyalty \
  --git https://github.com/greymooseinc/moose_extensions.git

# Add an adapter from a local extensions workspace
moose adapter add stripe --path ./extensions/lib/adapters

# Add a Sinhala locale file
moose locale add si
```

---

## Documentation Index

### Start here

| Document | What it covers |
|---|---|
| [ARCHITECTURE.md](./ARCHITECTURE.md) | Bootstrap sequence, DI architecture, all layers in detail |
| [ANTI_PATTERNS.md](./ANTI_PATTERNS.md) | What NOT to do — common mistakes, violations, pitfalls |

### Building features (plugins + sections)

| Document | What it covers |
|---|---|
| [PLUGIN_SYSTEM.md](./PLUGIN_SYSTEM.md) | Full plugin lifecycle, config, routes, bottom tabs |
| [FEATURE_SECTION.md](./FEATURE_SECTION.md) | FeatureSection pattern, getSetting coercions, AddonRegistry slots |
| [REPOSITORIES.md](./REPOSITORIES.md) | All 11 repository interfaces and their full method signatures |
| [ENTITY_EXTENSIONS.md](./ENTITY_EXTENSIONS.md) | CoreEntity extensions map, copyWith vs copyWithExtensions |

### Building backends (adapters)

| Document | What it covers |
|---|---|
| [ADAPTER_SYSTEM.md](./ADAPTER_SYSTEM.md) | BackendAdapter lifecycle, registerRepositoryFactory, lazy caching |
| [ADAPTER_SCHEMA_VALIDATION.md](./ADAPTER_SCHEMA_VALIDATION.md) | JSON Schema reference for configSchema |
| [PLUGIN_ADAPTER_CONFIG_GUIDE.md](./PLUGIN_ADAPTER_CONFIG_GUIDE.md) | environment.json structure, ConfigManager fallback chain |
| [PLUGIN_ADAPTER_MANIFEST.md](./PLUGIN_ADAPTER_MANIFEST.md) | moose.manifest.json schema (tooling convention, not runtime) |

### Infrastructure

| Document | What it covers |
|---|---|
| [REGISTRIES.md](./REGISTRIES.md) | WidgetRegistry, AddonRegistry, HookRegistry, ActionRegistry, EventBus |
| [EVENT_SYSTEM_GUIDE.md](./EVENT_SYSTEM_GUIDE.md) | EventBus vs HookRegistry decision matrix, patterns, BLoC integration |
| [CACHE_SYSTEM.md](./CACHE_SYSTEM.md) | CacheManager, MemoryCache, PersistentCache, TTL configuration |
| [API.md](./API.md) | Public API reference — exported classes, type definitions |

---

## Key Rules for AI Agents

1. **Register in `onRegister()`, not `onInit()`** — widget, route, hook, and addon registration is synchronous and must happen in `onRegister()`. `onInit()` is for async work only.

2. **Never call APIs from BLoCs or sections** — sections create BLoCs. BLoCs call repository methods. Repositories call the API client.

3. **BLoC for all state** — `FeatureSection.build()` creates a `BlocProvider`. Never use `setState` for business logic.

4. **`adaptersOf(context)` inside `build()` only** — it requires a live `BuildContext` with `MooseScope` above it.

5. **`configSchema` is required on adapters** — it is abstract; omitting it is a compile error. It is validated before `initialize()` is called.

6. **`configSchema` is optional on plugins** — defaults to `{'type': 'object'}`. Override it to document the plugin's configuration surface.

7. **Adapter config path has no `settings` segment** — `adapters:woocommerce:timeout`, not `adapters:woocommerce:settings:timeout`.

8. **Plugin config path includes `settings`** — `plugins:products:settings:display:itemsPerPage`. Use `getSetting<T>(key)` as the shortcut.

9. **`moose.manifest.json` is not parsed at runtime** — it is a developer/tooling convention for `moose_cli` and AI agents to discover what a package provides.

10. **Subscribe in `onInit()`/`onStart()`, unsubscribe in `onStop()`** — all `EventBus` subscriptions must be cancelled in `onStop()` to prevent memory leaks.

---

## Support

- GitHub Issues: https://github.com/greymooseinc/moose_core/issues
- moose_cli on pub.dev: https://pub.dev/packages/moose_cli
