# FeatureSection Pattern Guide

> Complete guide to creating configurable, reusable UI sections

## Table of Contents
- [Overview](#overview)
- [FeatureSection Base Class](#featuresection-base-class)
- [Creating a Section](#creating-a-section)
- [Configuration Patterns](#configuration-patterns)
- [Use Cases](#use-cases)
- [Best Practices](#best-practices)

## Overview

`FeatureSection` is the base class for all configurable, reusable UI components in moose_core. It provides:

- **Configuration Management**: Type-safe settings with defaults
- **Adapter Access**: Direct access to AdapterRegistry
- **Consistency**: Standard pattern for all sections
- **Fail-Fast**: Configuration errors caught early

## FeatureSection Base Class

```dart
abstract class FeatureSection extends StatelessWidget {
  final Map<String, dynamic>? settings;

  const FeatureSection({super.key, this.settings});

  /// Access the scoped AdapterRegistry from the widget tree.
  /// Call this inside build(context) — requires a MooseScope ancestor.
  AdapterRegistry adaptersOf(BuildContext context) =>
      MooseScope.adapterRegistryOf(context);

  /// Define default settings for this section
  /// All configurable values MUST be defined here
  Map<String, dynamic> getDefaultSettings();

  /// Get a setting value with type safety
  /// Throws [Exception] if key is missing or type mismatches.
  /// Also handles automatic numeric conversions (num→double, num→int) and Color parsing.
  T getSetting<T>(String key) {
    final config = {...getDefaultSettings(), ...(settings ?? {})};
    final value = config[key];

    // Fail fast if key not found
    if (value == null) {
      throw Exception(
        'Setting "$key" not found in $runtimeType. '
        'Ensure the key exists in getDefaultSettings() or settings.',
      );
    }

    // Handle automatic number conversions
    if (T == double && value is num) return value.toDouble() as T;
    if (T == int && value is num) return value.toInt() as T;
    if (T == Color) return ColorHelper.parse(value) as T;

    // Direct type match
    if (value is T) return value;

    // Fail fast if type mismatch
    throw Exception(
      'Setting "$key" in $runtimeType has type ${value.runtimeType} '
      'but expected type $T',
    );
  }
}
```

## Creating a Section

### Step 1: Extend FeatureSection

```dart
import 'package:moose_core/moose_core.dart';

class FeaturedProductsSection extends FeatureSection {
  const FeaturedProductsSection({super.key, super.settings});

  @override
  Map<String, dynamic> getDefaultSettings() {
    return {
      'title': 'FEATURED PRODUCTS',
      'titleFontSize': 18.0,
      'horizontalPadding': 20.0,
      'verticalPadding': 16.0,
      'perPage': 10,
      'columns': 2,
      'showLoadMore': true,
    };
  }

  @override
  Widget build(BuildContext context) {
    // Access AdapterRegistry from the widget tree via MooseScope
    final repository = adaptersOf(context).getRepository<ProductsRepository>();

    return BlocProvider(
      create: (context) => ProductsBloc(repository)
        ..add(LoadProducts(limit: getSetting<int>('perPage'))),
      child: _buildContent(context),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: getSetting<double>('horizontalPadding'),
        vertical: getSetting<double>('verticalPadding'),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            getSetting<String>('title'),
            style: TextStyle(
              fontSize: getSetting<double>('titleFontSize'),
              fontWeight: FontWeight.bold,
            ),
          ),
          SizedBox(height: 16),
          BlocBuilder<ProductsBloc, ProductsState>(
            builder: (context, state) {
              if (state is ProductsLoading) {
                return Center(child: CircularProgressIndicator());
              }
              if (state is ProductsLoaded) {
                return _buildProductGrid(state.products);
              }
              if (state is ProductsError) {
                return Text('Error: ${state.message}');
              }
              return SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildProductGrid(List<Product> products) {
    return GridView.builder(
      shrinkWrap: true,
      physics: NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: getSetting<int>('columns'),
        childAspectRatio: 0.75,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemCount: products.length,
      itemBuilder: (context, index) {
        return ProductCard(product: products[index]);
      },
    );
  }
}
```

### Step 2: Register the Section

Register sections in `onRegister()` (sync), not `initialize()` (reserved for async I/O):

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
  }
}
```

### Step 3: Configure in JSON

```json
{
  "plugins": {
    "home": {
      "sections": {
        "main": [
          {
            "name": "products.featured_section",
            "description": "Featured products grid",
            "settings": {
              "title": "TOP PICKS FOR YOU",
              "perPage": 8,
              "columns": 2,
              "titleFontSize": 20.0
            }
          }
        ]
      }
    }
  }
}
```

## Configuration Patterns

### Pattern 1: Basic Configuration

```dart
@override
Map<String, dynamic> getDefaultSettings() {
  return {
    'title': 'Section Title',
    'fontSize': 16.0,
    'padding': 20.0,
  };
}

@override
Widget build(BuildContext context) {
  return Text(
    getSetting<String>('title'),
    style: TextStyle(fontSize: getSetting<double>('fontSize')),
  );
}
```

### Pattern 2: Complex Configuration

```dart
@override
Map<String, dynamic> getDefaultSettings() {
  return {
    'layout': {
      'columns': 2,
      'spacing': 10.0,
      'padding': 16.0,
    },
    'styling': {
      'backgroundColor': '#FFFFFF',
      'borderRadius': 8.0,
    },
    'behavior': {
      'autoRefresh': true,
      'refreshInterval': 30,
    },
  };
}

@override
Widget build(BuildContext context) {
  final layout = getSetting<Map<String, dynamic>>('layout');
  final columns = layout['columns'] as int;
  final spacing = layout['spacing'] as double;

  return GridView(
    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      crossAxisSpacing: spacing,
    ),
    // ...
  );
}
```

### Pattern 3: Conditional Configuration

```dart
@override
Map<String, dynamic> getDefaultSettings() {
  return {
    'showFilters': true,
    'showSortOptions': true,
    'enableInfiniteScroll': false,
    'itemsPerPage': 20,
  };
}

@override
Widget build(BuildContext context) {
  return Column(
    children: [
      if (getSetting<bool>('showFilters'))
        FiltersWidget(),
      if (getSetting<bool>('showSortOptions'))
        SortOptionsWidget(),
      ProductsList(
        itemsPerPage: getSetting<int>('itemsPerPage'),
        infiniteScroll: getSetting<bool>('enableInfiniteScroll'),
      ),
    ],
  );
}
```

## Use Cases

### Use Case 1: Content Sections

FeatureSection for content sections registered in WidgetRegistry:

```dart
class HeroSection extends FeatureSection {
  const HeroSection({super.key, super.settings});

  @override
  Map<String, dynamic> getDefaultSettings() {
    return {
      'title': 'Welcome',
      'subtitle': 'Discover amazing products',
      'backgroundImage': '',
      'height': 300.0,
    };
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: getSetting<double>('height'),
      decoration: BoxDecoration(
        image: DecorationImage(
          image: NetworkImage(getSetting<String>('backgroundImage')),
          fit: BoxFit.cover,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            getSetting<String>('title'),
            style: TextStyle(fontSize: 32, color: Colors.white),
          ),
          Text(
            getSetting<String>('subtitle'),
            style: TextStyle(fontSize: 16, color: Colors.white),
          ),
        ],
      ),
    );
  }
}
```

**Load with buildSectionGroup:**
```dart
final sections = widgetRegistry.buildSectionGroup(
  context,
  pluginName: 'home',
  groupName: 'main',
);
```

### Use Case 2: Sliver Sections

FeatureSection for sliver widgets in CustomScrollView:

```dart
class AppBarSliver extends FeatureSection {
  final Function(String, dynamic)? onEvent;

  const AppBarSliver({
    super.key,
    super.settings,
    this.onEvent,
  });

  @override
  Map<String, dynamic> getDefaultSettings() {
    return {
      'title': 'Store',
      'showSearch': true,
      'showCart': true,
      'backgroundColor': '#FFFFFF',
    };
  }

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      title: Text(getSetting<String>('title')),
      backgroundColor: Color(
        int.parse(getSetting<String>('backgroundColor').replaceFirst('#', '0xFF')),
      ),
      actions: [
        if (getSetting<bool>('showSearch'))
          IconButton(
            icon: Icon(Icons.search),
            onPressed: () => onEvent?.call('search_tap', null),
          ),
        if (getSetting<bool>('showCart'))
          IconButton(
            icon: Icon(Icons.shopping_cart),
            onPressed: () => onEvent?.call('cart_tap', null),
          ),
      ],
    );
  }
}
```

**Use in CustomScrollView:**
```dart
CustomScrollView(
  slivers: [
    widgetRegistry.build(
      'home.app_bar',
      context,
      data: {'settings': {'title': 'My Store'}},
      onEvent: (event, payload) {
        if (event == 'search_tap') Navigator.pushNamed(context, '/search');
      },
    ),
    // Other slivers...
  ],
)
```

### Use Case 3: Parameterized Sections

Sections that accept additional data:

```dart
class ReviewListSection extends FeatureSection {
  final String? productId;
  final Function(String, dynamic)? onEvent;

