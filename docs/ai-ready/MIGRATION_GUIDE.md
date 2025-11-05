# Migration Guide for AI Agents

> Complete guide for AI agents working with the moose_core package after the package split

## Overview

This project has been split into two packages:
1. **moose_core** - Reusable core architecture (THIS PACKAGE)
2. **flutter_shopping_app** - Main application using the core

This guide helps AI agents understand how to work with both packages effectively.

## Package Structure

```
repos/
├── moose_core/                 # Core architecture package
│   ├── lib/
│   │   ├── src/                   # Private implementation
│   │   │   ├── actions/
│   │   │   ├── adapter/
│   │   │   ├── api/
│   │   │   ├── cache/
│   │   │   ├── config/
│   │   │   ├── entities/
│   │   │   ├── events/
│   │   │   ├── helpers/
│   │   │   ├── plugin/
│   │   │   ├── repositories/
│   │   │   ├── services/
│   │   │   ├── utils/
│   │   │   └── widgets/
│   │   └── moose_core.dart    # Public API (single import)
│   ├── docs/ai-ready/             # Core documentation
│   └── pubspec.yaml
│
└── flutter_shopping_app/          # Application package
    ├── lib/
    │   ├── adapters/              # Backend implementations
    │   ├── plugins/               # Feature plugins
    │   ├── app.dart
    │   └── main.dart
    ├── docs/ai-ready/             # App documentation
    └── pubspec.yaml               # Depends on moose_core
```

## Import Changes

### OLD (Before Split)
```dart
// Multiple imports from core
import 'package:ecommerce_ai/core/widgets/feature_section.dart';
import 'package:ecommerce_ai/core/entities/product.dart';
import 'package:ecommerce_ai/core/adapter/adapter_registry.dart';
import 'package:ecommerce_ai/core/repositories/products_repository.dart';
import 'package:ecommerce_ai/core/plugin/feature_plugin.dart';
```

### NEW (After Split)
```dart
// Single import for ALL core functionality
import 'package:moose_core/moose_core.dart';

// All core classes are now available:
// - FeatureSection
// - Product
// - AdapterRegistry
// - ProductsRepository
// - FeaturePlugin
// - etc.
```

### What Changed

| Old Import | New Import | Notes |
|------------|------------|-------|
| `package:ecommerce_ai/core/*` | `package:moose_core/moose_core.dart` | Single import for all core |
| `package:ecommerce_ai/adapters/*` | Same (no change) | App-specific, stays in app |
| `package:ecommerce_ai/plugins/*` | Same (no change) | App-specific, stays in app |

## Documentation Structure

### Core Package Docs (`moose_core/docs/ai-ready/`)

**When to Read:**
- Understanding core architectural patterns
- Creating new plugins
- Implementing custom adapters
- Extending core functionality
- Learning about registries

**Files:**
- [README.md](./README.md) - Core package overview
- [ARCHITECTURE.md](./ARCHITECTURE.md) - Core patterns (Plugin, BLoC, Repository, FeatureSection)
- [PLUGIN_SYSTEM.md](./PLUGIN_SYSTEM.md) - How to create plugins
- [FEATURE_SECTION.md](./FEATURE_SECTION.md) - FeatureSection pattern
- [ADAPTER_PATTERN.md](./ADAPTER_PATTERN.md) - Backend adapter pattern
- [REGISTRIES.md](./REGISTRIES.md) - All registry systems
- [CACHE_SYSTEM.md](./CACHE_SYSTEM.md) - Caching patterns
- [ANTI_PATTERNS.md](./ANTI_PATTERNS.md) - What to avoid
- [API.md](./API.md) - Complete API reference

### App Package Docs (`flutter_shopping_app/docs/ai-ready/`)

**When to Read:**
- Working with WooCommerce adapter
- Creating app-specific plugins
- Setting up push notifications
- Platform-specific configuration

