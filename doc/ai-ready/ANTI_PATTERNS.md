# Anti-Patterns Reference

> **Critical:** These patterns will break the architecture. NEVER use them.

## Table of Contents
1. [State Management Anti-Patterns](#state-management-anti-patterns)
2. [Data Access Anti-Patterns](#data-access-anti-patterns)
3. [Configuration Anti-Patterns](#configuration-anti-patterns)
4. [Structure Anti-Patterns](#structure-anti-patterns)
5. [Type Anti-Patterns](#type-anti-patterns)
6. [Quick Reference Checklist](#quick-reference-checklist)

## State Management Anti-Patterns

### ❌ ANTI-PATTERN 1: StatefulWidget with setState() for Business Logic

**Why it's wrong:**
- Mixes UI and business logic
- Not testable
- Not reusable
- Violates separation of concerns

**Wrong:**
```dart
class ProductsSection extends StatefulWidget {
  @override
  _ProductsSectionState createState() => _ProductsSectionState();
}

class _ProductsSectionState extends State<ProductsSection> {
  List<Product> _products = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadProducts(); // ❌ Business logic in widget
  }

  Future<void> _loadProducts() async {
    setState(() => _isLoading = true);
    final products = await repository.getProducts(); // ❌ Direct repository call
    setState(() {
      _products = products;
      _isLoading = false;
    });
  }
}
```

**Correct:**
```dart
// BLoC
class ProductsBloc extends Bloc<ProductsEvent, ProductsState> {
  final ProductsRepository repository;
  ProductFilters _currentFilters = const ProductFilters();

  ProductsBloc(this.repository) : super(ProductsInitial()) {
    on<LoadProducts>(_onLoadProducts);
  }

  Future<void> _onLoadProducts(
    LoadProducts event,
    Emitter<ProductsState> emit,
  ) async {
    emit(ProductsLoading());
    try {
      _currentFilters = event.filters ?? const ProductFilters();
      final products = await repository.getProducts(_currentFilters);
      emit(ProductsLoaded(
        products: products,
        activeFilters: _currentFilters.hasActiveFilters ? _currentFilters : null,
      ));
    } catch (e) {
      emit(ProductsError(
        e.toString(),
        activeFilters: _currentFilters.hasActiveFilters ? _currentFilters : null,
      ));
    }
  }
}

// Widget
class ProductsSection extends FeatureSection {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ProductsBloc(repository)..add(const LoadProducts()),
      child: BlocBuilder<ProductsBloc, ProductsState>(
        builder: (context, state) {
          if (state is ProductsLoading) return const CircularProgressIndicator();
          if (state is ProductsLoaded) return _buildProducts(state.products);
          if (state is ProductsError) {
            return Column(
              children: [
                Text(state.message),
                TextButton(
                  onPressed: () => context.read<ProductsBloc>().add(
                        LoadProducts(filters: state.activeFilters),
                      ),
                  child: const Text('Retry'),
                ),
              ],
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }
}
```

### ❌ ANTI-PATTERN 2: Dropping Request Context from Error States

**Why it's wrong:**
- Retry buttons can't restore user choices
- Analytics hooks lose visibility into the failing request
- Filter badges reset even though the user never cleared them

**Wrong:**
```dart
class ProductsError extends ProductsState {
  final String message;
  const ProductsError(this.message);
}

emit(ProductsError(e.toString()));
```

**Correct:**
```dart
class ProductsError extends ProductsState {
  final String message;
  final ProductFilters? activeFilters;

  const ProductsError(this.message, {this.activeFilters});
}

emit(ProductsError(
  e.toString(),
  activeFilters: _currentFilters.hasActiveFilters ? _currentFilters : null,
));
```

### ❌ ANTI-PATTERN 3: Resolving `RefreshIndicator` Before the BLoC Finishes

**Why it's wrong:**
- The spinner stops even though the bloc is still fetching
- Users think nothing happened
- Race conditions when multiple refreshes stack up

**Wrong:**
```dart
RefreshIndicator(
  onRefresh: () async {
    context.read<ProductsBloc>().add(const RefreshProductsEvent());
  },
  child: _buildList(),
);
```

**Correct:**
```dart
RefreshIndicator(
  onRefresh: () async {
    final bloc = context.read<ProductsBloc>();
    bloc.add(RefreshProductsEvent(filters: state.activeFilters));
    await bloc.stream.firstWhere(
      (next) => next is ProductsLoaded || next is ProductsError,
    );
  },
  child: _buildList(),
);
```
## Data Access Anti-Patterns

### ❌ ANTI-PATTERN 4: Direct API Calls from BLoCs

**Why it's wrong:**
- Tight coupling to backend
- Not swappable
- Violates repository pattern

**Wrong:**
```dart
class ProductsBloc extends Bloc<ProductsEvent, ProductsState> {
  Future<void> _onLoadProducts(...) async {
    // ❌ Direct API call
    final response = await http.get('https://api.example.com/products');
    final products = (jsonDecode(response.body) as List)
        .map((json) => Product.fromJson(json))
        .toList();
    emit(ProductsLoaded(products));
  }
}
```

**Correct:**
```dart
class ProductsBloc extends Bloc<ProductsEvent, ProductsState> {
  final ProductsRepository repository; // ✅ Use repository interface

  ProductsBloc(this.repository) : super(ProductsInitial());

  Future<void> _onLoadProducts(...) async {
    // ✅ Call through repository
    final products = await repository.getProducts();
    emit(ProductsLoaded(products));
  }
}
```

### ❌ ANTI-PATTERN 5: Business Logic in Repositories

**Why it's wrong:**
- Violates single responsibility
- Can't be tested independently
- Wrong layer

**Wrong:**
```dart
class WooProductsRepository implements ProductsRepository {
  @override
  Future<List<Product>> getProducts(ProductFilters? filters) async {
    final dtos = await _client.getProducts();
    // ❌ Business logic in repository
    final filtered = dtos.where((p) => p.price > 10).toList();
    final sorted = filtered..sort((a, b) => a.price.compareTo(b.price));
    return sorted.map(_toEntity).toList();
  }
}
```

**Correct:**
```dart
// Repository: Just data access
class WooProductsRepository implements ProductsRepository {
  @override
  Future<List<Product>> getProducts(ProductFilters? filters) async {
    final dtos = await _client.getProducts(filters);
    return dtos.map(_toEntity).toList(); // ✅ Just convert and return
  }
}

// BLoC: Business logic
class ProductsBloc extends Bloc<ProductsEvent, ProductsState> {
  Future<void> _onLoadProducts(...) async {
    final products = await repository.getProducts();
    // ✅ Business logic in BLoC
    final filtered = products.where((p) => p.price > 10).toList();
    final sorted = filtered..sort((a, b) => a.price.compareTo(b.price));
    emit(ProductsLoaded(sorted));
  }
}
```

### ❌ ANTI-PATTERN 6: Returning DTOs from Repositories

**Why it's wrong:**
- Leaks implementation details
- Tight coupling to backend
- Violates abstraction

**Wrong:**
```dart
abstract class ProductsRepository {
  Future<List<WooProductDTO>> getProducts(); // ❌ Returns DTO
}
```

**Correct:**
```dart
abstract class ProductsRepository extends CoreRepository {
  Future<List<Product>> getProducts(); // ✅ Returns domain entity
}

class WooProductsRepository implements ProductsRepository {
  @override
  Future<List<Product>> getProducts() async {
    final dtos = await _client.getProducts();
    return dtos.map(_convertToEntity).toList(); // ✅ Convert DTO to entity
  }
}
```

## Configuration Anti-Patterns

### ❌ ANTI-PATTERN 7: Hardcoded Values in FeatureSections

**Why it's wrong:**
- Not configurable
- Not reusable
- Magic numbers

**Wrong:**
```dart
class CollectionsSection extends FeatureSection {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(20), // ❌ Hardcoded
      child: Text(
        'CURATED COLLECTIONS', // ❌ Hardcoded
        style: TextStyle(fontSize: 18), // ❌ Hardcoded
      ),
    );
  }
}
```

**Correct:**
```dart
class CollectionsSection extends FeatureSection {
  @override
  Map<String, dynamic> getDefaultSettings() {
    return {
      'title': 'CURATED COLLECTIONS',
      'titleFontSize': 18.0,
      'horizontalPadding': 20.0,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: getSetting<double>('horizontalPadding'), // ✅ Configurable
      ),
      child: Text(
        getSetting<String>('title'), // ✅ Configurable
        style: TextStyle(
          fontSize: getSetting<double>('titleFontSize'), // ✅ Configurable
        ),
      ),
    );
  }
}
```

### ❌ ANTI-PATTERN 8: Not Implementing getDefaultSettings()

**Why it's wrong:**
- Settings scattered in code
- Hard to maintain
- Not documented

**Wrong:**
```dart
class MySection extends FeatureSection {
  @override
  Widget build(BuildContext context) {
    final title = settings?['title'] ?? 'Default Title'; // ❌ Default in code
    final padding = settings?['padding'] ?? 20.0; // ❌ Default in code
    // ...
  }
}
```

**Correct:**
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
    final title = getSetting<String>('title'); // ✅ Type-safe, fail-fast
    final padding = getSetting<double>('padding');
    // ...
  }
}
```

## Structure Anti-Patterns

### ❌ ANTI-PATTERN 9: Using StatefulWidget for FeatureSections

**Why it's wrong:**
- Breaks FeatureSection contract (must extend FeatureSection, not StatefulWidget)
- Loses configuration system (getSetting<T>() not available)
- Not registerable with WidgetRegistry
- Mixes widget lifecycle management with business logic
- State management should be handled by BLoC, not widget state

**Wrong:**
```dart
// ❌ Extending StatefulWidget to listen to EventBus
class RecentlyViewedSection extends StatefulWidget {
  final ProductsRepository repository;
  final Map<String, dynamic>? settings;

  const RecentlyViewedSection({
    super.key,
    required this.repository,
    this.settings,
  });

  @override
  State<RecentlyViewedSection> createState() => _RecentlyViewedSectionState();
}

class _RecentlyViewedSectionState extends State<RecentlyViewedSection> {
  late final RecentlyViewedBloc _bloc;
  EventSubscription? _eventSubscription;

  @override
  void initState() {
    super.initState();
    _bloc = RecentlyViewedBloc(/* ... */);

    // ❌ EventBus subscription in widget state (and using EventBus() as singleton)
    _eventSubscription = EventBus().on('product.viewed', (event) {
      _bloc.add(LoadRecentlyViewed());
    });
  }

  @override
  void dispose() {
    _eventSubscription?.cancel();
    _bloc.close();
    super.dispose();
  }
}
```

**Correct:**
```dart
// ✅ EventBus subscription in BLoC, not widget
class RecentlyViewedBloc extends Bloc<RecentlyViewedEvent, RecentlyViewedState> {
  final RecentlyViewedService _service;
  final ProductsRepository _repository;
  EventSubscription? _eventSubscription;

  RecentlyViewedBloc({
    required RecentlyViewedService service,
    required ProductsRepository repository,
  })  : _service = service,
        _repository = repository,
        super(const RecentlyViewedState()) {
    on<LoadRecentlyViewed>(_onLoadRecentlyViewed);

    // ✅ EventBus subscription in BLoC — receive eventBus via constructor injection
    _eventSubscription = eventBus.on('product.viewed', (event) {
      add(LoadRecentlyViewed(
        maxAge: state.maxAge,
        cacheTTL: state.cacheTTL,
      ));
    });
  }

  @override
  Future<void> close() {
    _eventSubscription?.cancel();
    return super.close();
  }
}

// ✅ Section extends FeatureSection (stateless)
class RecentlyViewedSection extends FeatureSection {
  final ProductsRepository repository;

  const RecentlyViewedSection({
    super.key,
    required this.repository,
    super.settings,
  });

  @override
  Map<String, dynamic> getDefaultSettings() {
    return {
      'title': 'RECENTLY VIEWED',
      'maxAge': 72,
      'cacheTTL': 24,
    };
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => RecentlyViewedBloc(
        service: RecentlyViewedService(),
        repository: repository,
      )..add(LoadRecentlyViewed(
          maxAge: Duration(hours: getSetting<int>('maxAge')),
          cacheTTL: Duration(hours: getSetting<int>('cacheTTL')),
        )),
      child: BlocBuilder<RecentlyViewedBloc, RecentlyViewedState>(
        builder: (context, state) {
          // UI based on state
        },
      ),
    );
  }
}
```

**Key Principle:** If you need to react to external events (EventBus, timers, etc.), put that logic in the BLoC, not in widget state. The BLoC should listen and emit new states; the widget should only build UI based on those states.

### ❌ ANTI-PATTERN 10: Not Extending FeatureSection for Sections

**Why it's wrong:**
- Loses configuration system
- Not registerable with WidgetRegistry
- Inconsistent

**Wrong:**
```dart
class MySection extends StatelessWidget { // ❌ Should extend FeatureSection
  @override
  Widget build(BuildContext context) {
    return Container(/* ... */);
  }
}
```

**Correct:**
```dart
class MySection extends FeatureSection { // ✅ Extends FeatureSection
  const MySection({super.key, super.settings});

  @override
  Map<String, dynamic> getDefaultSettings() { /* ... */ }

  @override
  Widget build(BuildContext context) { /* ... */ }
}
```

### ❌ ANTI-PATTERN 11: Not Extending CoreRepository

**Why it's wrong:**
- Inconsistent API
- Violates repository contract
- Can't be registered with adapter

**Wrong:**
```dart
abstract class ProductsService { // ❌ Doesn't extend CoreRepository
  Future<List<Product>> getProducts();
}
```

**Correct:**
```dart
abstract class ProductsRepository extends CoreRepository { // ✅ Extends CoreRepository
  Future<List<Product>> getProducts();
}
```

## Type Anti-Patterns

### ❌ ANTI-PATTERN 12: Using int for UI Dimensions

**Why it's wrong:**
- Flutter uses double for dimensions
- Causes type errors with getSetting<double>()

**Wrong:**
```dart
@override
Map<String, dynamic> getDefaultSettings() {
  return {
    'padding': 20, // ❌ int
    'fontSize': 16, // ❌ int
    'width': 100, // ❌ int
  };
}
```

**Correct:**
```dart
@override
Map<String, dynamic> getDefaultSettings() {
  return {
    'padding': 20.0, // ✅ double
    'fontSize': 16.0, // ✅ double
    'width': 100.0, // ✅ double
    'itemCount': 10, // ✅ int OK for counts
  };
}
```

### ❌ ANTI-PATTERN 13: Not Using Equatable for Events/States

**Why it's wrong:**
- BLoC can't properly compare states
- Unnecessary rebuilds
- Broken state management

**Wrong:**
```dart
class ProductsLoaded extends ProductsState { // ❌ No Equatable
  final List<Product> products;
  const ProductsLoaded(this.products);
}
```

**Correct:**
```dart
class ProductsLoaded extends ProductsState {
  final List<Product> products;
  const ProductsLoaded(this.products);

  @override
  List<Object?> get props => [products]; // ✅ Equatable
}
```

### ❌ ANTI-PATTERN 14: Mutable Events/States

**Why it's wrong:**
- Violates BLoC contract
- Unpredictable behavior
- Hard to debug

**Wrong:**
```dart
class LoadProducts extends ProductsEvent {
  ProductFilters? filters; // ❌ Mutable
  LoadProducts({this.filters});
}
```

**Correct:**
```dart
class LoadProducts extends ProductsEvent {
  final ProductFilters? filters; // ✅ Immutable (final)
  const LoadProducts({this.filters}); // ✅ const constructor
}
```

### ❌ ANTI-PATTERN 15: Not Handling Error States

**Why it's wrong:**
- Poor user experience
- Crashes on errors
- Hard to debug

**Wrong:**
```dart
Future<void> _onLoadProducts(...) async {
  emit(ProductsLoading());
  final products = await repository.getProducts(); // ❌ No try-catch
  emit(ProductsLoaded(products));
}
```

**Correct:**
```dart
Future<void> _onLoadProducts(...) async {
  emit(ProductsLoading());
  try {
    final products = await repository.getProducts();
    emit(ProductsLoaded(products));
  } catch (e) {
    emit(ProductsError(e.toString())); // ✅ Handle errors
  }
}
```

### ❌ ANTI-PATTERN 16: Global / Static Cache Access

**Why it's wrong:**
- Two `MooseAppContext` instances share state — isolation breaks
- Tests leak state between runs
- Prevents proper DI and testability

**Wrong:**
```dart
// ❌ Static facade (removed in v1.2)
CacheManager.memoryCacheInstance().set('key', value);
CacheManager.persistentCacheInstance().getString('pref');

// ❌ Direct singleton construction
final cache = MemoryCache();   // shares global state
final cache = PersistentCache(); // shares global state
```

**Correct:**
```dart
// ✅ Always access through MooseAppContext
appContext.cache.memory.set('key', value);
await appContext.cache.persistent.getString('pref');

// ✅ In widgets
context.moose.cache.memory.set('key', value);
```

## Quick Reference Checklist

Before committing code, check:

**Core Patterns:**
- [ ] ✅ All state management uses BLoC pattern
- [ ] ✅ No setState() for business logic
- [ ] ✅ All data access through repository interfaces
- [ ] ✅ No direct API calls from BLoCs or widgets
- [ ] ✅ All repositories extend CoreRepository
- [ ] ✅ Repositories return domain entities (not DTOs)
- [ ] ✅ No business logic in repositories

**FeatureSection:**
- [ ] ✅ All sections extend FeatureSection
- [ ] ✅ All settings in getDefaultSettings()
- [ ] ✅ All configurable values use getSetting<T>()
- [ ] ✅ Use double for UI dimensions
- [ ] ✅ No hardcoded values in sections

**BLoC:**
- [ ] ✅ Use Equatable for Events and States
- [ ] ✅ Immutable Events and States (final, const)
- [ ] ✅ Error handling in BLoCs
- [ ] ✅ Emit initial state in constructor

**Cache:**
- [ ] ✅ All cache access via `appContext.cache` or `context.moose.cache`
- [ ] ✅ No `CacheManager.memoryCacheInstance()` / `persistentCacheInstance()` (removed)
- [ ] ✅ No direct `MemoryCache()` / `PersistentCache()` construction outside tests
- [ ] ✅ Dispose `appContext.cache` when tearing down a context in tests

**Plugin:**
- [ ] ✅ Extend FeaturePlugin
- [ ] ✅ Sections registered in WidgetRegistry
- [ ] ✅ Provide name and version
- [ ] ✅ Don't depend directly on other plugins

---

**Remember:** Following these patterns isn't optional—they're required for architectural consistency.

**See Also:**
- [ARCHITECTURE.md](./ARCHITECTURE.md) - Complete architectural guide
- [PLUGIN_SYSTEM.md](./PLUGIN_SYSTEM.md) - Plugin development
- [FEATURE_SECTION.md](./FEATURE_SECTION.md) - Section patterns
- [ADAPTER_PATTERN.md](./ADAPTER_PATTERN.md) - Adapter implementation

---

**Last Updated:** 2025-11-03
**Version:** 1.0.0

