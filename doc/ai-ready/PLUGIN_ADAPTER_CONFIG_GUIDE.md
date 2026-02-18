# Plugin and Adapter Configuration Guide for AI Agents

This guide explains how to properly implement configuration for plugins and adapters in the moose_core framework.

## Overview

The framework provides a three-tier configuration system:
1. **environment.json** - User-provided configuration (highest priority)
2. **Plugin/Adapter Defaults** - Defined in code via `getDefaultSettings()`
3. **Fallback Values** - Provided when calling `ConfigManager.get()`

## Plugin Configuration

### Step 1: Define Configuration Schema

Every plugin should define its configuration schema using JSON Schema:

```dart
class MyPlugin extends FeaturePlugin {
  @override
  String get name => 'my_plugin';

  @override
  String get version => '1.0.0';

  @override
  Map<String, dynamic> get configSchema => {
    'type': 'object',
    'properties': {
      'cache': {
        'type': 'object',
        'properties': {
          'ttl': {
            'type': 'integer',
            'minimum': 0,
            'description': 'Cache time-to-live in seconds',
          },
          'enabled': {
            'type': 'boolean',
            'description': 'Enable caching',
          },
        },
      },
      'display': {
        'type': 'object',
        'properties': {
          'itemsPerPage': {
            'type': 'integer',
            'minimum': 1,
            'description': 'Items per page',
          },
          'showImages': {
            'type': 'boolean',
            'description': 'Show images',
          },
        },
      },
    },
  };
}
```

### Step 2: Provide Default Settings

Implement `getDefaultSettings()` to provide sensible defaults:

```dart
@override
Map<String, dynamic> getDefaultSettings() {
  return {
    'cache': {
      'ttl': 300,
      'enabled': true,
    },
    'display': {
      'itemsPerPage': 20,
      'showImages': true,
    },
  };
}
```

### Step 3: Access Configuration in Plugin Code

Use ConfigManager to access settings with automatic fallback:

```dart
class MyPlugin extends FeaturePlugin {
  void someMethod() {
    final configManager = ConfigManager();

    // Access plugin settings - falls back to getDefaultSettings() if not in environment.json
    final ttl = configManager.get('plugins:my_plugin:settings:cache:ttl');
    final itemsPerPage = configManager.get('plugins:my_plugin:settings:display:itemsPerPage');

    // With explicit fallback
    final enabled = configManager.get(
      'plugins:my_plugin:settings:cache:enabled',
      defaultValue: true,
    );
  }
}
```

### Configuration Path Format for Plugins

Plugin settings use the path format:
```
plugins:{plugin_name}:settings:{nested:path:to:value}
```

Examples:
- `plugins:products:settings:cache:productsTTL`
- `plugins:products:settings:display:itemsPerPage`
- `plugins:blog:settings:filters:latest:perPage`

### How Defaults Are Registered

The `PluginRegistry` automatically registers your defaults during plugin registration:

```dart
Future<void> registerPlugin(FeaturePlugin Function() factory) async {
  final plugin = factory();

  // Automatically registers defaults
  final defaults = plugin.getDefaultSettings();
  if (defaults.isNotEmpty) {
    _configManager.registerPluginDefaults(plugin.name, defaults);
  }

  // ... rest of registration
}
```

**Important**: You don't need to manually register defaults - it happens automatically!

## Adapter Configuration

### Step 1: Provide Default Settings

Override `getDefaultSettings()` in your adapter:

```dart
class MyBackendAdapter extends BackendAdapter {
  @override
  String get name => 'my_backend';

  @override
  Map<String, dynamic> getDefaultSettings() {
    return {
      'baseUrl': 'https://api.example.com',
      'apiVersion': 'v1',
      'timeout': 30,
      'retries': 3,
      'enableLogging': false,
    };
  }
}
```

### Step 2: Access Configuration in Adapter Code

```dart
class MyBackendAdapter extends BackendAdapter {
  late final String _baseUrl;
  late final int _timeout;

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    // Config is already validated against configSchema before this is called.
    // Values in config come from environment.json (or getDefaultSettings() fallback).
    _baseUrl = config['baseUrl'] as String;
    _timeout = config['timeout'] as int? ?? 30;

    // Alternatively, access via ConfigManager (same values):
    // _baseUrl = ConfigManager().get('adapters:my_backend:baseUrl');
    // _timeout = ConfigManager().get('adapters:my_backend:timeout');
  }
}
```

