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
  ProductsRepository? _productsRepository;

  ProductsRepository _repository() {
    _productsRepository ??= adapterRegistry.getRepository<ProductsRepository>();
    return _productsRepository!;
  }

  @override
  String get name => 'products';

  @override
  String get version => '1.0.0';

  @override
  void onRegister() {
    // Register sections and pass dependencies explicitly
    widgetRegistry.register(
      'products.featured',
      (context, {data, onEvent}) => FeaturedProductsSection(
        repository: _repository(),
        settings: data?['settings'] as Map<String, dynamic>?,
      ),
    );
  }

  @override
  Map<String, WidgetBuilder>? getRoutes() => {
        '/products': (context) => ProductsListScreen(),
      };
}

// 2. Create a FeatureSection
class FeaturedProductsSection extends FeatureSection {
  final ProductsRepository repository;

  const FeaturedProductsSection({
    super.key,
    super.settings,
    required this.repository,
  });

  @override
  Map<String, dynamic> getDefaultSettings() => {
        'title': 'FEATURED PRODUCTS',
        'itemCount': 10,
      };

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => FeaturedProductsBloc(repository)
        ..add(const LoadFeaturedProducts()),
      child: BlocBuilder<FeaturedProductsBloc, FeaturedProductsState>(
        builder: (context, state) {
          if (state is FeaturedProductsLoaded) {
            return _buildProducts(state.products);
          }
          if (state is FeaturedProductsError) {
            return Text(state.message);
          }
          return const CircularProgressIndicator();
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
await AdapterRegistry().registerAdapter(() async {
  final adapter = WooCommerceAdapter();
  await adapter.initialize(config['woocommerce']);
  return adapter;
});

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

#### EventBus
Asynchronous event-driven communication between plugins:
```dart
// Fire events (fire-and-forget)
EventBus().fire(
  'cart.item.added',
  data: {
    'productId': 'prod-123',
    'quantity': 2,
  },
  metadata: {
    'cartTotal': 99.99,
  },
);

// Subscribe to events
final subscription = EventBus().on('cart.item.added', (event) {
  final productId = event.data['productId'];
  print('Item added: $productId');
});

// Async event handlers
EventBus().onAsync('order.placed', (event) async {
  await sendConfirmationEmail(event.data['orderId']);
});

// Clean up
await subscription.cancel();
```

#### HookRegistry
Synchronous data transformation and service hooks:
```dart
// Cart plugin exposes hooks
hookRegistry.register('cart:get_cart_item_count', (data) {
  if (state is CartLoaded) return state.cart.itemCount;
  return 0;
});

hookRegistry.register('cart:item_count_stream', (data) {
  return cartBloc.stream.map((state) => state.totalItems).distinct();
});

// Other plugins consume hooks
final count = hookRegistry.execute<int>('cart:get_cart_item_count', 0);
final stream = hookRegistry.execute<Stream<int>>(
  'cart:item_count_stream',
  const Stream<int>.empty(),
);
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
| **services.dart** | Utilities & helpers | EventBus, HookRegistry, ActionRegistry, ApiClient, Logger |

See [Migration Guide](doc/MIGRATION_MODULAR_STRUCTURE.md) for details on using modular imports.

## Documentation

- [Architecture Guide](doc/ai-ready/ARCHITECTURE.md) - Complete architectural patterns
- [Plugin System](doc/ai-ready/PLUGIN_SYSTEM.md) - Creating and using plugins
- [FeatureSection Guide](doc/ai-ready/FEATURE_SECTION.md) - Building configurable sections
- [Adapter Pattern](doc/ai-ready/ADAPTER_PATTERN.md) - Backend adapter implementation
- [Event System Guide](doc/ai-ready/EVENT_SYSTEM_GUIDE.md) - EventBus and HookRegistry usage
- [Registries](doc/ai-ready/REGISTRIES.md) - Using registry systems
- [Anti-Patterns](doc/ai-ready/ANTI_PATTERNS.md) - What to avoid
- [API Reference](doc/ai-ready/API.md) - Complete API documentation
- [Migration Guide](doc/MIGRATION_MODULAR_STRUCTURE.md) - Modular structure migration

## Example Projects

See the [example](example/) directory for complete working examples:
- Basic plugin implementation
- Custom adapter creation
- FeatureSection usage
- Full app integration

## AI-Assisted Development

This package is designed for AI-assisted development with comprehensive AI-ready documentation. See [doc/ai-ready/README.md](doc/ai-ready/README.md) for:
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

- [Documentation](https://github.com/greymooseinc/moose_core)
- [Issue Tracker](https://github.com/greymooseinc/moose_core/issues)
- [Discussions](https://github.com/greymooseinc/moose_core/discussions)

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for version history.
