# Plugin System Guide

> Complete guide to creating and managing plugins in moose_core

## Table of Contents
- [Overview](#overview)
- [Plugin Architecture](#plugin-architecture)
- [Creating a Plugin](#creating-a-plugin)
- [Plugin Lifecycle](#plugin-lifecycle)
- [Registration Patterns](#registration-patterns)
- [Best Practices](#best-practices)

## Overview

The Plugin System is the foundation of the moose_core architecture. Every major feature is encapsulated in a self-contained plugin that can be independently developed, tested, and maintained.

### Key Features

- **Plugin Configuration**: Enable/disable plugins and configure settings via environment.json
- **Lifecycle Management**: Automatic registration, initialization, and activation control
- **Default Active**: Plugins are active by default if no configuration exists
- **Settings Support**: Each plugin can have its own settings section
- **Section Management**: Sections can be individually activated/deactivated
- **Registry Access**: Plugins have access to hooks, widgets, adapters, actions, and event bus

## Plugin Architecture

### FeaturePlugin Base Class

```dart
abstract class FeaturePlugin {
  /// Unique identifier for the plugin
  String get name;

  /// Semantic version of the plugin
  String get version;

  /// Called immediately after plugin registration
  /// Use this for registering hooks, actions, and other registries
  void onRegister();

  /// Called during app initialization
  /// Use this for async setup, registering sections, and routes
  Future<void> initialize();

  /// Return routes provided by this plugin
  /// Routes will be merged into the app's routing table
  Map<String, WidgetBuilder>? getRoutes();
}
```

### Plugin Responsibilities

A plugin should:
- ✅ Define its own routes
- ✅ Register sections with WidgetRegistry
- ✅ Register hooks with HookRegistry
- ✅ Register custom actions with ActionRegistry
- ✅ Initialize plugin-specific resources
- ✅ Provide clear metadata (name, version)

A plugin should NOT:
- ❌ Depend on other plugins directly
- ❌ Modify other plugins' state
- ❌ Access private implementation details of other plugins
- ❌ Contain backend-specific code (use adapters)

## Creating a Plugin

### Step 1: Extend FeaturePlugin

```dart
import 'package:moose_core/moose_core.dart';

class ProductsPlugin extends FeaturePlugin {
  @override
  String get name => 'products';

  @override
  String get version => '1.0.0';

  @override
  void onRegister() {
    // Register hooks
    hookRegistry.register('products:after_load', (products) {
      // Allow other plugins to modify products
      return products;
    });

    // Register custom actions
    actionRegistry.registerCustomHandler('view_product', (context, params) {
      final productId = params?['productId'] as String?;
      if (productId != null) {
        Navigator.pushNamed(context, '/product', arguments: productId);
      }
    });
  }

  @override
  Future<void> initialize() async {
    // Register sections
    widgetRegistry.register(
      'products.featured_section',
      (context, {data, onEvent}) => FeaturedProductsSection(
        settings: data?['settings'] as Map<String, dynamic>?,
      ),
    );

    widgetRegistry.register(
      'products.list_section',
      (context, {data, onEvent}) => ProductsListSection(
        settings: data?['settings'] as Map<String, dynamic>?,
      ),
    );

    // Initialize resources
    await _initializeProductCategories();
  }

  @override
  Map<String, WidgetBuilder>? getRoutes() {
    return {
      '/products': (context) => ProductsListScreen(),
      '/product': (context) {
        final productId = ModalRoute.of(context)?.settings.arguments as String?;
        return ProductDetailScreen(productId: productId);
      },
      '/products/category': (context) => CategoryProductsScreen(),
    };
  }

  Future<void> _initializeProductCategories() async {
    // Initialize plugin-specific resources
  }
}
```

### Step 2: Register the Plugin

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final pluginRegistry = PluginRegistry();

  // Register plugins
  await pluginRegistry.registerPlugin(() => ProductsPlugin());
  await pluginRegistry.registerPlugin(() => CartPlugin());
  await pluginRegistry.registerPlugin(() => CheckoutPlugin());

  runApp(MyApp(pluginRegistry: pluginRegistry));
}
```

## Plugin Configuration

Plugins can be configured in `environment.json` under the `plugins` key. Each plugin can have:

- **active**: Boolean flag to enable/disable the plugin (default: `true`)
- **settings**: Plugin-specific configuration (cache settings, API keys, etc.)
- **sections**: Widget sections configuration for the plugin

### Configuration Example

```json
{
  "plugins": {
    "products": {
      "active": true,
      "settings": {
        "cache": {
          "productsTTL": 300,
          "categoriesTTL": 600,
          "collectionsTTL": 600
        },
        "perPage": 20,
        "enableReviews": true
      },
      "sections": {
        "main": [
          {
            "name": "product.featured_section",
            "description": "Featured products carousel",
            "active": true,
            "settings": {
              "title": "Featured Products",
              "perPage": 10
            }
          }
        ]
      }
    },
    "analytics": {
      "active": false,
      "settings": {
        "trackingId": "UA-123456-1"
      }
    }
  }
}
```

### Accessing Plugin Configuration

```dart
class ProductsPlugin extends FeaturePlugin {
  @override
  Future<void> initialize() async {
    final registry = PluginRegistry();
    final config = registry.getPluginConfig('products');

    // Access settings
    final cacheTTL = config.getSetting<int>('cache.productsTTL') ?? 300;
    final perPage = config.getSetting<int>('perPage') ?? 20;

    print('Products plugin active: ${config.active}');
    print('Cache TTL: $cacheTTL seconds');
  }
}
```

## Plugin Lifecycle

### 1. Registration Phase

```dart
await pluginRegistry.registerPlugin(() => MyPlugin());
```

- Plugin factory function is called
- Plugin instance is created
- **Configuration check**: PluginRegistry checks `plugins:{pluginName}` in environment.json
- If `active: false`, registration is skipped (plugin won't be registered or initialized)
- If `active: true` or no configuration exists, registration continues:
  - `onRegister()` is called immediately
  - Plugin is added to the registry

**Important**: If no plugin configuration exists in environment.json, the plugin is considered active by default.

### 2. Initialization Phase

```dart
// Happens automatically after registration
```

- `initialize()` is called on each active plugin
- Async resources are set up
- Sections are registered with WidgetRegistry
- Routes are collected

### 3. Runtime Phase

- Plugins respond to hooks
- Custom actions are executed
- Routes are available for navigation
- Sections are built from configuration

## Registration Patterns

### Pattern 1: Basic Plugin

Minimal plugin with just routes:

```dart
class BasicPlugin extends FeaturePlugin {
  @override
  String get name => 'basic';

  @override
  String get version => '1.0.0';

  @override
  void onRegister() {
    // No hooks or actions needed
  }

  @override
  Future<void> initialize() async {
    // No async setup needed
  }

  @override
  Map<String, WidgetBuilder>? getRoutes() {
    return {
      '/basic': (context) => BasicScreen(),
    };
  }
}
```

### Pattern 2: Plugin with Sections

Plugin that provides configurable sections:

```dart
class HomePlugin extends FeaturePlugin {
  @override
  String get name => 'home';

  @override
  String get version => '1.0.0';

  @override
  void onRegister() {}

  @override
  Future<void> initialize() async {
    // Register multiple sections
    widgetRegistry.register(
      'home.hero_section',
      (context, {data, onEvent}) => HeroSection(
        settings: data?['settings'] as Map<String, dynamic>?,
      ),
    );

    widgetRegistry.register(
      'home.promo_section',
      (context, {data, onEvent}) => PromoSection(
        settings: data?['settings'] as Map<String, dynamic>?,
      ),
    );
  }

  @override
  Map<String, WidgetBuilder>? getRoutes() {
    return {
      '/': (context) => HomeScreen(),
    };
  }
}
```

### Pattern 3: Plugin with Hooks

Plugin that provides extensibility points:

```dart
class CartPlugin extends FeaturePlugin {
  late CartBloc _cartBloc;

  @override
  String get name => 'cart';

  @override
  String get version => '1.0.0';

  @override
  void onRegister() {
    // Register hooks for cart operations
    hookRegistry.register('cart:add_to_cart', (data) {
      if (data is Map<String, dynamic>) {
        final productId = data['product_id']?.toString();
        final quantity = data['quantity'] as int? ?? 1;

        if (productId != null) {
          _cartBloc.add(AddToCart(
            productId: productId,
            quantity: quantity,
          ));
        }
      }
      return data;
    });

    hookRegistry.register('cart:get_cart_item_count', (data) {
      if (_cartBloc.state is CartLoaded) {
        final state = _cartBloc.state as CartLoaded;
        return state.cart.itemCount;
      }
      return 0;
    });
  }

  @override
  Future<void> initialize() async {
    final repository = adapterRegistry.getRepository<CartRepository>();
    _cartBloc = CartBloc(repository);
  }

  @override
  Map<String, WidgetBuilder>? getRoutes() {
    return {
      '/cart': (context) => CartScreen(cartBloc: _cartBloc),
    };
  }
}
```

### Pattern 4: Plugin with Custom Actions

Plugin that handles user interactions:

```dart
class SharePlugin extends FeaturePlugin {
  @override
  String get name => 'share';

  @override
  String get version => '1.0.0';

  @override
  void onRegister() {
    // Register custom action handlers
    actionRegistry.registerCustomHandler('share_product', (context, params) {
      final productId = params?['productId'] as String?;
      final productName = params?['productName'] as String?;
      final productUrl = params?['productUrl'] as String?;

      if (productUrl != null) {
        Share.share(
          'Check out $productName: $productUrl',
          subject: productName,
        );
      }
    });

    actionRegistry.registerCustomHandler('share_cart', (context, params) {
      final cartUrl = params?['cartUrl'] as String?;
      if (cartUrl != null) {
        Share.share('My shopping cart: $cartUrl');
      }
    });
  }

  @override
  Future<void> initialize() async {}

  @override
  Map<String, WidgetBuilder>? getRoutes() => null;
}
```

## Best Practices

### Plugin Configuration

**Always provide sensible defaults:**

```dart
class ProductsPlugin extends FeaturePlugin {
  @override
  Future<void> initialize() async {
    final registry = PluginRegistry();
    final config = registry.getPluginConfig('products');

    // Provide fallback values
    final cacheTTL = config.getSetting<int>('cache.productsTTL') ?? 300;
    final perPage = config.getSetting<int>('perPage') ?? 20;
  }
}
```

**Check plugin configuration for optional features:**

```dart
@override
Future<void> initialize() async {
  final config = PluginRegistry().getPluginConfig('products');

  // Only enable feature if configured
  if (config.getSetting<bool>('enableReviews') == true) {
    widgetRegistry.register('product.reviews_section', ...);
  }
}
```

**Use nested settings for organization:**

```json
{
  "plugins": {
    "products": {
      "settings": {
        "cache": {
          "productsTTL": 300,
          "categoriesTTL": 600
        },
        "display": {
          "perPage": 20,
          "gridColumns": 2
        },
        "features": {
          "enableReviews": true,
          "enableWishlist": true
        }
      }
    }
  }
}
```

### Disabling Plugins

Plugins can be disabled in environment.json without removing their configuration:

```json
{
  "plugins": {
    "analytics": {
      "active": false,
      "settings": {
        "trackingId": "UA-123456-1"
      }
    }
  }
}
```

When a plugin is inactive:
- ✅ Registration is skipped (saves resources)
- ✅ `onRegister()` is never called
- ✅ `initialize()` is never called
- ✅ Routes are not added to the app
- ✅ Sections are not registered
- ❌ Plugin cannot be retrieved with `getPlugin()`

### Plugin Naming

Use clear, descriptive names:

```dart
// Good
'products'
'cart'
'checkout'
'user_profile'
'wishlist'

// Bad
'prod'
'p'
'feature1'
```

### Plugin Versioning

Follow semantic versioning:

```dart
@override
String get version => '1.0.0';  // MAJOR.MINOR.PATCH
```

- **MAJOR**: Breaking changes
- **MINOR**: New features (backward compatible)
- **PATCH**: Bug fixes

### Plugin Independence

Plugins should be independent:

```dart
// ❌ BAD: Direct dependency
class CheckoutPlugin extends FeaturePlugin {
  final CartPlugin cartPlugin;  // Direct dependency!

  CheckoutPlugin(this.cartPlugin);
}

// ✅ GOOD: Use hooks
class CheckoutPlugin extends FeaturePlugin {
  @override
  void onRegister() {
    // Communicate through hooks
    hookRegistry.register('checkout:get_cart', (data) {
      return hookRegistry.execute('cart:get_current_cart', null);
    });
  }
}
```

### Resource Management

Clean up resources when needed:

```dart
class NotificationsPlugin extends FeaturePlugin {
  StreamSubscription? _subscription;

  @override
  Future<void> initialize() async {
    final repo = adapterRegistry.getRepository<NotificationRepository>();
    _subscription = repo.onNotificationReceived.listen((notification) {
      // Handle notification
    });
  }

  void dispose() {
    _subscription?.cancel();
  }
}
```

### Error Handling

Handle errors gracefully:

```dart
@override
Future<void> initialize() async {
  try {
    await _initializeResources();
  } catch (e) {
    print('Failed to initialize ${name} plugin: $e');
    // Gracefully degrade or rethrow
  }
}
```

### Documentation

Document your plugin:

```dart
/// Products Plugin
///
/// Provides product browsing, searching, and filtering functionality.
///
/// **Sections:**
/// - `products.featured_section`: Featured products display
/// - `products.list_section`: Product list with filters
///
/// **Routes:**
/// - `/products`: Products list screen
/// - `/product`: Product detail screen (requires productId argument)
///
/// **Hooks:**
/// - `products:after_load`: Allows modification of loaded products
/// - `products:before_search`: Allows modification of search parameters
///
/// **Custom Actions:**
/// - `view_product`: Navigate to product detail (params: productId)
class ProductsPlugin extends FeaturePlugin {
  // ...
}
```

## Testing Plugins

### Unit Testing

```dart
void main() {
  group('ProductsPlugin', () {
    late ProductsPlugin plugin;

    setUp(() {
      plugin = ProductsPlugin();
    });

    test('has correct name', () {
      expect(plugin.name, equals('products'));
    });

    test('has correct version', () {
      expect(plugin.version, equals('1.0.0'));
    });

    test('provides routes', () {
      final routes = plugin.getRoutes();
      expect(routes, isNotNull);
      expect(routes?['/products'], isNotNull);
      expect(routes?['/product'], isNotNull);
    });
  });
}
```

### Integration Testing

```dart
void main() {
  testWidgets('ProductsPlugin registers sections', (tester) async {
    final plugin = ProductsPlugin();
    final widgetRegistry = WidgetRegistry();

    await plugin.initialize();

    expect(
      widgetRegistry.isRegistered('products.featured_section'),
      isTrue,
    );
  });
}
```

## Common Patterns

### Lazy Plugin Initialization

```dart
class AnalyticsPlugin extends FeaturePlugin {
  Analytics? _analytics;

  Analytics get analytics {
    _analytics ??= Analytics();
    return _analytics!;
  }

  @override
  Future<void> initialize() async {
    // Don't initialize analytics until first use
  }
}
```

### Conditional Plugin Features

```dart
class PremiumPlugin extends FeaturePlugin {
  @override
  Future<void> initialize() async {
    final isPremium = await checkPremiumStatus();

    if (isPremium) {
      // Register premium features
      widgetRegistry.register('premium.exclusive_section', ...);
    }
  }
}
```

### Plugin Composition

```dart
class EcommercePlugin extends FeaturePlugin {
  late final ProductsPlugin _productsPlugin;
  late final CartPlugin _cartPlugin;
  late final CheckoutPlugin _checkoutPlugin;

  @override
  Future<void> initialize() async {
    _productsPlugin = ProductsPlugin();
    _cartPlugin = CartPlugin();
    _checkoutPlugin = CheckoutPlugin();

    await _productsPlugin.initialize();
    await _cartPlugin.initialize();
    await _checkoutPlugin.initialize();
  }

  @override
  Map<String, WidgetBuilder>? getRoutes() {
    return {
      ...?_productsPlugin.getRoutes(),
      ...?_cartPlugin.getRoutes(),
      ...?_checkoutPlugin.getRoutes(),
    };
  }
}
```

## Related Documentation

- **[ARCHITECTURE.md](./ARCHITECTURE.md)** - Overall architecture
- **[FEATURE_SECTION.md](./FEATURE_SECTION.md)** - Creating sections
- **[REGISTRIES.md](./REGISTRIES.md)** - Registry systems
- **[ANTI_PATTERNS.md](./ANTI_PATTERNS.md)** - What to avoid

---

**Last Updated:** 2025-11-06
**Version:** 2.0.0

## Changelog

### Version 2.0.0 (2025-11-06)
- Added plugin configuration support with `active` flag and `settings` section
- Updated plugin lifecycle to check configuration during registration
- Added `PluginConfig` entity for type-safe plugin configuration
- Added `getPluginConfig()` method to PluginRegistry
- Documented plugin configuration best practices
- Updated section configuration to support `active` flag
- Moved cache configuration from root level to `settings` section
