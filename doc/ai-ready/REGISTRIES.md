# Registry Systems

## Overview

`moose_core` provides five registry systems, all owned by `MooseAppContext` and injected into plugins and adapters via convenience getters. All registries are instance-based — there are no singletons. Each `MooseAppContext` owns an independent set.

| Registry | Purpose |
|---|---|
| `HookRegistry` | Synchronous data transformation pipeline — modify data passing through named hook points |
| `EventBus` | Asynchronous publish/subscribe — fire-and-forget notifications across plugins |
| `WidgetRegistry` | Dynamic UI composition — map string keys to `FeatureSection` builders |
| `AddonRegistry` | Slot-based UI injection — multiple plugins contribute widgets to named slots |
| `ActionRegistry` | User interaction handling — route `UserInteraction` entities to navigation/URL/custom handlers |

Access in plugins via convenience getters (`hookRegistry`, `eventBus`, `widgetRegistry`, `addonRegistry`, `actionRegistry`). Access in widgets via `context.moose.<registry>` or `MooseScope.<registry>Of(context)`.

---

## HookRegistry

### Purpose

HookRegistry implements a **synchronous filter pipeline**. A hook point is a named string. Callbacks registered on that name receive a value, transform it (or observe it), and return it. All callbacks execute in sequence; the output of each becomes the input of the next. If no callbacks are registered, the original value is returned unchanged.

Use `HookRegistry` when:
- A repository needs to let plugins modify or enrich data before returning it (e.g., apply price adjustments to a product)
- A plugin needs to intercept a data flow from another plugin without direct coupling
- Multiple transformations must compose in a defined order

**Do not** use `HookRegistry` for asynchronous side effects or notifications — use `EventBus` for those.

### API

```dart
class HookRegistry {
  HookRegistry();

  /// Register a callback on a named hook point.
  /// Callbacks execute in descending priority order (highest first).
  /// Default priority is 1.
  void register(String hookName, dynamic Function(dynamic) callback, {int priority = 1});

  /// Execute all callbacks registered on hookName, threading data through.
  /// Returns the original data if no callbacks are registered.
  /// Errors in individual callbacks are logged and skipped — remaining callbacks still run.
  T execute<T>(String hookName, T data);

  /// Remove a specific callback from a hook point (by function reference equality).
  void removeHook(String hookName, dynamic Function(dynamic) callback);

  /// Remove all callbacks from a specific hook point.
  void clearHooks(String hookName);

  /// Remove all callbacks from all hook points.
  void clearAllHooks();

  /// Returns true if the hook point has at least one registered callback.
  bool hasHook(String hookName);

  /// Number of callbacks registered on a hook point.
  int getHookCount(String hookName);

  /// All currently registered hook names.
  List<String> getRegisteredHooks();
}
```

### Priority

Callbacks execute in **descending** priority order — higher number runs first:

```dart
hookRegistry.register('product:transform', modifyPrices, priority: 20); // runs first
hookRegistry.register('product:transform', addBadges,    priority: 10); // runs second
hookRegistry.register('product:transform', logView,      priority: 1);  // runs last (default)
```

### Defining a hook point (in a repository)

Adapters fire hooks inside repository methods to allow plugins to extend behaviour:

```dart
class WooProductsRepository extends ProductsRepository {
  final HookRegistry _hooks;

  WooProductsRepository({required HookRegistry hooks}) : _hooks = hooks;

  @override
  Future<Product> getProductById(String id, {Duration? cacheTTL}) async {
    final raw = await _client.get('/products/$id');
    Product product = _toProduct(raw);

    // Let plugins transform the product before returning it
    product = _hooks.execute('product:transform', product);

    return product;
  }
}
```

The hook name is a contract between the adapter and any plugins that want to extend it. Document hook names in the adapter's source or docs.

### Consuming a hook point (in a plugin)

```dart
class PromotionsPlugin extends FeaturePlugin {
  @override
  void onRegister() {
    // Apply a 10% discount to all products
    hookRegistry.register(
      'product:transform',
      (product) {
        final p = product as Product;
        return p.copyWith(price: p.price * 0.9);
      },
      priority: 10,
    );
  }
}

class AnalyticsPlugin extends FeaturePlugin {
  @override
  void onRegister() {
    // Observe product views without modifying the product
    hookRegistry.register(
      'product:transform',
      (product) {
        _analytics.logView((product as Product).id);
        return product; // always return — even if not modified
      },
      priority: 1,
    );
  }
}
```