  const ReviewListSection({
    super.key,
    super.settings,
    this.productId,
    this.onEvent,
  });

  @override
  Map<String, dynamic> getDefaultSettings() {
    return {
      'perPage': 10,
      'showRating': true,
      'allowReply': false,
    };
  }

  @override
  Widget build(BuildContext context) {
    if (productId == null) {
      return SizedBox.shrink();
    }

    final repository = adaptersOf(context).getRepository<ReviewRepository>();

    return BlocProvider(
      create: (context) => ReviewsBloc(repository)
        ..add(LoadReviews(
          productId: productId!,
          limit: getSetting<int>('perPage'),
        )),
      child: BlocBuilder<ReviewsBloc, ReviewsState>(
        builder: (context, state) {
          // Build reviews list
        },
      ),
    );
  }
}
```

**Register with additional parameters:**
```dart
widgetRegistry.register(
  'reviews.list_section',
  (context, {data, onEvent}) => ReviewListSection(
    settings: data?['settings'] as Map<String, dynamic>?,
    productId: data?['productId'] as String?,
    onEvent: onEvent,
  ),
);
```

## Best Practices

### DO

```dart
// ✅ Extend FeatureSection
class MySection extends FeatureSection {
  const MySection({super.key, super.settings});
}

// ✅ Define all settings with defaults
@override
Map<String, dynamic> getDefaultSettings() {
  return {
    'title': 'Default Title',
    'fontSize': 16.0,
    'padding': 20.0,
  };
}

