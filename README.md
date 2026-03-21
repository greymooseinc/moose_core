# moose_core

[![pub package](https://img.shields.io/pub/v/moose_core.svg)](https://pub.dev/packages/moose_core)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**Flutter e-commerce framework for AI-assisted development.**

`moose_core` gives you the architectural scaffolding to kick-start production-ready Flutter e-commerce apps — with clean architecture, a plugin system, swappable backends, and documentation structured for AI agents to generate correct code from day one.

---

## What you get

| Capability | How |
|---|---|
| **Clean architecture** | Presentation → BLoC → Repository → BackendAdapter, enforced by the framework |
| **Swappable backends** | WooCommerce, Shopify, or custom — swap without touching UI code |
| **Plugin-based features** | Every feature is an isolated `FeaturePlugin` with its own routes, widgets, and hooks |
| **Swappable themes** | `MooseTheme` bundles `ThemeData` + style resolvers; select via `environment.json` — no code change to switch |
| **AI-agent-ready** | 18 structured docs in `doc/ai-ready/` so AI agents generate correct code first time |
| **Dynamic UI composition** | `WidgetRegistry` lets adapters and plugins inject UI sections at runtime |
| **Event-driven communication** | `EventBus` + `HookRegistry` for decoupled cross-plugin messaging |
| **Multi-layer caching** | Memory + persistent cache with TTL, managed by `CacheManager` |
| **Type-safe DI** | `MooseAppContext` wires everything; `context.moose` serves it anywhere in the widget tree |

---

## Project folder structure

Below is the recommended structure for a Flutter app built with `moose_core`. Each feature lives in its own plugin and is registered at boot time.

```
my_store/
├── lib/
│   ├── main.dart                        # Bootstrap: MooseAppContext → MooseBootstrapper
│   │
│   ├── plugins/
│   │   ├── products/
│   │   │   ├── products_plugin.dart     # FeaturePlugin — registers routes & widgets
│   │   │   ├── bloc/
│   │   │   │   ├── products_bloc.dart
│   │   │   │   ├── products_event.dart
│   │   │   │   └── products_state.dart
│   │   │   ├── sections/
│   │   │   │   └── featured_products_section.dart  # FeatureSection
│   │   │   └── screens/
│   │   │       └── products_list_screen.dart
│   │   │
│   │   ├── cart/
│   │   │   ├── cart_plugin.dart
│   │   │   ├── bloc/
│   │   │   └── sections/
│   │   │
│   │   └── ...
│   │
│   ├── themes/
│   │   ├── default_theme.dart           # MooseTheme — bundles ThemeData + style resolvers
│   │   └── colorful_theme.dart
│   │
│   └── adapters/
│       └── woocommerce/
│           ├── woo_adapter.dart         # BackendAdapter — wires repositories
│           ├── woo_products_repository.dart
│           ├── woo_cart_repository.dart
│           └── woo_auth_repository.dart
│
├── pubspec.yaml
└── ...

# moose_core provides (you implement these interfaces):
#   ProductsRepository, CartRepository, AuthRepository, OrderRepository ...
#   BackendAdapter, FeaturePlugin, FeatureSection
```

---

## Architecture

```
┌────────────────────────────────────────────────────┐
│  Presentation  (Screens, FeatureSections)          │
│  → reads from BLoC, calls actionRegistry           │
└──────────────────────┬─────────────────────────────┘
                       │ events / states
┌──────────────────────▼─────────────────────────────┐
│  BLoC  (feature-scoped state machines)             │
│  → calls Repository interfaces                     │
└──────────────────────┬─────────────────────────────┘
                       │ abstract calls
┌──────────────────────▼─────────────────────────────┐
│  Repository interfaces  (defined in moose_core)    │
│  ProductsRepository, CartRepository, Auth...       │
└──────────────────────┬─────────────────────────────┘
                       │ concrete implementation
┌──────────────────────▼─────────────────────────────┐
│  BackendAdapter  (you write this per backend)      │
│  WooCommerce / Shopify / custom REST / GraphQL     │
└────────────────────────────────────────────────────┘

  MooseAppContext  ──  owns all registries
  MooseScope       ──  InheritedWidget; serves context.moose
  MooseBootstrapper ─  wires adapters + plugins at startup
```

---

## Quick start

```yaml
# pubspec.yaml
dependencies:
  moose_core: ^1.3.1
```

```dart
// main.dart
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:moose_core/app.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final config = json.decode(
    await rootBundle.loadString('config/environment.json'),
  ) as Map<String, dynamic>;

  runApp(
    MooseApp(
      config: config,
      themes: [DefaultTheme(), ColorfulTheme()],  // active theme from config['theme']
      adapters: [WooCommerceAdapter()],
      plugins: [() => ProductsPlugin(), () => CartPlugin()],
      builder: (context, appContext) => MyApp(appContext: appContext),
    ),
  );
}
```

`MooseApp` creates `MooseAppContext`, runs `MooseBootstrapper`, wraps the tree in `MooseScope`, and shows a spinner until bootstrap completes — no boilerplate required.

Supply `loadingWidget` for a custom splash screen:

```dart
MooseApp(
  config: config,
  adapters: [...],
  plugins: [...],
  builder: (context, appContext) => MyApp(appContext: appContext),
  loadingWidget: const SplashScreen(),
)
```

---

## Theming

Extend `MooseTheme` to bundle a complete visual configuration — `ThemeData` for light/dark plus style resolvers for text, buttons, inputs, and backgrounds:

```dart
class MyBrandTheme extends MooseTheme {
  @override String get name => 'my_brand';
  @override ThemeData get light => MyBrandThemes.light;
  @override ThemeData get dark => MyBrandThemes.dark;
  @override TextStyle resolveText(String name, BuildContext ctx) => MyBrandTextStyles.resolve(name, ctx);
  @override ButtonStyle resolveButton(String name, BuildContext ctx) => MyBrandButtonStyles.resolve(name, ctx);
  @override InputDecoration resolveInput(String name, BuildContext ctx, StyleHookData data) =>
      MyBrandInputStyles.resolve(name, ctx, data);
}
```

Register themes in `MooseApp` and select the active one via `environment.json`:

```dart
MooseApp(themes: [DefaultTheme(), MyBrandTheme()], ...)
```

```json
{ "theme": "my_brand" }
```

If `"theme"` is absent or does not match any registered name, the first theme in the list is used. No code change is needed to switch themes — only the JSON value changes.

---

## Core building blocks

### FeaturePlugin
```dart
class ProductsPlugin extends FeaturePlugin {
  @override String get name => 'products';
  @override String get version => '1.0.0';

  @override
  void onRegister() {
    widgetRegistry.register(
      'products.featured',
      (ctx, {data, onEvent}) => FeaturedProductsSection(settings: data?['settings']),
    );
    actionRegistry.register('products.refresh', (ctx, _) async { /* ... */ });
  }

  @override
  Map<String, WidgetBuilder>? getRoutes() => {
    '/products': (_) => ProductsListScreen(),
  };
}
```

### BackendAdapter
```dart
class WooCommerceAdapter extends BackendAdapter {
  @override String get name => 'woocommerce';
  @override String get version => '1.0.0';

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    // Each factory is auto-tagged with this adapter's name ('woocommerce') as provider.
    registerRepositoryFactory<ProductsRepository>(
      () => WooProductsRepository(apiClient, hookRegistry: hookRegistry, eventBus: eventBus),
    );
    registerRepositoryFactory<CartRepository>(
      () => WooCartRepository(apiClient, hookRegistry: hookRegistry, eventBus: eventBus),
    );
  }
}
```

Retrieve repositories:
```dart
// Default — last-registered adapter wins
appContext.getRepository<ProductsRepository>();

// Provider-scoped — specific adapter by its name
appContext.getRepository<AuthRepository>(provider: 'shopify');
appContext.getRepository<AuthRepository>(provider: 'google_sign_in');

// Optional repositories — guard before accessing
if (appContext.adapterRegistry.hasRepository<PushNotificationRepository>()) {
  final push = appContext.getRepository<PushNotificationRepository>();
}
```

### FeatureSection
```dart
class FeaturedProductsSection extends FeatureSection {
  const FeaturedProductsSection({super.key, super.settings});

  @override
  Map<String, dynamic> getDefaultSettings() => {'title': 'Featured', 'itemCount': 10};

  @override
  Widget build(BuildContext context) {
    final repo = adaptersOf(context).getRepository<ProductsRepository>();
    return BlocProvider(
      create: (_) => FeaturedProductsBloc(repo)..add(LoadFeaturedProducts()),
      child: BlocBuilder<FeaturedProductsBloc, FeaturedProductsState>(
        builder: (ctx, state) => switch (state) {
          FeaturedProductsLoaded() => _buildGrid(state.products),
          FeaturedProductsError() => Text(state.message),
          _ => const CircularProgressIndicator(),
        },
      ),
    );
  }
}
```

---

## Package modules

```dart
import 'package:moose_core/moose_core.dart';   // everything

// or selectively:
import 'package:moose_core/app.dart';          // MooseAppContext, MooseScope, MooseBootstrapper
import 'package:moose_core/entities.dart';     // Product, Cart, Order, Category, User ...
import 'package:moose_core/repositories.dart'; // ProductsRepository, CartRepository ...
import 'package:moose_core/plugin.dart';       // FeaturePlugin, PluginRegistry
import 'package:moose_core/widgets.dart';      // FeatureSection, WidgetRegistry, UnknownSectionWidget
import 'package:moose_core/adapters.dart';     // BackendAdapter, AdapterRegistry
import 'package:moose_core/cache.dart';        // CacheManager, MemoryCache, PersistentCache
import 'package:moose_core/services.dart';     // EventBus, HookRegistry, ActionRegistry, ApiClient
```

---

## AI-assisted development

The `doc/ai-ready/` directory contains 18 structured documents written for AI agents and developers:

- [Architecture Guide](doc/ai-ready/ARCHITECTURE.md)
- [Plugin System](doc/ai-ready/PLUGIN_SYSTEM.md)
- [Adapter Pattern](doc/ai-ready/ADAPTER_PATTERN.md)
- [FeatureSection Guide](doc/ai-ready/FEATURE_SECTION.md)
- [Event System](doc/ai-ready/EVENT_SYSTEM_GUIDE.md)
- [Registries](doc/ai-ready/REGISTRIES.md)
- [Anti-Patterns](doc/ai-ready/ANTI_PATTERNS.md)
- [API Reference](doc/ai-ready/API.md)

---

## Requirements

- Dart SDK `>=3.0.0 <4.0.0`
- Flutter `>=3.0.0`

**Dependencies:** `flutter_bloc`, `equatable`, `dio`, `shared_preferences`, `intl`

---

## License

MIT — see [LICENSE](LICENSE).

[pub.dev](https://pub.dev/packages/moose_core) · [Issues](https://github.com/greymooseinc/moose_core/issues) · [Changelog](CHANGELOG.md)
