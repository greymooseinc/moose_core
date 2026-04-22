# Registry Systems

> **Current version: 2.3.0**

## Overview

`moose_core` provides four registry systems, all owned by `MooseAppContext` and injected into plugins and adapters via convenience getters. All registries are instance-based — there are no singletons. Each `MooseAppContext` owns an independent set.

| Registry | Purpose |
|---|---|
| `HookRegistry` | Synchronous data transformation pipeline — modify data passing through named hook points |
| `EventBus` | Asynchronous publish/subscribe — fire-and-forget notifications across plugins |
| `WidgetRegistry` | Dynamic UI composition — map string keys to `FeatureSection` builders or plain widget builders |
| `ActionRegistry` | User interaction handling — route `UserInteraction` entities to navigation/URL/custom handlers |

Access in plugins via convenience getters (`hookRegistry`, `eventBus`, `widgetRegistry`, `actionRegistry`). Access in widgets via `context.moose.<registry>` or `MooseScope.<registry>Of(context)`.

---

## Naming Conventions

All registry keys — widget sections, slots, hooks, events, and commands — follow a consistent naming grammar. Understanding this grammar lets you predict, discover, and validate any registration name without reading source code.

### Four-Segment Grammar

```
<provider>.<plugin>.<type>.<name>
```

| Segment | Values | Rules |
|---|---|---|
| `<provider>` | `moose` (system), or your vendor prefix | `moose.` is reserved for system-owned registrations. Third-party plugins must use their own prefix. |
| `<plugin>` | Plugin identifier (`products`, `banner`, `cart`, `auth`, …) | Must match the plugin's `name` getter. `snake_case`. |
| `<type>` | `section`, `slot`, `widget`, `hook`, `event`, `cmd` | Always one of these six. See table below. |
| `<name>` | Descriptive name — `snake_case` with optional `:` sub-paths | Dots separate structural segments; colons are used only within `<name>` for hierarchy. |

### Type Segment Values

| `<type>` | Registry | Direction | Description |
|---|---|---|---|
| `section` | `WidgetRegistry.registerSection` | — | A named `FeatureSection` that can appear in `environment.json` page layouts |
| `slot` | `WidgetRegistry.registerWidget` | — | An injection or override point inside a section or widget |
| `widget` | `WidgetRegistry.registerWidget` | — | A reusable named widget instance (not a layout section) |
| `hook` | `HookRegistry.register` | Sync — bidirectional data transform | Intercept and modify data flowing through a named pipeline point |
| `event` | `EventBus.fire` / `EventBus.on` | Outbound — state notification | Fired by the plugin when something happens; external plugins subscribe |
| `cmd` | `EventBus.fire` / `EventBus.on` | Inbound — command bus | Fired by external plugins to drive a BLoC; the owning plugin subscribes and forwards |

### `<name>` Sub-Path Rules

- **Dots** are reserved for separating the four structural segments — never appear inside `<name>`.
- **Colons** are used inside `<name>` for hierarchy: `detail:price`, `section:{key}:loading`.
- **`{key}`** is a runtime placeholder substituted with the section instance's `key` setting: `section:home_banner:loading`, `slot.home_banner:build_overlay`.

### Complete Examples

```
# Widget sections — reference in environment.json
moose.products.section.categories
moose.products.section.detail:image_gallery
moose.banner.section.banner

# Widget slots — injection / override points
moose.products.slot.product_card:sale_badge
moose.products.slot.product_card:after_media
moose.products.slot.detail:price
moose.products.slot.section:{key}:loading
moose.products.slot.section:{key}:build_product_card
moose.banner.slot.{key}:build_banner_item
moose.banner.slot.{key}:build_banner_overlay

# Named widgets — reusable across plugins
moose.products.widget.product_card

# Hooks — synchronous data pipelines
moose.products.hook.before_load_products
moose.products.hook.after_load_products
moose.products.hook.get_current_filters       # read-only snapshot
moose.banner.hook.before_load_banners
moose.banner.hook.after_load_banners
moose.banner.hook.before_banner_tap
moose.banner.hook.get_current_state           # read-only snapshot

# Events — outbound state notifications
moose.products.event.list.loaded
moose.products.event.list.filters_changed
moose.products.event.product.viewed
moose.products.event.detail.variation_selected
moose.banner.event.banner.loaded
moose.banner.event.banner.tapped
moose.banner.event.banner.index_changed
moose.banner.event.banner.error

# Commands — inbound command bus
moose.products.cmd.apply_filters
moose.products.cmd.refresh_products
moose.products.cmd.clear_filters
moose.banner.cmd.refresh
moose.banner.cmd.go_to_index
```

### Third-Party Plugin Naming

Third-party plugins use their own `<provider>` prefix — never `moose.`:

```
acme.wishlist.slot.product_card:after_price      # wishlist button after price
acme.loyalty.hook.after_load_products            # enrich products with loyalty data
shopify.promotions.event.coupon.applied          # promotions plugin fires coupon event
```

### manifest.json and environment.json

`moose.manifest.json` declares every name a plugin owns under `widget_sections`, `widget_slots`, `widget_widgets`, `hooks`, `events`, `commands`, and `actions`. This is the single source of truth for tooling and AI agents.

`environment.json` references section names in page layouts. Names must match exactly (including provider prefix):

```json
{ "name": "moose.banner.section.banner" }
{ "name": "moose.products.section.categories" }
```

### Quick Rule Summary

1. `moose.` prefix = system-owned. Third-party plugins must not use it.
2. Dots separate the four structural segments. Never use dots inside `<name>`.
3. Colons are for hierarchy within `<name>` only.
4. `{key}` is a runtime placeholder — substitute the actual `key` value at registration time.
5. `event` = fired by plugin (outbound). `cmd` = fired by external plugins (inbound).
6. `hook` = synchronous, returns a value. `event`/`cmd` = asynchronous, no return.

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

  /// Execute all callbacks synchronously, threading data through each in priority order.
  /// Returns the original data if no callbacks are registered.
  /// Errors in individual callbacks are logged and skipped — remaining callbacks still run.
  /// Asserts (debug mode) if any callback returns a Future — use executeAsync() for async hooks.
  T execute<T>(String hookName, T data);

  /// Execute all callbacks asynchronously, awaiting each result before passing to the next.
  /// Sync callbacks are also supported — their return value is used directly.
  /// Use this whenever one or more registered callbacks return a Future.
  Future<T> executeAsync<T>(String hookName, T data);

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

System plugins use the four-segment `moose.<plugin>.hook.<verb>_<object>` convention:

```
moose.products.hook.before_load_products    // transform filters before products fetch
moose.products.hook.after_load_products     // filter/enrich product list after fetch
moose.products.hook.get_current_filters     // read-only: returns active filter state
moose.banner.hook.before_load_banners       // modify load params before banner fetch
moose.banner.hook.after_load_banners        // filter/reorder/enrich banner list
moose.banner.hook.before_banner_tap         // intercept tap data before event fires
moose.banner.hook.get_current_state         // read-only: returns active banner state
```

**Grammar:**
- `moose` — provider prefix; system-owned hooks always start with `moose.`
- `<plugin>` — the plugin that executes (owns) the hook point (`products`, `banner`, `cart`)
- `hook` — type segment — always `hook` for `HookRegistry` entries
- `<verb>_<object>` — what the hook does: `before_load_products`, `after_load_banners`, `get_current_filters`

**Third-party plugins** use their own prefix:
```
acme.loyalty.hook.after_load_products       // acme's loyalty plugin enriches product data
shopify.promotions.hook.before_load_banners // promotions plugin injects placement filter
```

**Read-only vs transform hooks:**
- `before_*` / `after_*` — receive data, transform it, return modified value
- `get_*` — read-only snapshot; registered handler should return the provided value unchanged

**Adapter-level hooks** (not owned by plugins) may use the legacy `<domain>:<action>` form:
```
product:transform          // adapter-level product enrichment
cart:item.added            // adapter-level cart modification
bottom_tabs:filter_tabs    // built-in: modify the bottom navigation tab list
```

Hook names are defined by whoever executes them — `moose_core` itself only defines `bottom_tabs:filter_tabs` (used by `PluginRegistry` for bottom navigation).

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

  /// Fire and yield once to the microtask queue.
  /// Synchronous handlers complete before the returned Future resolves.
  /// Async I/O handlers may still be in flight — use a Completer for full coordination.
  Future<void> fireAndFlush(String eventName, {Map<String, dynamic>? data, Map<String, dynamic>? metadata});

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

System plugins use the four-segment `<provider>.<plugin>.<noun>.<verb>` convention.

#### Outbound events (state notifications)

```
moose.products.event.list.loaded            // product list finished loading
moose.products.event.list.filters_changed   // active filters changed
moose.products.event.list.refreshed         // pull-to-refresh completed
moose.products.event.product.viewed         // product detail screen opened
moose.products.event.detail.variation_selected // user picked a variant attribute
moose.products.event.categories.loaded      // category list loaded
moose.products.event.collections.loaded     // collections list loaded
moose.banner.event.banner.loaded            // banners finished loading
moose.banner.event.banner.tapped            // user tapped a banner slide
moose.banner.event.banner.index_changed     // carousel moved to a new slide
moose.banner.event.banner.error             // banner load failed
```

#### Inbound commands (command bus)

