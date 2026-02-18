# moose_core Documentation

> AI-ready documentation for the moose_core package - A modular, plugin-based architecture for Flutter e-commerce applications

## Overview

The `moose_core` package provides a comprehensive architectural foundation for building scalable, maintainable e-commerce applications in Flutter. It implements industry-standard patterns including Plugin Architecture, Repository Pattern, BLoC State Management, and Adapter Pattern.

## Quick Start

### Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  moose_core:
    git:
      url: https://github.com/greymooseinc/moose_core.git
      ref: main
```

### Basic Usage

```dart
// Import entire package
import 'package:moose_core/moose_core.dart';

// Or import specific modules
import 'package:moose_core/entities.dart';
import 'package:moose_core/repositories.dart';
import 'package:moose_core/plugin.dart';
import 'package:moose_core/widgets.dart';
import 'package:moose_core/adapters.dart';
import 'package:moose_core/cache.dart';
import 'package:moose_core/services.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize registries
  final adapterRegistry = AdapterRegistry();
  final pluginRegistry = PluginRegistry();

  // Register your adapter
  await adapterRegistry.registerAdapter(() async {
    final adapter = WooCommerceAdapter();
    await adapter.initialize(config);
    return adapter;
  });

  // Register your plugins
  await pluginRegistry.registerPlugin(() => ProductsPlugin());
  await pluginRegistry.registerPlugin(() => CartPlugin());

  runApp(MyApp(
    pluginRegistry: pluginRegistry,
    adapterRegistry: adapterRegistry,
  ));
}
```

## Modular Package Structure

The package is organized into focused modules for better maintainability and selective imports:

| Module | Description | Key Exports |
|--------|-------------|-------------|
| **entities.dart** | Domain entities | Product, Cart, Order, Category, etc. |
| **repositories.dart** | Repository interfaces | ProductsRepository, CartRepository, etc. |
| **plugin.dart** | Plugin system | FeaturePlugin, PluginRegistry |
| **widgets.dart** | UI components | FeatureSection, WidgetRegistry, AddonRegistry |
| **adapters.dart** | Adapter pattern | BackendAdapter, AdapterRegistry |
| **cache.dart** | Caching system | CacheManager, MemoryCache, PersistentCache |
| **services.dart** | Utilities & helpers | EventBus, HookRegistry, ActionRegistry, ApiClient, Logger |

### Import Options

```dart
// Option 1: Import everything (recommended for most cases)
import 'package:moose_core/moose_core.dart';

// Option 2: Import only what you need (for optimized builds)
import 'package:moose_core/entities.dart';      // Just domain entities
import 'package:moose_core/repositories.dart';  // Just repository interfaces
import 'package:moose_core/adapters.dart';      // Just adapter pattern

// Option 3: Mix and match
import 'package:moose_core/entities.dart';
import 'package:moose_core/plugin.dart';
import 'package:moose_core/services.dart';
```

## Documentation Index

### Core Architectural Patterns

1. **[ARCHITECTURE.md](./ARCHITECTURE.md)** - Core architectural patterns
   - Plugin System
   - Repository Pattern
   - FeatureSection Pattern
   - BLoC Pattern
   - Adapter Pattern
   - Configuration System

2. **[PLUGIN_SYSTEM.md](./PLUGIN_SYSTEM.md)** - Plugin architecture guide
   - Creating plugins
   - Plugin lifecycle
   - Registration patterns
   - Best practices

3. **[FEATURE_SECTION.md](./FEATURE_SECTION.md)** - FeatureSection pattern
   - Creating configurable sections
   - Configuration patterns
   - Use cases and examples
   - Content vs Sliver sections

4. **[ADAPTER_PATTERN.md](./ADAPTER_PATTERN.md)** - Backend adapter pattern
   - BackendAdapter abstraction
   - Creating custom adapters
   - Repository factory pattern
   - Lazy loading and caching

5. **[MANIFEST.md](./MANIFEST.md)** - moose.manifest.json reference
   - Complete manifest file structure
   - Field definitions and validation rules
   - Plugin and adapter manifest examples
   - Best practices and common patterns
   - Troubleshooting guide

### Registry Systems

6. **[REGISTRIES.md](./REGISTRIES.md)** - Complete registry guide
   - WidgetRegistry
   - AdapterRegistry
   - ActionRegistry
   - HookRegistry
   - AddonRegistry

### Event-Driven Communication

7. **[EVENT_SYSTEM_GUIDE.md](./EVENT_SYSTEM_GUIDE.md)** - ⚡ Complete event system guide for AI agents
   - TL;DR decision matrix
   - EventBus: Asynchronous pub/sub for notifications
   - HookRegistry: Synchronous callbacks for data transformation
   - String-based events with dot notation (e.g., 'cart.item.added')
   - Common event patterns for all domains
   - BLoC integration examples
   - Testing strategies
   - Common pitfalls and best practices
   - **START HERE for event systems**

### Advanced Topics

8. **[CACHE_SYSTEM.md](./CACHE_SYSTEM.md)** - Caching system
   - CacheManager
   - MemoryCache
   - PersistentCache
   - TTL configuration

9. **[ANTI_PATTERNS.md](./ANTI_PATTERNS.md)** - What NOT to do
   - State management anti-patterns
   - Architecture violations
   - Common mistakes
   - Quick reference checklist

10. **[API.md](./API.md)** - Public API reference
    - Exported classes and methods
    - Usage examples
    - Type definitions

### Authentication & Authorization

11. **[AUTH_ADAPTER_GUIDE.md](./AUTH_ADAPTER_GUIDE.md)** - Authentication adapter guide
    - Multi-provider authentication
    - AuthRepository implementation
    - Provider-specific integration (Firebase, Auth0, custom)
    - User entity with provider data
    - Complete examples for AI agents

### Domain Entities

12. **[PRODUCT_SECTIONS.md](./PRODUCT_SECTIONS.md)** - Product Sections System
    - Dynamic content sections for products
    - Flexible backend mapping
    - Custom section types
    - UI rendering patterns
    - Migration from legacy fields

13. **[../ai_agent_quick_reference.md](../ai_agent_quick_reference.md)** - Quick Reference for AI Agents
    - Product sections quick guide
    - Copy-paste templates
    - Common patterns
    - Decision trees

## Key Concepts

### Plugin Architecture

Every feature is a self-contained plugin that can be independently developed, tested, and maintained:

```dart
class MyFeaturePlugin extends FeaturePlugin {
  @override
  String get name => 'my_feature';