### Hook naming convention

Use `<domain>:<action>` dot notation for sub-paths if needed:

```
product:transform          // transform a product entity
cart:item.added           // observe/modify a cart item being added
checkout:before.submit    // intercept a checkout request before submission
bottom_tabs:filter_tabs   // built-in: modify the bottom navigation tab list
```

Hook names are defined by the adapter or plugin that executes them — `moose_core` itself only defines `bottom_tabs:filter_tabs` (used by `PluginRegistry` for bottom navigation).

### Built-in hook: bottom_tabs:filter_tabs

`PluginRegistry` automatically wires bottom navigation tabs declared by plugins through this hook. Plugins expose tabs via `get bottomTabs => [BottomTab(...)]` — no manual hook registration is needed. Consuming the hook to extend the tab list:

```dart
hookRegistry.register(
  'bottom_tabs:filter_tabs',
  (tabs) {
    final list = List<BottomTab>.from(tabs as List<BottomTab>);
    list.add(BottomTab(id: 'wishlist', label: 'Wishlist', route: '/wishlist'));
    return list;
  },
  priority: 5,
);
```

---

## EventBus

### Purpose

`EventBus` implements an **asynchronous publish/subscribe** system. Events are string-named and carry a `Map<String, dynamic>` payload. Subscribers receive events on a broadcast stream — there is no return value and no ordering guarantee.

Use `EventBus` when:
- A repository or plugin needs to notify the rest of the app about something that happened (e.g., a payment completed)
- Multiple unrelated components need to react to the same event
- The publisher must not know who is listening

**Do not** use `EventBus` to transform data — use `HookRegistry` for that.

### API

```dart
class Event {
  final String name;
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;
}

class EventSubscription {
  Future<void> cancel();
  bool get isActive;
  void pause([Future<void>? resumeSignal]);
  void resume();
}

class EventBus {
  EventBus();

  /// Subscribe synchronously to a named event. Returns a handle for cancellation.
  EventSubscription on(
    String eventName,
    void Function(Event event) onEvent, {
    Function? onError,
    void Function()? onDone,
  });

  /// Subscribe asynchronously — handler is a Future. Errors are caught and logged.
  EventSubscription onAsync(
    String eventName,
    Future<void> Function(Event event) onEvent, {
    Function? onError,
    void Function()? onDone,
  });

  /// Publish an event to all current subscribers. Fire-and-forget.
  void fire(String eventName, {Map<String, dynamic>? data, Map<String, dynamic>? metadata});

  /// Publish an event and await one microtask cycle before returning.
  /// Useful when you need subscribers to have been notified before continuing.
  Future<void> fireAndWait(String eventName, {Map<String, dynamic>? data, Map<String, dynamic>? metadata});

  /// Raw Stream<Event> for the named event — supports stream operators.
  Stream<Event> stream(String eventName);

  /// Cancel all subscriptions for a specific event name.
  Future<void> cancelSubscriptionsForEvent(String eventName);

  /// Cancel all active subscriptions across all events.
  Future<void> cancelAllSubscriptions();

  /// Destroy the EventBus: cancel all subscriptions and close all controllers.
  Future<void> destroy();

  /// Alias for destroy(). Useful in tests.
  Future<void> reset();

  // Introspection
  int get activeSubscriptionCount;
  int get registeredEventCount;
  bool hasSubscribers(String eventName);
  List<String> getRegisteredEvents();
}
```

### Firing events (in a repository or adapter)

```dart
class WooCartRepository extends CartRepository {
  final EventBus _eventBus;

  WooCartRepository({required EventBus eventBus}) : _eventBus = eventBus;

  @override
  Future<Cart> addItem({required String productId, int quantity = 1, ...}) async {
    final cart = await _client.post('/cart/add', {...});

    _eventBus.fire('cart.item.added', data: {
      'productId': productId,
      'quantity': quantity,
      'cartId': cart.id,
    });

    return _toCart(cart);
  }
}
```

### Subscribing to events (in a plugin)

Store the subscription and cancel it in `onStop()` to prevent memory leaks:

```dart
class AnalyticsPlugin extends FeaturePlugin {
  EventSubscription? _cartSubscription;
  EventSubscription? _orderSubscription;

  @override
  void onRegister() {
    // Sync subscription
    _cartSubscription = eventBus.on('cart.item.added', (event) {
      _analytics.trackAddToCart(
        productId: event.data['productId'] as String,
        quantity: event.data['quantity'] as int,
      );
    });

    // Async subscription
    _orderSubscription = eventBus.onAsync('order.placed', (event) async {
      await _analytics.trackPurchase(event.data['orderId'] as String);
    });
  }

  @override
  Future<void> onStop() async {
    await _cartSubscription?.cancel();
    await _orderSubscription?.cancel();
  }
}
```

### Stream operator usage

```dart
// Debounce rapid search events
eventBus.stream('search.query.changed')
    .debounceTime(const Duration(milliseconds: 300))
    .listen((event) => _performSearch(event.data['query'] as String));
```

### Event naming convention

Use dot notation: `<domain>.<action>` or `<domain>.<entity>.<action>`:

```
cart.item.added
cart.coupon.applied
order.placed
order.payment.completed
user.logged.in
user.logged.out
search.query.changed
notification.received
```

### HookRegistry vs EventBus

| | HookRegistry | EventBus |
|---|---|---|
| **Return value** | Transformed data (same type) | None |
| **Execution** | Synchronous, sequential | Asynchronous, broadcast |
| **Ordering** | Priority-controlled | No guarantee |
| **Use for** | Data transformation | Notifications / side effects |
| **Multiple handlers** | Yes, all run in priority order | Yes, all receive the event |
| **Subscription handle** | N/A | `EventSubscription` (cancel in `onStop`) |

---

## WidgetRegistry

### Purpose

`WidgetRegistry` maps string keys to `FeatureSection` builder functions. Screens call `buildSectionGroup` to render all sections declared in `environment.json` for a plugin/group combination, without any compile-time dependency on the section classes themselves.

### API

```dart
typedef SectionBuilderFn = FeatureSection Function(
  BuildContext context, {
  Map<String, dynamic>? data,
  void Function(String event, dynamic payload)? onEvent,
});

class WidgetRegistry {
  WidgetRegistry();

  /// Register a FeatureSection builder under a key.
  void register(String name, SectionBuilderFn builder);

  /// Build a single registered section by key.
  /// In debug mode: returns UnknownSectionWidget if key is not registered.
  /// In release mode: returns SizedBox.shrink() if key is not registered.
  Widget build(
    String name,
    BuildContext context, {
    Map<String, dynamic>? data,
    void Function(String event, dynamic payload)? onEvent,
  });

  /// Read section configs from environment.json for pluginName/groupName,
  /// filter to active:true entries, build each, and return the list.
  List<Widget> buildSectionGroup(
    BuildContext context, {
    required String pluginName,
    required String groupName,
    Map<String, dynamic>? data,
    void Function(String event, dynamic payload)? onEvent,
  });

  /// Read SectionConfig objects from environment.json without building.
  List<SectionConfig> getSections(String pluginName, String groupName);

  bool isRegistered(String name);
  List<String> getRegisteredWidgets();
  void unregister(String name);
}
```

`SectionConfig` fields: `name` (String), `description` (String), `active` (bool, default true), `settings` (Map).

`buildSectionGroup` merges each section's settings from `SectionConfig` with any additional `data` passed by the caller. Inactive sections (`active: false`) are skipped.

### Registering sections (in a plugin)

Register in `onRegister()` — always synchronous, always before `onInit`:

```dart
class ProductsPlugin extends FeaturePlugin {
  @override
  void onRegister() {
    widgetRegistry.register(
      'products.featured_section',
      (context, {data, onEvent}) => FeaturedProductsSection(
        settings: data?['settings'] as Map<String, dynamic>?,
      ),
    );

    widgetRegistry.register(
      'products.related_section',
      (context, {data, onEvent}) => RelatedProductsSection(
        settings: data?['settings'] as Map<String, dynamic>?,
        productId: data?['productId'] as String?,
        onEvent: onEvent,
      ),
    );
  }
}
```

### Building a section group (in a screen)

```dart
class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final sections = context.moose.widgetRegistry.buildSectionGroup(
      context,
      pluginName: 'home',
      groupName: 'main',
      onEvent: (event, payload) {
        if (event == 'banner_tapped') {
          final route = (payload as Map<String, dynamic>?)?['route'] as String?;
          if (route != null) Navigator.pushNamed(context, route);
        }
      },
    );

    return Scaffold(body: ListView(children: sections));
  }
}
```

Corresponding environment.json:

