
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

  /// JSON Schema describing this plugin's configuration surface
  Map<String, dynamic> get configSchema => {'type': 'object'};

  /// Default settings that are registered with ConfigManager
  Map<String, dynamic> getDefaultSettings() => const {};

  /// Called immediately after plugin registration
  void onRegister();

  /// Called during app initialization
  Future<void> initialize();

  /// Return routes provided by this plugin
  Map<String, WidgetBuilder>? getRoutes();

  /// Optional: bottom navigation tabs contributed by this plugin
  List<BottomTab> get bottomTabs => const [];

  /// Helper to read strongly typed settings for this plugin.
  /// Reads from the scoped ConfigManager injected via appContext.
  T getSetting<T>(String key) {
    return appContext.configManager.get('plugins:$name:settings:$key');
  }
}
```

#### Configuration Schema & Defaults

- Override `configSchema` with a JSON Schema definition so tools (and CI) can validate `environment.json`.
- Override `getDefaultSettings()` with a full tree of sensible defaults. The registry automatically registers these via `ConfigManager.registerPluginDefaults`, so any missing keys fall back to your code-defined values.
- Use `getSetting<T>('cache:ttl')` (or direct `ConfigManager().get(...)`) to read settings. The helper merges environment overrides with defaults transparently.
- See [PLUGIN_ADAPTER_CONFIG_GUIDE.md](./PLUGIN_ADAPTER_CONFIG_GUIDE.md) for end-to-end examples.

#### Distributing Plugin Settings to Internal Layers

Keep the plugin as the single owner of its configuration surface. When downstream widgets/BLoCs need config values:

1. Read settings in the plugin (via `getSetting`).
2. Pass them down explicitly (as constructor params, resolvers, or value objects).
3. Avoid letting random layers reach for `ConfigManager`—that couples them to global paths and defaults.

**Example – Blog filters**

```dart
class BlogPlugin extends FeaturePlugin {
  @override
  void onRegister() {
    widgetRegistry.register(
      'blog.latest_posts_section',
      (context, {data, onEvent}) => LatestPostsSection(
        settings: data?['settings'] as Map<String, dynamic>? ?? {},
        filterResolver: _getFilterConfig, // plugin-owned resolver
      ),
    );
  }

  Map<String, dynamic>? _getFilterConfig(String key) {
    final value = getSetting<Map<String, dynamic>>('filters:$key');
    return value != null ? Map<String, dynamic>.from(value) : null;
  }
}

class PostsBloc extends Bloc<PostsEvent, PostsState> {
  PostsBloc({
    required PostRepository repository,
    required HookRegistry hookRegistry,
    Map<String, dynamic>? Function(String key)? filterResolver,
  }) : _filterResolver = filterResolver;
}
```

This pattern keeps configuration logic in the plugin where it belongs while still giving internal layers the data they need.

### Bottom Navigation Tabs (AI Agent Guidance)

Bottom tabs are now declared directly on each plugin. **Do not** register the `bottom_tabs:filter_tabs` hook manually unless you have a truly dynamic/conditional scenario. Instead:

1. Override `List<BottomTab> get bottomTabs`.
2. Return a const list of tabs owned by the plugin.
3. Let `PluginRegistry` merge and expose them through the existing hooks (`bottom_tabs:get_tabs`, etc.).

```dart
class ProductsPlugin extends FeaturePlugin {
  @override
  String get name => 'products';

  @override
  List<BottomTab> get bottomTabs => const [
        BottomTab(
          id: 'products',
          label: 'Shop',
          icon: Icons.shopping_bag_outlined,
          activeIcon: Icons.shopping_bag,
          route: '/products',
        ),
      ];
}
```

If you need to toggle tabs at runtime (auth state, experiments, feature flags), keep `bottomTabs` minimal (or empty) and layer conditional logic through a hook:

```dart
class NotificationsPlugin extends FeaturePlugin {
  @override
  List<BottomTab> get bottomTabs => const [];

