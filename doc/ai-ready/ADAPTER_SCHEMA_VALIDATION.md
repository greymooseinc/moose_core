# Adapter Configuration Schema Validation

> Automatic JSON schema validation for backend adapter configurations

**Last Updated**: 2025-11-12
**Version**: 1.1.0

## Overview

The moose_core framework now includes automatic JSON schema validation for all backend adapter configurations. This ensures configuration errors are caught early with clear, actionable error messages.

## Features

- ✅ **Fail-Fast Validation**: Configuration errors detected before initialization
- ✅ **Type Safety**: Enforce correct data types for all configuration fields
- ✅ **Required Fields**: Automatically validate required configuration parameters
- ✅ **Format Validation**: Validate URLs, UUIDs, patterns, and other formats
- ✅ **Clear Error Messages**: Detailed error messages with schema information
- ✅ **No Manual Validation**: Remove manual `if (field == null)` checks from adapters
- ✅ **JSON Schema Standard**: Uses industry-standard JSON Schema specification

## How It Works

### 1. Define Schema in Adapter

Every adapter must override the `configSchema` getter to define its configuration requirements:

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
      'apiKey': {
        'type': 'string',
        'minLength': 10,
        'description': 'API authentication key',
      },
      'baseUrl': {
        'type': 'string',
        'format': 'uri',
        'description': 'Base URL of the API',
      },
      'timeout': {
        'type': 'integer',
        'minimum': 0,
        'default': 30,
        'description': 'Request timeout in seconds',
      },
    },
    'additionalProperties': false,
  };

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    // No validation needed - already done by base class
    // Config is guaranteed to be valid here
    final apiKey = config['apiKey'] as String;
    final baseUrl = config['baseUrl'] as String;
    final timeout = config['timeout'] as int? ?? 30;

    // ... initialize adapter
  }
}
```

### 2. Automatic Validation

Validation happens automatically when `initializeFromConfig()` is called:

```dart
// In main.dart
await adapterRegistry.registerAdapter(() => MyAdapter());
// ↓
// AdapterRegistry calls adapter.initializeFromConfig()
// ↓
// BackendAdapter.initializeFromConfig() validates config against schema
// ↓
// If valid: calls adapter.initialize(config)
// If invalid: throws AdapterConfigValidationException
```

### 3. Clear Error Messages

When validation fails, you get detailed error messages:

```
AdapterConfigValidationException: Configuration validation failed for adapter "myadapter":
  - root: The object must have a required property 'apiKey'

Schema: Required fields: apiKey, baseUrl
Available fields:
  - apiKey (string) [REQUIRED]: API authentication key
  - baseUrl (string) [REQUIRED]: Base URL of the API
  - timeout (integer): Request timeout in seconds