**Files:**
- README.md - App documentation index
- ADAPTERS.md - WooCommerce & OneSignal implementation
- PLUGINS.md - Real plugin examples (Home, Products, Cart)
- EXAMPLES.md - Working code from the app
- ONESIGNAL_SETUP.md - Push notification setup
- PUSH_NOTIFICATIONS.md - Notification handling
- NATIVE_PLATFORM_SETUP.md - Platform setup

## Working with Core Package

### Task: Understand Core Architecture

1. Read `moose_core/docs/ai-ready/README.md`
2. Read `moose_core/docs/ai-ready/ARCHITECTURE.md`
3. Check `moose_core/docs/ai-ready/API.md` for API reference
4. Review anti-patterns in `moose_core/docs/ai-ready/ANTI_PATTERNS.md`

### Task: Create a New Plugin (in App)

1. **Read Core Docs**:
   - `moose_core/docs/ai-ready/PLUGIN_SYSTEM.md` - Plugin pattern
   - `moose_core/docs/ai-ready/FEATURE_SECTION.md` - Section pattern

2. **Check App Examples**:
   - `flutter_shopping_app/docs/ai-ready/PLUGINS.md` - Real examples
   - `flutter_shopping_app/lib/plugins/home/home_plugin.dart` - Reference

3. **Create Plugin**:
   ```dart
   import 'package:moose_core/moose_core.dart';

   class MyPlugin extends FeaturePlugin {
     @override
     String get name => 'my_plugin';

     @override
     void onRegister() {
       WidgetRegistry().register(
         'my_plugin.section',
         (context, {data, onEvent}) => MySection(),
       );
     }
   }
   ```

### Task: Create a FeatureSection (in App)

1. **Read Core Docs**:
   - `moose_core/docs/ai-ready/FEATURE_SECTION.md`

2. **Import Core Package**:
   ```dart
   import 'package:moose_core/moose_core.dart';
   ```

3. **Extend FeatureSection**:
   ```dart
   class MySection extends FeatureSection {
     const MySection({super.key, super.settings});

     @override
     Map<String, dynamic> getDefaultSettings() {
       return {'title': 'My Section'};
     }

     @override
     Widget build(BuildContext context) {
       final repo = adapters.getRepository<MyRepository>();
       // Build UI...
     }
   }
   ```

### Task: Create a Backend Adapter (in App)

1. **Read Core Docs**:
   - `moose_core/docs/ai-ready/ADAPTER_PATTERN.md`

2. **Check App Examples**:
   - `flutter_shopping_app/docs/ai-ready/ADAPTERS.md`
   - `flutter_shopping_app/lib/adapters/woocommerce/woocommerce_adapter.dart`

3. **Implement BackendAdapter**:
   ```dart
   import 'package:moose_core/moose_core.dart';

   class MyAdapter extends BackendAdapter {
     @override
     String get name => 'my_backend';

     @override
     Future<void> initialize(Map<String, dynamic> config) async {
       // Setup...

       registerRepositoryFactory<ProductsRepository>(
         () => MyProductsRepository(),
       );
     }
   }
   ```

## Working with App Package

### Task: Modify Existing Plugin

**Location**: `flutter_shopping_app/lib/plugins/{plugin_name}/`

**Steps**:
1. Plugin already imports `package:moose_core/moose_core.dart`
2. All core classes available without additional imports
3. Modify plugin logic/presentation as needed
4. Follow patterns in `moose_core/docs/ai-ready/`

### Task: Modify Adapter

**Location**: `flutter_shopping_app/lib/adapters/{adapter_name}/`

**Steps**:
1. Adapter already imports `package:moose_core/moose_core.dart`
2. Implements repository interfaces from core
3. Uses entities from core (Product, Cart, etc.)
4. Check `flutter_shopping_app/docs/ai-ready/ADAPTERS.md` for patterns

### Task: Add New Repository Interface (Core Change)

**This requires modifying BOTH packages:**