### Configuration Path Format for Adapters

Adapter settings use the path format:
```
adapters:{adapter_name}:{setting_key}
```

Examples:
- `adapters:shopify:apiVersion`
- `adapters:judgeme:apiVersion`
- `adapters:onesignal:debug`

### How Defaults Are Registered

The `AdapterRegistry` automatically registers your defaults during adapter registration:

```dart
// Inside AdapterRegistry.registerAdapter():
Future<void> registerAdapter(dynamic Function() factory, {bool autoInitialize = true}) async {
  final adapter = factory() as BackendAdapter;

  // If autoInitialize, calls adapter.initializeFromConfig() which validates config
  // and then calls adapter.initialize(config)
  if (autoInitialize) await adapter.initializeFromConfig();

  // Automatically registers defaults from getDefaultSettings()
  final defaults = adapter.getDefaultSettings();
  if (defaults.isNotEmpty) {
    ConfigManager().registerAdapterDefaults(adapter.name, defaults);
  }

  // ... extract and register all repositories
}
```

**Important**: You don't need to manually register defaults - it happens automatically!

## User Configuration (environment.json)

Users can override any default value in `environment.json`:

```json
{
  "plugins": {
    "my_plugin": {
      "active": true,
      "settings": {
        "cache": {
          "ttl": 600,
          "enabled": false
        },
        "display": {
          "itemsPerPage": 50
        }
      }
    },
    "blog": {
      "active": true,
      "settings": {
        "filters": {
          "latest": {
            "perPage": 20,
            "sortBy": "modified"
          }
        }
      }
    }
  },
  "adapters": {
    "shopify": {
      "apiVersion": "2024-07"
    },
    "onesignal": {
      "debug": true,
      "promptForPermission": false
    }
  }
}
```

## Configuration Fallback Flow

When `ConfigManager.get('plugins:my_plugin:settings:cache:ttl')` is called:

1. **Check environment.json**: Is `plugins.my_plugin.settings.cache.ttl` defined?
   - If YES → return that value
   - If NO → continue to step 2

2. **Check Plugin Defaults**: Is there a registered default for `my_plugin` with a `cache.ttl` value?
   - If YES → return that value
   - If NO → continue to step 3

3. **Use Fallback**: Return the `defaultValue` parameter passed to `get()`
   - If no `defaultValue` provided → return `null`

## Best Practices

### 1. Always Provide Defaults

```dart
// ✅ GOOD - Provides comprehensive defaults
@override
Map<String, dynamic> getDefaultSettings() {
  return {
    'cache': {
      'ttl': 300,
      'enabled': true,
    },
    'display': {
      'itemsPerPage': 20,
      'showImages': true,
    },
  };
}

// ❌ BAD - Empty defaults force users to configure everything
@override
Map<String, dynamic> getDefaultSettings() => {};
```

### 2. Use Descriptive Schema Descriptions

```dart
// ✅ GOOD - Clear descriptions
'ttl': {
  'type': 'integer',
  'minimum': 0,
  'description': 'Cache time-to-live in seconds',
}

// ❌ BAD - No description
'ttl': {
  'type': 'integer',
}
```

### 3. Use the Correct Configuration Path

```dart
// ✅ GOOD - Correct plugin path
ConfigManager().get('plugins:my_plugin:settings:cache:ttl')

// ❌ BAD - Missing 'settings' segment
ConfigManager().get('plugins:my_plugin:cache:ttl')

// ✅ GOOD - Correct adapter path
ConfigManager().get('adapters:shopify:apiVersion')

// ❌ BAD - Incorrect path format
ConfigManager().get('adapters:shopify:settings:apiVersion')
```

### 4. Choose Sensible Defaults

```dart
// ✅ GOOD - Safe, reasonable defaults
@override
Map<String, dynamic> getDefaultSettings() {
  return {
    'cache': {
      'ttl': 300,          // 5 minutes - reasonable
      'enabled': true,     // Opt-out rather than opt-in
    },
    'retries': 3,          // Enough to handle transient failures
    'timeout': 30,         // Reasonable timeout
  };
}

// ❌ BAD - Unsafe or extreme defaults
@override
Map<String, dynamic> getDefaultSettings() {
  return {
    'cache': {
      'ttl': 86400000,     // 1000 days - too long
      'enabled': false,    // Opt-in - users might not know to enable
    },
    'retries': 100,        // Excessive
    'timeout': 1,          // Too short
  };
}
```

