# moose_core

A comprehensive, production-ready core architecture package for building modular Flutter e-commerce applications.

## Features

- **Plugin-Based Architecture**: Modular feature plugins with clean boundaries
- **Repository Pattern**: Abstract data layer with swappable backend adapters
- **BLoC State Management**: Built-in support for predictable state management
- **FeatureSection Pattern**: Configurable, reusable UI sections
- **Registry Systems**: Widget, Adapter, Action, Hook, and Addon registries
- **Cache Management**: Multi-layer caching with TTL support
- **Configuration System**: JSON-based external configuration
- **Modular Imports**: Import entire package or specific modules for optimized builds
- **Type-Safe APIs**: Generic methods with compile-time type checking
- **AI-Ready Documentation**: Comprehensive documentation for AI-assisted development

## Quick Start

### Installation

Add to your `pubspec.yaml`:

```yaml
dependencies:
  moose_core: ^1.1.0
```

### Import Options

```dart
// Option 1: Import everything (recommended for most cases)
import 'package:moose_core/moose_core.dart';

// Option 2: Import specific modules (for optimized builds)
import 'package:moose_core/entities.dart';       // Domain entities
import 'package:moose_core/repositories.dart';   // Repository interfaces
import 'package:moose_core/plugin.dart';         // Plugin system
import 'package:moose_core/widgets.dart';        // UI components
import 'package:moose_core/adapters.dart';       // Adapter pattern
import 'package:moose_core/cache.dart';          // Caching system
import 'package:moose_core/services.dart';       // Utilities & helpers
```

### Basic Usage

```dart
import 'package:moose_core/moose_core.dart';

// 1. Create a plugin
class ProductsPlugin extends FeaturePlugin {
  @override
  String get name => 'products';

  @override
  String get version => '1.0.0';

  @override
  void onRegister() {
    // Register sections
    WidgetRegistry().register(
      'products.featured',
      (context, {data, onEvent}) => FeaturedProductsSection(
        settings: data?['settings'] as Map<String, dynamic>?,
      ),
    );
  }

  @override
  Map<String, WidgetBuilder>? getRoutes() {
    return {
      '/products': (context) => ProductsListScreen(),
    };
  }
}

// 2. Create a FeatureSection
class FeaturedProductsSection extends FeatureSection {
  const FeaturedProductsSection({super.key, super.settings});

  @override
  Map<String, dynamic> getDefaultSettings() {
    return {
      'title': 'Featured Products',
      'itemCount': 10,
      'showPrice': true,
    };
  }

  @override
  Widget build(BuildContext context) {
    // Access repository via adapters getter
    final repository = adapters.getRepository<ProductsRepository>();

    return BlocProvider(
      create: (context) => FeaturedProductsBloc(repository)
        ..add(LoadFeaturedProducts()),
      child: BlocBuilder<FeaturedProductsBloc, FeaturedProductsState>(
        builder: (context, state) {
          if (state is FeaturedProductsLoaded) {
            return _buildProducts(state.products);
          }
          return CircularProgressIndicator();
        },
      ),
    );
  }
}

// 3. Create a backend adapter
class WooCommerceAdapter extends BackendAdapter {
  @override
  String get name => 'woocommerce';

  @override
  String get version => '1.0.0';

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    // Register repository implementations
    registerRepositoryFactory<ProductsRepository>(
      () => WooProductsRepository(apiClient),
    );
    registerRepositoryFactory<CartRepository>(
      () => WooCartRepository(apiClient),
    );
  }
}
```

## Core Concepts

### Plugin System

Every feature is a self-contained plugin:

```dart
class MyPlugin extends FeaturePlugin {
  @override
  String get name => 'my_plugin';

  @override
  Future<void> initialize() async {
    // Initialize plugin resources
  }

  @override
  void onRegister() {
    // Register widgets, actions, hooks
  }

  @override
  Map<String, WidgetBuilder>? getRoutes() {
    // Define navigation routes
  }
}
```

### Repository Pattern

Abstract interfaces with backend-specific implementations:

```dart
// Core repository interface
abstract class ProductsRepository {
  Future<List<Product>> getProducts(ProductFilters? filters);
  Future<Product> getProductById(String id);
}

// Backend implementation
class WooProductsRepository implements ProductsRepository {
  @override
  Future<List<Product>> getProducts(ProductFilters? filters) async {
    // WooCommerce-specific implementation
  }
}
```

### FeatureSection Pattern

Configurable UI sections:

```dart
class MySection extends FeatureSection {
  const MySection({super.key, super.settings});

  @override
  Map<String, dynamic> getDefaultSettings() {
    return {
      'title': 'Default Title',
      'itemCount': 5,
    };
  }

  @override
  Widget build(BuildContext context) {
    final title = getSetting<String>('title');
    final count = getSetting<int>('itemCount');
    // Build UI...
  }
}
```

### Registry Systems

#### WidgetRegistry
Dynamic widget composition:
```dart
WidgetRegistry().register('my.widget', (context, {data, onEvent}) => MyWidget());
final widget = WidgetRegistry().build('my.widget', context);
```

#### AdapterRegistry
Backend adapter management:
```dart
AdapterRegistry().register(WooCommerceAdapter());
final repo = AdapterRegistry().getRepository<ProductsRepository>();
```

#### ActionRegistry
Custom action handling:
```dart
ActionRegistry().register('custom_action', (context, payload) async {
  // Handle action
});
ActionRegistry().execute('custom_action', context, payload);
```

## Architecture

```
┌─────────────────────────────────────────────┐
│         Presentation Layer                  │
│         (Screens, Sections)                 │
└──────────────────┬──────────────────────────┘
                   │ Events/States
┌──────────────────▼──────────────────────────┐
│         Business Logic (BLoC)               │
└──────────────────┬──────────────────────────┘
                   │ Repository Calls
┌──────────────────▼──────────────────────────┐
│         Repository Interfaces               │
└──────────────────┬──────────────────────────┘
                   │ Implementation
┌──────────────────▼──────────────────────────┐
│         Backend Adapters                    │
│         (WooCommerce, Shopify, etc.)        │
└─────────────────────────────────────────────┘
```

## Package Modules

The package is organized into focused modules for better maintainability and selective imports:

| Module | Description | Key Exports |
|--------|-------------|-------------|
| **entities.dart** | Domain entities | Product, Cart, Order, Category, etc. |
| **repositories.dart** | Repository interfaces | ProductsRepository, CartRepository, etc. |
| **plugin.dart** | Plugin system | FeaturePlugin, PluginRegistry |
| **widgets.dart** | UI components | FeatureSection, WidgetRegistry, AddonRegistry |
| **adapters.dart** | Adapter pattern | BackendAdapter, AdapterRegistry |
| **cache.dart** | Caching system | CacheManager, MemoryCache, PersistentCache |
| **services.dart** | Utilities & helpers | ActionRegistry, HookRegistry, ApiClient, Logger |

See [Migration Guide](docs/MIGRATION_MODULAR_STRUCTURE.md) for details on using modular imports.

## Documentation

- [Architecture Guide](docs/ai-ready/ARCHITECTURE.md) - Complete architectural patterns
- [Plugin System](docs/ai-ready/PLUGIN_SYSTEM.md) - Creating and using plugins
- [FeatureSection Guide](docs/ai-ready/FEATURE_SECTION.md) - Building configurable sections
- [Adapter Pattern](docs/ai-ready/ADAPTER_PATTERN.md) - Backend adapter implementation
- [Registries](docs/ai-ready/REGISTRIES.md) - Using registry systems
- [Anti-Patterns](docs/ai-ready/ANTI_PATTERNS.md) - What to avoid
- [API Reference](docs/ai-ready/API.md) - Complete API documentation
- [Migration Guide](docs/MIGRATION_MODULAR_STRUCTURE.md) - Modular structure migration

## Example Projects

See the [example](example/) directory for complete working examples:
- Basic plugin implementation
- Custom adapter creation
- FeatureSection usage
- Full app integration

## AI-Assisted Development

This package is designed for AI-assisted development with comprehensive AI-ready documentation. See [docs/ai-ready/README.md](docs/ai-ready/README.md) for:
- Architectural patterns for AI agents
- Code generation guidelines
- Anti-patterns to avoid
- Best practices

## Requirements

- Dart SDK: `>=3.0.0 <4.0.0`
- Flutter: `>=3.0.0`

## Dependencies

- `flutter_bloc` - State management
- `equatable` - Value equality
- `dio` - HTTP client
- `shared_preferences` - Local storage
- `intl` - Internationalization

## Contributing

Contributions are welcome! Please read our [Contributing Guide](CONTRIBUTING.md) for details.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

- [Documentation](https://github.com/yourusername/moose_core)
- [Issue Tracker](https://github.com/yourusername/moose_core/issues)
- [Discussions](https://github.com/yourusername/moose_core/discussions)

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.