Commands are fired by external plugins to drive a BLoC without importing it. Use `cmd` as the type segment to distinguish them clearly from outbound state notifications:

```
moose.products.cmd.apply_filters            // apply a filter set to the product list BLoC
moose.products.cmd.refresh_products         // trigger a product list refresh
moose.products.cmd.clear_filters            // clear all active filters
moose.banner.cmd.refresh                    // reload banners
moose.banner.cmd.go_to_index               // jump carousel to a slide index
```

#### Third-party events

Third-party plugins use their own prefix for any events they own:

```
acme.wishlist.event.product.added           // product added to wishlist
shopify.promotions.event.coupon.applied     // coupon applied from a promotion
```

#### Legacy / adapter-level events

Adapters and non-system plugins may use the legacy `<domain>.<noun>.<verb>` form without a provider prefix. These predate the four-segment convention and remain supported:

```
cart.item.added
cart.coupon.applied
order.placed
user.logged.in
user.logged.out
locale.changed
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

`WidgetRegistry` maps string keys to builder functions for two purposes:

- **Section builders** (`registerSection`) — map a key to a `FeatureSection` builder, driven by `environment.json` section config
- **Widget builders** (`registerWidget`) — map a key to a plain widget builder that may return `null` to opt out; multiple plugins can contribute to the same key (slot-based UI injection)

Both registration types share a single internal map (`Map<String, List<_Entry>>`). Priority controls ordering within a key — higher priority is returned first.

### API

```dart
typedef SectionBuilderFn = FeatureSection Function(
  BuildContext context, {
  Map<String, dynamic>? data,
  void Function(String event, dynamic payload)? onEvent,
});

typedef WidgetBuilderFn = Widget? Function(
  BuildContext context, {
  Map<String, dynamic>? data,
  void Function(String, dynamic)? onEvent,
});

class WidgetRegistry {
  WidgetRegistry();

  /// Register a FeatureSection builder under a key.
  void registerSection(String name, SectionBuilderFn builder, {int priority = 0});

  /// Register a plain widget builder under a key.
  /// Multiple plugins may register builders for the same key.
  /// Builder may return null to opt out.
  void registerWidget(String name, WidgetBuilderFn builder, {int priority = 0});

  /// Build the first non-null result for a key.
  /// In debug mode: returns UnknownSectionWidget if no builder produces a result.
  /// In release mode: returns SizedBox.shrink() if no builder produces a result.
  Widget build(
    String name,
    BuildContext context, {
    Map<String, dynamic>? data,
    void Function(String event, dynamic payload)? onEvent,
  });