  @override
  void onRegister() {
    hookRegistry.register(
      'bottom_tabs:filter_tabs',
      (tabs) {
        if (tabs is! List<BottomTab>) return tabs;
        final isAuthenticated =
            hookRegistry.execute('auth:is_authenticated', false) as bool? ?? false;
        if (!isAuthenticated) return tabs;

        const alertsTab = BottomTab(
          id: 'alerts',
          label: 'Alerts',
          icon: Icons.notifications_outlined,
          activeIcon: Icons.notifications,
          route: '/alerts',
        );

        final index = tabs.indexWhere((t) => t.id == alertsTab.id);
        if (index != -1) {
          tabs[index] = alertsTab;
          return tabs;
        }
        return [...tabs, alertsTab];
      },
      priority: 10,
    );
  }
}
```

> **AI Agent Checklist:**  
> - Always start with the `bottomTabs` getter.  
> - Only fall back to hook registration for runtime/conditional needs.  
> - Keep tab ordering data in `environment.json` (`plugins.bottom_tabs.settings.tabs`).

#### Tab Ordering & Enablement

Order, enablement, and other navigation metadata now live in configuration rather than `BottomTab.extensions`:

```json
"plugins": {
  "bottom_tabs": {
    "settings": {
      "tabs": [
        { "id": "home", "order": 10, "enabled": true },
        { "id": "products", "order": 30, "enabled": true },
        { "id": "search", "order": 50, "enabled": true },
        { "id": "cart", "order": 100, "enabled": true }
      ]
    }
  }
}
```

`BottomTabsPlugin` merges this list with the `bottomTabs` declared by each plugin. Adjust configuration—not source code—when you need to reorder or hide tabs.

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

### Step 2: Bootstrap the Plugin

Plugins are registered and initialized through `MooseBootstrapper`, not `PluginRegistry` directly:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await CacheManager.initPersistentCache();

  final ctx = MooseAppContext();

  runApp(
    MooseScope(
      appContext: ctx,
      child: MaterialApp(home: AppBootstrapScreen(appContext: ctx)),
    ),
  );
}

class AppBootstrapScreen extends StatefulWidget {
  final MooseAppContext appContext;
  const AppBootstrapScreen({super.key, required this.appContext});
  @override State<AppBootstrapScreen> createState() => _State();
}

class _State extends State<AppBootstrapScreen> {
  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    final report = await MooseBootstrapper(appContext: widget.appContext).run(
      config: await loadConfig(), // your config map
      adapters: [WooCommerceAdapter()],
      plugins: [
        () => ProductsPlugin(),
        () => CartPlugin(),
        () => CheckoutPlugin(),
      ],
    );
    // navigate to main screen when done
  }
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

Use `getSetting<T>()` (which reads from the scoped `ConfigManager` via `appContext`):

```dart
class ProductsPlugin extends FeaturePlugin {
  @override
  Future<void> initialize() async {
    // getSetting reads from appContext.configManager automatically
    final cacheTTL = getSetting<int>('cache.productsTTL'); // falls back to getDefaultSettings()
    final perPage = getSetting<int>('perPage');
  }
}
```

## Plugin Lifecycle

### 1. Registration Phase — `PluginRegistry.register(plugin, appContext:)`

Triggered by `MooseBootstrapper.run(plugins: [...])` for each factory in the list.

- Plugin factory `() => MyPlugin()` is called — plugin instance is created
- **Configuration check**: PluginRegistry checks `plugins:{pluginName}` in environment.json via `appContext.configManager`
- If `active: false`, registration is skipped (plugin won't be registered or initialized)
- If `active: true` or no configuration exists, registration continues:
  - `plugin.appContext = appContext` — injects the scoped context
  - `plugin.onRegister()` is called immediately (sync)
  - Plugin is added to the registry

**Important**: If no plugin configuration exists in environment.json, the plugin is considered active by default.

### 2. Initialization Phase — `PluginRegistry.initializeAll()`

Triggered automatically by `MooseBootstrapper.run()` after all plugins are registered.

- `initialize()` is called on each active plugin (async, in registration order)
- Async resources are set up (network connections, caches, services)
- Routes are collected via `getRoutes()`

### 3. Runtime Phase

- Plugins respond to hooks via `hookRegistry`
- Custom actions are executed via `actionRegistry`
- Routes are available for navigation
- Sections are built from configuration via `widgetRegistry`

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
  void onRegister() {
    // Register sections in onRegister() (sync, before initialize())
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
  Future<void> initialize() async {
    // Async setup only (no widget registration here)
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

Plugin that handles user interactions (uses `actionRegistry` convenience getter, not `ActionRegistry()` singleton):

```dart
class SharePlugin extends FeaturePlugin {
  @override
  String get name => 'share';

  @override
  String get version => '1.0.0';