1. **In Core Package** (`moose_core/`):
   ```dart
   // lib/src/repositories/my_repository.dart
   abstract class MyRepository extends CoreRepository {
     Future<MyEntity> getData();
   }
   ```

2. **Export in barrel file** (`moose_core/lib/moose_core.dart`):
   ```dart
   export 'src/repositories/my_repository.dart';
   ```

3. **In App Package** (`flutter_shopping_app/`):
   ```dart
   // lib/adapters/woocommerce/my_repository_impl.dart
   import 'package:moose_core/moose_core.dart';

   class WooMyRepository implements MyRepository {
     @override
     Future<MyEntity> getData() async {
       // Implementation...
     }
   }
   ```

4. **Register in Adapter**:
   ```dart
   // In WooCommerceAdapter.initialize()
   registerRepositoryFactory<MyRepository>(
     () => WooMyRepository(),
   );
   ```

## Common Scenarios

### Scenario 1: Adding a new domain entity

**Where**: Core package (`moose_core/lib/src/entities/`)

**Steps**:
1. Create entity class: `lib/src/entities/my_entity.dart`
2. Export in barrel: `lib/moose_core.dart`
3. Add to `docs/ai-ready/API.md`
4. Use in app with `import 'package:moose_core/moose_core.dart';`

### Scenario 2: Adding a new widget to WidgetRegistry

**Where**: App package (`flutter_shopping_app/lib/plugins/{plugin}/`)

**Steps**:
1. Import core: `import 'package:moose_core/moose_core.dart';`
2. Create FeatureSection extending `FeatureSection`
3. Register in plugin's `onRegister()` using `WidgetRegistry()`
4. All core functionality available via single import

### Scenario 3: Modifying cache behavior

**Where**: Core package (`moose_core/lib/src/cache/`)

**Steps**:
1. Modify cache classes in core
2. Update version in `moose_core/pubspec.yaml`
3. Update `CHANGELOG.md`
4. App will get changes via dependency update

### Scenario 4: Adding configuration to FeatureSection

**Where**: App package (section in `flutter_shopping_app/lib/plugins/`)

**Steps**:
1. Section already extends `FeatureSection` from core
2. Add new setting to `getDefaultSettings()`
3. Use with `getSetting<T>('key')`
4. Update `assets/config/environment.json`

## File Location Quick Reference

### Core Package Files

| Component | Location | Import |
|-----------|----------|--------|
| FeatureSection | `moose_core/lib/src/widgets/feature_section.dart` | `import 'package:moose_core/moose_core.dart';` |
| FeaturePlugin | `moose_core/lib/src/plugin/feature_plugin.dart` | Same |
| BackendAdapter | `moose_core/lib/src/adapter/backend_adapter.dart` | Same |
| WidgetRegistry | `moose_core/lib/src/widgets/widget_registry.dart` | Same |
| AdapterRegistry | `moose_core/lib/src/adapter/adapter_registry.dart` | Same |
| ActionRegistry | `moose_core/lib/src/actions/action_registry.dart` | Same |
| Product Entity | `moose_core/lib/src/entities/product.dart` | Same |
| CacheManager | `moose_core/lib/src/cache/cache_manager.dart` | Same |

**Key Point**: ALL core imports use ONE import statement: `import 'package:moose_core/moose_core.dart';`

### App Package Files

| Component | Location | Notes |
|-----------|----------|-------|
| Plugins | `flutter_shopping_app/lib/plugins/{name}/` | Import moose_core |
| Adapters | `flutter_shopping_app/lib/adapters/{name}/` | Implement core interfaces |
| Main App | `flutter_shopping_app/lib/main.dart` | Uses core |
| Config | `flutter_shopping_app/assets/config/environment.json` | App config |

## Decision Tree: Which Package to Modify?