```json
{
  "plugins": {
    "home": {
      "active": true,
      "sections": {
        "main": [
          {
            "name": "products.featured_section",
            "description": "Featured products grid",
            "active": true,
            "settings": { "title": "Top Picks", "perPage": 8 }
          },
          {
            "name": "products.categories_section",
            "description": "Category grid",
            "active": false
          }
        ]
      }
    }
  }
}
```

### Building a single section

```dart
final widget = context.moose.widgetRegistry.build(
  'products.featured_section',
  context,
  data: {
    'settings': {'title': 'Override', 'perPage': 4},
  },
);
```

### Naming convention

`<plugin_name>.<section_name>` — the plugin prefix prevents collisions:

```
products.featured_section
products.categories_section
cart.mini_cart_widget
home.hero_section
checkout.order_summary_section
```

---

## AddonRegistry

### Purpose

`AddonRegistry` enables **slot-based UI injection**. A section exposes a named slot; other plugins register builders for that slot. All registered builders are called; each may return a widget or `null`. Non-null results are collected into a `List<Widget>` in descending priority order.

Unlike `WidgetRegistry` (one builder owns a full section), `AddonRegistry` supports zero-to-many contributors per slot.

### API

```dart
typedef WidgetBuilderFn = Widget? Function(
  BuildContext context, {
  Map<String, dynamic>? data,
  void Function(String event, dynamic payload)? onEvent,
});

class AddonRegistry {
  AddonRegistry();

  /// Register a builder for a named slot.
  /// Duplicate builder references for the same slot are silently ignored.
  void register(String name, WidgetBuilderFn builder, {int priority = 1});

  /// Call all builders for the slot; collect non-null results in priority order.
  /// Builder errors are caught and logged; other builders continue running.
  List<Widget> build<T>(String name, BuildContext context, {
    Map<String, dynamic>? data,
    void Function(String event, dynamic payload)? onEvent,
  });

  /// Remove a specific builder from a slot (by function reference equality).
  void removeAddon(String name, WidgetBuilderFn builder);

  /// Remove all builders from a slot.
  void clearAddons(String name);

  /// Remove all builders from all slots.
  void clearAllAddons();

  /// All registered slot names.
  List<String> getRegisteredAddons();

  /// Count of builders registered for a slot.
  int getAddonCount(String name);

  /// True if a slot has at least one registered builder.
  bool hasAddon(String name);
}
```

### Exposing a slot (in a section)

