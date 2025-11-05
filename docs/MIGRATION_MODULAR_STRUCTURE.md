# Migration Guide: Modular Package Structure

> Guide for migrating to the new modular export structure in moose_core v1.1.0

## Overview

The moose_core package has been restructured to use modular exports, allowing developers to import specific modules instead of the entire package. This improves build times, reduces bundle sizes, and makes dependencies more explicit.

## What Changed

### Before (v1.0.0)

The package had a single barrel file `lib/moose_core.dart` that exported everything:

```dart
library moose_core;

// Actions
export 'src/actions/action_registry.dart';

// Adapter Pattern
export 'src/adapter/adapter_registry.dart';
export 'src/adapter/backend_adapter.dart';

// [... 140+ more exports ...]
```

### After (v1.1.0)

The package now has focused module files:

```
lib/
├── moose_core.dart          # Main export (re-exports all modules)
├── entities.dart            # Domain entities module
├── repositories.dart        # Repository interfaces module
├── plugin.dart              # Plugin system module
├── widgets.dart             # UI components module
├── adapters.dart            # Adapter pattern module
├── cache.dart               # Caching system module
└── services.dart            # Utilities & helpers module
```

## Migration Paths

### Option 1: No Changes Required (Recommended for Most Projects)

If you were importing the entire package, **no changes are needed**:

```dart
// This still works exactly the same
import 'package:moose_core/moose_core.dart';
```

The main `moose_core.dart` file now re-exports all modules, maintaining full backward compatibility.

### Option 2: Optimize with Selective Imports (Optional)

For better tree-shaking and smaller builds, you can now import only the modules you need:

#### Example 1: Feature Plugin

```dart
// Before
import 'package:moose_core/moose_core.dart';

// After (optimized)
import 'package:moose_core/plugin.dart';        // FeaturePlugin, PluginRegistry
import 'package:moose_core/widgets.dart';       // WidgetRegistry
import 'package:moose_core/repositories.dart';  // Repository interfaces
```

#### Example 2: Backend Adapter

```dart
// Before
import 'package:moose_core/moose_core.dart';

// After (optimized)
import 'package:moose_core/adapters.dart';      // BackendAdapter, AdapterRegistry
import 'package:moose_core/repositories.dart';  // Repository interfaces
import 'package:moose_core/entities.dart';      // Domain entities
import 'package:moose_core/cache.dart';         // CacheManager
```

#### Example 3: UI Screen

```dart
// Before
import 'package:moose_core/moose_core.dart';

// After (optimized)
import 'package:moose_core/entities.dart';      // Product, Cart, etc.
import 'package:moose_core/widgets.dart';       // FeatureSection
import 'package:moose_core/repositories.dart';  // ProductsRepository
```

## Module Reference

### entities.dart

**What it exports:** All domain entities (Product, Cart, Order, Category, etc.)

**Use when:**
- Working with domain models
- Creating DTOs to entity mappers
- Building UI that displays entity data

**Includes:**
- Cart entities (Cart, CartItem)
- Product entities (Product, ProductVariation, ProductSection, etc.)
- Order entities (Order, Checkout)
- Common entities (Category, ProductTag, PaginatedResult, etc.)

### repositories.dart

**What it exports:** All repository interface definitions

**Use when:**
- Implementing backend adapters
- Creating BLoCs that need data access
- Testing with mock repositories

**Includes:**
- ProductsRepository
- CartRepository
- ReviewRepository
- SearchRepository
- PostRepository
- PushNotificationRepository

### plugin.dart

**What it exports:** Plugin system components

**Use when:**
- Creating feature plugins
- Managing plugin lifecycle
- Registering plugins in main app

**Includes:**
- FeaturePlugin
- PluginRegistry

### widgets.dart

**What it exports:** UI components and widget system

**Use when:**
- Creating FeatureSections
- Registering custom widgets
- Using UI extension points

**Includes:**
- FeatureSection
- WidgetRegistry
- AddonRegistry

### adapters.dart

**What it exports:** Backend adapter pattern

**Use when:**
- Implementing backend adapters (WooCommerce, Shopify, etc.)
- Managing adapter registration
- Swapping backends

**Includes:**
- BackendAdapter
- AdapterRegistry

### cache.dart

**What it exports:** Caching system

