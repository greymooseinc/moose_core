# FeatureSection

## Overview

`FeatureSection` is the abstract base class for all configurable, JSON-driven UI sections in `moose_core`. It extends `StatelessWidget` and adds two things on top:

1. **Settings system** — a merging configuration mechanism via `getDefaultSettings()` and `getSetting<T>(key)`
2. **Registry access** — `adaptersOf(context)` to reach the scoped `AdapterRegistry` without touching `MooseScope` directly

Sections are registered in `WidgetRegistry` by plugins, configured via `environment.json`, and rendered by calling `widgetRegistry.buildSectionGroup(...)` or `widgetRegistry.build(...)` from within a screen.

---

## Class Definition

```dart
abstract class FeatureSection extends StatelessWidget {
  final Map<String, dynamic>? settings;

  const FeatureSection({super.key, this.settings});

  /// Returns the scoped AdapterRegistry from the nearest MooseScope.
  /// Must be called inside build(context).
  AdapterRegistry adaptersOf(BuildContext context) =>
      MooseScope.adapterRegistryOf(context);

  /// All configurable keys with their default values.
  /// Every key used in getSetting<T> MUST appear here.
  Map<String, dynamic> getDefaultSettings();

  /// Retrieves a setting value, merging defaults with constructor-provided settings.
  /// Constructor settings override defaults.
  /// Throws Exception if the key is absent or the type does not match.
  /// Automatic conversions: num→double, num→int, String→Color (via ColorHelper).
  T getSetting<T>(String key);
}
```

### getSetting<T> resolution order

1. Constructor `settings` map (highest priority)
2. `getDefaultSettings()` map (fallback)

If the key is absent in both, `getSetting` throws immediately with a descriptive message. If the value is present but cannot be cast to `T`, it also throws. This fail-fast behaviour catches misconfiguration during development rather than silently returning wrong values.

### Automatic type coercions in getSetting

| Requested `T` | Value type | Behaviour |
|---|---|---|
| `double` | `num` | `.toDouble()` |
| `int` | `num` | `.toInt()` |
| `Color` | `String` | `ColorHelper.parse(value)` |
| any other `T` | `T` | direct cast |

This means JSON-supplied integers like `20` are accepted when `getSetting<double>` is called, so sections work correctly regardless of whether the JSON author wrote `20` or `20.0`.

---

## Implementing a FeatureSection

### Minimal skeleton

```dart
import 'package:flutter/material.dart';
import 'package:moose_core/moose_core.dart';

class FeaturedProductsSection extends FeatureSection {
  const FeaturedProductsSection({super.key, super.settings});

  @override
  Map<String, dynamic> getDefaultSettings() {
    return {
      'title': 'Featured Products',
      'titleFontSize': 18.0,
      'horizontalPadding': 20.0,
      'verticalPadding': 16.0,
      'perPage': 10,
      'columns': 2,
    };
  }

  @override
  Widget build(BuildContext context) {
    final repo = adaptersOf(context).getRepository<ProductsRepository>();

    return BlocProvider(
      create: (_) => ProductsBloc(repo)
        ..add(LoadProducts(limit: getSetting<int>('perPage'))),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: getSetting<double>('horizontalPadding'),
          vertical: getSetting<double>('verticalPadding'),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              getSetting<String>('title'),
              style: TextStyle(fontSize: getSetting<double>('titleFontSize')),
            ),
            BlocBuilder<ProductsBloc, ProductsState>(
              builder: (context, state) {
                if (state is ProductsLoading) return const CircularProgressIndicator();
                if (state is ProductsLoaded) return _buildGrid(state.products);
                if (state is ProductsError) return Text('Error: ${state.message}');
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGrid(List<Product> products) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: getSetting<int>('columns'),
        childAspectRatio: 0.75,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: products.length,
      itemBuilder: (_, index) => ProductCard(product: products[index]),
    );
  }
}
```

### Key rules

- Call `adaptersOf(context)` only inside `build()` — it reads from the widget tree.
- Never access `settings` directly; always go through `getSetting<T>(key)`.
- Use BLoC for all state management inside a section. Keep business logic out of `build()`.
- Use `double` for all layout dimensions (padding, font size, height, width). `int` is for counts and limits.

---

## Accepting Additional Runtime Data

Sections often need data beyond settings (e.g., a product ID passed by the caller). Add extra constructor parameters alongside `super.settings`:

