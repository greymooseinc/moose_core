# moose.manifest.json Documentation

> Complete reference for the moose.manifest.json file structure used by plugins and adapters

**Last Updated:** 2025-11-15
**Version:** 1.0.0
**Target Audience:** AI Agents, Plugin Developers, Adapter Developers

## Table of Contents
- [Overview](#overview)
- [File Purpose](#file-purpose)
- [File Location](#file-location)
- [Schema Definition](#schema-definition)
- [Field Reference](#field-reference)
- [Examples](#examples)
- [Validation Rules](#validation-rules)
- [Best Practices](#best-practices)
- [Common Patterns](#common-patterns)
- [Troubleshooting](#troubleshooting)

## Overview

The `moose.manifest.json` file is a **required metadata file** for all plugins and adapters in the Moose framework. It provides essential information about the plugin/adapter including its name, version, entry point, and dependencies.

**Key Functions:**
- Declares plugin/adapter identity (name, version)
- Specifies the Dart import path and main class
- Defines dependencies required by the plugin/adapter
- Enables automatic discovery and loading by the Moose framework

## File Purpose

### For Plugins
Plugins use `moose.manifest.json` to:
- Register the plugin with the Moose framework
- Declare the plugin's entry point class (extends `FeaturePlugin`)
- Specify dependencies needed for plugin functionality
- Enable dynamic loading and initialization

### For Adapters
Adapters use `moose.manifest.json` to:
- Register the adapter with the Moose framework
- Declare the adapter's entry point class (extends `BackendAdapter`)
- Specify backend-specific dependencies (API clients, DTOs, etc.)
- Enable backend switching without code changes

## File Location

**Plugin Manifest Location:**
```
lib/plugins/{plugin_name}/moose.manifest.json
```

**Adapter Manifest Location:**
```
lib/adapters/{adapter_name}/moose.manifest.json
```

**Examples:**
- `lib/plugins/products/moose.manifest.json`
- `lib/plugins/cart/moose.manifest.json`
- `lib/adapters/shopify/moose.manifest.json`
- `lib/adapters/woocommerce/moose.manifest.json`

## Schema Definition

```typescript
{
  "name": string,              // Required: Unique identifier (snake_case)
  "version": string,           // Required: Semantic version (e.g., "1.0.0")
  "import": string[],          // Required: Array of import paths
  "class": string,             // Required: Main class name (PascalCase)
  "dependencies": object       // Required: Map of package dependencies
}
```

## Field Reference

### `name` (Required)
**Type:** `string`
**Format:** `snake_case`
**Description:** Unique identifier for the plugin or adapter

**Rules:**
- MUST be unique across all plugins/adapters
- MUST use snake_case format
- SHOULD match the directory name
- CANNOT contain spaces or special characters (except underscores)

**Examples:**
```json
"name": "products"
"name": "cart"
"name": "shopify"
"name": "recently_viewed"
```

**Common Mistakes:**
```json
// ❌ WRONG - PascalCase
"name": "ProductsPlugin"

// ❌ WRONG - kebab-case
"name": "recently-viewed"

// ❌ WRONG - Contains spaces
"name": "products plugin"

// ✅ CORRECT
"name": "recently_viewed"
```

### `version` (Required)
**Type:** `string`
**Format:** Semantic Versioning (MAJOR.MINOR.PATCH)
**Description:** Version number following semver specification

**Rules:**
- MUST follow semantic versioning format (X.Y.Z)
- MAJOR version for breaking changes
- MINOR version for new features (backward compatible)
- PATCH version for bug fixes

**Examples:**
```json
"version": "1.0.0"
"version": "2.1.3"
"version": "0.1.0"
```

**Common Mistakes:**
```json
// ❌ WRONG - Missing patch version
"version": "1.0"

// ❌ WRONG - Non-numeric
"version": "v1.0.0"

// ❌ WRONG - Invalid format
"version": "latest"

// ✅ CORRECT
"version": "1.0.0"
```

### `import` (Required)
**Type:** `array of strings`
**Description:** Array of relative import paths to Dart files

**Rules:**
- MUST be an array (even for single import)
- Paths are relative to `lib/` directory
- MUST start with `./plugins/` or `./adapters/`
- MUST point to valid Dart files (.dart extension)
- Typically contains one entry (the main plugin/adapter file)

**Format:**
```
./plugins/{plugin_name}/{plugin_name}_plugin.dart
./adapters/{adapter_name}/{adapter_name}_adapter.dart
```

**Examples:**
```json
// Plugin import
"import": [
  "./plugins/products/products_plugin.dart"
]

// Adapter import
"import": [
  "./adapters/shopify/shopify_adapter.dart"
]
```

**Multiple Imports (Rare):**
```json
"import": [
  "./plugins/analytics/analytics_plugin.dart",
  "./plugins/analytics/analytics_helper.dart"
]
```

**Common Mistakes:**
```json
// ❌ WRONG - Not an array
"import": "./plugins/products/products_plugin.dart"

// ❌ WRONG - Absolute path
"import": [
  "lib/plugins/products/products_plugin.dart"
]

// ❌ WRONG - Missing .dart extension
"import": [
  "./plugins/products/products_plugin"
]

// ✅ CORRECT
"import": [
  "./plugins/products/products_plugin.dart"
]
```

### `class` (Required)
**Type:** `string`
**Format:** `PascalCase`
**Description:** Main class name that will be instantiated

**Rules:**
- MUST be PascalCase
- MUST extend `FeaturePlugin` (for plugins) or `BackendAdapter` (for adapters)
- MUST exist in one of the imported files
- Typically follows pattern: `{Name}Plugin` or `{Name}Adapter`

**Examples:**
```json
// Plugin classes
"class": "ProductsPlugin"
"class": "CartPlugin"
"class": "AnalyticsPlugin"

// Adapter classes
"class": "ShopifyAdapter"
"class": "WooCommerceAdapter"
"class": "OneSignalAdapter"
```

**Common Mistakes:**
```json
// ❌ WRONG - snake_case
"class": "products_plugin"

// ❌ WRONG - Missing suffix
"class": "Products"

// ❌ WRONG - Typo or wrong class name
"class": "ProductPlugin"  // But file has ProductsPlugin

// ✅ CORRECT
"class": "ProductsPlugin"
```

### `dependencies` (Required)
**Type:** `object`
**Description:** Map of package dependencies required by the plugin/adapter

**Rules:**
- MUST be an object (even if empty: `{}`)
- Keys are package names
- Values follow `pubspec.yaml` dependency format
- MUST include `moose_core` dependency for all plugins/adapters
- Additional dependencies specific to plugin/adapter functionality

**Dependency Value Formats:**

**Git Dependency (moose_core):**
```json
"moose_core": {
  "git": {
    "url": "https://github.com/greymooseinc/moose_core.git",
    "ref": "main"
  }
}
```

**Pub.dev Dependency:**
```json
"equatable": "^2.0.5",
"flutter_bloc": "^9.1.0",
"dio": "^5.4.0"
```

**Examples:**

**Minimal Dependencies (Plugin):**
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

**Plugin with Additional Dependencies:**
```json
"dependencies": {
  "moose_core": {
    "git": {
      "url": "https://github.com/greymooseinc/moose_core.git",
      "ref": "main"
    }
  },
  "equatable": "^2.0.5",
  "flutter_bloc": "^9.1.0",
  "google_fonts": "^6.1.0"
}
```

**Adapter with Backend-Specific Dependencies:**
```json
"dependencies": {
  "moose_core": {
    "git": {
      "url": "https://github.com/greymooseinc/moose_core.git",
      "ref": "main"
    }
  },
  "dio": "^5.4.0"
}
```

**Common Mistakes:**
```json
// ❌ WRONG - Array instead of object
"dependencies": [
  "moose_core",
  "equatable"
]

// ❌ WRONG - Missing moose_core
"dependencies": {
  "equatable": "^2.0.5"
}

// ❌ WRONG - Invalid git format
"dependencies": {
  "moose_core": "https://github.com/greymooseinc/moose_core.git"
}

// ✅ CORRECT
"dependencies": {
  "moose_core": {
    "git": {
      "url": "https://github.com/greymooseinc/moose_core.git",
      "ref": "main"
    }
  },
  "equatable": "^2.0.5"
}
```

## Examples

### Complete Plugin Manifest

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
    "equatable": "^2.0.5",
    "flutter_bloc": "^9.1.0",
    "google_fonts": "^6.1.0"
  }
}
```

### Complete Adapter Manifest

**File:** `lib/adapters/shopify/moose.manifest.json`

```json
{
  "name": "shopify",
  "version": "1.0.0",
  "import": [
    "./adapters/shopify/shopify_adapter.dart"
  ],
  "class": "ShopifyAdapter",
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

### Minimal Plugin Manifest

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

## Validation Rules

### Required Fields Checklist
- ✅ `name` field exists and is snake_case
- ✅ `version` field exists and follows semver (X.Y.Z)
- ✅ `import` field exists and is an array
- ✅ `class` field exists and is PascalCase
- ✅ `dependencies` field exists and is an object
- ✅ `moose_core` is included in dependencies with git format

### File Location Validation
- ✅ Manifest file is named exactly `moose.manifest.json`
- ✅ Located in plugin root: `lib/plugins/{name}/moose.manifest.json`
- ✅ Or adapter root: `lib/adapters/{name}/moose.manifest.json`
- ✅ Directory name matches `name` field

### Import Path Validation
- ✅ Import paths start with `./plugins/` or `./adapters/`
- ✅ Import paths end with `.dart`
- ✅ Import paths point to existing files
- ✅ Main class exists in imported file

### Class Validation
- ✅ Class name matches `class` field exactly (case-sensitive)
- ✅ For plugins: Class extends `FeaturePlugin`
- ✅ For adapters: Class extends `BackendAdapter`
- ✅ Class has proper implementation of required methods

## Best Practices

### 1. Naming Conventions

**Plugin Names:**
```json
// ✅ GOOD - Short, descriptive, snake_case
"name": "cart"
"name": "products"
"name": "recently_viewed"

// ❌ BAD - Too verbose
"name": "shopping_cart_plugin"

// ❌ BAD - Not descriptive
"name": "plugin1"
```

**Class Names:**
```json
// ✅ GOOD - PascalCase with suffix
"class": "CartPlugin"
"class": "ShopifyAdapter"

// ❌ BAD - No suffix
"class": "Cart"

// ❌ BAD - Wrong case
"class": "cartPlugin"
```

### 2. Version Management

**Start New Plugins/Adapters at 1.0.0:**
```json
"version": "1.0.0"
```

**Increment Appropriately:**
```json
// Bug fix: 1.0.0 → 1.0.1
"version": "1.0.1"

// New feature: 1.0.1 → 1.1.0
"version": "1.1.0"

// Breaking change: 1.1.0 → 2.0.0
"version": "2.0.0"
```

### 3. Dependency Management

**Always Include moose_core:**
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

**Use Caret Versions for Pub Packages:**
```json
// ✅ GOOD - Allows compatible updates
"equatable": "^2.0.5"

// ❌ BAD - Too restrictive
"equatable": "2.0.5"

// ❌ BAD - Too permissive
"equatable": "*"
```

**Only Include Direct Dependencies:**
```json
// ✅ GOOD - Only what this plugin uses
"dependencies": {
  "moose_core": {...},
  "flutter_bloc": "^9.1.0"  // Plugin uses BLoC directly
}

// ❌ BAD - Including transitive dependencies
"dependencies": {
  "moose_core": {...},
  "flutter_bloc": "^9.1.0",
  "bloc": "^9.1.0"  // Already included by flutter_bloc
}
```

### 4. File Organization

**Keep Manifest at Plugin/Adapter Root:**
```
✅ CORRECT STRUCTURE:
lib/plugins/products/
├── moose.manifest.json          ← Here
├── products_plugin.dart
├── logic/
├── presentation/
└── data/

❌ WRONG - Nested too deep:
lib/plugins/products/
├── logic/
└── config/
    └── moose.manifest.json      ← Not here
```

### 5. JSON Formatting

**Use Consistent Indentation:**
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
    }
  }
}
```

**No Trailing Commas:**
```json
// ❌ BAD - Trailing comma
{
  "name": "products",
  "version": "1.0.0",  ← No comma on last field
}

// ✅ GOOD
{
  "name": "products",
  "version": "1.0.0"
}
```

## Common Patterns

### Pattern 1: Simple Plugin (No Extra Dependencies)
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

### Pattern 2: Plugin with BLoC and UI Dependencies
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
    "equatable": "^2.0.5",
    "flutter_bloc": "^9.1.0",
    "google_fonts": "^6.1.0"
  }
}
```

### Pattern 3: Adapter with HTTP Client
```json
{
  "name": "shopify",
  "version": "1.0.0",
  "import": [
    "./adapters/shopify/shopify_adapter.dart"
  ],
  "class": "ShopifyAdapter",
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

### Pattern 4: Adapter with Third-Party SDK
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

## Troubleshooting

### Error: "Plugin not found"
**Possible Causes:**
1. Manifest file missing or wrong location
2. `name` field doesn't match directory name
3. Manifest file not named exactly `moose.manifest.json`

**Solution:**
```bash
# Check file exists at correct location
lib/plugins/{plugin_name}/moose.manifest.json

# Verify name matches directory
{
  "name": "products"  ← Must match directory name
}
```

### Error: "Class not found"
**Possible Causes:**
1. `class` field doesn't match actual class name
2. Import path incorrect
3. Class not exported or doesn't exist

**Solution:**
```json
// In manifest
{
  "import": [
    "./plugins/products/products_plugin.dart"  ← Check path
  ],
  "class": "ProductsPlugin"  ← Must match exactly
}
```

```dart
// In products_plugin.dart
class ProductsPlugin extends FeaturePlugin {  ← Must match manifest
  // ...
}
```

### Error: "Invalid dependency format"
**Possible Causes:**
1. `dependencies` is an array instead of object
2. Git dependency missing required fields
3. Invalid version format

**Solution:**
```json
// ❌ WRONG
"dependencies": [
  "moose_core"
]

// ✅ CORRECT
"dependencies": {
  "moose_core": {
    "git": {
      "url": "https://github.com/greymooseinc/moose_core.git",
      "ref": "main"
    }
  }
}
```

### Error: "Version conflict"
**Possible Causes:**
1. Multiple plugins depend on conflicting versions
2. Invalid semver format

**Solution:**
```json
// Use compatible version ranges
"dependencies": {
  "equatable": "^2.0.5"  // Allows 2.0.5 to <3.0.0
}
```

### Error: "Import path not found"
**Possible Causes:**
1. Path doesn't start with `./`
2. Path is absolute instead of relative
3. File doesn't exist at specified path

**Solution:**
```json
// ❌ WRONG - Absolute path
"import": [
  "lib/plugins/products/products_plugin.dart"
]

// ❌ WRONG - Missing ./
"import": [
  "plugins/products/products_plugin.dart"
]

// ✅ CORRECT - Relative path with ./
"import": [
  "./plugins/products/products_plugin.dart"
]
```

## Related Documentation

- [ARCHITECTURE.md](./ARCHITECTURE.md) - Complete architectural guide
- [PLUGIN_SYSTEM.md](./PLUGIN_SYSTEM.md) - Plugin development guide
- [ADAPTER_SYSTEM.md](./ADAPTER_SYSTEM.md) - Backend adapter guide
- [README.md](./README.md) - Documentation index

---

**Version:** 1.0.0
**Last Updated:** 2025-11-15
**Maintained By:** Development Team

**Note to AI Agents:** This manifest file is REQUIRED for every plugin and adapter. When generating new plugins or adapters, ALWAYS create a `moose.manifest.json` file following the patterns documented above. Validate all fields against the rules specified in this document before considering the plugin/adapter complete.