**Use when:**
- Implementing caching strategies
- Configuring cache layers
- Managing cache TTL

**Includes:**
- CacheManager
- MemoryCache
- PersistentCache

### services.dart

**What it exports:** Services, utilities, and helper functions

**Use when:**
- Using utility services
- Logging
- Working with actions and hooks
- Making API calls

**Includes:**
- ActionRegistry
- HookRegistry
- ApiClient
- ConfigManager
- ColorHelper, TextStyleHelper
- VariationSelectorService
- AppLogger

## Best Practices

### DO

✅ Use `import 'package:moose_core/moose_core.dart'` for quick prototyping and small projects

✅ Use modular imports for production apps to reduce bundle size

✅ Import only the modules you actually use in each file

✅ Group related imports together

```dart
// Good: Grouped by module
import 'package:moose_core/entities.dart';
import 'package:moose_core/repositories.dart';

import 'package:moose_core/widgets.dart';
```

### DON'T

❌ Mix full package imports with modular imports in the same file

```dart
// Bad: Inconsistent
import 'package:moose_core/moose_core.dart';
import 'package:moose_core/entities.dart';  // Already exported by moose_core.dart
```

❌ Import modules you don't use

```dart
// Bad: Importing unused modules
import 'package:moose_core/cache.dart';  // Not using any cache classes
import 'package:moose_core/services.dart';  // Not using any services
```

## Migration Checklist

- [ ] Review your current imports of `package:moose_core/moose_core.dart`
- [ ] Decide: Keep full imports or optimize with modular imports?
- [ ] If optimizing, identify which modules each file needs
- [ ] Update imports file by file
- [ ] Run `flutter analyze` to check for any issues
- [ ] Test your application thoroughly
- [ ] Update your team documentation if needed

## Breaking Changes

**None.** This is a fully backward-compatible change. All existing code will continue to work without modifications.

## Performance Benefits

Using modular imports can provide:

- **Faster compilation**: Dart analyzer only needs to process imported modules
- **Smaller bundles**: Tree-shaking can remove unused code more effectively
- **Better IDE performance**: Faster code completion and analysis
- **Clearer dependencies**: Explicit module imports make dependencies obvious

## Examples

### Complete Migration Example

#### Before

```dart
// lib/plugins/products/product_plugin.dart
import 'package:flutter/material.dart';
import 'package:moose_core/moose_core.dart';

class ProductsPlugin extends FeaturePlugin {
  @override
  String get name => 'products';

  @override
  void onRegister() {
    WidgetRegistry().register('products.list', (context, {data, onEvent}) {
      return ProductListSection(settings: data);
    });
  }
}

class ProductListSection extends FeatureSection {
  const ProductListSection({super.key, super.settings});

  @override
  Map<String, dynamic> getDefaultSettings() => {'perPage': 10};

  @override
  Widget build(BuildContext context) {
    final repo = adapters.getRepository<ProductsRepository>();
    // Build UI
  }
}
```

#### After (Optimized)

```dart
// lib/plugins/products/product_plugin.dart
import 'package:flutter/material.dart';
import 'package:moose_core/plugin.dart';        // FeaturePlugin
import 'package:moose_core/widgets.dart';       // WidgetRegistry, FeatureSection
import 'package:moose_core/repositories.dart';  // ProductsRepository

class ProductsPlugin extends FeaturePlugin {
  @override
  String get name => 'products';

  @override
  void onRegister() {
    WidgetRegistry().register('products.list', (context, {data, onEvent}) {
      return ProductListSection(settings: data);
    });
  }
}

class ProductListSection extends FeatureSection {
  const ProductListSection({super.key, super.settings});

  @override
  Map<String, dynamic> getDefaultSettings() => {'perPage': 10};

  @override
  Widget build(BuildContext context) {
    final repo = adapters.getRepository<ProductsRepository>();
    // Build UI
  }
}
```

## Questions?

If you have questions about the migration:

1. Check this guide first
2. Review the [AI-ready documentation](./ai-ready/README.md)
3. Open an issue on GitHub

## Version History

- **v1.1.0** (2025-11-04): Introduced modular package structure
- **v1.0.0** (2025-11-03): Initial release with single barrel file

---

**Last Updated:** 2025-11-04
**Migration Difficulty:** Easy (No breaking changes)