Provided config: {baseUrl: https://api.example.com, timeout: 30}
```

## Schema Definition Guide

### Basic Types

```dart
'properties': {
  'stringField': {
    'type': 'string',
    'minLength': 1,
    'maxLength': 100,
    'description': 'A string field',
  },
  'numberField': {
    'type': 'number',
    'minimum': 0,
    'maximum': 100,
    'description': 'A number field',
  },
  'integerField': {
    'type': 'integer',
    'minimum': 0,
    'description': 'An integer field',
  },
  'booleanField': {
    'type': 'boolean',
    'description': 'A boolean field',
  },
}
```

### Format Validation

```dart
'properties': {
  'url': {
    'type': 'string',
    'format': 'uri',
    'description': 'A valid URL',
  },
  'email': {
    'type': 'string',
    'format': 'email',
    'description': 'A valid email address',
  },
  'uuid': {
    'type': 'string',
    'format': 'uuid',
    'description': 'A valid UUID',
  },
}
```

### Pattern Matching

```dart
'properties': {
  'shopifyStore': {
    'type': 'string',
    'pattern': r'^[a-zA-Z0-9][a-zA-Z0-9-]*\.myshopify\.com$',
    'description': 'Shopify store URL',
  },
  'consumerKey': {
    'type': 'string',
    'pattern': r'^ck_[a-zA-Z0-9]{40}$',
    'description': 'WooCommerce consumer key',
  },
  'apiVersion': {
    'type': 'string',
    'pattern': r'^\d{4}-\d{2}$',
    'description': 'API version (e.g., 2024-01)',
  },
}
```

### Required Fields

```dart
{
  'type': 'object',
  'required': ['apiKey', 'baseUrl'], // These fields must be present
  'properties': {
    'apiKey': { 'type': 'string' },
    'baseUrl': { 'type': 'string' },
    'optionalField': { 'type': 'string' }, // Not in 'required', so optional
  },
}
```

### Alternative Requirements

Use `anyOf` when at least one of multiple fields must be provided:

```dart
{
  'type': 'object',
  'required': ['shopDomain'], // Always required
  'properties': {
    'publicApiKey': { 'type': 'string' },
    'apiKey': { 'type': 'string' },
    'privateApiKey': { 'type': 'string' },
    'shopDomain': { 'type': 'string' },
  },
  'anyOf': [
    {'required': ['publicApiKey']},
    {'required': ['apiKey']},
    {'required': ['privateApiKey']},
  ],
}
```

This means: `shopDomain` is always required, AND at least one of the API key fields must be provided.

### Disallow Additional Properties

```dart
{
  'type': 'object',
  'properties': {
    'apiKey': { 'type': 'string' },
  },
  'additionalProperties': false, // Only 'apiKey' is allowed
}
```

## Example: Complete Adapter Schemas

### Shopify Adapter

```dart
@override
Map<String, dynamic> get configSchema => {
  'type': 'object',
  'required': ['storeUrl', 'storefrontAccessToken'],
  'properties': {
    'storeUrl': {
      'type': 'string',
      'minLength': 1,
      'pattern': r'^[a-zA-Z0-9][a-zA-Z0-9-]*\.myshopify\.com$',
      'description': 'Shopify store URL (e.g., mystore.myshopify.com)',
    },
    'storefrontAccessToken': {
      'type': 'string',
      'minLength': 1,
      'description': 'Shopify Storefront API access token',
    },
    'apiVersion': {
      'type': 'string',
      'pattern': r'^\d{4}-\d{2}$',
      'description': 'Shopify API version (e.g., 2024-01)',
    },
  },
  'additionalProperties': false,
};
```

### WooCommerce Adapter

```dart
@override
Map<String, dynamic> get configSchema => {
  'type': 'object',
  'required': ['baseUrl', 'consumerKey', 'consumerSecret'],
  'properties': {
    'baseUrl': {
      'type': 'string',
      'minLength': 1,
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
  },
  'additionalProperties': false,
};
```

### OneSignal Adapter

```dart
@override
Map<String, dynamic> get configSchema => {
  'type': 'object',
  'required': ['appId'],
  'properties': {
    'appId': {
      'type': 'string',
      'minLength': 1,
      'pattern': r'^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$',
      'description': 'OneSignal App ID (UUID format)',
    },
    'debug': {
      'type': 'boolean',
      'description': 'Enable verbose logging',
    },
  },
  'additionalProperties': false,
};
```

## Migration Guide

### Before (Manual Validation)

```dart
@override
Future<void> initialize(Map<String, dynamic> config) async {
  // Manual validation
  final appId = config['appId'] as String?;

  if (appId == null || appId.isEmpty) {
    throw Exception('OneSignal App ID not configured');
  }

  if (!RegExp(r'^[a-f0-9]{8}-[a-f0-9]{4}').hasMatch(appId)) {
    throw Exception('Invalid OneSignal App ID format');
  }

  // Initialize...
}
```

### After (Schema Validation)

```dart
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
  },
  'additionalProperties': false,
};

@override
Future<void> initialize(Map<String, dynamic> config) async {
  // No validation needed - config is guaranteed valid
  final appId = config['appId'] as String;

  // Initialize...
}
```

## Benefits

### 1. Fail-Fast

Errors are caught at startup, not during runtime:

```
❌ Before: App runs, user clicks "Add to Cart", adapter fails because apiKey is missing