  /// Call all builders for a key; collect non-null results in priority order.
  /// Builder errors are caught and logged; other builders continue running.
  List<Widget> buildAll(
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
    widgetRegistry.registerSection(
      'products.featured_section',
      (context, {data, onEvent}) => FeaturedProductsSection(
        settings: data?['settings'] as Map<String, dynamic>?,
      ),
    );

    widgetRegistry.registerSection(
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

### Registering widget builders (in a plugin)

Use `registerWidget` when multiple plugins may contribute to the same named slot:

```dart
class PromotionsPlugin extends FeaturePlugin {
  @override
  void onRegister() {
    widgetRegistry.registerWidget(
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
    widgetRegistry.registerWidget(
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

### Slot injection with buildAll (in a widget)

Use `buildAll` to collect contributions from all registered widget builders for a slot:

```dart
class ProductCard extends StatelessWidget {
  final Product product;

  @override
  Widget build(BuildContext context) {
    final badges = context.moose.widgetRegistry.buildAll(
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

### Widget builder naming convention

System plugins follow the four-segment `<provider>.<plugin>.<type>.<name>` convention.

#### Grammar

| Segment | Meaning | Examples |
|---|---|---|
| `<provider>` | Who owns the name | `moose` (system), `acme` (third-party), `shopify` (vendor plugin) |
| `<plugin>` | Which plugin registers it | `products`, `banner`, `cart`, `auth` |
| `<type>` | Registration category | `section`, `slot`, `widget` |
| `<name>` | What it is | `categories`, `product_card`, `detail:price` |

**Dots** separate the four structural segments.
**Colons** are used only *within* the `<name>` segment for sub-path hierarchy.
`{key}` within a name is a runtime placeholder substituted per instance.

#### `registerSection` keys

```
moose.products.section.categories           // grid of product categories
moose.products.section.collections         // horizontal collections carousel
moose.products.section.products            // configurable products carousel
moose.products.section.detail:image_gallery // product detail — image gallery section
moose.products.section.detail:price        // product detail — price section
moose.products.section.list_filter_bar     // product list — filter bar
moose.banner.section.banner                // swipeable promotional banner carousel
```

#### `registerWidget` keys — named widgets

Named widgets are reusable instances callable by any plugin via `widgetRegistry.build(...)`:

```
moose.products.widget.product_card         // renders a ProductCard — no ProductCard import needed
core_ui.close_button                       // core UI close/back button
```

#### `registerWidget` keys — slot injection

Slots allow injection and override. Colon separates the component path from the slot name within `<name>`:

```
moose.products.slot.product_card:media             // replace media gallery in ProductCard
moose.products.slot.product_card:sale_badge        // replace sale badge in ProductCard
moose.products.slot.product_card:after_media       // inject after media (buildAll)
moose.products.slot.detail:image_gallery           // override detail image gallery section
moose.products.slot.detail:action_bar              // override detail action bar
moose.products.slot.section:{key}:loading          // override loading state per section instance
moose.products.slot.section:{key}:build_product_card // override individual product card in carousel
moose.banner.slot.{key}:build_banner_item          // override individual banner slide
moose.banner.slot.{key}:build_banner_overlay       // override per-slide title overlay
```

#### Third-party naming

Third-party plugins prefix with their own vendor + plugin identifiers:

```
acme.wishlist.slot.product_card:after_price    // wishlist button after price in ProductCard
acme.loyalty.section.points_banner            // loyalty points section
shopify.promotions.slot.home_banner:build_banner_overlay // custom overlay on home banner
```

**Rule**: Never register a `moose.*` name from a third-party plugin. The `moose.` prefix is reserved for system-owned extensions.

---

## ActionRegistry

### Purpose

`ActionRegistry` handles `UserInteraction` entities — the standard way entities in `moose_core` carry tap/action data. It dispatches to the correct handler based on `UserInteractionType`:

- `internal` → `MooseNavigator.of(context).pushNamed()` with the route and parameters
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
// Internal navigation (goes through MooseNavigator.of(context).pushNamed())
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
    widgetRegistry.registerSection('...', ...);
    widgetRegistry.registerWidget('...', ...);
    actionRegistry.registerCustomHandler('...', ...);
    eventBus.on('...', (event) { ... });
  }
}
```

### From a widget (via context.moose)

```dart
context.moose.hookRegistry
context.moose.widgetRegistry
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

test('buildAll returns only non-null results in priority order', () {
  final registry = WidgetRegistry();

  registry.registerWidget('slot', (ctx, {data, onEvent}) => const Text('A'), priority: 10);
  registry.registerWidget('slot', (ctx, {data, onEvent}) => null, priority: 5);
  registry.registerWidget('slot', (ctx, {data, onEvent}) => const Text('C'), priority: 1);

  // Requires a real BuildContext — use flutter_test's tester
  // Result contains Text('A') and Text('C'); null entry is excluded
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
T result = hookRegistry.execute('hook:name', data);               // sync — asserts on Future return
T result = await hookRegistry.executeAsync('hook:name', data);    // async — awaits each callback
bool exists = hookRegistry.hasHook('hook:name');

// EventBus
final sub = eventBus.on('event.name', (event) { ... });
eventBus.onAsync('event.name', (event) async { ... });
eventBus.fire('event.name', data: {'key': 'value'});
await eventBus.fireAndFlush('event.name', data: {...});
await sub.cancel(); // in onStop()

// WidgetRegistry
widgetRegistry.registerSection('plugin.section_name', (ctx, {data, onEvent}) => MySection(...));
widgetRegistry.registerWidget('component:slot', (ctx, {data, onEvent}) => MyWidget(...), priority: 10);
Widget w = widgetRegistry.build('plugin.section_name', ctx, data: {...});
List<Widget> ws = widgetRegistry.buildAll('component:slot', ctx, data: {...});
List<Widget> sections = widgetRegistry.buildSectionGroup(ctx, pluginName: 'home', groupName: 'main');
bool exists = widgetRegistry.isRegistered('plugin.section_name');

// ActionRegistry
actionRegistry.registerCustomHandler('action_id', (ctx, params) { ... });
actionRegistry.handleInteraction(ctx, userInteraction);
bool has = actionRegistry.hasCustomHandler('action_id');
```

---

## Related

- [PLUGIN_SYSTEM.md](./PLUGIN_SYSTEM.md) — Plugin lifecycle and how registries are used from plugins
- [ADAPTER_SYSTEM.md](./ADAPTER_SYSTEM.md) — How adapters pass registries to repository constructors
- [FEATURE_SECTION.md](./FEATURE_SECTION.md) — FeatureSection and WidgetRegistry integration
- [EVENT_SYSTEM_GUIDE.md](./EVENT_SYSTEM_GUIDE.md) — Extended EventBus and HookRegistry patterns
- [ARCHITECTURE.md](./ARCHITECTURE.md) — Overall layer structure
