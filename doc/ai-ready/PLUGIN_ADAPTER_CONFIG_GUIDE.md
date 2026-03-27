# Plugin and Adapter Configuration Guide

## Overview

Configuration in `moose_core` flows through a single `ConfigManager` instance owned by `MooseAppContext`. It provides a three-tier fallback chain for every key lookup:

1. **environment.json** — user-supplied at app startup (highest priority)
2. **Plugin / adapter defaults** — registered automatically from `getDefaultSettings()` at registration time
3. **Call-site fallback** — optional `defaultValue` parameter on `get()` (lowest priority)

Plugins and adapters declare their configuration surface through two mechanisms:
- `configSchema` — JSON Schema used for **validation** (adapters: validated before `initialize()` is called; plugins: available for documentation/tooling)
- `getDefaultSettings()` — **fallback values** registered automatically by `PluginRegistry` / `AdapterRegistry`

---

## ConfigManager API

```dart
class ConfigManager {
  /// Load the full environment.json map. Called once by MooseBootstrapper.
  void initialize(Map<String, dynamic> config);

  /// Retrieve a value by dotted or colon-delimited key path.
  /// Falls back through defaults then defaultValue.
  /// Returns null if the key is absent and no defaultValue is provided.
  dynamic get(String key, {dynamic defaultValue});

  /// Returns true if the key exists in environment.json (not in defaults).
  bool has(String key);

  /// Raw config map (environment.json contents).
  Map<String, dynamic> get config;
}
```

`get()` accepts both `.` and `:` as path separators — they are interchangeable. The recommended convention is `:` for config keys in this codebase.

---

## Plugin Configuration

### Declaring the schema

```dart
class ProductsPlugin extends FeaturePlugin {
  @override
  String get name => 'products';

  @override
  String get version => '1.0.0';

  @override
  Map<String, dynamic> get configSchema => {
    'type': 'object',
    'properties': {
      'cache': {
        'type': 'object',
        'properties': {
          'productsTTL': {
            'type': 'integer',
            'minimum': 0,
            'description': 'Cache TTL for products in seconds',
          },
          'categoriesTTL': {
            'type': 'integer',
            'minimum': 0,
            'description': 'Cache TTL for categories in seconds',
          },
        },
      },
      'display': {
        'type': 'object',
        'properties': {
          'itemsPerPage': {
            'type': 'integer',
            'minimum': 1,
            'description': 'Products per page',
          },
          'showOutOfStock': {
            'type': 'boolean',
            'description': 'Include out-of-stock products in listings',
          },
        },
      },
    },
  };
```

`configSchema` on `FeaturePlugin` defaults to `{'type': 'object'}` — override it to document the plugin's configuration surface.

### Declaring defaults

```dart
  @override
  Map<String, dynamic> getDefaultSettings() {
    return {
      'cache': {
        'productsTTL': 300,
        'categoriesTTL': 600,
      },
      'display': {
        'itemsPerPage': 20,
        'showOutOfStock': true,
      },
    };
  }
```

`PluginRegistry.register()` calls `configManager.registerPluginDefaults(name, defaults)` automatically — you never need to register defaults manually.

### Accessing plugin settings — preferred: getSetting<T>

`FeaturePlugin` provides a `getSetting<T>(key)` convenience method that reads from `configManager` using the correct path prefix automatically:

```dart
@override
Future<void> onInit() async {
  // Equivalent to: configManager.get('plugins:products:settings:cache:productsTTL')
  final productsTTL = getSetting<int>('cache:productsTTL');
  final itemsPerPage = getSetting<int>('display:itemsPerPage');
  final showOutOfStock = getSetting<bool>('display:showOutOfStock');
}
```

`getSetting<T>(key)` resolves `plugins:<name>:settings:<key>` through the full fallback chain (environment.json → defaults).

### Accessing plugin settings — direct via configManager

When you need a value from outside the `plugins.<name>.settings` subtree, use `configManager.get()` directly:

```dart
// Full path required when using configManager directly
final productsTTL = configManager.get('plugins:products:settings:cache:productsTTL');

// With an inline fallback (used if absent in both environment.json and defaults)
final perPage = configManager.get(
  'plugins:products:settings:display:itemsPerPage',
  defaultValue: 20,
);

// Check if a key is explicitly set in environment.json
if (configManager.has('plugins:products:settings:display:itemsPerPage')) {
  // user explicitly configured this value
}
```

### Plugin config path format

```
plugins:<plugin_name>:settings:<nested_key_path>
```

Examples:
```
plugins:products:settings:cache:productsTTL
plugins:products:settings:display:itemsPerPage
plugins:blog:settings:filters:latest:perPage
plugins:cart:settings:checkout:requirePhone
```

### Activating / deactivating a plugin

`PluginRegistry` checks `plugins:<name>` in environment.json for an `active` field:

```json
{
  "plugins": [
    { "id": "products", "active": true, "settings": { ... } },
    { "id": "reviews", "active": false }
  ]
}
```

When `active` is `false`, `PluginRegistry.register()` skips the plugin entirely — `onRegister`, `onInit`, and `onStart` are never called. The default is `true` if the key is absent.

---

## Adapter Configuration

### Declaring the schema (required)

Unlike plugins, `configSchema` is **abstract** on `BackendAdapter` — it is a compile error to omit it. The schema is validated automatically by `initializeFromConfig()` before `initialize()` is called.

```dart
class WooCommerceAdapter extends BackendAdapter {
  @override
  String get name => 'woocommerce';

  @override
  String get version => '1.0.0';

  @override
  Map<String, dynamic> get configSchema => {
    'type': 'object',
    'required': ['baseUrl', 'consumerKey', 'consumerSecret'],
    'properties': {
      'baseUrl': {
        'type': 'string',
        'format': 'uri',
        'description': 'WooCommerce store URL',
      },
      'consumerKey': {
        'type': 'string',
        'minLength': 1,
        'description': 'WooCommerce REST API consumer key',
      },
      'consumerSecret': {
        'type': 'string',
        'minLength': 1,
        'description': 'WooCommerce REST API consumer secret',
      },
      'apiVersion': {
        'type': 'string',
        'description': 'REST API version (e.g., wc/v3)',
      },
      'timeout': {
        'type': 'integer',
        'minimum': 0,
        'description': 'Request timeout in seconds',
      },
    },
    'additionalProperties': false,
  };
```

Use `'additionalProperties': false` to catch environment.json typos at startup rather than silently ignoring unknown keys.

### Declaring defaults

```dart
  @override
  Map<String, dynamic> getDefaultSettings() => {
    'apiVersion': 'wc/v3',
    'timeout': 30,
  };
```

`AdapterRegistry.registerAdapter()` calls `configManager.registerAdapterDefaults(name, defaults)` automatically.

### Receiving config in initialize()

`initialize(Map<String, dynamic> config)` receives the **merged** configuration: environment.json values merged with `getDefaultSettings()` values. By the time `initialize()` is called, validation has already passed — do not re-validate.

```dart
  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    // config is validated and merged — read directly from the map
    final baseUrl = config['baseUrl'] as String;
    final consumerKey = config['consumerKey'] as String;
    final consumerSecret = config['consumerSecret'] as String;
    final apiVersion = config['apiVersion'] as String;   // defaults to 'wc/v3'
    final timeout = config['timeout'] as int;             // defaults to 30

    _client = WooApiClient(
      baseUrl: baseUrl,
      consumerKey: consumerKey,
      consumerSecret: consumerSecret,
      apiVersion: apiVersion,
      timeout: Duration(seconds: timeout),
    );

    _registerRepositories();
  }
```

### Accessing adapter config via configManager

The `config` map in `initialize()` is the canonical source. Alternatively, use `configManager.get()` with the adapter path format:

```
adapters:<adapter_name>:<key_path>
```

Note: adapter keys do **not** include a `settings` segment (unlike plugin keys):

```dart
// In initialize() — prefer the config map directly
final timeout = config['timeout'] as int;

// Via configManager — same value, same fallback chain
final timeout = configManager.get('adapters:woocommerce:timeout') as int;
```

Examples:
```
adapters:woocommerce:baseUrl
adapters:woocommerce:timeout
adapters:shopify:apiVersion
adapters:onesignal:debug
```

### Adapter config in environment.json

`"adapters"` is a top-level array. Each entry must have an `"id"` field that exactly matches `adapter.name`, an optional `"active"` flag, and a `"settings"` envelope containing the actual config values. `ConfigManager.initialize()` normalises the array to a keyed map before `initializeFromConfig()` runs.

```json
{
  "adapters": [
    {
      "id": "woocommerce",
      "active": true,
      "settings": {
        "baseUrl": "https://mystore.example.com",
        "consumerKey": "ck_xxxxxxxxxxxx",
        "consumerSecret": "cs_xxxxxxxxxxxx"
      }
    },
    {
      "id": "shopify",
      "active": true,
      "settings": {
        "storeUrl": "mystore.myshopify.com",
        "storefrontAccessToken": "xxxxxxxxxxxx"
      }
    }
  ]
}
```

The legacy flat format (settings at the top level of the adapter block, without a `settings` key) is still accepted for backwards compatibility. `initializeFromConfig()` detects which format is in use: when a `settings` key is present, it unwraps the inner map before passing it to `initialize()` — so adapter implementation code is identical for both formats.

---

## Full environment.json Structure

`"adapters"`, `"plugins"`, `"pages"`, and `"tabs"` are top-level arrays. `ConfigManager.initialize()` normalises each to a keyed map before any plugin or adapter code runs. `"sections"` inside plugin/page entries remain objects (not arrays).

