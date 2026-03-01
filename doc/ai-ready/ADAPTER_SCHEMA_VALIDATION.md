# Adapter Schema Validation

> JSON schema validation for backend adapter configurations in moose_core

## Table of Contents
- [Overview](#overview)
- [How Validation Works](#how-validation-works)
- [configSchema Reference](#configschema-reference)
- [getDefaultSettings and configSchema](#getdefaultsettings-and-configschema)
- [Schema Definition Guide](#schema-definition-guide)
- [Complete Adapter Examples](#complete-adapter-examples)
- [Error Messages](#error-messages)
- [Manual Validation in Tests](#manual-validation-in-tests)
- [Troubleshooting](#troubleshooting)
- [Related Documentation](#related-documentation)

---

## Overview

Every `BackendAdapter` subclass must define a `configSchema` getter that describes its configuration surface as a [JSON Schema](https://json-schema.org/) object. The framework validates the adapter's section of `environment.json` against this schema automatically during bootstrap — before `initialize()` is ever called.

**What this gives you:**
- Configuration errors are caught at startup, not at the first API call.
- `initialize(config)` receives a map that is already guaranteed valid — no manual `if (field == null)` guards needed.
- The schema doubles as machine-readable documentation for the adapter's configuration.
- Detailed error messages tell the caller exactly which fields are missing or wrong.

---

## How Validation Works

### Call chain during bootstrap

```
MooseBootstrapper.run(adapters: [MyAdapter()])
  └─ adapterRegistry.registerAdapter(() => adapter)
       ├─ adapter.appContext = appContext          // inject scoped context
       ├─ adapter.initializeFromConfig(            // called automatically (autoInitialize: true)
       │    configManager: appContext.configManager
       │  )
       │    ├─ reads configManager.get('adapters')            // full adapters block
       │    ├─ reads adaptersConfig[adapter.name]             // this adapter's config map
       │    ├─ adapter.validateConfig(adapterConfig)          // ← schema validation here
       │    │    └─ throws AdapterConfigValidationException   // if invalid
       │    └─ adapter.initialize(adapterConfig)              // ← only reached if valid
       └─ configManager.registerAdapterDefaults(              // defaults registered AFTER initialize
            adapter.name, adapter.getDefaultSettings()
          )
```

**Important ordering detail:** `getDefaultSettings()` values are registered in `ConfigManager` *after* `initialize()` completes. The `config` map passed to `initialize()` is the raw map from `environment.json` — it does not include defaults. If an optional field is absent from `environment.json`, your `initialize()` must handle `null` for that field (or set a `default` in `configSchema` — see below).

### What `validateConfig()` does

`validateConfig(Map<String, dynamic> config)` is a public method on `BackendAdapter`. It is called internally by `initializeFromConfig()` but you can also call it directly in tests.

```dart
// Called automatically — you never need to call this yourself in production code
void validateConfig(Map<String, dynamic> config) {
  final schema = JsonSchema.create(configSchema);
  final result = schema.validate(config);
  if (!result.isValid) {
    throw AdapterConfigValidationException(...);
  }
}
```

The validator uses the `json_schema` package (`>=5.2.2 <6.0.0`).

### environment.json structure required

```json
{
  "adapters": {
    "<adapter.name>": {
      // fields validated against configSchema
    }
  }
}
```

The key under `"adapters"` must exactly match the adapter's `name` getter. If the key is absent, `initializeFromConfig()` throws before validation even runs.

---

## configSchema Reference

`configSchema` is an **abstract getter** — every `BackendAdapter` subclass must override it. Omitting it is a compile error.

```dart
@override
Map<String, dynamic> get configSchema => {
  'type': 'object',           // always 'object' for adapter configs
  'required': [...],          // list of field names that must be present
  'properties': { ... },      // field definitions
  'additionalProperties': false, // recommended — rejects unknown keys
};
```

### Field definition properties

| Property | Purpose | Example |
|---|---|---|
| `type` | JSON type of the field | `'string'`, `'integer'`, `'number'`, `'boolean'`, `'array'`, `'object'` |
| `description` | Human/AI-readable explanation (appears in error messages) | `'API authentication key'` |
| `minLength` / `maxLength` | String length bounds | `'minLength': 1` |
| `minimum` / `maximum` | Numeric bounds (inclusive) | `'minimum': 0` |
| `format` | Semantic format validation | `'uri'`, `'email'`, `'date-time'` |
| `pattern` | Regex the value must match | `r'^ck_[a-zA-Z0-9]{40}$'` |
| `enum` | Whitelist of allowed values | `['wc/v3', 'wc/v2']` |
| `default` | Value hint for documentation (does NOT affect runtime defaults — use `getDefaultSettings()` for that) | `30` |

### Full template

```dart
@override
Map<String, dynamic> get configSchema => {
  'type': 'object',
  'required': ['baseUrl', 'apiKey'],
  'properties': {
    'baseUrl': {
      'type': 'string',
      'format': 'uri',
      'description': 'Base URL of the backend API',
    },
    'apiKey': {
      'type': 'string',
      'minLength': 1,
      'description': 'API authentication key',
    },
    'timeout': {
      'type': 'integer',
      'minimum': 0,
      'description': 'Request timeout in seconds (default: 30)',
    },
    'enableLogging': {
      'type': 'boolean',
      'description': 'Enable verbose request logging',
    },
    'apiVersion': {
      'type': 'string',
      'enum': ['v1', 'v2', 'v3'],
      'description': 'API version to use',
    },
  },
  'additionalProperties': false,
};
```

---

## getDefaultSettings and configSchema

These two serve different purposes and operate at different points in the lifecycle:

| | `configSchema` | `getDefaultSettings()` |
|---|---|---|
| **Purpose** | Validates the environment.json map before `initialize()` | Provides fallback values for ConfigManager lookups after bootstrap |
| **When used** | During `initializeFromConfig()` — before `initialize()` | After `initialize()` — registered in ConfigManager post-init |
| **Affects `initialize(config)`?** | Yes — invalid config throws before `initialize()` runs | No — `initialize()` receives the raw environment.json map |
| **Where to read** | n/a — validated automatically | Via `configManager.get('adapters:<name>:<key>')` after bootstrap |

**Practical rule:** If an optional field can be absent from `environment.json` and you need to handle it inside `initialize()`, use a null-aware cast:

```dart
@override
Future<void> initialize(Map<String, dynamic> config) async {
  final timeout = config['timeout'] as int? ?? 30; // null-safe, 30 is the code default
  // ...
}
```

`getDefaultSettings()` is for values that other parts of the app (plugins, sections) read from `ConfigManager` after bootstrap. It does not pre-fill `initialize(config)`.

---

## Schema Definition Guide

### Basic types

```dart
'properties': {
  // String
  'apiKey': {
    'type': 'string',
    'minLength': 1,       // rejects empty string
    'description': 'API authentication key',
  },
  // Integer
  'timeout': {
    'type': 'integer',
    'minimum': 0,
    'description': 'Request timeout in seconds',
  },
  // Number (float or int)
  'retryDelay': {
    'type': 'number',
    'minimum': 0.0,
    'description': 'Delay between retries in seconds',
  },
  // Boolean
  'enableLogging': {
    'type': 'boolean',
    'description': 'Enable verbose logging',
  },
}
```

### Format validation

```dart
'properties': {
  'baseUrl': {
    'type': 'string',
    'format': 'uri',       // validates https://... etc.
    'description': 'API base URL',
  },
  'contactEmail': {
    'type': 'string',
    'format': 'email',
    'description': 'Support contact email',
  },
}
```

### Pattern matching

```dart
'properties': {
  'consumerKey': {
    'type': 'string',
    'pattern': r'^ck_[a-zA-Z0-9]{40}$',
    'description': 'WooCommerce consumer key',
  },
  'appId': {
    'type': 'string',
    'pattern': r'^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$',
    'description': 'App ID in UUID format',
  },
  'apiVersion': {
    'type': 'string',
    'pattern': r'^\d{4}-\d{2}$',
    'description': 'API version in YYYY-MM format',
  },
  'shopDomain': {
    'type': 'string',
    'pattern': r'^[a-zA-Z0-9][a-zA-Z0-9-]*\.myshopify\.com$',
    'description': 'Shopify store domain (e.g. mystore.myshopify.com)',
  },
}
```

### Enum (whitelist)

```dart
'apiVersion': {
  'type': 'string',
  'enum': ['wc/v3', 'wc/v2'],
  'description': 'WooCommerce REST API version',
},
```

### Nested objects

```dart
'rateLimiting': {
  'type': 'object',
  'properties': {
    'maxRequests': {'type': 'integer', 'minimum': 1},
    'windowSeconds': {'type': 'integer', 'minimum': 1},
  },
  'required': ['maxRequests', 'windowSeconds'],
  'description': 'Rate limiting configuration',
},
```

### Alternative requirements (anyOf)

Use when at least one of several optional fields must be provided:

```dart
{
  'type': 'object',
  'required': ['shopDomain'],
  'properties': {
    'shopDomain':      {'type': 'string'},
    'publicApiKey':    {'type': 'string'},
    'privateApiKey':   {'type': 'string'},
    'storefrontToken': {'type': 'string'},
  },
  'anyOf': [
    {'required': ['publicApiKey']},
    {'required': ['privateApiKey']},
    {'required': ['storefrontToken']},
  ],
}
```

`shopDomain` is always required AND exactly one of the key fields must be present.

### additionalProperties: false

Always include this in production schemas. It causes validation to reject any key in the config that isn't declared in `properties`, catching typos before they silently go unused:

```dart
'additionalProperties': false,
```

---

## Complete Adapter Examples

### WooCommerce adapter

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
        'description': 'WooCommerce store base URL',
      },
      'consumerKey': {
        'type': 'string',
        'minLength': 1,
        'pattern': r'^ck_[a-zA-Z0-9]{40}$',
        'description': 'WooCommerce REST API consumer key',
      },
      'consumerSecret': {
        'type': 'string',
        'minLength': 1,
        'pattern': r'^cs_[a-zA-Z0-9]{40}$',
        'description': 'WooCommerce REST API consumer secret',
      },
      'apiVersion': {
        'type': 'string',
        'enum': ['wc/v3', 'wc/v2'],
        'description': 'WooCommerce REST API version',
      },
      'timeout': {
        'type': 'integer',
        'minimum': 0,
        'description': 'Request timeout in seconds',
      },
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
    // config is guaranteed valid — required fields present, types correct
    _client = WooApiClient(
      baseUrl:        config['baseUrl']        as String,
      consumerKey:    config['consumerKey']    as String,
      consumerSecret: config['consumerSecret'] as String,
      apiVersion:     config['apiVersion']     as String? ?? 'wc/v3',
      timeout:        Duration(seconds: config['timeout'] as int? ?? 30),
    );
    _registerRepositories();
  }
}
```

### Shopify adapter

```dart
class ShopifyAdapter extends BackendAdapter {
  @override
  String get name => 'shopify';

  @override
  String get version => '1.0.0';

  @override
  Map<String, dynamic> get configSchema => {
    'type': 'object',
    'required': ['storeUrl', 'storefrontAccessToken'],
    'properties': {
      'storeUrl': {
        'type': 'string',
        'minLength': 1,
        'pattern': r'^[a-zA-Z0-9][a-zA-Z0-9-]*\.myshopify\.com$',
        'description': 'Shopify store URL (e.g. mystore.myshopify.com)',
      },
      'storefrontAccessToken': {
        'type': 'string',
        'minLength': 1,
        'description': 'Shopify Storefront API access token',
      },
      'apiVersion': {
        'type': 'string',
        'pattern': r'^\d{4}-\d{2}$',
        'description': 'Shopify API version in YYYY-MM format',
      },
    },
    'additionalProperties': false,
  };

  @override
  Map<String, dynamic> getDefaultSettings() => {
    'apiVersion': '2024-01',
  };

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    _client = ShopifyClient(
      storeUrl:    config['storeUrl']              as String,
      accessToken: config['storefrontAccessToken'] as String,
      apiVersion:  config['apiVersion']            as String? ?? '2024-01',
    );
    _registerRepositories();
  }
}
```

### Push notification adapter (UUID app ID)

```dart
class OneSignalAdapter extends BackendAdapter {
  @override
  String get name => 'onesignal';

  @override
  String get version => '1.0.0';

  @override
  Map<String, dynamic> get configSchema => {
    'type': 'object',
    'required': ['appId'],
    'properties': {
      'appId': {
        'type': 'string',
        'pattern': r'^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$',
        'description': 'OneSignal App ID (UUID format)',
      },
      'debug': {
        'type': 'boolean',
        'description': 'Enable verbose SDK logging',
      },
    },
    'additionalProperties': false,
  };

  @override
  Map<String, dynamic> getDefaultSettings() => {'debug': false};

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    await OneSignal.shared.setAppId(config['appId'] as String);
    if (config['debug'] as bool? ?? false) {
      OneSignal.shared.setLogLevel(OSLogLevel.verbose, OSLogLevel.none);
    }
    registerRepositoryFactory<PushNotificationRepository>(
      () => OneSignalNotificationRepository(),
    );
  }
}
```

---

## Error Messages

When validation fails, `AdapterConfigValidationException` is thrown with a message in this format:

```
AdapterConfigValidationException: Configuration validation failed for adapter "woocommerce":
  - root: The object must have a required property 'consumerKey'
  - root: The object must have a required property 'consumerSecret'

Schema: Required fields: baseUrl, consumerKey, consumerSecret
Available fields:
  - baseUrl (string) [REQUIRED]: WooCommerce store base URL
  - consumerKey (string) [REQUIRED]: WooCommerce REST API consumer key
  - consumerSecret (string) [REQUIRED]: WooCommerce REST API consumer secret
  - apiVersion (string): WooCommerce REST API version
  - timeout (integer): Request timeout in seconds

Provided config: {baseUrl: https://mystore.example.com}
```

The error message includes:
- The adapter name
- Every failing constraint and which field caused it
- The full schema summary (required vs optional, types, descriptions)
- The exact config map that was rejected

`AdapterConfigValidationException` is exported from `package:moose_core/adapters.dart` — catch it by type in tests and error handling:

```dart
try {
  await MooseBootstrapper(appContext: ctx).run(config: config, adapters: [MyAdapter()]);
} catch (e) {
  if (e is AdapterConfigValidationException) {
    // schema violation at startup
  }
}
```

---

## Manual Validation in Tests

`validateConfig()` is public and can be called directly without going through the full bootstrap. This is useful for unit-testing the schema in isolation.

```dart
class MyAdapter extends BackendAdapter {
  @override
  String get name => 'myadapter';

  @override
  String get version => '1.0.0';

  @override
  Map<String, dynamic> get configSchema => {
    'type': 'object',
    'required': ['apiKey', 'baseUrl'],
    'properties': {
      'apiKey':   {'type': 'string', 'minLength': 10, 'description': 'API key'},
      'baseUrl':  {'type': 'string', 'format': 'uri', 'description': 'API base URL'},
      'timeout':  {'type': 'integer', 'minimum': 0,   'description': 'Timeout in seconds'},
    },
    'additionalProperties': false,
  };

  @override
  Future<void> initialize(Map<String, dynamic> config) async { /* ... */ }
}

void main() {
  group('MyAdapter schema', () {
    late MyAdapter adapter;

    setUp(() => adapter = MyAdapter());

    test('accepts valid config', () {
      expect(
        () => adapter.validateConfig({
          'apiKey': 'valid-api-key-1234',
          'baseUrl': 'https://api.example.com',
        }),
        returnsNormally,
      );
    });

    test('optional timeout can be omitted', () {
      expect(
        () => adapter.validateConfig({
          'apiKey': 'valid-api-key-1234',
          'baseUrl': 'https://api.example.com',
        }),
        returnsNormally,
      );
    });

    test('rejects missing required field', () {
      expect(
        () => adapter.validateConfig({'baseUrl': 'https://api.example.com'}),
        throwsA(isA<AdapterConfigValidationException>()),
      );
    });

    test('rejects wrong type', () {
      expect(
        () => adapter.validateConfig({
          'apiKey': 'valid-api-key-1234',
          'baseUrl': 'https://api.example.com',
          'timeout': 'thirty', // should be integer
        }),
        throwsA(isA<AdapterConfigValidationException>()),
      );
    });

    test('rejects value below minimum', () {
      expect(
        () => adapter.validateConfig({
          'apiKey': 'valid-api-key-1234',
          'baseUrl': 'https://api.example.com',
          'timeout': -1,
        }),
        throwsA(isA<AdapterConfigValidationException>()),
      );
    });

    test('rejects additional properties', () {
      expect(
        () => adapter.validateConfig({
          'apiKey':  'valid-api-key-1234',
          'baseUrl': 'https://api.example.com',
          'unknown': 'value',
        }),
        throwsA(isA<AdapterConfigValidationException>()),
      );
    });

    test('rejects string shorter than minLength', () {
      expect(
        () => adapter.validateConfig({
          'apiKey':  'short',   // < 10 chars
          'baseUrl': 'https://api.example.com',
        }),
        throwsA(isA<AdapterConfigValidationException>()),
      );
    });

    test('error message includes adapter name and field list', () {
      try {
        adapter.validateConfig({});
        fail('Expected AdapterConfigValidationException');
      } on AdapterConfigValidationException catch (e) {
        expect(e.toString(), contains('"myadapter"'));
        expect(e.toString(), contains('Required fields'));
        expect(e.toString(), contains('apiKey'));
        expect(e.toString(), contains('Available fields'));
      }
    });

    test('boundary: accepts apiKey exactly at minLength (10 chars)', () {
      expect(
        () => adapter.validateConfig({
          'apiKey':  '1234567890',
          'baseUrl': 'https://api.example.com',
        }),
        returnsNormally,
      );
    });

    test('boundary: accepts timeout = 0 (at minimum)', () {
      expect(
        () => adapter.validateConfig({
          'apiKey':  'valid-api-key-1234',
          'baseUrl': 'https://api.example.com',
          'timeout': 0,
        }),
        returnsNormally,
      );
    });
  });
}
```

---

## Troubleshooting

### "No configuration found for adapter `<name>`"

`initializeFromConfig()` looks up `adapters.<adapter.name>` in `environment.json`. The key must exactly match `adapter.name`.

```json
// adapter.name returns 'woocommerce'
// environment.json must have:
{
  "adapters": {
    "woocommerce": { ... }   // ✅ exact match
  }
}
// NOT "WooCommerce" or "woo_commerce"
```

### "No adapters configuration found in environment.json"

The root `"adapters"` key is missing from the config map passed to `MooseBootstrapper.run(config:)`.

```json
{
  "adapters": {   // ← must be present at root level
    "myadapter": { ... }
  }
}
```

### "Additional properties not allowed"

The config map contains a key not declared in `properties`. Common causes:
1. A typo in environment.json (e.g. `"timeOut"` instead of `"timeout"`)
2. A field was removed from the schema but still present in config
3. The schema has `'additionalProperties': false` but the config has extra keys for a future feature

Fix: either add the field to `properties`, remove it from environment.json, or remove `'additionalProperties': false` if you want to allow arbitrary extra keys.

### "The object must have a required property `<field>`"

The field is in `required` but absent from the config. Check:
1. The key spelling in environment.json matches exactly (case-sensitive)
2. The field is nested correctly if the schema uses nested objects

### Pattern validation failing

```json
// Schema: pattern r'^ck_[a-zA-Z0-9]{40}$'
// Config:  "consumerKey": "ck_abc123"    ← too short, not 40 chars after ck_
// Config:  "storeUrl": "https://mystore.myshopify.com"  ← pattern expects no https://
```

Read the pattern carefully — many patterns expect a specific prefix/suffix or length. Add the `description` field to your schema to make the expected format explicit in error messages.

### `configSchema` compile error

`configSchema` is an **abstract getter** — it must be overridden in every concrete `BackendAdapter` subclass. There is no base implementation to fall back on. If you forget it, the Dart compiler will report a missing concrete implementation, not a runtime error.

```dart
// ❌ Compile error — missing override
class MyAdapter extends BackendAdapter {
  @override String get name => 'myadapter';
  @override String get version => '1.0.0';
  @override Future<void> initialize(Map<String, dynamic> config) async {}
  // configSchema not overridden → compile error
}

// ✅ Correct
class MyAdapter extends BackendAdapter {
  @override
  Map<String, dynamic> get configSchema => {
    'type': 'object',
    'properties': {},
  };
  // ...
}
```

---

## Common Pattern Reference

```dart
// UUID
'pattern': r'^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$'

// URL
'format': 'uri'

// Email
'format': 'email'

// Shopify domain (no https://)
'pattern': r'^[a-zA-Z0-9][a-zA-Z0-9-]*\.myshopify\.com$'

// Shopify API version (YYYY-MM)
'pattern': r'^\d{4}-\d{2}$'

// WooCommerce consumer key
'pattern': r'^ck_[a-zA-Z0-9]{40}$'

// WooCommerce consumer secret
'pattern': r'^cs_[a-zA-Z0-9]{40}$'

// Non-empty string
'minLength': 1

// Positive integer (including zero)
'minimum': 0

// Positive integer (excluding zero)
'minimum': 1
```

---

## Related Documentation

- [ADAPTER_SYSTEM.md](./ADAPTER_SYSTEM.md) — Full adapter implementation guide
- [PLUGIN_ADAPTER_CONFIG_GUIDE.md](./PLUGIN_ADAPTER_CONFIG_GUIDE.md) — Configuration deep-dive
- [ARCHITECTURE.md](./ARCHITECTURE.md) — Overall system architecture
- [ANTI_PATTERNS.md](./ANTI_PATTERNS.md) — Common mistakes to avoid

---

**Last Updated:** 2026-03-01
**Version:** 2.0.0