  @override
  String get version => '1.0.0';

  @override
  Future<void> initialize() async {
    // Register sections, routes, etc.
  }

  @override
  void onRegister() {
    // Register hooks, actions, etc.
  }
}
```

### Repository Pattern

Abstract data operations from specific backends:

```dart
// Core repository interface
abstract class ProductsRepository extends CoreRepository {
  Future<List<Product>> getProducts(ProductFilters? filters);
  Future<Product> getProductById(String id);
}

// Implementation in your adapter
class WooProductsRepository implements ProductsRepository {
  @override
  Future<List<Product>> getProducts(ProductFilters? filters) async {
    // WooCommerce-specific implementation
  }
}
```

### FeatureSection Pattern

Create configurable, reusable UI sections:

```dart
class FeaturedProductsSection extends FeatureSection {
  const FeaturedProductsSection({super.key, super.settings});

  @override
  Map<String, dynamic> getDefaultSettings() {
    return {
      'title': 'Featured Products',
      'perPage': 10,
      'columns': 2,
    };
  }

  @override
  Widget build(BuildContext context) {
    final repository = adapters.getRepository<ProductsRepository>();
    // Build your UI using getSetting<T>() for configuration
  }
}
```

### BLoC Pattern

Mandatory state management pattern:

```dart
// Event
class LoadProducts extends ProductsEvent {
  final ProductFilters? filters;
  const LoadProducts({this.filters});
}

// State
class ProductsLoaded extends ProductsState {
  final List<Product> products;
  const ProductsLoaded(this.products);
}

// BLoC
class ProductsBloc extends Bloc<ProductsEvent, ProductsState> {
  final ProductsRepository repository;

  ProductsBloc(this.repository) : super(ProductsInitial()) {
    on<LoadProducts>(_onLoadProducts);
  }
}
```

## Extending the Core

### Creating a Custom Plugin

1. Extend `FeaturePlugin`
2. Implement required methods
3. Register sections, routes, hooks
4. Initialize resources

See [PLUGIN_SYSTEM.md](./PLUGIN_SYSTEM.md) for complete guide.

### Creating a Custom Adapter

1. Extend `BackendAdapter`
2. Implement repository factories
3. Register repositories
4. Initialize with configuration

See [ADAPTER_PATTERN.md](./ADAPTER_PATTERN.md) for complete guide.

### Creating Custom Sections

1. Extend `FeatureSection`
2. Implement `getDefaultSettings()`
3. Use `getSetting<T>()` for configuration
4. Use BLoC for state management

See [FEATURE_SECTION.md](./FEATURE_SECTION.md) for complete guide.

## Architecture Layers

```
┌─────────────────────────────────────────────────────────────┐
│                     Presentation Layer                       │
│              (Screens, Sections, Widgets)                    │
└──────────────────────┬──────────────────────────────────────┘
                       │ Events/States
┌──────────────────────▼──────────────────────────────────────┐
│                  Business Logic Layer (BLoC)                 │
│                  (Events, States, BLoCs)                     │
└──────────────────────┬──────────────────────────────────────┘
                       │ Repository Calls