```dart
class RelatedProductsSection extends FeatureSection {
  final String? productId;
  final void Function(String event, dynamic payload)? onEvent;

  const RelatedProductsSection({
    super.key,
    super.settings,
    this.productId,
    this.onEvent,
  });

  @override
  Map<String, dynamic> getDefaultSettings() {
    return {
      'title': 'Related Products',
      'perPage': 6,
      'horizontalPadding': 20.0,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (productId == null) return const SizedBox.shrink();

    final repo = adaptersOf(context).getRepository<ProductsRepository>();

    return BlocProvider(
      create: (_) => RelatedProductsBloc(repo)
        ..add(LoadRelated(productId: productId!, limit: getSetting<int>('perPage'))),
      child: BlocBuilder<RelatedProductsBloc, RelatedProductsState>(
        builder: (context, state) { /* ... */ },
      ),
    );
  }
}
```

In the plugin registration, the extra parameter is extracted from `data`:

```dart
widgetRegistry.register(
  'products.related_section',
  (context, {data, onEvent}) => RelatedProductsSection(
    settings: data?['settings'] as Map<String, dynamic>?,
    productId: data?['productId'] as String?,
    onEvent: onEvent,
  ),
);
```

---

## Registering a Section

Register sections in `FeaturePlugin.onRegister()` — the synchronous registration step, called before any async initialisation.

```dart
class ProductsPlugin extends FeaturePlugin {
  @override
  String get name => 'products';

  @override
  String get version => '1.0.0';

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

  @override
  Future<void> onInit() async { /* async setup */ }
}
```

Naming convention: `<plugin_name>.<section_name>`. This namespacing prevents collisions between plugins.

---

## Configuring Sections in environment.json

Sections are declared under `plugins.<pluginName>.sections.<groupName>` as a list:

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
            "settings": {
              "title": "Top Picks",
              "perPage": 8,
              "columns": 2,
              "titleFontSize": 20.0,
              "horizontalPadding": 16.0
            }
          },
          {
            "name": "products.new_arrivals_section",
            "description": "New arrivals carousel",
            "active": false
          }
        ]
      }
    }
  }
}
```

Fields in each section entry (`SectionConfig`):

| Field | Type | Required | Default | Description |
|---|---|---|---|---|
| `name` | String | Yes | — | Registered key in `WidgetRegistry` |
| `description` | String | No | `''` | Human-readable label |
| `active` | bool | No | `true` | When `false`, section is skipped by `buildSectionGroup` |
| `settings` | Object | No | `{}` | Merged over the section's `getDefaultSettings()` |

---

## Rendering Sections

### Building a named group

`WidgetRegistry.buildSectionGroup` reads the JSON config, filters inactive entries, and builds all active sections in order:

```dart
@override
Widget build(BuildContext context) {
  final sections = context.moose.widgetRegistry.buildSectionGroup(
    context,
    pluginName: 'home',
    groupName: 'main',
  );

  return ListView(children: sections);
}
```

With optional shared data and event handler:

```dart
context.moose.widgetRegistry.buildSectionGroup(
  context,
  pluginName: 'home',
  groupName: 'main',
  data: {'someSharedKey': 'value'},
  onEvent: (event, payload) { /* handle section events */ },
);
```

The `data` map is merged into each section's data alongside its settings from config.

### Building a single section by name

```dart
final widget = context.moose.widgetRegistry.build(
  'products.featured_section',
  context,
  data: {
    'settings': {'title': 'Override Title', 'perPage': 4},
  },
  onEvent: (event, payload) { /* ... */ },
);
```

In debug mode, if the name is not registered, `build` returns an `UnknownSectionWidget` showing what was requested and what is available. In release mode it returns `SizedBox.shrink()`.

---

## Settings Type Reference

Always match the Dart type to the semantics of the value:

| Value semantics | Type in defaults | `getSetting` call |
|---|---|---|
| Layout dimension (padding, size, spacing) | `double` — `20.0` | `getSetting<double>('padding')` |
| Font size | `double` — `16.0` | `getSetting<double>('fontSize')` |
| Count / limit | `int` — `10` | `getSetting<int>('perPage')` |
| Toggle flag | `bool` — `true` | `getSetting<bool>('showHeader')` |
| Text | `String` — `'Title'` | `getSetting<String>('title')` |
| Color | `String` (hex/name) — `'#FF5722'` | `getSetting<Color>('accentColor')` |
| Nested config | `Map<String, dynamic>` | `getSetting<Map<String, dynamic>>('layout')` |

### Color format support (via ColorHelper.parse)

| Format | Example |
|---|---|
| 6-digit hex | `'#FF5733'` or `'FF5733'` |
| 3-digit hex | `'#F57'` |
| 8-digit hex with alpha | `'#80FF5733'` |
| Material color name | `'red'`, `'blue'`, `'white'`, `'transparent'` |
| RGBA | `'rgba(255, 87, 51, 1.0)'` |

Usage:

```dart
@override
Map<String, dynamic> getDefaultSettings() {
  return {
    'backgroundColor': '#FFFFFF',
    'titleColor': '#212121',
    'accentColor': '#FF5722',
  };
}

