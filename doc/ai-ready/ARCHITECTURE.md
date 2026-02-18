# Core Architecture Guide

> Comprehensive architectural patterns and principles for moose_core package

## Table of Contents
- [Overview](#overview)
- [Architectural Patterns](#architectural-patterns)
- [Layer Architecture](#layer-architecture)
- [Plugin System](#plugin-system)
- [BLoC Pattern](#bloc-pattern)
- [Repository Pattern](#repository-pattern)
- [FeatureSection Pattern](#featuresection-pattern)
- [Configuration System](#configuration-system)
- [Adapter Pattern](#adapter-pattern)
- [Design Decisions](#design-decisions)

## Overview

The moose_core package implements a **multi-layered, plugin-based architecture** with strict separation of concerns:

```
┌─────────────────────────────────────────────────────────────┐
│                     Presentation Layer                       │
│              (Screens, Sections, Widgets)                    │
│                     - UI Rendering Only                      │
│                     - NO Business Logic                      │
└──────────────────────┬──────────────────────────────────────┘
                       │ Events/States
┌──────────────────────▼──────────────────────────────────────┐
│                  Business Logic Layer (BLoC)                 │
│                  (Events, States, BLoCs)                     │
│                - State Management                            │
│                - Business Logic Orchestration                │
└──────────────────────┬──────────────────────────────────────┘
                       │ Repository Calls
┌──────────────────────▼──────────────────────────────────────┐
│                    Repository Layer                          │
│              (Abstract Interfaces)                           │
│            - Define Data Operations                          │
│            - Platform Agnostic                               │
└──────────────────────┬──────────────────────────────────────┘
                       │ Implementation
┌──────────────────────▼──────────────────────────────────────┐
│                     Adapter Layer                            │
│         (Backend-Specific Implementation)                    │
│         - DTO ↔ Entity Conversion                           │
└─────────────────────────────────────────────────────────────┘
```

## Architectural Patterns

### 1. Plugin-Based Architecture

Every major feature area is encapsulated in a self-contained plugin.

**Purpose:** Modularity, scalability, maintainability

**Structure:**
```dart
abstract class FeaturePlugin {
  String get name;
  String get version;
  Future<void> initialize();
  Map<String, WidgetBuilder>? getRoutes();
  void onRegister();
}
```

**Example:**
```dart
class ProductsPlugin extends FeaturePlugin {
  @override
  String get name => 'products';

  @override
  String get version => '1.0.0';

  @override
  Future<void> initialize() async {
    // Register sections with WidgetRegistry
    widgetRegistry.register(
      'product.featured_section',
      (context, {data, onEvent}) => FeaturedProductsSection(
        settings: data?['settings'] as Map<String, dynamic>?,
      ),
    );
  }

  @override
  Map<String, WidgetBuilder>? getRoutes() {
    return {
      '/products': (context) => ProductsListScreen(),
      '/product': (context) => ProductDetailScreen(...),
    };
  }
}
```

**Plugin Responsibilities:**
- ✅ Register sections with `WidgetRegistry`
- ✅ Define navigation routes
- ✅ Initialize plugin-specific resources
- ✅ Provide metadata (name, version)

### 2. BLoC Pattern (Mandatory)

**Business Logic Component** - ALL state management MUST use this pattern.

**Purpose:** Separate business logic from UI, testable, predictable state management

**Structure:**
```
Event (User Action) → BLoC (Process) → State (UI Update)
```

**Rules:**
- ✅ ALL business logic in BLoCs
- ✅ Use `Equatable` for Events and States
- ✅ Immutable Events and States
- ✅ Handle errors with error states
- ❌ NO `setState()` in widgets for business logic
- ❌ NO API calls in widgets

**Example:**
```dart
// Event
abstract class ProductsEvent extends Equatable {
  const ProductsEvent();
}

class LoadProducts extends ProductsEvent {
  final ProductFilters? filters;
  const LoadProducts({this.filters});

  @override
  List<Object?> get props => [filters];
}

// State
abstract class ProductsState extends Equatable {
  const ProductsState();
}

class ProductsLoading extends ProductsState {
  @override
  List<Object?> get props => [];
}

class ProductsLoaded extends ProductsState {
  final List<Product> products;
  const ProductsLoaded(this.products);

  @override
  List<Object?> get props => [products];
}

// BLoC
class ProductsBloc extends Bloc<ProductsEvent, ProductsState> {
  final ProductsRepository repository;

  ProductsBloc(this.repository) : super(ProductsInitial()) {
    on<LoadProducts>(_onLoadProducts);
  }

  Future<void> _onLoadProducts(
    LoadProducts event,
    Emitter<ProductsState> emit,
  ) async {
    emit(ProductsLoading());
    try {
      final products = await repository.getProducts(event.filters);
      emit(ProductsLoaded(products));
    } catch (e) {
      emit(ProductsError(e.toString()));
    }
  }
}
```

### 3. Repository Pattern

Abstract interfaces for data operations, implemented by backend-specific adapters.

**Purpose:** Decouple business logic from data sources, swappable backends

**Structure:**
```dart
// Abstract Repository (in core package)
abstract class ProductsRepository extends CoreRepository {
  Future<List<Product>> getProducts(ProductFilters? filters);
  Future<Product> getProductById(String id);
  Future<List<Category>> getCategories();
}

// Adapter Implementation (in your app or separate package)
class WooProductsRepository extends CoreRepository implements ProductsRepository {
  final WooCommerceApiClient _apiClient;

  WooProductsRepository(this._apiClient);

  @override
  void initialize() {
    // Called automatically after instantiation
    _setupEventListeners();
  }

  @override
  Future<List<Product>> getProducts(ProductFilters? filters) async {
    final response = await _apiClient.get('/products', params: filters);
    final products = response.map((json) => Product.fromWooDTO(json)).toList();

    // Use eventBus to fire analytics events
    eventBus.fire(AppProductSearchedEvent(...));

    return products;
  }

  void _setupEventListeners() {
    // Setup any necessary listeners
  }
}
```

**Rules:**
- ✅ Repositories are abstract interfaces
- ✅ Return domain entities (NOT DTOs)
- ✅ All repositories extend `CoreRepository`
- ❌ NO platform-specific code in repository interfaces
- ❌ NO business logic in repositories

### 4. FeatureSection Pattern

Base class for all reusable, configurable UI sections.

**Purpose:** Consistent, configurable sections with external configuration

**Structure:**
```dart
abstract class FeatureSection extends StatelessWidget {
  final Map<String, dynamic>? settings;

  const FeatureSection({super.key, this.settings});

  /// Convenient getter for accessing the AdapterRegistry instance
  AdapterRegistry get adapters => AdapterRegistry();

  Map<String, dynamic> getDefaultSettings();

  T getSetting<T>(String key) {
    // Merge defaults with provided settings
    // Fail-fast if key missing or type mismatch
  }
}
```

**Key Features:**
- **`adapters` getter**: Direct access to `AdapterRegistry` instance
- **`getSetting<T>()`**: Type-safe configuration value retrieval
- **`getDefaultSettings()`**: Define all configurable values with defaults

**Requirements:**
- ✅ Extend `FeatureSection` (not `StatelessWidget`)
- ✅ Implement `getDefaultSettings()`
- ✅ Use `getSetting<T>()` for ALL configurable values
- ✅ Use BLoC for state management
- ✅ Accept `super.settings` parameter
- ❌ NO hardcoded values
- ❌ NO `StatefulWidget` for sections
- ❌ NO direct API/repository calls

**Example:**
```dart
class FeaturedProductsSection extends FeatureSection {
  const FeaturedProductsSection({super.key, super.settings});

  @override
  Map<String, dynamic> getDefaultSettings() {
    return {
      'title': 'FEATURED PRODUCTS',
      'titleFontSize': 18.0,
      'horizontalPadding': 20.0,
      'perPage': 10,
    };
  }

  @override
  Widget build(BuildContext context) {
    // Use adapters getter from FeatureSection base class
    final repository = adapters.getRepository<ProductsRepository>();

    return BlocProvider(
      create: (context) => ProductsBloc(repository)
        ..add(LoadProducts(limit: getSetting<int>('perPage'))),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: getSetting<double>('horizontalPadding'),
        ),
        child: Column(
          children: [
            Text(
              getSetting<String>('title'),
              style: TextStyle(
                fontSize: getSetting<double>('titleFontSize'),
              ),
            ),
            BlocBuilder<ProductsBloc, ProductsState>(
              builder: (context, state) {
                if (state is ProductsLoading) {
                  return CircularProgressIndicator();
                }
                if (state is ProductsLoaded) {
                  return _buildProducts(state.products);
                }
                if (state is ProductsError) {
                  return Text(state.message);
                }
                return SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }
}
```

## Layer Architecture

### Layer 1: Presentation

**Responsibility:** UI rendering ONLY

**Components:**
- **Screens**: Full-page views
- **Sections**: Reusable, configurable components (extend FeatureSection)
- **Widgets**: Standard Flutter widgets

**Rules:**
- ✅ Use `BlocProvider` to provide BLoCs
- ✅ Use `BlocBuilder` or `BlocListener` for state
- ✅ Sections MUST extend `FeatureSection`
- ❌ NO business logic
- ❌ NO API calls
- ❌ NO direct repository calls
- ❌ NO `setState()` for business data

### Layer 2: Business Logic (BLoC)

**Responsibility:** State management and business logic

**Components:**
- **Events**: User actions
- **States**: Data states
- **BLoCs**: Process events, emit states

**Rules:**
- ✅ Event → BLoC → State pattern
- ✅ Use `Equatable` for equality
- ✅ Call repositories for data
- ✅ Handle errors with error states
- ✅ Emit initial state in constructor
- ❌ NO direct API calls
- ❌ NO UI code

### Layer 3: Repository

**Responsibility:** Abstract data operation contracts

**Rules:**
- ✅ Abstract classes only
- ✅ Return domain entities
- ✅ Well-documented contracts
- ✅ Extend `CoreRepository`
- ❌ NO implementation details
- ❌ NO platform-specific code

### Layer 4: Adapter

**Responsibility:** Backend-specific implementations

**Components:**
- **Repository Implementations**: Implement core repository interfaces
- **DTOs**: Backend-specific data models
- **API Clients**: HTTP/network communication

**Rules:**
- ✅ Implement repository interfaces
- ✅ Convert DTOs ↔ domain entities
- ✅ Handle backend-specific errors
- ✅ Be swappable

## Plugin System

### Plugin Lifecycle

1. **Registration**: Plugin registered via `PluginRegistry`
2. **onRegister()**: Called immediately - register hooks, actions
3. **initialize()**: Called after registration - setup resources, register sections
4. **Route Setup**: `getRoutes()` called - navigation configured
5. **Runtime**: Sections built from configuration

### Example Plugin Implementation

```dart
class MyFeaturePlugin extends FeaturePlugin {
  @override
  String get name => 'my_feature';

  @override
  String get version => '1.0.0';

  @override
  void onRegister() {
    // Register hooks (executed immediately)
    hookRegistry.register('my_feature:data_loaded', (data) {
      // Transform data
      return data;
    });

    // Register custom actions
    actionRegistry.registerCustomHandler('my_action', (context, params) {
      // Handle action
    });
  }

  @override
  Future<void> initialize() async {
    // Register sections
    widgetRegistry.register(
      'my_feature.section',
      (context, {data, onEvent}) => MyFeatureSection(
        settings: data?['settings'] as Map<String, dynamic>?,
      ),
    );

    // Initialize resources
    await _initializeResources();
  }

  @override
  Map<String, WidgetBuilder>? getRoutes() {
    return {
      '/my-feature': (context) => MyFeatureScreen(),
    };
  }
}
```

## Configuration System

### Structure

Configuration is loaded from JSON and accessed via `ConfigManager`:

```dart
// Get configuration value
final value = ConfigManager().get('plugins:products:perPage');

// Get with default
final value = ConfigManager().get('plugins:products:perPage', defaultValue: 10);

// Get nested object
final cache = ConfigManager().get('plugins:products:settings:cache');
```

### Access in FeatureSection

```dart
class MySection extends FeatureSection {
  @override
  Map<String, dynamic> getDefaultSettings() {
    return {
      'title': 'Default Title',
      'padding': 20.0,
    };
  }

  @override
  Widget build(BuildContext context) {
    final title = getSetting<String>('title');
    final padding = getSetting<double>('padding');
    // Use values in UI
  }
}
```

## Adapter Pattern

### Purpose

Support multiple e-commerce backends (WooCommerce, Shopify, etc.) without changing business logic.

### Structure

The adapter system uses **lazy, factory-based repository registration**:

```dart
abstract class BackendAdapter {
  String get name;
  String get version;

  /// Repository factories storage
  final Map<Type, Object> _factories = {};

  /// Repository cache storage
  final Map<Type, Object> _cache = {};

  /// Register a synchronous factory for a repository type
  void registerRepositoryFactory<T extends CoreRepository>(
    T Function() factory,
  ) {
    _factories[T] = factory;
  }

  /// Register an asynchronous factory for a repository type
  void registerAsyncRepositoryFactory<T extends CoreRepository>(
    Future<T> Function() factory,
  ) {
    _factories[T] = factory;
  }

  /// Get repository synchronously (for sync factories)
  T getRepository<T extends CoreRepository>() {
    // Check cache first
    // Instantiate from factory if not cached
  }

  /// Get repository asynchronously (supports both sync and async factories)
  Future<T> getRepositoryAsync<T extends CoreRepository>() async {
    // Check cache first
    // Instantiate from factory if not cached
  }

  Future<void> initialize(Map<String, dynamic> config);
}
```

**Example Implementation:**
```dart
class WooCommerceAdapter extends BackendAdapter {
  @override
  String get name => 'woocommerce';

  @override
  String get version => '1.0.0';

  @override
  Future<void> initialize(Map<String, dynamic> config) async {
    // Setup API client
    final apiClient = WooCommerceApiClient(
      baseUrl: config['baseUrl'],
      consumerKey: config['consumerKey'],
      consumerSecret: config['consumerSecret'],
    );

    // Register repositories using factory-based registration
    registerRepositoryFactory<ProductsRepository>(
      () => WooProductsRepository(apiClient),
    );

    registerRepositoryFactory<CartRepository>(
      () => WooCartRepository(apiClient),
    );

    registerAsyncRepositoryFactory<ReviewRepository>(
      () async {
        final reviewConfig = await loadReviewConfig();
        return WooReviewRepository(apiClient, reviewConfig);
      },
    );
  }
}
```

### Key Benefits

**Lazy Initialization:**
- Repositories only created when first accessed
- Reduces memory footprint
- Faster app startup
- Automatic caching after first instantiation

**Type Safety:**
- Full compile-time and runtime type safety
- Generic `getRepository<T>()` ensures correct types
- All repositories must extend `CoreRepository`
- IDE autocomplete support

**Extensibility:**
- Add new repositories without modifying `BackendAdapter`
- Custom adapters can register domain-specific repositories
- Support for both synchronous and asynchronous factories

## Design Decisions

### Why Plugin-Based Architecture?
- **Modularity**: Features are isolated and independent
- **Scalability**: Easy to add new features without affecting existing ones
- **Maintainability**: Clear boundaries and responsibilities
- **Testability**: Each plugin can be tested independently

### Why BLoC Pattern?
- **Separation of Concerns**: Business logic separate from UI
- **Testability**: Easy to test business logic without UI
- **Predictability**: Clear flow: Event → BLoC → State
- **Reusability**: BLoCs can be shared across widgets

### Why Repository Pattern?
- **Abstraction**: Business logic doesn't know about backends
- **Swappability**: Easy to switch backends (WooCommerce → Shopify)
- **Testability**: Easy to mock repositories in tests
- **Consistency**: Standard interface across all data operations

### Why FeatureSection Pattern?
- **Configurability**: Sections configured externally via JSON
- **Reusability**: Same section, different configurations
- **Consistency**: All sections follow same pattern
- **Fail-Fast**: Configuration errors caught early

## Best Practices

### Code Organization
- Group by feature, not by type
- Keep files focused and under 500 lines
- Use meaningful, descriptive names
- Follow consistent naming conventions

### State Management
- Always use BLoC for business logic
- Keep widgets stateless when possible
- Emit clear, descriptive states
- Handle all error cases

### Configuration
- All configurable values in `getDefaultSettings()`
- Use `getSetting<T>()` with proper types
- Document all settings
- Use double for UI dimensions

### Testing
- Test BLoCs with `bloc_test`
- Mock repositories in tests
- Test state transitions
- Test error handling

## Related Documentation

- **[PLUGIN_SYSTEM.md](./PLUGIN_SYSTEM.md)** - Complete plugin guide
- **[FEATURE_SECTION.md](./FEATURE_SECTION.md)** - FeatureSection pattern
- **[ADAPTER_PATTERN.md](./ADAPTER_PATTERN.md)** - Adapter implementation
- **[REGISTRIES.md](./REGISTRIES.md)** - Registry systems
- **[ANTI_PATTERNS.md](./ANTI_PATTERNS.md)** - What NOT to do

---

**Last Updated:** 2025-11-03
**Version:** 1.0.0