```dart
class ProductCard extends StatelessWidget {
  final Product product;

  @override
  Widget build(BuildContext context) {
    final badges = context.moose.addonRegistry.build(
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

### Contributing to a slot (in a plugin)

Register in `onRegister()`:

```dart
class PromotionsPlugin extends FeaturePlugin {
  @override
  void onRegister() {
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

class LoyaltyPlugin extends FeaturePlugin {
  @override
  void onRegister() {
    addonRegistry.register(
      'product.card:badge',
      (context, {data, onEvent}) {
        final product = data?['product'] as Product?;
        final points = product?.getExtension<int>('loyalty_points');
        if (points == null || points == 0) return null;

        return LoyaltyBadge(points: points);
      },
      priority: 5, // renders after sale badge
    );
  }
}
```

### Slot naming convention

`<component>:<slot>` or `<plugin>.<component>:<slot>`:

```
product.card:badge        // badge slot on product cards
product.card:overlay      // overlay slot on product cards
cart.item:actions         // action button slot on cart line items
checkout:summary.extras   // extra rows in the checkout summary
pdp:above.price           // slot above the price on the product detail page
home.hero:overlay         // overlay on the home hero section
```

### WidgetRegistry vs AddonRegistry

| | WidgetRegistry | AddonRegistry |
|---|---|---|
| Returns | Single `Widget` | `List<Widget>` (zero or more) |
| Builder return type | `FeatureSection` (never null) | `Widget?` (null = skip) |
| Multiple registrations | Last registered wins | All registered run, priority-ordered |
| Owns the area | Yes — owns a full section | No — supplements an existing section |
| Configured in JSON | Yes (`environment.json` sections) | No |

---

## ActionRegistry

### Purpose

`ActionRegistry` handles `UserInteraction` entities — the standard way entities in `moose_core` carry tap/action data. It dispatches to the correct handler based on `UserInteractionType`:

- `internal` → `AppNavigator.pushNamed` with the route and parameters
- `external` → external URL handler (default: shows a SnackBar; override in production with `url_launcher`)
- `custom` → a custom handler registered with `registerCustomHandler`
- `none` → no-op

### UserInteraction and UserInteractionType

```dart
enum UserInteractionType { internal, external, custom, none }

class UserInteraction {
  final UserInteractionType interactionType;
  final String? route;          // for internal
  final String? url;            // for external
  final Map<String, dynamic>? parameters;
  final String? customActionId; // for custom

  // Factory constructors:
  factory UserInteraction.internal({required String route, Map<String, dynamic>? parameters});
  factory UserInteraction.external({required String url, Map<String, dynamic>? parameters});
  factory UserInteraction.custom({required String actionId, Map<String, dynamic>? parameters});
  factory UserInteraction.none();

  bool get isValid; // false for invalid state (e.g. internal with no route)
}
```

### API

```dart
typedef CustomActionHandler = void Function(
  BuildContext context,
  Map<String, dynamic>? parameters,
);

class ActionRegistry {
  ActionRegistry();

  /// Register a handler for a custom action ID. Last registration wins.
  void registerCustomHandler(String actionId, CustomActionHandler handler);

  /// Register multiple handlers at once.
  void registerMultipleHandlers(Map<String, CustomActionHandler> handlers);

  /// Unregister a custom action handler.
  void unregisterCustomHandler(String actionId);

  /// Remove all custom handlers.
  void clearCustomHandlers();

  /// Dispatch a UserInteraction to the appropriate handler.
  /// Null or invalid interactions are silently ignored.
  void handleInteraction(BuildContext context, UserInteraction? interaction);

  bool hasCustomHandler(String actionId);
  List<String> getRegisteredHandlers();
}
```

### Registering custom handlers (in a plugin)

```dart
class DeepLinkPlugin extends FeaturePlugin {
  @override
  void onRegister() {
    actionRegistry.registerCustomHandler('open_filter', (context, params) {
      final categoryId = params?['categoryId'] as String?;
      Navigator.pushNamed(context, '/filter', arguments: {'categoryId': categoryId});
    });

    actionRegistry.registerCustomHandler('show_loyalty_modal', (context, params) {
      showModalBottomSheet(
        context: context,
        builder: (_) => LoyaltyModal(tier: params?['tier'] as String?),
      );
    });

    // Register multiple at once
    actionRegistry.registerMultipleHandlers({
      'share_product': (context, params) => _shareProduct(context, params),
      'add_to_wishlist': (context, params) => _addToWishlist(context, params),
    });
  }
}
```

### Dispatching interactions (in a widget)

```dart
GestureDetector(
  onTap: () => context.moose.actionRegistry.handleInteraction(context, item.action),
  child: CollectionCard(item: item),
)
```

### Building UserInteraction in adapters

```dart
// Internal navigation (goes through AppNavigator.pushNamed)
UserInteraction.internal(
  route: '/products',
  parameters: {'categoryId': 'summer', 'filter': 'new'},
)

// External URL
UserInteraction.external(url: 'https://blog.example.com/summer-sale')

// Custom action (handler must be registered first)
UserInteraction.custom(
  actionId: 'show_loyalty_modal',
  parameters: {'tier': 'gold'},
)

// Explicitly no action
UserInteraction.none()
```

---

## Accessing Registries

### From a plugin (via convenience getters)

```dart
class MyPlugin extends FeaturePlugin {
  @override
  void onRegister() {
    hookRegistry.register('...', ...);
    widgetRegistry.register('...', ...);
    addonRegistry.register('...', ...);
    actionRegistry.registerCustomHandler('...', ...);
    eventBus.on('...', (event) { ... });
  }
}
```

### From a widget (via context.moose)

```dart
context.moose.hookRegistry
context.moose.widgetRegistry
context.moose.addonRegistry
context.moose.actionRegistry
context.moose.eventBus
```

### From a repository (via constructor injection)

Repositories receive registries from the adapter's factory closure:

```dart
// In the adapter
registerRepositoryFactory<ProductsRepository>(
  () => WooProductsRepository(
    _client,
    hooks: hookRegistry,
    eventBus: eventBus,
  ),
);

// In the repository class
class WooProductsRepository extends ProductsRepository {
  final HookRegistry _hooks;
  final EventBus _eventBus;

  WooProductsRepository(this._client, {
    required HookRegistry hooks,
    required EventBus eventBus,
  }) : _hooks = hooks,
       _eventBus = eventBus;
}
```

---

## Testing

### HookRegistry

```dart
test('hooks transform data in priority order', () {
  final registry = HookRegistry();

  registry.register('test', (v) => (v as int) + 10, priority: 20);
  registry.register('test', (v) => (v as int) * 2,  priority: 10);

  // priority 20 runs first: 5 + 10 = 15, then * 2 = 30
  expect(registry.execute('test', 5), equals(30));
});

test('execute returns original value when no hooks registered', () {
  final registry = HookRegistry();
  expect(registry.execute('unused', 42), equals(42));
});
```

### EventBus

```dart
test('on() receives fired events', () async {
  final bus = EventBus();
  final received = <Event>[];

  bus.on('test.event', received.add);
  bus.fire('test.event', data: {'key': 'value'});

  await Future.delayed(Duration.zero);
  expect(received.length, equals(1));
  expect(received.first.data['key'], equals('value'));

  await bus.reset();
});
```

### WidgetRegistry

```dart
test('build returns UnknownSectionWidget for missing key in debug', () {
  final registry = WidgetRegistry();
  // In debug mode, building an unregistered key returns UnknownSectionWidget
  // rather than throwing — inspect with isA<UnknownSectionWidget>()
});

test('isRegistered returns false before register', () {
  final registry = WidgetRegistry();
  expect(registry.isRegistered('some.section'), isFalse);
});
```

### AddonRegistry

```dart
test('build returns only non-null results', () {
  final registry = AddonRegistry();

  registry.register('slot', (ctx, {data, onEvent}) => const Text('A'), priority: 10);
  registry.register('slot', (ctx, {data, onEvent}) => null, priority: 5);
  registry.register('slot', (ctx, {data, onEvent}) => const Text('C'), priority: 1);

  // Requires a real BuildContext — use flutter_test's tester
});

test('getAddonCount returns correct count', () {
  final registry = AddonRegistry();
  registry.register('slot', (ctx, {data, onEvent}) => null);
  registry.register('slot', (ctx, {data, onEvent}) => null);
  expect(registry.getAddonCount('slot'), equals(2));
});
```

### ActionRegistry

```dart
test('handleInteraction calls registered custom handler', () {
  final registry = ActionRegistry();
  var called = false;

  registry.registerCustomHandler('my_action', (context, params) {
    called = true;
  });

  // handleInteraction requires BuildContext — use pumpWidget in widget tests
});

test('hasCustomHandler returns false before registration', () {
  final registry = ActionRegistry();
  expect(registry.hasCustomHandler('not_registered'), isFalse);
});
```

---

## Quick Reference

```dart
// HookRegistry
hookRegistry.register('hook:name', callback, priority: 10);
T result = hookRegistry.execute('hook:name', data);
bool exists = hookRegistry.hasHook('hook:name');

// EventBus
final sub = eventBus.on('event.name', (event) { ... });
eventBus.onAsync('event.name', (event) async { ... });
eventBus.fire('event.name', data: {'key': 'value'});
await eventBus.fireAndWait('event.name', data: {...});
await sub.cancel(); // in onStop()

// WidgetRegistry
widgetRegistry.register('plugin.section_name', (ctx, {data, onEvent}) => MySection(...));
Widget w = widgetRegistry.build('plugin.section_name', ctx, data: {...});
List<Widget> ws = widgetRegistry.buildSectionGroup(ctx, pluginName: 'home', groupName: 'main');
bool exists = widgetRegistry.isRegistered('plugin.section_name');

// AddonRegistry
addonRegistry.register('component:slot', builder, priority: 10);
List<Widget> addons = addonRegistry.build('component:slot', ctx, data: {...});
bool has = addonRegistry.hasAddon('component:slot');

// ActionRegistry
actionRegistry.registerCustomHandler('action_id', (ctx, params) { ... });
actionRegistry.handleInteraction(ctx, userInteraction);
bool has = actionRegistry.hasCustomHandler('action_id');
```

---

## Related

- [PLUGIN_SYSTEM.md](./PLUGIN_SYSTEM.md) — Plugin lifecycle and how registries are used from plugins
- [ADAPTER_SYSTEM.md](./ADAPTER_SYSTEM.md) — How adapters pass registries to repository constructors
- [FEATURE_SECTION.md](./FEATURE_SECTION.md) — FeatureSection and AddonRegistry slot integration
- [EVENT_SYSTEM_GUIDE.md](./EVENT_SYSTEM_GUIDE.md) — Extended EventBus and HookRegistry patterns
- [ARCHITECTURE.md](./ARCHITECTURE.md) — Overall layer structure
