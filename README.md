# moose_core

[![pub package](https://img.shields.io/pub/v/moose_core.svg)](https://pub.dev/packages/moose_core)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

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
  moose_core: ^1.0.0
```

### Import Options

```dart
// Option 1: Import everything (recommended for most cases)
import 'package:moose_core/moose_core.dart';

// Option 2: Import specific modules (for optimized builds)
import 'package:moose_core/app.dart';            // MooseAppContext, MooseScope, MooseBootstrapper
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

// 1. Bootstrap the app with MooseAppContext + MooseScope
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CacheManager.initPersistentCache();
  final appContext = MooseAppContext();
  runApp(MooseScope(
    appContext: appContext,
    child: AppBootstrap(appContext: appContext),
  ));
}

class AppBootstrap extends StatefulWidget {
  final MooseAppContext appContext;
  const AppBootstrap({super.key, required this.appContext});
  @override State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    MooseBootstrapper(appContext: widget.appContext).run(
      config: {'adapters': {'woocommerce': {'baseUrl': 'https://mystore.com'}}},
      adapters: [WooCommerceAdapter()],
      plugins: [() => ProductsPlugin()],
    ).then((_) { if (mounted) setState(() => _ready = true); });
  }

  @override
  Widget build(BuildContext context) => _ready
      ? const MyApp()
      : const Scaffold(body: Center(child: CircularProgressIndicator()));
}

// 2. Create a plugin — use inherited registry getters (hookRegistry, widgetRegistry, etc.)
class ProductsPlugin extends FeaturePlugin {
  @override String get name => 'products';
  @override String get version => '1.0.0';

  @override
  void onRegister() {
    // widgetRegistry, hookRegistry, addonRegistry, etc. delegate to injected appContext
    widgetRegistry.register(
      'products.featured',
      (context, {data, onEvent}) => FeaturedProductsSection(
        settings: data?['settings'] as Map<String, dynamic>?,
      ),
    );
  }

  @override Future<void> onInit() async {}

  @override
  Map<String, WidgetBuilder>? getRoutes() => {
    '/products': (_) => ProductsListScreen(),
  };
}

// 3. Create a FeatureSection — use adaptersOf(context) inside build()
class FeaturedProductsSection extends FeatureSection {
  const FeaturedProductsSection({super.key, super.settings});

  @override
  Map<String, dynamic> getDefaultSettings() => {
    'title': 'FEATURED PRODUCTS',
    'itemCount': 10,
  };

  @override
  Widget build(BuildContext context) {
    final repository = adaptersOf(context).getRepository<ProductsRepository>();
    return BlocProvider(
      create: (_) => FeaturedProductsBloc(repository)
        ..add(const LoadFeaturedProducts()),
      child: BlocBuilder<FeaturedProductsBloc, FeaturedProductsState>(
        builder: (context, state) {
          if (state is FeaturedProductsLoaded) return _buildProducts(state.products);
          if (state is FeaturedProductsError) return Text(state.message);
          return const CircularProgressIndicator();
        },
      ),
    );
  }
}

// 4. Create a backend adapter — hookRegistry and eventBus are set before initializeFromConfig
class WooCommerceAdapter extends BackendAdapter {
  @override String get name => 'woocommerce';
  @override String get version => '1.0.0';

