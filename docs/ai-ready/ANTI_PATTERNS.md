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

  ProductsBloc(this.repository) : super(ProductsInitial()) {
    on<LoadProducts>(_onLoadProducts);
  }

  Future<void> _onLoadProducts(
    LoadProducts event,
    Emitter<ProductsState> emit,
  ) async {
    emit(ProductsLoading());
    try {
      final products = await repository.getProducts();
      emit(ProductsLoaded(products));
    } catch (e) {
      emit(ProductsError(e.toString()));
    }
  }
}

// Widget
class ProductsSection extends FeatureSection {
  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ProductsBloc(repository)..add(LoadProducts()),
      child: BlocBuilder<ProductsBloc, ProductsState>(
        builder: (context, state) {
          if (state is ProductsLoading) return CircularProgressIndicator();
          if (state is ProductsLoaded) return _buildProducts(state.products);
          if (state is ProductsError) return Text(state.message);
          return SizedBox.shrink();
        },
      ),
    );
  }
}
```

## Data Access Anti-Patterns

### ❌ ANTI-PATTERN 2: Direct API Calls from BLoCs

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

### ❌ ANTI-PATTERN 3: Business Logic in Repositories

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

### ❌ ANTI-PATTERN 4: Returning DTOs from Repositories

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

### ❌ ANTI-PATTERN 5: Hardcoded Values in FeatureSections

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

### ❌ ANTI-PATTERN 6: Not Implementing getDefaultSettings()

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

### ❌ ANTI-PATTERN 7: Not Extending FeatureSection for Sections

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

### ❌ ANTI-PATTERN 8: Not Extending CoreRepository

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

### ❌ ANTI-PATTERN 9: Using int for UI Dimensions

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

### ❌ ANTI-PATTERN 10: Not Using Equatable for Events/States

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

### ❌ ANTI-PATTERN 11: Mutable Events/States

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

### ❌ ANTI-PATTERN 12: Not Handling Error States

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
