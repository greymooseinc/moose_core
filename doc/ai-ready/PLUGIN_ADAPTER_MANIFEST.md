# Plugin and Adapter Manifest (moose.manifest.json)

## Overview

Every plugin package and adapter package that is distributed separately from the host app must include a `moose.manifest.json` file at the root of its `lib/` directory structure. This file tells the host app how to import and instantiate the plugin or adapter, and which Dart packages it depends on.

**Important:** `moose.manifest.json` is a developer/tooling convention. It is **not** parsed by `moose_core` at runtime. The Dart class it describes (`class` field) must still be instantiated and passed to `MooseBootstrapper.run()` manually by the host app. The manifest exists so tooling, AI agents, and developers can understand what a package provides without reading its source.

---

## File Location

| Package type | Path |
|---|---|
| Plugin | `lib/plugins/<plugin_name>/moose.manifest.json` |
| Adapter | `lib/adapters/<adapter_name>/moose.manifest.json` |

Examples:
```
lib/plugins/products/moose.manifest.json
lib/plugins/cart/moose.manifest.json
lib/adapters/woocommerce/moose.manifest.json
lib/adapters/shopify/moose.manifest.json
```

The directory name should match the `name` field in the manifest.

---

## Schema

```json
{
  "name": "<snake_case identifier>",
  "version": "<semver>",
  "import": ["<relative dart file path>"],
  "class": "<PascalCase class name>",
  "dependencies": {
    "<package>": "<version constraint or git object>"
  }
}
```

All five fields are required.

---

## Field Reference

### `name`

**Type:** string
**Format:** `snake_case`

Unique identifier for the plugin or adapter. Must match the plugin's `name` getter (`String get name => 'products'`) for plugins, or the adapter's `name` getter for adapters.

```json
"name": "products"
"name": "cart"
"name": "woocommerce"
"name": "recently_viewed"
```

Rules:
- Lowercase letters, digits, and underscores only
- No hyphens, spaces, or PascalCase
- Must match the `name` getter on the Dart class

---

### `version`

**Type:** string
**Format:** Semantic versioning — `MAJOR.MINOR.PATCH`

```json
"version": "1.0.0"
"version": "2.1.3"
```

Use the same version string returned by the Dart class's `version` getter.

---

### `import`

**Type:** array of strings

Relative paths to the Dart files that must be imported for the class in `class` to be available. Paths are relative to the `lib/` directory and must start with `./`.

```json
"import": [
  "./plugins/products/products_plugin.dart"
]
```

```json
"import": [
  "./adapters/woocommerce/woocommerce_adapter.dart"
]
```

Multiple imports are rare but allowed when the entry class is spread across files:

```json
"import": [
  "./plugins/analytics/analytics_plugin.dart",
  "./plugins/analytics/analytics_models.dart"
]
```

Rules:
- Must be an array (not a string)
- Must start with `./`
- Must end with `.dart`
- All listed files must exist in the package

---

### `class`

**Type:** string
**Format:** `PascalCase`

The name of the Dart class to instantiate. For plugins, this class must extend `FeaturePlugin`. For adapters, it must extend `BackendAdapter`.

```json
"class": "ProductsPlugin"
"class": "CartPlugin"
"class": "WooCommerceAdapter"
"class": "ShopifyAdapter"
```

The class name must match exactly (case-sensitive) with the class definition in the imported file.

---

### `dependencies`

**Type:** object (key-value map)

Packages that this plugin or adapter requires. The format mirrors `pubspec.yaml` dependency declarations.

Every plugin and adapter must include `moose_core`:

```json
"dependencies": {
  "moose_core": {
    "git": {
      "url": "https://github.com/greymooseinc/moose_core.git",
      "ref": "main"
    }
  }
}
```

For pub.dev packages, use caret version constraints to allow compatible updates:

```json
"dependencies": {
  "moose_core": { "git": { "url": "...", "ref": "main" } },
  "flutter_bloc": "^9.1.0",
  "equatable": "^2.0.5",
  "dio": "^5.4.0"
}
```

Only list direct dependencies — do not list transitive dependencies that come in through other packages.

---

## Complete Examples

### Plugin — minimal (no extra dependencies)

**File:** `lib/plugins/analytics/moose.manifest.json`

```json
{
  "name": "analytics",
  "version": "1.0.0",
  "import": [
    "./plugins/analytics/analytics_plugin.dart"
  ],
  "class": "AnalyticsPlugin",
  "dependencies": {
    "moose_core": {
      "git": {
        "url": "https://github.com/greymooseinc/moose_core.git",
        "ref": "main"
      }
    }
  }
}
```

### Plugin — with BLoC and UI packages

**File:** `lib/plugins/products/moose.manifest.json`

