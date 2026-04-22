# Page System Guide

> **Current version: 2.3.0**

> Decision guide for AI agents adding new pages or routes to a moose_core application.

## Table of Contents
- [Overview](#overview)
- [Decision Table](#decision-table)
- [Form 1 — Plain Auto-Route](#form-1--plain-auto-route-pagescreen)
- [Form 2 — Plugin-Owned Route](#form-2--plugin-owned-route-getroutes)
- [Form 3 — Plugin-Provided Page Slot](#form-3--plugin-provided-page-slot-pageslots)
- [Use Case Examples](#use-case-examples)
- [AppBar & BottomBar Config Reference](#appbar--bottombar-config-reference)
- [Common Pitfalls](#common-pitfalls)
- [Related Documentation](#related-documentation)

---

## Overview

Every navigable screen in a moose_core app is backed by one of three page forms. The correct form depends on whether the page needs runtime state setup, multiple config-driven instances, or navigation arguments at build time.

| Form | Route registered by | Screen widget comes from |
|---|---|---|
| **Plain auto-route** | `MooseBootstrapper` | `PageScreen` — sections driven by `WidgetRegistry` |
| **Plugin-owned route** | Plugin (`getRoutes()`) | Plugin-controlled screen widget |
| **Plugin-provided page slot** | `MooseBootstrapper` | `PageSlotBuilder` returned by plugin's `pageSlots` map |

---

## Decision Table

Use this table to choose the right form before writing any code.

| Criteria | Plain auto-route | Plugin-owned route | Page slot |
|---|:---:|:---:|:---:|
| Purely layout-driven (no custom BLoC setup) | ✅ | — | — |
| Needs BLoC or async state initialised at route creation | — | ✅ | ✅ |
| Needs navigation arguments (`productId`, `postId`, etc.) at build time | — | ✅ | ✅ |
| Multiple config-driven instances of the same screen (different filters, sections, layouts) | — | — | ✅ |
| Different section layout per instance without code changes | — | — | ✅ |
| Route layout defined entirely in `environment.json` | ✅ | — | ✅ (sections per-instance) |
| Plugin full-controls screen (no env.json layout needed) | — | ✅ | — |

**Quick rule:**
- No BLoC, no args → **plain auto-route**
- One route, one screen, plugin owns it → **plugin-owned route**
- Multiple routes sharing the same logic, or needs `routeArgs` → **page slot**

---

## Form 1 — Plain Auto-Route (PageScreen)

### When to use

The page is purely layout-driven. Its sections, appBar, and bottomBar are fully defined in `environment.json`. No BLoC setup is needed, and no navigation arguments are required at build time.

Good fits: About pages, brand story pages, static landing pages, promotional pages with only section widgets.

### How it works

`MooseBootstrapper` detects any page entry without a `"plugin"` field and without a `"pageSlotIdentifier"` field and automatically wraps it in `PageScreen`. Sections are looked up from `WidgetRegistry` by name at render time.

### environment.json

```json
{
  "pages": [
    {
      "route": "/about",
      "description": "Brand story page",
      "active": true,
      "appBar": {
        "title": "Our Story",
        "floating": false,
        "pinned": true,
        "buttonsLeft": [{ "name": "core_ui.back_button" }],
        "buttonsRight": []
      },
      "sections": [
        {
          "name": "moose.banner.section.banner",
          "settings": { "key": "about_hero", "height": 280 }
        },
        {
          "name": "moose.blog.section.latest_posts",
          "settings": { "title": "News", "limit": 3 }
        }
      ]
    }
  ]
}
```

### No Dart code required

The bootstrapper handles everything. There is no plugin class change needed.

---

## Form 2 — Plugin-Owned Route (`getRoutes`)

### When to use

The plugin needs full control over the screen widget. Typically: one specific route, custom BLoC/repository wiring at screen creation, and no need for multiple config-driven instances of the same screen.

Good fits: Login/sign-up screens, profile pages, checkout flows, search screens.

### How to implement

```dart
class ProfilePlugin extends FeaturePlugin {
  @override
  String get name => 'profile';

  @override
  String get version => '1.0.0';

  @override
  void onRegister() {}

  @override
  Future<void> onInit() async {}

  @override
  Map<String, WidgetBuilder>? getRoutes() => {
    '/profile': (_) => BlocProvider(
      create: (_) => ProfileBloc(
        adapterRegistry.getRepository<AuthRepository>(),
        eventBus: eventBus,
      )..add(const LoadProfileEvent()),
      child: const ProfileScreen(),
    ),
  };
}
```

### Reading page layout config

If the plugin still wants the layout (sections, appBar) defined in `environment.json`, declare the page entry with `"plugin": "<name>"`. The bootstrapper stores it under `plugin:<name>:<route>` and skips route registration — the plugin reads it:

```dart
Map<String, dynamic>? _resolvePageConfig(BuildContext context) {
  final pages = context.moose.configManager.get('pages');
  return (pages is Map ? pages['plugin:profile:/profile'] as Map? : null)
      ?.cast<String, dynamic>();
}
```

### environment.json (plugin-owned)

```json
{
  "pages": [
    {
      "route": "/profile",
      "plugin": "profile",
      "description": "User profile — owned by profile plugin",
      "active": true,
      "appBar": {
        "title": "My Profile",
        "floating": false,
        "pinned": true,
        "buttonsLeft": [{ "name": "core_ui.back_button" }],
        "buttonsRight": [{ "name": "profile.edit_button" }]
      },
      "sections": [
        { "name": "profile.section.header" },
        { "name": "profile.section.orders" },
        { "name": "profile.section.settings_link" }
      ]
    }
  ]
}
```

> **Note:** Setting `"plugin": "<name>"` causes the bootstrapper to store the entry under the key `plugin:<name>:<route>` and skip route registration. The plugin must register the route in `getRoutes()` itself.

---

## Form 3 — Plugin-Provided Page Slot (`pageSlots`)

### When to use

- The same plugin logic (BLoC + screen) needs to back **multiple routes**, each with different config (different filters, different section layouts), OR
- The screen needs **navigation arguments** (`productId`, `postId`, etc.) that are only available at route-build time.

Good fits: Product list pages with different filters per route, product detail pages (need `productId`), blog post detail pages (need `postId`), seasonal campaign pages with different layouts.

### PageSlotBuilder signature

```dart
typedef PageSlotBuilder = Widget Function(
  BuildContext context,
  Map<String, dynamic> pageConfig,  // full page entry from environment.json
  Map<String, dynamic> settings,    // the "settings" sub-map (empty map if absent)
  Object? routeArgs,                // ModalRoute.of(ctx)?.settings.arguments
);
```

- `pageConfig` — the complete page entry object (includes `route`, `appBar`, `sections`, etc.)
- `settings` — convenience: the `"settings"` key from the page entry (for per-instance config like filters)
- `routeArgs` — the navigation arguments passed at `MooseNavigator.of(context).pushNamed()` time (`null` when none)

### How to implement

```dart
class ProductsPlugin extends FeaturePlugin {
  final Map<String, ProductsBloc> _listBlocs = {};
  final Map<String, String> _listFilterKeys = {};
  final Map<String, ProductsBloc> _detailBlocs = {};

  @override
  Map<String, PageSlotBuilder>? get pageSlots => {
    // ── List pages ─────────────────────────────────────────────────────────
    'plugins/products/slots/product_list':
        (context, pageConfig, settings, routeArgs) {
      final route = pageConfig['route'] as String;
      final filtersRaw = settings['filters'] as Map?;
      final filters = filtersRaw != null
          ? ProductFilters.fromJson(Map<String, dynamic>.from(filtersRaw))
          : null;
      final filtersKey = filters?.toQueryParams().toString() ?? '';

      // Only create a new BLoC when the route is new or filters changed.
      if (_listBlocs[route] == null || _listFilterKeys[route] != filtersKey) {
        _listFilterKeys[route] = filtersKey;
        _listBlocs[route]?.close();
        final bloc = ProductsBloc(
          repository: adapterRegistry.getRepository<ProductsRepository>(),
          eventBus: eventBus,
          hookRegistry: hookRegistry,
        )..add(filters != null
            ? LoadProductsEvent(filters: filters)
            : const LoadProductsEvent());
        _listBlocs[route] = bloc;
      }

      return BlocProvider.value(
        value: _listBlocs[route]!,
        child: ProductsListScreen(filters: filters, pageConfig: pageConfig),
      );
    },

    // ── Detail pages ───────────────────────────────────────────────────────
    'plugins/products/slots/product_detail':
        (context, pageConfig, settings, routeArgs) {
      final productId = _extractProductId(routeArgs);

      // Guard: do not re-dispatch LoadProductDetailEvent on every rebuild.
      if (!_detailBlocs.containsKey(productId)) {
        final bloc = ProductsBloc(
          repository: adapterRegistry.getRepository<ProductsRepository>(),
          eventBus: eventBus,
          hookRegistry: hookRegistry,
        )..add(LoadProductDetailEvent(productId));
        _detailBlocs[productId] = bloc;
      }

      return BlocProvider.value(
        value: _detailBlocs[productId]!,
        child: ProductDetailScreen(pageConfig: pageConfig),
      );
    },
  };

  String _extractProductId(Object? routeArgs) {
    if (routeArgs is String && routeArgs.isNotEmpty) return routeArgs;
    if (routeArgs is Map<String, dynamic>) {
      final id = routeArgs['productId'];
      if (id is String && id.isNotEmpty) return id;
    }
    throw ArgumentError('productId is required');
  }

  @override
  Future<void> onStop() async {
    for (final bloc in _listBlocs.values) await bloc.close();
    _listBlocs.clear();
    _listFilterKeys.clear();
    for (final bloc in _detailBlocs.values) await bloc.close();
    _detailBlocs.clear();
  }
}
```

### One slot identifier → multiple routes

A single slot identifier can back any number of routes. Each route entry in `environment.json` gets its own `sections`, `appBar`, and `settings`:

```json
{
  "pages": [
    {
      "route": "/products",
      "pageSlotIdentifier": "plugins/products/slots/product_list",
      "description": "Default product catalogue",
      "appBar": { "title": "Products", "floating": true, "pinned": false,
        "buttonsLeft": [], "buttonsRight": [{ "name": "cart.app_bar_button" }] },
      "sections": [
        { "name": "moose.products.section.list_filter_bar" },
        { "name": "moose.products.section.list_grid" }
      ]
    },
    {
      "route": "/products/sale",
      "pageSlotIdentifier": "plugins/products/slots/product_list",
      "description": "Sale items — pre-filtered",
      "settings": { "filters": { "onSale": true } },
      "appBar": { "title": "Sale", "floating": true, "pinned": false,
        "buttonsLeft": [{ "name": "core_ui.back_button" }],
        "buttonsRight": [{ "name": "cart.app_bar_button" }] },
      "sections": [
        { "name": "moose.products.section.list_grid" }
      ]
    }
  ]
}
```

### Navigating with routeArgs

```dart
// Navigate to product detail — pass productId as routeArgs
MooseNavigator.of(context).pushNamed(
  context,
  '/products/item',
  arguments: {'productId': product.id},
);

// Also works with a plain String
MooseNavigator.of(context).pushNamed('/products/item', arguments: product.id);
```

---

## Use Case Examples

### Example 1 — Brand Story / About Page

**Scenario:** A static marketing page with a hero banner and a few text sections. No BLoC, no navigation arguments.

**Form:** Plain auto-route

**Why:** No state setup required. All content is section-based and layout-driven. Zero Dart code needed.

**environment.json:**
```json
{
  "route": "/about",
  "description": "Brand story page",
  "active": true,
  "appBar": {
    "title": "Our Story",
    "floating": false,
    "pinned": true,
    "buttonsLeft": [{ "name": "core_ui.back_button" }],
    "buttonsRight": []
  },
  "sections": [
    {
      "name": "moose.banner.section.banner",
      "settings": { "key": "brand_hero", "height": 320 }
    },
    {
      "name": "moose.blog.section.latest_posts",
      "settings": { "title": "In the Press", "limit": 4, "showReadMore": true }
    }
  ]
}
```

**Dart:** No changes required in any plugin.

---

### Example 2 — User Profile Page

**Scenario:** A page that loads the authenticated user's orders and account info. Needs an `AuthRepository` and a `ProfileBloc` set up at route creation time. Only one instance of this page exists.

**Form:** Plugin-owned route

**Why:** Needs BLoC wiring at screen creation. Single route, no multi-instance requirement. The plugin manages the lifecycle.

**environment.json:**
```json
{
  "route": "/profile",
  "plugin": "profile",
  "description": "User account page — owned by profile plugin",
  "active": true,
  "appBar": {
    "title": "My Account",
    "floating": false,
    "pinned": true,
    "buttonsLeft": [{ "name": "core_ui.back_button" }],
    "buttonsRight": [{ "name": "profile.section.edit_button" }]
  },
  "sections": [
    { "name": "profile.section.avatar_header" },
    { "name": "profile.section.recent_orders" },
    { "name": "profile.section.account_settings" }
  ]
}
```

**Dart sketch:**
```dart
class ProfilePlugin extends FeaturePlugin {
  @override
  String get name => 'profile';

  @override
  String get version => '1.0.0';

  @override
  void onRegister() {
    widgetRegistry.registerSection('profile.section.avatar_header', ...);
    widgetRegistry.registerSection('profile.section.recent_orders', ...);
    widgetRegistry.registerSection('profile.section.account_settings', ...);
  }

  @override
  Future<void> onInit() async {}

  @override
  Map<String, WidgetBuilder>? getRoutes() => {
    '/profile': (context) {
      final auth = adapterRegistry.getRepository<AuthRepository>();
      final pageConfig = _resolvePageConfig(context);
      return BlocProvider(
        create: (_) => ProfileBloc(auth, eventBus: eventBus)..add(LoadProfileEvent()),
        child: ProfileScreen(pageConfig: pageConfig),
      );
    },
  };

  Map<String, dynamic> _resolvePageConfig(BuildContext context) {
    final pages = context.moose.configManager.get('pages');
    return (pages is Map ? pages['plugin:profile:/profile'] as Map? : null)
        ?.cast<String, dynamic>() ?? {};
  }
}
```

---

### Example 3 — Multiple Category Product Lists

**Scenario:** The app needs `/products`, `/products/new`, `/products/sale`, and `/products/featured` — all using the same product list screen and BLoC, but with different pre-applied filters and different appBar titles.

**Form:** Page slot

**Why:** Same plugin logic and screen, multiple config-driven instances. Filters vary per route and are cleanly expressed in `environment.json` without any Dart changes.

**environment.json:**
```json
[
  {
    "route": "/products",
    "pageSlotIdentifier": "plugins/products/slots/product_list",
    "appBar": { "title": "All Products", "floating": true, "pinned": false,
      "buttonsLeft": [], "buttonsRight": [{ "name": "cart.app_bar_button" }] },
    "sections": [
      { "name": "moose.products.section.list_filter_bar" },
      { "name": "moose.products.section.list_grid" }
    ]
  },
  {
    "route": "/products/new",
    "pageSlotIdentifier": "plugins/products/slots/product_list",
    "settings": { "filters": { "orderBy": "date", "order": "desc" } },
    "appBar": { "title": "New Arrivals", "floating": true, "pinned": false,
      "buttonsLeft": [{ "name": "core_ui.back_button" }],
      "buttonsRight": [{ "name": "cart.app_bar_button" }] },
    "sections": [
      { "name": "moose.products.section.list_grid" }
    ]
  },
  {
    "route": "/products/sale",
    "pageSlotIdentifier": "plugins/products/slots/product_list",
    "settings": { "filters": { "onSale": true } },
    "appBar": { "title": "Sale", "floating": true, "pinned": false,
      "buttonsLeft": [{ "name": "core_ui.back_button" }],
      "buttonsRight": [{ "name": "cart.app_bar_button" }] },
    "sections": [
      { "name": "moose.products.section.list_grid" }
    ]
  }
]
```

**Dart sketch:** See the `product_list` slot handler in [Form 3](#form-3--plugin-provided-page-slot-pageslots) above. No new code — the `settings['filters']` value drives the BLoC event automatically.

---

### Example 4 — Product Detail Page (needs productId)

**Scenario:** `/products/item` must show a specific product. The product ID is only known at navigation time. Additionally, you want `/products/electronics` and `/products/clothing` to show the same product but with different section layouts (e.g. electronics shows specs; clothing shows size guide and reviews).

**Form:** Page slot

**Why:** Navigation argument (`productId`) must be resolved at route-build time, not at config-load time. Multiple routes with different section arrays also benefit from the per-instance config capability of slots.

**environment.json:**
```json
[
  {
    "route": "/products/item",
    "pageSlotIdentifier": "plugins/products/slots/product_detail",
    "description": "Default product detail",
    "appBar": { "floating": true, "pinned": false,
      "buttonsLeft": [{ "name": "core_ui.back_button" }],
      "buttonsRight": [{ "name": "cart.app_bar_button" }] },
    "bottomBar": { "name": "moose.products.section.detail:action_bar" },
    "sections": [
      { "name": "moose.products.section.detail:image_gallery" },
      { "name": "moose.products.section.detail:product_info" },
      { "name": "moose.products.section.detail:price" },
      { "name": "moose.products.section.detail:attribute_selector" },
      { "name": "moose.products.section.detail:stock_and_sku" },
      { "name": "moose.products.section.detail:rating" },
      { "name": "moose.products.section.detail:reviews" }
    ]
  },
  {
    "route": "/products/electronics",
    "pageSlotIdentifier": "plugins/products/slots/product_detail",
    "description": "Electronics detail — specs-focused",
    "appBar": { "floating": true, "pinned": false,
      "buttonsLeft": [{ "name": "core_ui.back_button" }],
      "buttonsRight": [{ "name": "cart.app_bar_button" }] },
    "bottomBar": { "name": "moose.products.section.detail:action_bar" },
    "sections": [
      { "name": "moose.products.section.detail:image_gallery" },
      { "name": "moose.products.section.detail:product_info" },
      { "name": "moose.products.section.detail:price" },
      { "name": "moose.products.section.detail:attribute_selector" },
      { "name": "moose.products.section.detail:stock_and_sku" },
      { "name": "moose.products.section.detail:metadata" }
    ]
  }
]
```

**Navigation call:**
```dart
MooseNavigator.of(context).pushNamed(
  context,
  '/products/electronics',
  arguments: {'productId': product.id},
);
```

**Dart sketch:**
```dart
'plugins/products/slots/product_detail':
    (context, pageConfig, settings, routeArgs) {
  final productId = _extractProductId(routeArgs); // throws if missing
  if (!_detailBlocs.containsKey(productId)) {
    _detailBlocs[productId] = ProductsBloc(
      repository: adapterRegistry.getRepository<ProductsRepository>(),
      eventBus: eventBus,
      hookRegistry: hookRegistry,
    )..add(LoadProductDetailEvent(productId));
  }
  return BlocProvider.value(
    value: _detailBlocs[productId]!,
    child: ProductDetailScreen(pageConfig: pageConfig), // sections come from pageConfig
  );
},
```

---

### Example 5 — Seasonal Campaign Landing Pages

**Scenario:** Marketing wants `/summer-sale`, `/black-friday`, and `/winter-collection` pages. Each has a distinct hero banner, different product sections, and a custom appBar. The team wants to swap layouts by editing `environment.json` without touching Dart.

**Form:** Page slot

**Why:** Each page has a completely different sections array — but they all show product grids backed by the same BLoC. Config drives everything; no navigation args are needed.

**environment.json:**
```json
[
  {
    "route": "/summer-sale",
    "pageSlotIdentifier": "plugins/products/slots/product_list",
    "settings": { "filters": { "onSale": true, "tag": "summer" } },
    "description": "Summer sale campaign page",
    "appBar": { "title": "Summer Sale ☀️", "floating": false, "pinned": true,
      "buttonsLeft": [{ "name": "core_ui.back_button" }],
      "buttonsRight": [{ "name": "cart.app_bar_button" }] },
    "sections": [
      {
        "name": "moose.banner.section.banner",
        "settings": { "key": "summer_hero", "height": 260 }
      },
      { "name": "moose.products.section.list_grid",
        "settings": { "columns": 2 } }
    ]
  },
  {
    "route": "/black-friday",
    "pageSlotIdentifier": "plugins/products/slots/product_list",
    "settings": { "filters": { "onSale": true, "orderBy": "popularity" } },
    "description": "Black Friday deals",
    "appBar": { "title": "Black Friday", "floating": false, "pinned": true,
      "buttonsLeft": [{ "name": "core_ui.back_button" }],
      "buttonsRight": [{ "name": "cart.app_bar_button" }] },
    "sections": [
      {
        "name": "moose.banner.section.banner",
        "settings": { "key": "bf_hero", "height": 200 }
      },
      { "name": "moose.products.section.list_filter_bar" },
      { "name": "moose.products.section.list_grid",
        "settings": { "columns": 3 } }
    ]
  }
]
```

**Dart:** No new plugin code. Both routes re-use the `product_list` slot handler already in `ProductsPlugin`. The `settings.filters` and `sections` differ entirely in config.

---

## AppBar & BottomBar Config Reference

### appBar fields

| Field | Type | Default | Description |
|---|---|---|---|
| `title` | `String` | `""` | Text shown in the app bar |
| `floating` | `bool` | `false` | AppBar floats over scroll content |
| `pinned` | `bool` | `true` | AppBar stays visible when scrolling |
| `buttonsLeft` | `Array` | `[]` | Widget buttons on the left side |
| `buttonsRight` | `Array` | `[]` | Widget buttons on the right side |

Each button entry in `buttonsLeft` / `buttonsRight`:

```json
{ "name": "<widget_registry_key>", "settings": {} }
```

Common button keys:

| Key | Description |
|---|---|
| `core_ui.back_button` | Standard back / pop button |
| `cart.app_bar_button` | Cart icon with badge |
| `search.app_bar_button` | Search icon |
| `auth.app_bar_button` | Login / avatar icon |

### bottomBar field

```json
"bottomBar": { "name": "<section_registry_key>" }
```

The named section is rendered below the scroll content, outside the scroll view (sticky at the bottom). Commonly used for action bars (e.g. `moose.products.section.detail:action_bar`).

---

## Common Pitfalls

### 1. Adding `"plugin"` field to a slot entry

`"plugin": "products"` on a page entry causes the bootstrapper to store the entry under `plugin:products:<route>` and **skip route registration entirely**. The route will be 404.

```json
// ❌ Wrong — bootstrapper skips this route
{
  "route": "/products/sale",
  "plugin": "products",
  "pageSlotIdentifier": "plugins/products/slots/product_list"
}

// ✅ Correct — no "plugin" field; bootstrapper registers the slot route
{
  "route": "/products/sale",
  "pageSlotIdentifier": "plugins/products/slots/product_list"
}
```

### 2. Calling `ModalRoute.of(context)` in the outer WidgetBuilder

`routeArgs` is already extracted for you inside the `PageSlotBuilder` call. If you need to call `ModalRoute.of()` yourself (e.g. inside a `getRoutes()` builder), wrap the call in a `Builder`:

```dart
// ❌ Wrong — ModalRoute.of(context) is null here (outer builder context)
'/profile': (context) {
  final args = ModalRoute.of(context)?.settings.arguments; // null!
  ...
}

// ✅ Correct — use a Builder to get a descendant context
'/profile': (_) => Builder(builder: (ctx) {
  final args = ModalRoute.of(ctx)?.settings.arguments;
  ...
}),
```

### 3. Not cleaning up BLoCs in `onStop()`

Page slot handlers create BLoCs per-route or per-id. All must be closed when the plugin stops:

```dart
@override
Future<void> onStop() async {
  for (final bloc in _listBlocs.values) await bloc.close();
  _listBlocs.clear();
  _listFilterKeys.clear();
  for (final bloc in _detailBlocs.values) await bloc.close();
  _detailBlocs.clear();
}
```

### 4. Re-dispatching load events on every rebuild

Flutter can call the slot builder multiple times (e.g. during hot reload or widget rebuild). Guard with `containsKey` to avoid duplicate network requests:

```dart
// ❌ Creates a new BLoC and fires a network request every rebuild
_detailBlocs[productId] = ProductsBloc(...)..add(LoadProductDetailEvent(productId));

// ✅ Only creates the BLoC once per productId
if (!_detailBlocs.containsKey(productId)) {
  _detailBlocs[productId] = ProductsBloc(...)..add(LoadProductDetailEvent(productId));
}
```

---

## Related Documentation

| Document | What it covers |
|---|---|
| [PLUGIN_SYSTEM.md](./PLUGIN_SYSTEM.md) | Full plugin lifecycle, `getRoutes()`, `pageSlots`, `FeaturePlugin` API |
| [PLUGIN_ADAPTER_CONFIG_GUIDE.md](./PLUGIN_ADAPTER_CONFIG_GUIDE.md) | Full `environment.json` structure, page entry forms reference table |
| [FEATURE_SECTION.md](./FEATURE_SECTION.md) | Building `FeatureSection` subclasses — the building blocks placed in `"sections"` arrays |
| [REGISTRIES.md](./REGISTRIES.md) | `WidgetRegistry` key naming conventions — how section and widget keys are formed |
