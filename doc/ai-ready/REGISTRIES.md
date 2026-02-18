# Registry Systems Guide

> Comprehensive guide to the four core registry systems: HookRegistry, WidgetRegistry, AddonRegistry, and ActionRegistry

## Table of Contents
- [Overview](#overview)
- [HookRegistry](#hookregistry)
- [WidgetRegistry](#widgetregistry)
- [AddonRegistry](#addonregistry)
- [ActionRegistry](#actionregistry)
- [Best Practices](#best-practices)

---

## Overview

The application uses four singleton registry systems to provide extensibility, modularity, and loose coupling between components:

| Registry | Purpose | Use When |
|----------|---------|----------|
| **HookRegistry** | Data transformation and event interception | Need to modify data flow without changing source code |
| **WidgetRegistry** | Dynamic section creation and composition | Building configurable UI screens from JSON config |
| **AddonRegistry** | Injecting optional UI widgets into named slots | Adding supplementary widgets (badges, banners, overlays) to existing sections |
| **ActionRegistry** | User interaction handling | Processing taps, clicks, and custom actions |

---

## HookRegistry

### Purpose
HookRegistry provides a **filter/action hook system** similar to WordPress hooks. It allows plugins and components to intercept and modify data at specific execution points without modifying the original code.

### Location
```
lib/src/events/hook_registry.dart
```

### Core API

```dart
class HookRegistry {
  // Singleton instance
  factory HookRegistry() => _instance;
  static HookRegistry get instance => _instance;

  /// Register a hook callback
  /// @param hookName - Name of the hook point
  /// @param callback - Function that receives and returns data
  /// @param priority - Execution order (higher = earlier, default: 1)
  void register(String hookName, dynamic Function(dynamic) callback, {int priority = 1});

  /// Execute all registered hooks for a hook point
  /// @param hookName - Name of the hook point
  /// @param data - Initial data to pass through hooks
  /// @returns Transformed data after all hooks execute
  T execute<T>(String hookName, T data);

  /// Remove a specific hook callback
  void removeHook(String hookName, dynamic Function(dynamic) callback);

  /// Clear all hooks for a hook point
  void clearHooks(String hookName);

  /// Clear all hooks
  void clearAllHooks();

  /// Check if a hook has any registered callbacks
  bool hasHook(String hookName);

  /// Get count of registered callbacks for a hook
  int getHookCount(String hookName);

  /// Get all registered hook names
  List<String> getRegisteredHooks();
}
```

### Usage Examples

#### Example 1: Modifying Product Data After Load

**Register Hook (in plugin):**
```dart
class CustomPlugin extends FeaturePlugin {
  @override
  void onRegister() {
    hookRegistry.register('product:after_load_product', (product) {
      // Add 10% discount to all products
      final p = product as Product;
      return p.copyWith(price: p.price * 0.9);
    }, priority: 10);
  }
}
```

**Execute Hook (in repository):**
```dart
class WooProductsRepository extends ProductsRepository {
  @override
  Future<Product> getProductById(String id) async {
    // ... fetch product from API ...
    Product product = WooProductMapper.toEntity(dto);

    // Execute hooks - allows plugins to modify product
    product = hookRegistry.execute('product:after_load_product', product);

    return product;
  }
}
```

#### Example 2: Cart Operations

**Register Cart Hooks:**
```dart
class CartPlugin extends FeaturePlugin {
  @override
  void onRegister() {
    // Hook for adding items to cart
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

    // Hook to get cart item count
    hookRegistry.register('cart:get_cart_item_count', (data) {
      if (_cartBloc.state is CartLoaded) {
        final state = _cartBloc.state as CartLoaded;
        return state.cart.itemCount;
      }
      return 0;
    });
  }
}
```

**Trigger Cart Hooks:**
```dart
// From any widget or component
final hookRegistry = HookRegistry();

// Add item to cart without direct dependency on CartPlugin
hookRegistry.execute('cart:add_to_cart', {
  'product_id': '123',
  'quantity': 2,
  'metadata': {'source': 'quick_add'},
});

// Get cart item count
int itemCount = hookRegistry.execute('cart:get_cart_item_count', 0);
```

#### Example 3: Analytics Tracking

```dart
class AnalyticsPlugin extends FeaturePlugin {
  @override
  void onRegister() {
    // Track checkout events
    hookRegistry.register('after_checkout', (order) {
      analytics.logPurchase(
        orderId: order.id,
        total: order.total,
        items: order.items,
      );
      return order; // Always return data for next hook
    });

    // Track product views
    hookRegistry.register('product:after_load_product', (product) {
      analytics.logProductView(product.id);
      return product;
    }, priority: 5); // Lower priority runs later
  }
}
```

### Available Hook Points

#### Product Hooks
- `product:before_load_products` - Modify product filters before API call
- `product:after_load_product` - Modify product data after loading single product
- `before_load_product_request` - Modify product ID before fetch
- `after_load_product_response` - Modify raw API response

#### Cart Hooks
- `cart:add_to_cart` - Trigger add to cart action
- `cart:get_cart_state` - Retrieve current cart state
- `cart:get_cart_item_count` - Get cart item count
- `cart:refresh_cart` - Trigger cart refresh
- `cart:clear_cart` - Clear cart
- `after_get_cart` - Modify cart after fetching
- `after_add_cart_item` - Modify cart after adding item

#### Checkout Hooks
- `before_checkout` - Modify checkout request before submission
- `after_checkout` - Process order after checkout

### Hook Priority

Hooks execute in **descending priority order** (highest first):

```dart
hookRegistry.register('my_hook', callback1, priority: 10); // Runs first
hookRegistry.register('my_hook', callback2, priority: 5);  // Runs second
hookRegistry.register('my_hook', callback3, priority: 1);  // Runs third (default)
```

### Best Practices

✅ **DO:**
- Always return the data (potentially modified)
- Use descriptive hook names with namespace (e.g., `plugin:action`)
- Document your hook points in plugin documentation
- Handle errors gracefully - hooks continue executing even if one fails
- Use priority to control execution order when needed

❌ **DON'T:**
- Modify data types (return same type as received)
- Create side effects without returning data
- Use hooks for direct widget rendering (use WidgetRegistry instead)
- Rely on hook execution order without setting priority

---

## WidgetRegistry

### Purpose
WidgetRegistry enables **dynamic widget composition** from JSON configuration. It maps string identifiers to widget builder functions, allowing UI layouts to be configured at runtime without code changes.

### Location
```
lib/src/widgets/widget_registry.dart
```

### Core API

```dart
class WidgetRegistry {
  // Singleton instance
  factory WidgetRegistry() => _instance;
  static WidgetRegistry get instance => _instance;

  /// Register a section builder
  /// @param name - Unique identifier for the section
  /// @param builder - Function that builds the FeatureSection
  void register(String name, SectionBuilderFn builder);

  /// Build a single widget by name
  /// @param name - Widget identifier
  /// @param context - Build context
  /// @param data - Optional configuration data
  /// @param onEvent - Optional event callback
  Widget build(String name, BuildContext context, {
    Map<String, dynamic>? data,
    void Function(String event, dynamic payload)? onEvent,
  });

  /// Build multiple widgets from a plugin's section group config
  /// @param context - Build context
  /// @param pluginName - Plugin name (matches plugin key in environment.json)
  /// @param groupName - Section group name (e.g., 'main', 'featured')
  /// @param data - Optional shared data passed to all sections
  /// @param onEvent - Optional event callback passed to all sections
  List<Widget> buildSectionGroup(BuildContext context, {
    required String pluginName,
    required String groupName,
    Map<String, dynamic>? data,
    void Function(String event, dynamic payload)? onEvent,
  });

  /// Get section configs for a plugin's group from environment.json
  List<SectionConfig> getSections(String pluginName, String groupName);

  /// Check if widget is registered
  bool isRegistered(String name);

  /// Get all registered widget names
  List<String> getRegisteredWidgets();

  /// Unregister a widget
  void unregister(String name);
}

/// Section builder function type - returns a FeatureSection (not a plain Widget)
typedef SectionBuilderFn = FeatureSection Function(
  BuildContext context, {
  Map<String, dynamic>? data,
  void Function(String event, dynamic payload)? onEvent,
});
```

### Usage Examples

#### Example 1: Registering Sections in Plugin

```dart
class ProductsPlugin extends FeaturePlugin {
  @override
  Future<void> initialize() async {
    // Register featured products section
    widgetRegistry.register(
      'product.featured_products_section',
      (context, {data, onEvent}) => FeaturedProductsSection(
        settings: data?['settings'] as Map<String, dynamic>?,
      ),
    );

    // Register collections section
    widgetRegistry.register(
      'product.collections_section',
      (context, {data, onEvent}) => CollectionsSection(
        settings: data?['settings'] as Map<String, dynamic>?,
      ),
    );

    // Register category section with callback
    widgetRegistry.register(
      'product.categories_section',
      (context, {data, onEvent}) => CategoryListSection(
        showTitle: true,
        onCategorySelected: (categoryId) {
          Navigator.pushNamed(context, '/products', arguments: categoryId);
        },
      ),
    );
  }
}
```

#### Example 2: Building Widgets from JSON Config

**environment.json:**
```json
{
  "plugins": {
    "home": {
      "sections": {
        "main": [
          {
            "name": "product.categories_section",
            "description": "Product categories grid",
            "settings": {}
          },
          {
            "name": "banner_section",
            "description": "Promotional banners",
            "settings": {
              "height": 200,
              "showIndicators": true
            }
          },
          {
            "name": "product.featured_products_section",
            "description": "Featured products carousel",
            "settings": {
              "title": "FEATURED PRODUCTS",
              "perPage": 10
            }
          }
        ]
      }
    }
  }
}
```

**Building the UI:**
```dart
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: ListView(
        children: WidgetRegistry().buildSectionGroup(
          context,
          pluginName: 'home',
          groupName: 'main',
        ),
      ),
    );
  }
}
```

#### Example 3: Dynamic Widget with Event Handling

```dart
// Register widget with event handling
widgetRegistry.register(
  'custom.interactive_banner',
  (context, {data, onEvent}) {
    return GestureDetector(
      onTap: () {
        // Trigger event
        onEvent?.call('banner_clicked', {
          'banner_id': data?['id'],
          'timestamp': DateTime.now().toIso8601String(),
        });
      },
      child: BannerWidget(data: data),
    );
  },
);

// Build widget with event handler
final widget = widgetRegistry.build(
  'custom.interactive_banner',
  context,
  data: {'id': 'promo_1', 'image': 'https://...'},
  onEvent: (eventName, eventData) {
    print('Event: $eventName, Data: $eventData');
    // Handle event (navigation, analytics, etc.)
  },
);
```

### Widget Naming Convention

Use namespaced names to avoid conflicts:

```
{plugin_name}.{widget_type}_{descriptor}

Examples:
- product.featured_products_section
- product.collections_section
- cart.mini_cart_widget
- banner_section
- home.hero_section
```

### Best Practices

✅ **DO:**
- Use descriptive, namespaced names
- Pass configuration through `data` parameter
- Support both data and onEvent parameters
- Register widgets during plugin initialization
- Document available settings for each widget

❌ **DON'T:**
- Register widgets with generic names (e.g., "list", "card")
- Create widgets that require specific parent widgets
- Ignore the data parameter structure
- Register the same name twice from different plugins

---

## AddonRegistry

### Purpose
AddonRegistry enables **slot-based UI injection** — plugins can register optional widgets into named slots that existing sections expose. Unlike WidgetRegistry (which owns the full section), AddonRegistry is for _supplementary_ content: badges, banners, overlays, or any widget added on top of an existing component.

Multiple addons can be registered for the same slot; they are rendered in **descending priority order** (highest priority first). Each builder may return `null` to opt out of rendering for a particular call.

### Location
```
lib/src/widgets/addon_registry.dart
```

### Core API

```dart
/// Addon builder function type - may return null to skip rendering
typedef WidgetBuilderFn = Widget? Function(
  BuildContext context, {
  Map<String, dynamic>? data,
  void Function(String event, dynamic payload)? onEvent,
});

class Addon {
  final int priority;
  final WidgetBuilderFn builder;
}

class AddonRegistry {
  // Singleton instance
  factory AddonRegistry() => _instance;
  static AddonRegistry get instance => _instance;

  /// Register an addon builder for a named slot.
  /// @param name     - Slot identifier (e.g., 'product.card:badge')
  /// @param builder  - Builder that returns a Widget or null
  /// @param priority - Render order; higher = rendered first (default: 1)
  /// Duplicate builders (same function reference) for the same slot are ignored.
  void register(String name, WidgetBuilderFn builder, {int priority = 1});

  /// Build all addons for a named slot.
  /// Returns a list of non-null widgets in priority order.
  /// Builder errors are caught and logged; other addons continue rendering.
  List<Widget> build<T>(String name, BuildContext context, {
    Map<String, dynamic>? data,
    void Function(String event, dynamic payload)? onEvent,
  });

  /// Remove a specific builder from a slot
  void removeAddon(String name, WidgetBuilderFn builder);

  /// Remove all builders from a slot
  void clearAddons(String name);

  /// Remove all builders from all slots
  void clearAllAddons();

  /// Get all registered slot names
  List<String> getRegisteredAddons();

  /// Count of registered builders for a slot
  int getAddonCount(String name);

  /// Whether a slot has at least one registered builder
  bool hasAddon(String name);
}
```

### Key Differences from WidgetRegistry

| | WidgetRegistry | AddonRegistry |
|---|---|---|
| **Returns** | Single `Widget` | `List<Widget>` (zero or more) |
| **Builder return** | Always a `FeatureSection` | `Widget?` (null = skip) |
| **Multiple registrations** | Not recommended (last wins) | Designed for multiple (priority-ordered) |
| **Use case** | Full section owning a screen area | Supplementary widgets injected into slots |

### Usage Examples

#### Example 1: Adding a Sale Badge to Product Cards

**Register the addon (in plugin):**
```dart
class PromotionsPlugin extends FeaturePlugin {
  @override
  void onRegister() {
    // Inject a sale badge into every product card that shows a product on sale
    addonRegistry.register(
      'product.card:badge',
      (context, {data, onEvent}) {
        final product = data?['product'] as Product?;
        if (product == null || !product.onSale) return null; // opt out

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(4),
          ),
          child: const Text('SALE', style: TextStyle(color: Colors.white, fontSize: 10)),
        );
      },
      priority: 10,
    );
  }
}
```

**Render the slot (in the section/widget):**
```dart
class ProductCard extends StatelessWidget {
  final Product product;
  const ProductCard({super.key, required this.product});

  @override
  Widget build(BuildContext context) {
    final badges = AddonRegistry().build(
      'product.card:badge',
      context,
      data: {'product': product},
    );

    return Stack(
      children: [
        ProductImage(product: product),
        if (badges.isNotEmpty)
          Positioned(
            top: 8,
            left: 8,
            child: Column(children: badges),
          ),
      ],
    );
  }
}
```

#### Example 2: Priority-Ordered Addons

```dart
// Register multiple addons for the same slot with different priorities
addonRegistry.register(
  'checkout:summary_extras',
  (context, {data, onEvent}) => LoyaltyPointsWidget(data: data),
  priority: 20, // renders first
);

addonRegistry.register(
  'checkout:summary_extras',
  (context, {data, onEvent}) => GiftMessageWidget(data: data),
  priority: 10, // renders second
);

// Render all - returns [LoyaltyPointsWidget, GiftMessageWidget]
final extras = AddonRegistry().build('checkout:summary_extras', context);
```

#### Example 3: Conditional Rendering with Null

```dart
addonRegistry.register(
  'product.card:overlay',
  (context, {data, onEvent}) {
    final product = data?['product'] as Product?;
    // Return null when condition isn't met - this addon is skipped entirely
    if (product == null || product.inStock) return null;

    return const OutOfStockOverlay();
  },
);
```

### Slot Naming Convention

Use namespaced dot-notation with a colon separating the component from the slot:

```
{plugin_or_component}.{widget_name}:{slot_name}

Examples:
- product.card:badge          // badge slot on product cards
- product.card:overlay        // overlay slot on product cards
- cart.item:actions           // extra action buttons on cart items
- checkout:summary_extras     // extra rows in checkout summary
- home.hero:overlay           // overlay on the hero section
```

### Best Practices

✅ **DO:**
- Return `null` when the addon should not render (e.g., condition not met)
- Use namespaced slot names to avoid conflicts between plugins
- Use priority to control render order when multiple addons share a slot
- Keep addon builders lightweight — they may be called on every rebuild
- Register addons in `onRegister()` (not `initialize()`)

❌ **DON'T:**
- Use AddonRegistry to own a full section area — use WidgetRegistry for that
- Register the same builder function reference twice (silently ignored)
- Throw exceptions from builders — return `null` instead to skip gracefully
- Assume any addon will be present — always guard with `hasAddon()` or check list length

---

## ActionRegistry

### Purpose
ActionRegistry provides a **centralized system for handling user interactions** such as taps, clicks, and custom actions. It enables declarative action definitions and extensible custom action handlers.

### Location
```
lib/src/actions/action_registry.dart
```

### Core API

```dart
class ActionRegistry {
  // Singleton instance
  factory ActionRegistry() => _instance;
  static ActionRegistry get instance => _instance;

  /// Register a custom action handler
  /// @param actionId - Unique identifier for the action
  /// @param handler - Function that executes the action
  void registerCustomHandler(String actionId, CustomActionHandler handler);

  /// Handle a user interaction
  /// @param context - Build context
  /// @param interaction - User interaction definition
  void handleInteraction(BuildContext context, UserInteraction? interaction);

  /// Check if custom handler is registered
  bool hasCustomHandler(String actionId);

  /// Get all registered custom action IDs
  List<String> getRegisteredActions();

  /// Unregister a custom action handler
  void unregisterCustomHandler(String actionId);
}

/// Custom action handler function type
typedef CustomActionHandler = void Function(
  BuildContext context,
  Map<String, dynamic>? parameters,
);
```

### UserInteraction Entity

```dart
enum UserInteractionType {
  internalNavigation,  // Navigate to app route
  externalUrl,         // Open external URL
  customAction,        // Execute custom handler
  none,               // No action
}

class UserInteraction {
  final UserInteractionType interactionType;
  final String? route;              // For internalNavigation
  final String? url;                // For externalUrl
  final Map<String, dynamic>? parameters;
  final String? customActionId;     // For customAction

  // Factory constructors for common patterns
  factory UserInteraction.navigate({
    required String route,
    Map<String, dynamic>? parameters,
  });

  factory UserInteraction.openUrl({
    required String url,
  });

  factory UserInteraction.custom({
    required String actionId,
    Map<String, dynamic>? parameters,
  });

  factory UserInteraction.none();
}
```

### Usage Examples

#### Example 1: Built-in Navigation Actions

```dart
// Define action in entity
class Collection {
  final String id;
  final String title;
  final UserInteraction? action;

  const Collection({
    required this.id,
    required this.title,
    this.action,
  });
}

// Create collection with navigation action
final collection = Collection(
  id: '1',
  title: 'Summer Sale',
  action: UserInteraction.navigate(
    route: '/products',
    parameters: {'categoryId': 'summer'},
  ),
);

// Handle tap in widget
GestureDetector(
  onTap: () {
    ActionRegistry().handleInteraction(context, collection.action);
  },
  child: CollectionCard(collection: collection),
)
```

#### Example 2: External URL Actions

```dart
// Open external link
final action = UserInteraction.openUrl(
  url: 'https://example.com/promo',
);

ActionRegistry().handleInteraction(context, action);
```

#### Example 3: Custom Action Handlers

**Register Custom Handler:**
```dart
class CameraPlugin extends FeaturePlugin {
  @override
  void onRegister() {
    // Register camera action
    ActionRegistry().registerCustomHandler('open_camera', (context, params) {
      final mode = params?['mode'] ?? 'photo';
      Navigator.pushNamed(context, '/camera', arguments: {'mode': mode});
    });

    // Register share action
    ActionRegistry().registerCustomHandler('share', (context, params) async {
      final content = params?['content'] ?? '';
      await Share.share(content);
    });
  }
}
```

**Use Custom Action:**
```dart
// Define custom action
final action = UserInteraction.custom(
  actionId: 'open_camera',
  parameters: {'mode': 'video'},
);

// Execute action
GestureDetector(
  onTap: () => ActionRegistry().handleInteraction(context, action),
  child: CameraButton(),
)
```

#### Example 4: Collection with Multiple Action Types

```dart
// Navigation action
final navCollection = Collection(
  id: '1',
  title: 'New Arrivals',
  action: UserInteraction.navigate(
    route: '/products',
    parameters: {'filter': 'new'},
  ),
);

// External URL action
final urlCollection = Collection(
  id: '2',
  title: 'Blog',
  action: UserInteraction.openUrl(
    url: 'https://blog.example.com',
  ),
);

// Custom action
final customCollection = Collection(
  id: '3',
  title: 'Share App',
  action: UserInteraction.custom(
    actionId: 'share',
    parameters: {
      'content': 'Check out this amazing app!',
      'url': 'https://app.example.com',
    },
  ),
);

// No action
final staticCollection = Collection(
  id: '4',
  title: 'Coming Soon',
  action: UserInteraction.none(),
);
```

### Available Custom Action Examples

```dart
// Payment action
ActionRegistry().registerCustomHandler('process_payment', (context, params) {
  final amount = params?['amount'] as double?;
  final paymentMethod = params?['method'] as String?;
  // Process payment...
});

// Analytics action
ActionRegistry().registerCustomHandler('track_event', (context, params) {
  final eventName = params?['event'] as String?;
  final properties = params?['properties'] as Map<String, dynamic>?;
  analytics.logEvent(eventName, properties);
});

// Deep link action
ActionRegistry().registerCustomHandler('deep_link', (context, params) {
  final url = params?['url'] as String?;
  DeepLinkHandler.handle(url);
});

// Modal action
ActionRegistry().registerCustomHandler('show_modal', (context, params) {
  final modalType = params?['type'] as String?;
  showModalBottomSheet(
    context: context,
    builder: (context) => CustomModal(type: modalType),
  );
});
```

### Best Practices

✅ **DO:**
- Use descriptive action IDs
- Provide parameter validation in custom handlers
- Handle errors gracefully in custom handlers
- Document available parameters for custom actions
- Use factory constructors for common patterns
- Return early for `null` or `none` interactions

❌ **DON'T:**
- Perform async operations without proper error handling
- Assume parameters exist without null checks
- Register multiple handlers with same actionId
- Execute actions without BuildContext when needed
- Ignore the interaction type

---

## Best Practices

### Registry Selection Guide

**Use HookRegistry when:**
- You need to modify data flow between components
- You want plugins to extend functionality without code changes
- You need multiple handlers to process the same data
- Order of execution matters

**Use WidgetRegistry when:**
- Building UI from configuration files
- Creating plugin-based section systems
- Supporting runtime UI composition
- Need dynamic section selection

**Use AddonRegistry when:**
- Injecting supplementary widgets into slots exposed by existing sections
- Multiple plugins need to contribute to the same UI area (badges, overlays, extras)
- The additions are optional — builders can return null to opt out
- You need priority-ordered rendering of multiple injected widgets

**Use ActionRegistry when:**
- Handling user interactions (taps, clicks)
- Supporting multiple action types (navigation, URLs, custom)
- Want declarative action definitions
- Need extensible custom action handlers

### Common Patterns

#### Pattern 1: Plugin Registration

```dart
class MyPlugin extends FeaturePlugin {
  @override
  void onRegister() {
    // Register hooks first (low-level)
    hookRegistry.register('my_plugin:data_transform', _transformData);

    // Register custom actions (mid-level)
    ActionRegistry().registerCustomHandler('my_action', _handleAction);
  }

  @override
  Future<void> initialize() async {
    // Register widgets last (high-level)
    widgetRegistry.register('my_plugin.section', _buildSection);
  }
}
```

#### Pattern 2: Cross-Plugin Communication

```dart
// Plugin A - Exposes hook
class PluginA extends FeaturePlugin {
  Future<Data> loadData() async {
    Data data = await _fetchData();

    // Allow other plugins to modify data
    data = hookRegistry.execute('plugin_a:after_load_data', data);

    return data;
  }
}

// Plugin B - Modifies data from Plugin A
class PluginB extends FeaturePlugin {
  @override
  void onRegister() {
    hookRegistry.register('plugin_a:after_load_data', (data) {
      // Enhance data from Plugin A
      return enhanceData(data);
    });
  }
}
```

#### Pattern 3: Event-Driven Architecture

```dart
// Trigger events through hooks
hookRegistry.execute('user:logged_in', userId);
hookRegistry.execute('cart:item_added', cartItem);
hookRegistry.execute('order:completed', order);

// Handle events in plugins
class AnalyticsPlugin extends FeaturePlugin {
  @override
  void onRegister() {
    hookRegistry.register('user:logged_in', (userId) {
      analytics.logLogin(userId);
      return userId;
    });

    hookRegistry.register('cart:item_added', (item) {
      analytics.logAddToCart(item);
      return item;
    });
  }
}
```

### Testing

```dart
// Test hook registration
test('hook modifies data correctly', () {
  final hookRegistry = HookRegistry();

  hookRegistry.register('test_hook', (value) => value * 2);

  final result = hookRegistry.execute('test_hook', 5);

  expect(result, equals(10));
});

// Test widget registration
test('widget builds correctly', () {
  final widgetRegistry = WidgetRegistry();

  widgetRegistry.register('test_widget', (context, {data, onEvent}) {
    return MySection(settings: data?['settings']);
  });

  final widget = widgetRegistry.build('test_widget', context,
    data: {'title': 'Test'});

  expect(widget, isA<Text>());
});

// Test action handling
test('action executes custom handler', () {
  final actionRegistry = ActionRegistry();
  var executed = false;

  actionRegistry.registerCustomHandler('test_action', (context, params) {
    executed = true;
  });

  final interaction = UserInteraction.custom(actionId: 'test_action');
  actionRegistry.handleInteraction(context, interaction);

  expect(executed, isTrue);
});
```

---

## Quick Reference

### HookRegistry
```dart
// Register
hookRegistry.register('hook_name', callback, priority: 10);

// Execute
result = hookRegistry.execute('hook_name', data);

// Check
bool exists = hookRegistry.hasHook('hook_name');
```

### WidgetRegistry
```dart
// Register
widgetRegistry.register('widget_name', builder);

// Build single section
widget = widgetRegistry.build('widget_name', context, data: {...});

// Build all sections in a plugin group
widgets = widgetRegistry.buildSectionGroup(context, pluginName: 'home', groupName: 'main');

// Check
bool exists = widgetRegistry.isRegistered('widget_name');
```

### AddonRegistry
```dart
// Register
addonRegistry.register('slot.name:zone', builder, priority: 10);

// Build all addons for a slot
List<Widget> addons = AddonRegistry().build('slot.name:zone', context, data: {...});

// Check
bool exists = AddonRegistry().hasAddon('slot.name:zone');
int count = AddonRegistry().getAddonCount('slot.name:zone');
```

### ActionRegistry
```dart
// Register
ActionRegistry().registerCustomHandler('action_id', handler);

// Handle
ActionRegistry().handleInteraction(context, interaction);

// Check
bool exists = ActionRegistry().hasCustomHandler('action_id');
```