```json
{
  "name": "products",
  "version": "1.0.0",
  "import": [
    "./plugins/products/products_plugin.dart"
  ],
  "class": "ProductsPlugin",
  "dependencies": {
    "moose_core": {
      "git": {
        "url": "https://github.com/greymooseinc/moose_core.git",
        "ref": "main"
      }
    },
    "flutter_bloc": "^9.1.0",
    "equatable": "^2.0.5",
    "cached_network_image": "^3.3.0"
  }
}
```

### Adapter — REST API backend

**File:** `lib/adapters/woocommerce/moose.manifest.json`

```json
{
  "name": "woocommerce",
  "version": "1.0.0",
  "import": [
    "./adapters/woocommerce/woocommerce_adapter.dart"
  ],
  "class": "WooCommerceAdapter",
  "dependencies": {
    "moose_core": {
      "git": {
        "url": "https://github.com/greymooseinc/moose_core.git",
        "ref": "main"
      }
    },
    "dio": "^5.4.0"
  }
}
```

### Adapter — third-party SDK

**File:** `lib/adapters/onesignal/moose.manifest.json`

```json
{
  "name": "onesignal",
  "version": "1.0.0",
  "import": [
    "./adapters/onesignal/onesignal_adapter.dart"
  ],
  "class": "OneSignalAdapter",
  "dependencies": {
    "moose_core": {
      "git": {
        "url": "https://github.com/greymooseinc/moose_core.git",
        "ref": "main"
      }
    },
    "onesignal_flutter": "^5.2.5"
  }
}
```

---

## Directory Structure

A well-structured plugin package looks like:

```
lib/
└── plugins/
    └── products/
        ├── moose.manifest.json          ← manifest at plugin root
        ├── products_plugin.dart         ← FeaturePlugin subclass
        ├── logic/
        │   ├── products_bloc.dart
        │   └── products_state.dart
        ├── presentation/
        │   ├── sections/
        │   │   ├── featured_products_section.dart
        │   │   └── category_grid_section.dart
        │   └── screens/
        │       └── product_detail_screen.dart
        └── repositories/               ← optional concrete repos if bundled
            └── mock_products_repository.dart
```

A well-structured adapter package looks like:

```
lib/
└── adapters/
    └── woocommerce/
        ├── moose.manifest.json          ← manifest at adapter root
        ├── woocommerce_adapter.dart     ← BackendAdapter subclass
        ├── client/
        │   └── woo_api_client.dart
        └── repositories/
            ├── woo_products_repository.dart
            ├── woo_cart_repository.dart
            └── woo_auth_repository.dart
```

---

## Relationship to Dart Classes

The manifest `class` field maps directly to the entry class in the package. The constraints the Dart class must satisfy:

### Plugin class requirements

```dart
// class must match "class" field in manifest
class ProductsPlugin extends FeaturePlugin {
  // name must match "name" field in manifest
  @override
  String get name => 'products';

  // version must match "version" field in manifest
  @override
  String get version => '1.0.0';

  @override
  void onRegister() { /* register widgets, addons, routes */ }

  @override
  Future<void> onInit() async { /* async setup */ }
}
```

### Adapter class requirements

```dart
// class must match "class" field in manifest
class WooCommerceAdapter extends BackendAdapter {
  // name must match "name" field in manifest
  @override
  String get name => 'woocommerce';

  // version must match "version" field in manifest
  @override
  String get version => '1.0.0';

  // configSchema is required — no default, compile error if omitted
  @override
  Map<String, dynamic> get configSchema => { /* JSON Schema */ };

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    // create API client, register repository factories
  }
}
```

See [ADAPTER_SYSTEM.md](./ADAPTER_SYSTEM.md) for the full adapter implementation guide.
See [PLUGIN_SYSTEM.md](./PLUGIN_SYSTEM.md) for the full plugin implementation guide.

---

## Checklist for New Plugins / Adapters

Before publishing or distributing a plugin or adapter, verify:

- [ ] `moose.manifest.json` exists at `lib/plugins/<name>/` or `lib/adapters/<name>/`
- [ ] `name` matches the directory name and the `name` getter on the Dart class
- [ ] `version` matches the `version` getter on the Dart class
- [ ] `import` paths start with `./`, end with `.dart`, and point to existing files
- [ ] `class` name exactly matches the Dart class name (case-sensitive)
- [ ] `class` extends `FeaturePlugin` (plugin) or `BackendAdapter` (adapter)
- [ ] `dependencies` includes `moose_core` with the git dependency format
- [ ] All additional dependencies use caret version constraints
- [ ] No transitive dependencies listed
- [ ] JSON is valid (no trailing commas, proper string quoting)

---

## Related

- [ADAPTER_SYSTEM.md](./ADAPTER_SYSTEM.md) — Full guide to implementing `BackendAdapter` and repositories
- [PLUGIN_SYSTEM.md](./PLUGIN_SYSTEM.md) — Full guide to implementing `FeaturePlugin`
- [PLUGIN_ADAPTER_CONFIG_GUIDE.md](./PLUGIN_ADAPTER_CONFIG_GUIDE.md) — `environment.json` configuration reference