@override
Widget build(BuildContext context) {
  return Container(
    color: getSetting<Color>('backgroundColor'),
    child: Text(
      getSetting<String>('title'),
      style: TextStyle(color: getSetting<Color>('titleColor')),
    ),
  );
}
```

---

## onEvent Pattern

Sections surface user interactions back to their caller without owning navigation or business logic. The `onEvent` callback is a loose contract: the section fires a named event with a payload, and the screen decides what to do.

```dart
class PromoBannerSection extends FeatureSection {
  final void Function(String event, dynamic payload)? onEvent;

  const PromoBannerSection({super.key, super.settings, this.onEvent});

  @override
  Map<String, dynamic> getDefaultSettings() => {'height': 200.0};

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onEvent?.call('banner_tapped', {'route': '/sale'}),
      child: SizedBox(height: getSetting<double>('height')),
    );
  }
}
```

Screen handler:

```dart
context.moose.widgetRegistry.buildSectionGroup(
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
```

---

## AddonRegistry Integration

Sections can include addon slots — named injection points where other plugins contribute widgets without modifying the section. Access `addonRegistry` via `context.moose`:

```dart
@override
Widget build(BuildContext context) {
  final addons = context.moose.addonRegistry.build(
    'products.above_price',
    context,
    data: {'productId': productId},
  );

  return Column(
    children: [
      PriceWidget(price: product.price),
      ...addons,  // zero or more widgets injected by other plugins
    ],
  );
}
```

Another plugin registers into the same slot:

```dart
// In LoyaltyPlugin.onRegister()
addonRegistry.register(
  'products.above_price',
  (context, {data, onEvent}) {
    final id = data?['productId'] as String?;
    return id != null ? LoyaltyBadge(productId: id) : null;
  },
  priority: 10,
);
```

Addons are rendered in descending priority order. A builder returning `null` is silently skipped.

---

## Testing

### Settings unit tests

```dart
test('getDefaultSettings returns all required keys with correct types', () {
  final section = FeaturedProductsSection();
  final defaults = section.getDefaultSettings();

  expect(defaults['title'], isA<String>());
  expect(defaults['titleFontSize'], isA<double>());
  expect(defaults['perPage'], isA<int>());
  expect(defaults['columns'], isA<int>());
  expect(defaults['horizontalPadding'], isA<double>());
});

test('constructor settings override defaults', () {
  final section = FeaturedProductsSection(
    settings: {'title': 'Override', 'perPage': 5},
  );

  expect(section.getSetting<String>('title'), equals('Override'));
  expect(section.getSetting<int>('perPage'), equals(5));
  expect(section.getSetting<int>('columns'), equals(2)); // default unchanged
});

test('getSetting throws on missing key', () {
  final section = FeaturedProductsSection();
  expect(
    () => section.getSetting<String>('nonExistent'),
    throwsA(isA<Exception>()),
  );
});

test('getSetting coerces int to double', () {
  // Simulates JSON supplying 20 instead of 20.0
  final section = FeaturedProductsSection(settings: {'horizontalPadding': 20});
  expect(section.getSetting<double>('horizontalPadding'), equals(20.0));
});
```

---

## Rules Summary

| Rule | Reason |
|---|---|
| Extend `FeatureSection`, not `StatelessWidget` | Enables `getSetting` and `adaptersOf` |
| Every key used in `getSetting` must be in `getDefaultSettings` | Fail-fast throws if key is absent |
| Call `adaptersOf(context)` inside `build()` only | Reads from widget tree — not safe at construction time |
| Use BLoC for all state | Keeps business logic out of the widget layer |
| Use `double` for layout dimensions | Prevents type errors when JSON supplies integers |
| Register in `onRegister()`, not `onInit()` | Registration is synchronous; `onInit` is for async work |
| Name sections as `<plugin>.<section>` | Avoids cross-plugin key collisions |
| Never read `settings` map directly | Use `getSetting<T>` for merging and type safety |

---

## Related

- [PLUGIN_SYSTEM.md](./PLUGIN_SYSTEM.md) — registering sections from within a plugin
- [ARCHITECTURE.md](./ARCHITECTURE.md) — overall layer structure and DI
- [API.md](./API.md) — `WidgetRegistry`, `AddonRegistry`, and `MooseScope` API reference