  @override
  void onRegister() {
    // Register custom action handlers via injected actionRegistry
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

**Always provide sensible defaults via `getDefaultSettings()`:**

```dart
class ProductsPlugin extends FeaturePlugin {
  @override
  Map<String, dynamic> getDefaultSettings() => {
    'cache': {'productsTTL': 300, 'categoriesTTL': 600},
    'perPage': 20,
    'enableReviews': false,
  };

  @override
  void onRegister() {
    // getSetting reads merged config (defaults + environment.json overrides)
    final cacheTTL = getSetting<int>('cache.productsTTL'); // → 300 if not overridden
    final perPage = getSetting<int>('perPage'); // → 20 if not overridden
  }
}
```

**Check plugin configuration for optional features:**

```dart
@override
void onRegister() {
  // Only register section if feature is enabled in config
  if (getSetting<bool>('enableReviews')) {
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
    // Use a scoped MooseAppContext — no singletons
    final appContext = MooseAppContext();
    final plugin = ProductsPlugin();

    // Inject context and call onRegister() (mirrors MooseBootstrapper behavior)
    appContext.pluginRegistry.register(plugin, appContext: appContext);

    expect(
      appContext.widgetRegistry.isRegistered('products.featured_section'),
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

## Plugin Documentation Standards

### Required Documentation Files

Every plugin **MUST** include comprehensive documentation:

#### README.md (Comprehensive AI-Ready Documentation)
**Location**: `lib/plugins/{plugin_name}/README.md`

**Purpose**: Complete AI-ready documentation guide (20-50 pages) that serves both as quick reference and comprehensive guide

**Required Sections** (in order):
1. **Header** - Title, last updated, version, target audience
2. **Overview** - What it does, architecture fit (2-3 paragraphs)
3. **Architecture** - BLoC layer, presentation layer, data layer
4. **Key Features** - Detailed feature descriptions with capabilities
5. **Widget Registry** - All registered widgets with table
6. **Routes** - All routes with arguments and examples
7. **Hook Points** - All hooks (data, event, addon) with examples
8. **Configuration** - Complete config examples with settings tables
9. **Usage Examples** - Real-world scenarios (3-5 examples)
10. **Advanced Customization** - Extension recipes with code (3-5)
11. **Integration with Other Plugins** - Cross-plugin patterns (3-5)
12. **Best Practices for AI Agents** - When to use, guidelines, pitfalls
13. **Troubleshooting** - Common issues with solutions
14. **File Structure** - Complete directory tree
15. **Dependencies** - Core and external dependencies
16. **Future Enhancements** (optional)
17. **Version History**
18. **Support** - Where to get help

### Documentation Quality Standards

All plugin documentation **MUST**:
- ✅ **Be Accurate**: Reflect actual implementation
- ✅ **Include Code Examples**: Working code for every pattern
- ✅ **Document Hook Points**: All extensibility points with examples
- ✅ **Show Configuration**: Complete JSON config examples
- ✅ **Explain WHY**: Not just what, but why certain patterns exist
- ✅ **Cross-Reference**: Link to related docs (ARCHITECTURE.md, REGISTRIES.md)
- ✅ **Target AI Agents**: Write for AI-first, humans second
- ✅ **Show Integration**: How plugin works with others
- ✅ **Include Troubleshooting**: Common issues and solutions
- ✅ **Document Extensions**: How to extend without modifying

### Documentation Format

- **Use Markdown**: All documentation in `.md` format
- **Use Tables**: For settings, hooks, and widget registry
- **Use Code Blocks**: With language hints (dart, json)
- **Use Headings**: Clear hierarchy (H1 → H2 → H3)
- **Use Lists**: For features, steps, and options
- **Use Links**: Cross-reference related documentation

### Hook Documentation Format

For every hook point, document:

```markdown
#### `{hook_name}`
Brief description of what the hook does.

**Data Provided**:
- `field1`: Type - Description
- `field2`: Type - Description

**Usage**:
\`\`\`dart
hookRegistry.register('{hook_name}', (data) {
  // Example implementation
  return modifiedData;
}, priority: 10);
\`\`\`
```

### Configuration Documentation Format

For every configurable section, provide:

```markdown
#### {Section Name}

\`\`\`json
{
  "name": "{plugin}.{section}",
  "settings": {
    "setting1": value1,
    "setting2": value2
  }
}
\`\`\`

**Settings**:
| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| `setting1` | Type | Default | What it does |
| `setting2` | Type | Default | What it does |
```

### Example README.md Structure

```markdown
# {Plugin Name} Plugin

> Comprehensive AI-ready documentation for the {Plugin Name} plugin

**Last Updated**: YYYY-MM-DD
**Version**: X.X.X
**Target Audience**: AI Agents & Developers

## Table of Contents
1. [Overview](#overview)
2. [Architecture](#architecture)
3. [Key Features](#key-features)
4. [Widget Registry](#widget-registry)
5. [Routes](#routes)
6. [Hook Points](#hook-points)
7. [Configuration](#configuration)
8. [Usage Examples](#usage-examples)
9. [Advanced Customization](#advanced-customization)
10. [Integration with Other Plugins](#integration-with-other-plugins)
11. [Best Practices for AI Agents](#best-practices-for-ai-agents)
12. [Troubleshooting](#troubleshooting)
13. [File Structure](#file-structure)
14. [Dependencies](#dependencies)
15. [Version History](#version-history)

## Overview

[2-3 paragraphs describing what the plugin does, its role in the architecture]

## Quick Start

\`\`\`json
{
  "sections": [
    {
      "name": "{plugin}.{section}",
      "settings": { ... }
    }
  ]
}
\`\`\`

[Continue with all 18 required sections...]
```

### Examples to Follow

Reference these plugins for documentation standards:
- **Products Plugin**: [lib/plugins/products/README.md](../../flutter_shopping_app/lib/plugins/products/README.md) - E-commerce functionality
- **Blog Plugin**: [lib/plugins/blog/README.md](../../flutter_shopping_app/lib/plugins/blog/README.md) - Content management
- **Share Plugin**: [lib/plugins/share/README.md](../../flutter_shopping_app/lib/plugins/share/README.md) - Cross-plugin integration

### AI Agent Instructions

When creating a new plugin, **ALWAYS**:

1. ✅ Create comprehensive `README.md` in the plugin directory
2. ✅ Follow the exact 18-section structure above
3. ✅ Document ALL hook points with examples
4. ✅ Provide complete configuration tables
5. ✅ Include 3-5 usage examples
6. ✅ Include 3-5 extension recipes
7. ✅ Include 3-5 integration examples
8. ✅ Add troubleshooting section
9. ✅ Cross-reference related documentation
10. ✅ Update README.md whenever code changes

**Do NOT**:
- ❌ Skip the README.md file
- ❌ Create incomplete documentation
- ❌ Put plugin docs in `docs/ai-ready/` (keep them with the plugin)
- ❌ Forget to update when code changes
- ❌ Write only for humans (AI agents are primary audience)

## Related Documentation

- **[ARCHITECTURE.md](./ARCHITECTURE.md)** - Overall architecture
- **[FEATURE_SECTION.md](./FEATURE_SECTION.md)** - Creating sections
- **[REGISTRIES.md](./REGISTRIES.md)** - Registry systems
- **[ANTI_PATTERNS.md](./ANTI_PATTERNS.md)** - What to avoid

## Reference Implementations

Plugins with exemplary documentation:
- `lib/plugins/products/` - Complete e-commerce plugin
- `lib/plugins/blog/` - Content management plugin
- `lib/plugins/share/` - Cross-plugin integration example

---

**Last Updated:** 2026-02-22
**Version:** 3.0.0

## Changelog

### Version 3.0.0 (2026-02-22)
- Replaced `PluginRegistry.registerPlugin()` + `initialize()` with `MooseBootstrapper.run(plugins: [...])` pattern
- `FeaturePlugin.getSetting<T>()` now reads from scoped `appContext.configManager` (not `ConfigManager()` singleton)
- Plugin registration uses `PluginRegistry.register(plugin, appContext:)` + `initializeAll()` (split lifecycle)
- `PluginRegistry.getPluginConfig()` usage replaced by `getSetting<T>()` + `getDefaultSettings()`
- Integration tests updated to use `MooseAppContext` instead of `WidgetRegistry()` singleton
- Widget/addon registration moved to `onRegister()` (sync); `initialize()` reserved for async I/O

### Version 2.3.0 (2025-11-10)
- Documented `configSchema`, `getDefaultSettings()`, and `getSetting()` on `FeaturePlugin`
- Refreshed bottom tab guidance to remove `extensions['order']` usage and point to `environment.json`
- Added configuration order/enablement instructions for the `bottom_tabs` plugin

### Version 2.2.0 (2025-11-11)
- **Updated Plugin Documentation Standards** section
- Changed to single comprehensive README.md file per plugin
- Simplified documentation structure (removed separate DOCUMENTATION.md)
- Updated AI agent instructions for single-file approach
- Updated example references to new structure

### Version 2.1.0 (2025-11-11)
- **Added Plugin Documentation Standards** section
- Required documentation files: README.md and DOCUMENTATION.md
- Defined 18 required sections for comprehensive documentation
- Documentation quality standards and format guidelines
- Hook and configuration documentation formats
- AI agent instructions for creating plugin documentation
- Reference implementations (Products, Blog, Share plugins)

### Version 2.0.0 (2025-11-06)
- Added plugin configuration support with `active` flag and `settings` section
- Updated plugin lifecycle to check configuration during registration
- Added `PluginConfig` entity for type-safe plugin configuration
- Added `getPluginConfig()` method to PluginRegistry
- Documented plugin configuration best practices
- Updated section configuration to support `active` flag
- Moved cache configuration from root level to `settings` section