```json
{
  "version": "1.0.0",
  "theme": "default",

  "adapters": [
    {
      "id": "<adapter.name>",
      "active": true,
      "settings": {
        "<key>": "<value>"
      }
    }
  ],

  "plugins": [
    {
      "id": "<plugin.name>",
      "active": true,
      "settings": {
        "<key>": "<value>"
      },
      "sections": {
        "<group_name>": [
          {
            "name": "<widget_registry_key>",
            "description": "...",
            "active": true,
            "settings": { "<key>": "<value>" }
          }
        ]
      }
    }
  ],

  "pages": [
    {
      "route": "<path>",
      "active": true,
      "appBar": { "title": "...", "buttonsLeft": [], "buttonsRight": [] },
      "sections": []
    },
    {
      "route": "<path>",
      "plugin": "<plugin.name>",
      "active": true,
      "sections": []
    },
    {
      "route": "<path>",
      "pageSlotIdentifier": "<plugin-declared slot identifier>",
      "settings": { "<key>": "<value>" },
      "appBar": { "title": "...", "floating": false, "pinned": true },
      "sections": []
    }
  ],

  "tabs": [
    {
      "id": "<tab_id>",
      "label": "...",
      "icon": "...",
      "activeIcon": "...",
      "route": "<path>",
      "order": 0,
      "enabled": true
    }
  ]
}
```

### Page entry forms

Three distinct forms are supported in the `"pages"` array. They differ in **who registers the Flutter route** and **where the screen widget comes from**:

| Form | Distinguishing field | Route registered by | Screen widget |
|------|---------------------|--------------------|----|
| **Plain auto-route** | none (just `"route"`) | `MooseBootstrapper` | `PageScreen` — sections driven by `WidgetRegistry` |
| **Plugin-owned** | `"plugin": "<name>"` | The plugin itself (via `getRoutes()`) | Plugin-controlled; config stored under `plugin:<name>:<route>` key |
| **Plugin-provided page slot** | `"pageSlotIdentifier": "<id>"` | `MooseBootstrapper` | `PageSlotBuilder` returned by the plugin's `pageSlots` map |

**Plain auto-route** — the bootstrapper wraps the entry in `PageScreen` automatically. Use this for purely config-driven screens with no BLoC setup.

**Plugin-owned** — the bootstrapper stores the entry under the key `plugin:<name>:<route>` and does **not** register a Flutter route. The plugin reads the config via that key and calls `PageScreen(pageConfig: ...)` itself (e.g. to wrap a BLoC). No auto-route is created.

**Plugin-provided page slot** — the bootstrapper registers the Flutter route but delegates widget construction to `pluginRegistry.getPageSlotBuilder(pageSlotIdentifier)`. The lookup is deferred to route build time via a `Builder`, so plugins are always registered before the lookup runs. Inside that `Builder`, `routeArgs` (`ModalRoute.of(ctx)?.settings.arguments`) is extracted and forwarded as the fourth argument to the slot builder. The builder receives the full `pageConfig` map, the `"settings"` sub-map, and `routeArgs` (the navigation arguments passed when pushing the route — e.g. `AppNavigator.pushNamed(context, '/products/item', arguments: {'productId': '123'})`; `null` when none were passed), and returns whatever widget it likes (typically a BLoC-wrapped screen). One slot identifier can back multiple routes with different `"settings"`.

---

## Fallback Chain Illustrated

For `configManager.get('plugins:products:settings:cache:productsTTL')`:

```
1. Look up plugins.products.settings.cache.productsTTL in environment.json
   ↓ found → return it
   ↓ not found

2. Look up cache.productsTTL in _pluginDefaults['products'] (from getDefaultSettings())
   ↓ found → return it
   ↓ not found

3. Return defaultValue parameter (or null if not provided)
```

For `configManager.get('adapters:woocommerce:timeout')`:

```
1. Look up adapters.woocommerce.timeout in environment.json
   ↓ found → return it
   ↓ not found

2. Look up timeout in _adapterDefaults['woocommerce'] (from getDefaultSettings())
   ↓ found → return it
   ↓ not found

3. Return defaultValue parameter (or null if not provided)
```

---

## Complete Examples

### ProductsPlugin — full configuration