// ✅ Use getSetting<T>() with proper types
final title = getSetting<String>('title');
final fontSize = getSetting<double>('fontSize');  // double for UI dimensions

// ✅ Use BLoC for state management
return BlocProvider(
  create: (context) => MyBloc(repository),
  child: BlocBuilder<MyBloc, MyState>(...),
);

// ✅ Use adaptersOf(context) for repositories (inside build())
final repository = adaptersOf(context).getRepository<ProductsRepository>();
```

### DON'T

```dart
// ❌ Don't extend StatelessWidget directly
class MySection extends StatelessWidget {  // Wrong!
}

// ❌ Don't hardcode values
return Text(
  'FEATURED PRODUCTS',  // Hardcoded!
  style: TextStyle(fontSize: 18),  // Hardcoded!
);

// ❌ Don't use int for UI dimensions
@override
Map<String, dynamic> getDefaultSettings() {
  return {
    'padding': 20,  // Should be 20.0 (double)
    'fontSize': 16,  // Should be 16.0 (double)
  };
}

// ❌ Don't access settings directly
return Text(settings?['title'] ?? 'Default');  // Wrong!

// ❌ Don't make direct repository calls
@override
Widget build(BuildContext context) {
  return FutureBuilder(
    future: repository.getProducts(),  // Wrong!
    // ...
  );
}
```

### Type Safety

Always use the correct types for settings:

```dart
@override
Map<String, dynamic> getDefaultSettings() {
  return {
    // UI dimensions - use double
    'padding': 20.0,
    'fontSize': 16.0,
    'height': 200.0,
    'width': 100.0,

    // Counts/quantities - use int
    'perPage': 10,
    'columns': 2,
    'maxItems': 50,

    // Text - use String
    'title': 'Title',
    'description': 'Description',

    // Flags - use bool
    'showHeader': true,
    'allowEditing': false,

    // Collections - use List/Map
    'items': <String>[],
    'config': <String, dynamic>{},
  };
}
```

### Documentation

Document your sections:

```dart
/// Featured Products Section
///
/// Displays a grid of featured products from the catalog.
///
/// **Configuration:**
/// - `title` (String): Section title (default: 'FEATURED PRODUCTS')
/// - `titleFontSize` (double): Title font size (default: 18.0)
/// - `perPage` (int): Number of products to display (default: 10)
/// - `columns` (int): Number of grid columns (default: 2)
/// - `horizontalPadding` (double): Horizontal padding (default: 20.0)
/// - `verticalPadding` (double): Vertical padding (default: 16.0)
///
/// **Example:**
/// ```json
/// {
///   "name": "products.featured_section",
///   "settings": {
///     "title": "TOP PICKS",
///     "perPage": 8,
///     "columns": 3
///   }
/// }
/// ```
class FeaturedProductsSection extends FeatureSection {
  // ...
}
```

## Testing

### Unit Test Settings

```dart
void main() {
  group('FeaturedProductsSection', () {
    test('getDefaultSettings returns all required settings', () {
      final section = FeaturedProductsSection();
      final defaults = section.getDefaultSettings();

      expect(defaults['title'], isA<String>());
      expect(defaults['titleFontSize'], isA<double>());
      expect(defaults['perPage'], isA<int>());
      expect(defaults['columns'], isA<int>());
    });

    test('getSetting returns correct value', () {
      final section = FeaturedProductsSection(
        settings: {'title': 'Custom Title'},
      );

      expect(section.getSetting<String>('title'), equals('Custom Title'));
      expect(section.getSetting<double>('titleFontSize'), equals(18.0));
    });

    test('getSetting throws on missing key', () {
      final section = FeaturedProductsSection();

      expect(
        () => section.getSetting<String>('nonExistent'),
        throwsA(isA<Exception>()),
      );
    });
  });
}
```

### Widget Test

```dart
void main() {
  testWidgets('FeaturedProductsSection displays title', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: FeaturedProductsSection(
            settings: {'title': 'Test Products'},
          ),
        ),
      ),
    );

    expect(find.text('Test Products'), findsOneWidget);
  });
}
```

## Related Documentation

- **[ARCHITECTURE.md](./ARCHITECTURE.md)** - Overall architecture
- **[PLUGIN_SYSTEM.md](./PLUGIN_SYSTEM.md)** - Creating plugins
- **[ANTI_PATTERNS.md](./ANTI_PATTERNS.md)** - What to avoid

---

**Last Updated:** 2025-11-03
**Version:** 1.0.0