  @override
  Future<void> initializeFromConfig({ConfigManager? configManager}) async {
    registerRepositoryFactory<ProductsRepository>(
      () => WooProductsRepository(apiClient, hookRegistry: hookRegistry, eventBus: eventBus),
    );
    registerRepositoryFactory<CartRepository>(
      () => WooCartRepository(apiClient, hookRegistry: hookRegistry, eventBus: eventBus),
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
  void onRegister() {
    // widgetRegistry, hookRegistry, actionRegistry, etc. are available as
    // inherited getters backed by the injected MooseAppContext
    widgetRegistry.register('my.section', (ctx, {data, onEvent}) => MySection());
    hookRegistry.register('my:hook', (data) => processData(data));
    actionRegistry.register('my.action', (ctx, payload) async { /* ... */ });
  }

  @override
  Future<void> onInit() async {
    // Async initialization (called after all plugins are registered)
  }

  @override
  Map<String, WidgetBuilder>? getRoutes() => {
    '/my-route': (_) => MyScreen(),
  };
}
```

### Repository Pattern

Abstract interfaces with backend-specific implementations:

```dart
// Core repository interface (abstract, defined in moose_core)
abstract class ProductsRepository extends CoreRepository {
  Future<ProductListResult> getProducts({ProductFilters? filters});
  Future<Product> getProductById(String id);
}

// Backend implementation — forward hookRegistry and eventBus to super
class WooProductsRepository extends ProductsRepository {
  final ApiClient _apiClient;

  WooProductsRepository(this._apiClient, {
    required super.hookRegistry,
    required super.eventBus,
  });

  @override
  Future<ProductListResult> getProducts({ProductFilters? filters}) async {
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
Dynamic widget composition. In plugins use the inherited getter; in widgets use `context.moose`:
```dart
// In a plugin's onRegister():
widgetRegistry.register('my.widget', (context, {data, onEvent}) => MyWidget());

// In any widget's build(context):
final widget = context.moose.widgetRegistry.build('my.widget', context);
```

#### AdapterRegistry
Backend adapter management. In `FeatureSection.build()` use `adaptersOf(context)`:
```dart
// In a FeatureSection's build(context):
final repo = adaptersOf(context).getRepository<ProductsRepository>();

// In any other widget's build(context):
final repo = context.moose.adapterRegistry.getRepository<ProductsRepository>();
```

#### ActionRegistry
Custom action handling:
```dart
// In a plugin's onRegister():
actionRegistry.register('custom_action', (context, payload) async {
  // Handle action
});

// In any widget's build(context):
context.moose.actionRegistry.execute('custom_action', context, payload);
```

#### EventBus
Asynchronous event-driven communication between plugins:
```dart
// In a plugin — fire events using the inherited getter:
eventBus.fire(
  'cart.item.added',
  data: {'productId': 'prod-123', 'quantity': 2},
  metadata: {'cartTotal': 99.99},
);

// In a plugin — subscribe to events:
final subscription = eventBus.on('cart.item.added', (event) {
  final productId = event.data['productId'];
});

// Async event handlers:
eventBus.onAsync('order.placed', (event) async {
  await sendConfirmationEmail(event.data['orderId']);
});

// In a widget — use context.moose:
context.moose.eventBus.fire('my.event', data: {});

// Clean up
await subscription.cancel();
```

#### HookRegistry
Synchronous data transformation and service hooks:
```dart
// In a plugin's onRegister() — expose hooks using inherited getter:
hookRegistry.register('cart:get_cart_item_count', (data) {
  if (state is CartLoaded) return state.cart.itemCount;
  return 0;
});

hookRegistry.register('cart:item_count_stream', (data) {
  return cartBloc.stream.map((state) => state.totalItems).distinct();
});

// In a widget — consume hooks via context.moose:
final count = context.moose.hookRegistry.execute<int>('cart:get_cart_item_count', 0);
final stream = context.moose.hookRegistry.execute<Stream<int>>(
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
| **app.dart** | Scoped architecture | MooseAppContext, MooseScope, MooseBootstrapper |
| **entities.dart** | Domain entities | Product, Cart, Order, Category, etc. |
| **repositories.dart** | Repository interfaces | ProductsRepository, CartRepository, etc. |
| **plugin.dart** | Plugin system | FeaturePlugin, PluginRegistry |
| **widgets.dart** | UI components | FeatureSection, WidgetRegistry, AddonRegistry |
| **adapters.dart** | Adapter pattern | BackendAdapter, AdapterRegistry |
| **cache.dart** | Caching system | CacheManager, MemoryCache, PersistentCache |
| **services.dart** | Utilities & helpers | EventBus, HookRegistry, ActionRegistry, ApiClient, Logger |

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