✅ After: App fails to start with clear error message about missing apiKey
```

### 2. Better Error Messages

```
❌ Before: "OneSignal App ID not configured"

✅ After:
"Configuration validation failed for adapter 'onesignal':
  - root: The object must have a required property 'appId'

Required fields: appId
Available fields:
  - appId (string) [REQUIRED]: OneSignal App ID (UUID format)
  - debug (boolean): Enable verbose logging

Provided config: {debug: true}"
```

### 3. Less Code

Remove all manual validation logic from adapters:

```dart
// Delete these:
if (apiKey == null || apiKey.isEmpty) { ... }
if (!isValidUrl(baseUrl)) { ... }
if (timeout < 0) { ... }
```

### 4. Self-Documenting

The schema serves as documentation:

```dart
'apiKey': {
  'type': 'string',
  'minLength': 10,
  'description': 'API authentication key',  // Clear documentation
}
```

## Testing

### Unit Tests

```dart
test('should validate config correctly', () {
  final adapter = MyAdapter();

  // Valid config
  expect(
    () => adapter.validateConfig({'apiKey': 'test123', 'baseUrl': 'https://api.com'}),
    returnsNormally,
  );

  // Invalid config
  expect(
    () => adapter.validateConfig({'apiKey': 'test123'}), // Missing baseUrl
    throwsA(isA<AdapterConfigValidationException>()),
  );
});
```

### Manual Testing

Call `validateConfig()` directly:

```dart
try {
  adapter.validateConfig(config);
  print('✓ Configuration valid');
} catch (e) {
  print('✗ Configuration error: $e');
}
```

## JSON Schema Resources

- [JSON Schema Documentation](https://json-schema.org/)
- [Understanding JSON Schema](https://json-schema.org/understanding-json-schema/)
- [json_schema Package](https://pub.dev/packages/json_schema)

## Common Patterns

### UUID Format

```dart
'pattern': r'^[a-f0-9]{8}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{4}-[a-f0-9]{12}$'
```

### URL Format

```dart
'format': 'uri'
```

### Email Format

```dart
'format': 'email'
```

### Shopify Domain

```dart
'pattern': r'^[a-zA-Z0-9][a-zA-Z0-9-]*\.myshopify\.com$'
```

### API Version (YYYY-MM)

```dart
'pattern': r'^\d{4}-\d{2}$'
```

### WooCommerce Keys

```dart
// Consumer Key
'pattern': r'^ck_[a-zA-Z0-9]{40}$'

// Consumer Secret
'pattern': r'^cs_[a-zA-Z0-9]{40}$'
```

## Troubleshooting

### Issue: "No schema defined"

**Cause**: Adapter doesn't override `configSchema` getter

**Solution**: Add schema to adapter:

```dart
@override
Map<String, dynamic> get configSchema => { ... };
```

### Issue: "Pattern validation failing"

**Cause**: Config value doesn't match regex pattern

**Solution**: Check the pattern and value:

```dart
// Pattern expects: mystore.myshopify.com
// But config has: https://mystore.myshopify.com
// Fix: Remove https:// from config
```

### Issue: "Additional properties not allowed"

**Cause**: Config has extra fields not in schema

**Solution**: Either:
1. Remove the extra fields from config
2. Add them to schema
3. Remove `'additionalProperties': false` from schema

## Version History

### Version 1.1.0 (2025-11-12)
- Added JSON schema validation to BackendAdapter
- Added `configSchema` abstract getter
- Added `validateConfig()` method
- Added `AdapterConfigValidationException`
- Integrated validation into `initializeFromConfig()`
- Added comprehensive test suite
- Updated all adapters with schemas:
  - ShopifyAdapter
  - WooCommerceAdapter
  - JudgemeAdapter
  - OneSignalAdapter
- Created documentation and migration guide

---

**Note**: This feature requires `json_schema: ^5.1.6` package in moose_core dependencies.