```
┌─────────────────────────────────────────────┐
│   What are you trying to do?               │
└──────────────────┬──────────────────────────┘
                   │
        ┌──────────┴──────────┐
        │                     │
        ▼                     ▼
┌───────────────┐     ┌───────────────┐
│ Add/modify    │     │ Add/modify    │
│ PATTERN or    │     │ IMPLEMENTATION│
│ INTERFACE     │     │ or FEATURE    │
└───────┬───────┘     └───────┬───────┘
        │                     │
        ▼                     ▼
┌───────────────┐     ┌───────────────┐
│ CORE PACKAGE  │     │  APP PACKAGE  │
│               │     │               │
│ Examples:     │     │ Examples:     │
│ - New entity  │     │ - New plugin  │
│ - New repo    │     │ - Adapter     │
│   interface   │     │   impl        │
│ - New registry│     │ - Screen      │
│ - Base class  │     │ - Section     │
└───────────────┘     └───────────────┘
```

## Testing After Changes

### Core Package Changes

```bash
cd moose_core
flutter pub get
flutter analyze
flutter test
```

### App Package Changes

```bash
cd flutter_shopping_app
flutter pub get
flutter analyze
flutter test
```

### Full Integration Test

```bash
# Terminal 1: Core package
cd moose_core
flutter pub get
flutter analyze

# Terminal 2: App package
cd flutter_shopping_app
flutter pub get
flutter analyze
flutter test
flutter run
```

## Version Management

### Core Package Versioning

Follow semantic versioning in `moose_core/pubspec.yaml`:

- **1.0.0 → 2.0.0**: Breaking changes (major)
- **1.0.0 → 1.1.0**: New features (minor)
- **1.0.0 → 1.0.1**: Bug fixes (patch)

### App Package Dependency

In `flutter_shopping_app/pubspec.yaml`:

```yaml
dependencies:
  # Development (local)
  moose_core:
    path: ../moose_core

  # Production (published)
  # moose_core: ^1.0.0
```

## Troubleshooting

### Issue: "Package not found"

**Solution**: Ensure core package path is correct in app's `pubspec.yaml`:
```yaml
moose_core:
  path: ../moose_core
```

### Issue: "Class not found after import"

**Solution**: Check that class is exported in `moose_core/lib/moose_core.dart`

### Issue: "Duplicate imports"

**Solution**: Remove multiple core imports, use single:
```dart
import 'package:moose_core/moose_core.dart';
```

### Issue: "Type mismatch"

**Solution**: Ensure both packages are using same core version. Run `flutter pub get` in both.

## Best Practices for AI Agents

1. **Always check package first**: Is this a core pattern or app implementation?

2. **Use single import**: Always use `import 'package:moose_core/moose_core.dart';`

3. **Read documentation**: Start with core docs, then app docs

4. **Follow patterns**: Check existing implementations before creating new ones

5. **Update both packages**: If changing core, test in app too

6. **Version carefully**: Core changes affect all consumers

7. **Document changes**: Update appropriate docs (core vs app)

8. **Test thoroughly**: Changes in core can break app

## Quick Commands

```bash
# Get core package info
cd moose_core && flutter pub get

# Get app package info
cd flutter_shopping_app && flutter pub get

# Analyze core
cd moose_core && flutter analyze

# Analyze app
cd flutter_shopping_app && flutter analyze

# Run app
cd flutter_shopping_app && flutter run

# Test core
cd moose_core && flutter test

# Test app
cd flutter_shopping_app && flutter test
```

## Summary

**Key Changes**:
- ✅ Core moved to separate package (`moose_core`)
- ✅ Single import for all core functionality
- ✅ Clear separation: patterns (core) vs implementations (app)
- ✅ Independent versioning and publishing
- ✅ Comprehensive documentation split

**Remember**:
- Core = Patterns, interfaces, base classes
- App = Implementations, plugins, adapters
- One import: `import 'package:moose_core/moose_core.dart';`
- Read core docs first, then app docs
- Test changes in both packages

---

**Last Updated**: 2025-11-03
**Version**: 1.0.0
**For**: AI Agents working with moose_core and flutter_shopping_app