┌──────────────────────▼──────────────────────────────────────┐
│                    Repository Layer                          │
│              (Abstract Interfaces)                           │
└──────────────────────┬──────────────────────────────────────┘
                       │ Implementation
┌──────────────────────▼──────────────────────────────────────┐
│                     Adapter Layer                            │
│         (Backend-Specific Implementation)                    │
└─────────────────────────────────────────────────────────────┘
```

## Best Practices

### DO

- Use BLoC for ALL state management
- Extend FeatureSection for configurable sections
- Define all settings in getDefaultSettings()
- Use repository interfaces for data access
- Keep plugins focused and independent
- Use double for UI dimensions
- Implement Equatable for Events and States

### DON'T

- Use StatefulWidget with setState() for business logic
- Make direct API calls from BLoCs or widgets
- Hardcode values in sections
- Put business logic in repositories
- Return DTOs from repositories
- Use int for UI dimensions
- Skip BLoC pattern for stateful operations

## Testing

The core package is designed for testability:

```dart
// Mock repository
class MockProductsRepository extends Mock implements ProductsRepository {}

// Test BLoC
blocTest<ProductsBloc, ProductsState>(
  'emits ProductsLoaded when LoadProducts succeeds',
  build: () => ProductsBloc(MockProductsRepository()),
  act: (bloc) => bloc.add(LoadProducts()),
  expect: () => [ProductsLoading(), ProductsLoaded(products)],
);
```

## Contributing

When contributing to the core package:

1. Read [ARCHITECTURE.md](./ARCHITECTURE.md) first
2. Follow patterns in [ANTI_PATTERNS.md](./ANTI_PATTERNS.md)
3. Add tests for new features
4. Update documentation
5. Follow the plugin architecture

## Related Documentation

### Core Architecture
- **[ARCHITECTURE.md](./ARCHITECTURE.md)** - Complete architectural guide
- **[PLUGIN_SYSTEM.md](./PLUGIN_SYSTEM.md)** - Plugin development guide
- **[ADAPTER_PATTERN.md](./ADAPTER_PATTERN.md)** - Backend adapter guide
- **[REGISTRIES.md](./REGISTRIES.md)** - Registry systems
- **[ANTI_PATTERNS.md](./ANTI_PATTERNS.md)** - What to avoid

### Domain Entities
- **[PRODUCT_SECTIONS.md](./PRODUCT_SECTIONS.md)** - Product sections comprehensive guide
- **[../ai_agent_quick_reference.md](../ai_agent_quick_reference.md)** - Quick reference for AI agents

## Support

- GitHub Issues: https://github.com/greymooseinc/moose_core/issues
- Documentation: https://github.com/greymooseinc/moose_core/blob/main/README.md
- Examples: https://github.com/greymooseinc/moose_core/tree/main/example

---

**Version:** 1.0.0
**Last Updated:** 2025-11-09
**License:** MIT

---

## Instructions for AI Agents

### Code Generation Best Practices

This package follows industry best practices for AI-ready codebases. All architectural patterns are explicitly documented to enable consistent code generation and maintenance.

### Git Workflow

**IMPORTANT:** After completing a batch of file changes in response to a user request, you MUST commit the changes to git with a descriptive commit message.

#### Git Commit Guidelines:

1. **When to Commit:**
   - After completing all file modifications for a single user request
   - One commit per user prompt (not per file)
   - Before finishing your response to the user

2. **Commit Message Format:**
   ```
   <type>: <short description>

   <optional detailed description>

   🤖 Generated with Claude Code

   Co-Authored-By: Claude <noreply@anthropic.com>
   ```

3. **Commit Types:**
   - `feat:` - New features or functionality
   - `fix:` - Bug fixes
   - `refactor:` - Code restructuring without behavior change
   - `docs:` - Documentation updates
   - `test:` - Test additions or modifications
   - `chore:` - Maintenance tasks

4. **Example Commit Workflow:**
   ```bash
   # After making changes to multiple files
   cd /path/to/repo
   git add .
   git commit -m "$(cat <<'EOF'
   refactor: Convert EventBus to string-based events

   - Removed typed event classes
   - Updated EventBus API to use string event names
   - Updated all plugins to use dot notation (e.g., 'cart.item.added')
   - Updated documentation with new patterns

   🤖 Generated with Claude Code

   Co-Authored-By: Claude <noreply@anthropic.com>
   EOF
   )"
   ```

5. **What NOT to Commit:**
   - `.claude/settings.local.json` (user-specific settings)
   - Temporary or build files
   - IDE-specific configuration files

6. **Before Committing:**
   - Verify changes with `git status`
   - Check for any unintended modifications
   - Ensure all related files are included