```dart
class ProductsPlugin extends FeaturePlugin {
  @override
  String get name => 'products';

  @override
  String get version => '1.0.0';

  @override
  Map<String, dynamic> get configSchema => {
    'type': 'object',
    'properties': {
      'cache': {
        'type': 'object',
        'properties': {
          'productsTTL': {'type': 'integer', 'minimum': 0},
          'categoriesTTL': {'type': 'integer', 'minimum': 0},
        },
      },
      'display': {
        'type': 'object',
        'properties': {
          'itemsPerPage': {'type': 'integer', 'minimum': 1},
          'showOutOfStock': {'type': 'boolean'},
        },
      },
    },
  };

  @override
  Map<String, dynamic> getDefaultSettings() => {
    'cache': {
      'productsTTL': 300,
      'categoriesTTL': 600,
    },
    'display': {
      'itemsPerPage': 20,
      'showOutOfStock': true,
    },
  };

  @override
  void onRegister() {
    widgetRegistry.register(
      'products.featured_section',
      (context, {data, onEvent}) => FeaturedProductsSection(
        settings: data?['settings'] as Map<String, dynamic>?,
      ),
    );
  }

  @override
  Future<void> onInit() async {
    // Use getSetting<T> — preferred for plugin settings
    final productsTTL = getSetting<int>('cache:productsTTL');
    final itemsPerPage = getSetting<int>('display:itemsPerPage');

    final repo = adapterRegistry.getRepository<ProductsRepository>();
    await repo.getFeaturedProducts(
      limit: itemsPerPage,
      cacheTTL: Duration(seconds: productsTTL),
    );
  }
}
```

Corresponding environment.json:

```json
{
  "plugins": [
    {
      "id": "products",
      "active": true,
      "settings": {
        "cache": {
          "productsTTL": 600
        },
        "display": {
          "itemsPerPage": 24
        }
      }
    }
  ]
}
```

`categoriesTTL` and `showOutOfStock` fall back to `getDefaultSettings()` since they are not overridden.

### WooCommerceAdapter — full configuration

```dart
class WooCommerceAdapter extends BackendAdapter {
  late WooApiClient _client;

  @override
  String get name => 'woocommerce';

  @override
  String get version => '1.0.0';

  @override
  Map<String, dynamic> get configSchema => {
    'type': 'object',
    'required': ['baseUrl', 'consumerKey', 'consumerSecret'],
    'properties': {
      'baseUrl': {'type': 'string', 'format': 'uri'},
      'consumerKey': {'type': 'string', 'minLength': 1},
      'consumerSecret': {'type': 'string', 'minLength': 1},
      'apiVersion': {'type': 'string'},
      'timeout': {'type': 'integer', 'minimum': 0},
    },
    'additionalProperties': false,
  };

  @override
  Map<String, dynamic> getDefaultSettings() => {
    'apiVersion': 'wc/v3',
    'timeout': 30,
  };

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    _client = WooApiClient(
      baseUrl: config['baseUrl'] as String,
      consumerKey: config['consumerKey'] as String,
      consumerSecret: config['consumerSecret'] as String,
      apiVersion: config['apiVersion'] as String,
      timeout: Duration(seconds: config['timeout'] as int),
    );

    registerRepositoryFactory<ProductsRepository>(
      () => WooProductsRepository(_client, cache: cache, eventBus: eventBus, hooks: hookRegistry),
    );
    registerRepositoryFactory<CartRepository>(
      () => WooCartRepository(_client, cache: cache, eventBus: eventBus),
    );
  }
}
```

Corresponding environment.json:

```json
{
  "adapters": [
    {
      "id": "woocommerce",
      "active": true,
      "settings": {
        "baseUrl": "https://mystore.example.com",
        "consumerKey": "ck_xxxxxxxxxxxx",
        "consumerSecret": "cs_xxxxxxxxxxxx"
      }
    }
  ]
}
```

`apiVersion` and `timeout` are not in environment.json — they fall back to `getDefaultSettings()`.

---

## Rules Summary

| | Plugin | Adapter |
|---|---|---|
| `configSchema` required | No (defaults to `{'type': 'object'}`) | **Yes** — compile error if missing |
| Schema validated automatically | No | Yes — before `initialize()` |
| `getDefaultSettings()` | Optional but recommended | Optional but recommended |
| Defaults auto-registered | Yes, by `PluginRegistry` | Yes, by `AdapterRegistry` |
| Preferred access method | `getSetting<T>(key)` | `config` map in `initialize()` |
| ConfigManager path prefix | `plugins:<name>:settings:` | `adapters:<name>:settings:` |
| Activation flag | `plugins:<name>:active` (default true) | `adapters:<name>:active` (informational — not enforced by framework) |
| `additionalProperties: false` | Optional | Recommended |

---

## Related

- [ADAPTER_SYSTEM.md](./ADAPTER_SYSTEM.md) — Full adapter implementation guide including `configSchema` and `initialize()`
- [ADAPTER_SCHEMA_VALIDATION.md](./ADAPTER_SCHEMA_VALIDATION.md) — JSON Schema validation reference
- [PLUGIN_SYSTEM.md](./PLUGIN_SYSTEM.md) — Full plugin implementation guide
- [ARCHITECTURE.md](./ARCHITECTURE.md) — Overall bootstrap sequence and ConfigManager initialization