### 5. Document Configuration in Plugin/Adapter Comments

```dart
/// My Plugin - Provides awesome functionality
///
/// ## Configuration
/// ```json
/// {
///   "plugins": {
///     "my_plugin": {
///       "settings": {
///         "cache": {
///           "ttl": 300,
///           "enabled": true
///         }
///       }
///     }
///   }
/// }
/// ```
class MyPlugin extends FeaturePlugin {
  // ...
}
```

## Examples

### Example 1: Products Plugin

```dart
class ProductsPlugin extends FeaturePlugin {
  @override
  String get name => 'products';

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
            'description': 'Number of items per page',
          },
          'showOutOfStock': {
            'type': 'boolean',
            'description': 'Show out of stock products',
          },
        },
      },
    },
  };

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

  void loadProducts() {
    final configManager = ConfigManager();
    final ttl = configManager.get('plugins:products:settings:cache:productsTTL');
    final perPage = configManager.get('plugins:products:settings:display:itemsPerPage');

    // Use ttl and perPage...
  }
}
```

### Example 2: Blog Plugin with Filters

```dart
class BlogPlugin extends FeaturePlugin {
  @override
  String get name => 'blog';

  @override
  Map<String, dynamic> get configSchema => {
    'type': 'object',
    'properties': {
      'filters': {
        'type': 'object',
        'description': 'Post filter configurations',
        'patternProperties': {
          '^.*\$': {
            'type': 'object',
            'properties': {
              'postType': {'type': 'string'},
              'sortBy': {
                'type': 'string',
                'enum': ['date', 'title', 'modified'],
              },
              'sortOrder': {
                'type': 'string',
                'enum': ['asc', 'desc'],
              },
              'perPage': {
                'type': 'integer',
                'minimum': 1,
              },
            },
          },
        },
      },
    },
  };

  @override
  Map<String, dynamic> getDefaultSettings() {
    return {
      'filters': {
        'latest': {
          'postType': 'post',
          'sortBy': 'date',
          'sortOrder': 'desc',
          'status': 'publish',
          'perPage': 10,
        },
        'featured': {
          'postType': 'post',
          'categoryId': 'featured',
          'sortBy': 'date',
          'sortOrder': 'desc',
          'perPage': 6,
        },
      },
    };
  }

  Map<String, dynamic> getFilterConfig(String filterKey) {
    final configManager = ConfigManager();
    return configManager.get(
      'plugins:blog:settings:filters:$filterKey',
      defaultValue: {},
    );
  }
}
```

### Example 3: Shopify Adapter

```dart
class ShopifyAdapter extends BackendAdapter {
  @override
  String get name => 'shopify';

  @override
  Map<String, dynamic> getDefaultSettings() {
    return {
      'apiVersion': '2024-01',
    };
  }

  @override
  Map<String, dynamic> get configSchema => {
    'type': 'object',
    'required': ['storeUrl', 'storefrontAccessToken'],
    'properties': {
      'storeUrl': {'type': 'string', 'description': 'Shopify store domain'},
      'storefrontAccessToken': {'type': 'string', 'description': 'Storefront API token'},
      'apiVersion': {'type': 'string', 'description': 'API version (e.g., 2024-01)'},
    },
  };

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    final apiVersion = config['apiVersion'] as String? ??
        ConfigManager().get('adapters:shopify:apiVersion');

    // Use apiVersion...
  }
}
```

## Summary for AI Agents

When creating or modifying plugins:
1. Add `configSchema` getter with JSON Schema definition
2. Add `getDefaultSettings()` method with sensible defaults
3. Access config using `ConfigManager().get('plugins:{name}:settings:{path}')`
4. Defaults are auto-registered - no manual registration needed
5. Document configuration in plugin class comments

When creating or modifying adapters:
1. Add `configSchema` getter with JSON Schema definition (REQUIRED - abstract in BackendAdapter)
2. Add `getDefaultSettings()` method with sensible defaults
3. Implement `initialize(Map<String, dynamic> config)` - config is pre-validated and merged with defaults
4. Defaults are auto-registered by AdapterRegistry - no manual registration needed
5. Use `ConfigManager().get('adapters:{name}:{key}')` as an alternative way to access config

The system handles the rest automatically!
