# Product Attribute Selection Implementation Guide

## Overview

This guide explains how to implement flexible product attribute selection that works with any attribute type and automatically handles variation matching and price updates.

## Architecture

### Core Components

1. **VariationSelectorService** (`lib/core/services/variation_selector_service.dart`)
   - Finds matching variations based on selected attributes
   - Determines available options based on stock
   - Smart selection logic that disables unavailable combinations

2. **ProductAttributeSelector Widget** (`lib/plugins/products/presentation/widgets/product_attribute_selector.dart`)
   - Dynamic UI that adapts to any attribute type
   - Special rendering for Color and Size attributes
   - Disables unavailable options visually
   - Emits selection changes with matched variation

3. **Product, ProductAttribute, ProductVariation Entities**
   - Product needs `attributes` and `variations` fields added
   - ProductAttribute already complete with `variation` flag
   - ProductVariation has `attributes` map for matching

## How It Works

### 1. Attribute Matching Algorithm

```dart
// Example product with variations
Product(
  id: '123',
  name: 'T-Shirt',
  attributes: [
    ProductAttribute(
      slug: 'pa_color',
      name: 'Color',
      options: ['Red', 'Blue', 'Green'],
      variation: true,  // This attribute affects variations
    ),
    ProductAttribute(
      slug: 'pa_size',
      name: 'Size',
      options: ['S', 'M', 'L', 'XL'],
      variation: true,
    ),
  ],
  variations: [
    ProductVariation(
      id: '123-1',
      attributes: {'pa_color': 'Red', 'pa_size': 'M'},
      price: 29.99,
      inStock: true,
    ),
    ProductVariation(
      id: '123-2',
      attributes: {'pa_color': 'Blue', 'pa_size': 'L'},
      price: 31.99,
      inStock: true,
    ),
    // ... more variations
  ],
)
```

### 2. Selection Flow

1. **User selects Color: Red**
   - Service checks which sizes are available for Red
   - Only shows/enables size options that have stock with Red

2. **User selects Size: M**
   - Service finds exact variation match: `{pa_color: 'Red', pa_size: 'M'}`
   - Returns matched ProductVariation with price $29.99

3. **Widget calls callback**
   ```dart
   onSelectionChanged(matchedVariation, selectedAttributes)
   ```

### 3. Usage in Product Detail Screen

```dart
class ProductDetailScreen extends StatefulWidget {
  final Product product;
  // ...
}

class _ProductDetailScreenState extends State<ProductDetailScreen> {
  ProductVariation? _selectedVariation;
  Map<String, String> _selectedAttributes = {};

  // Use the selected variation's price, or product's base price
  double get _currentPrice =>
    _selectedVariation?.price ?? widget.product.price;

  @override
  Widget build(BuildContext context) {
    // Only show selector for variable products
    final isVariable = widget.product.type == 'variable';

    return Column(
      children: [
        // Price display updates automatically
        Text('\$${_currentPrice.toStringAsFixed(2)}'),

        if (isVariable && widget.product.variations.isNotEmpty)
          ProductAttributeSelector(
            attributes: widget.product.attributes,
            variations: widget.product.variations,
            onSelectionChanged: (variation, selections) {
              setState(() {
                _selectedVariation = variation;
                _selectedAttributes = selections;
              });
            },
          ),

        // Add to cart button
        ElevatedButton(
          onPressed: _selectedVariation != null || !isVariable
            ? () => _addToCart()
            : null,  // Disable if no variation selected
          child: Text('Add to Cart'),
        ),
      ],
    );
  }

  void _addToCart() {
    final productId = widget.product.id;
    final variationId = _selectedVariation?.id;

    // Pass variation ID to cart if it exists
    cartRepository.addItem(
      productId: productId,
      variationId: variationId,
      quantity: 1,
      metadata: _selectedAttributes.isNotEmpty
        ? {'selected_attributes': _selectedAttributes}
        : null,
    );
  }
}
```

## Supported Attribute Types

### 1. Color Attributes
- Detects if attribute name/slug contains "color" or "colour"
- Renders as colored squares
- Unavailable colors shown with diagonal line

### 2. Size Attributes
- Detects if attribute name/slug contains "size"
- Renders as square buttons with text (S, M, L, XL, etc.)
- Selected size has black background with white text

### 3. Generic Attributes
- Any other attribute (Material, Style, Pattern, etc.)
- Renders as rectangular buttons with labels
- Works with any attribute type automatically

## Smart Option Availability

The service intelligently enables/disables options:

```dart
// Example: User selected Color = Red
// Service checks each size option:

Size S:
  - Check if variation exists with {color: Red, size: S}
  - Check if that variation is in stock
  - Enable if yes, disable if no

Size M:
  - Variation exists and in stock → ENABLED

Size L:
  - No variation with Red + L → DISABLED

Size XL:
  - Variation exists but out of stock → DISABLED
```

## Adding New Attribute Types

To add custom rendering for new attribute types:

```dart
// In ProductAttributeSelector._buildOptionsGrid()

bool _isMaterialAttribute(ProductAttribute attribute) {
  final nameLower = attribute.name.toLowerCase();
  return nameLower.contains('material');
}

Widget _buildMaterialOptions(ProductAttribute attribute, String? selectedValue) {
  return Wrap(
    spacing: 12,
    runSpacing: 12,
    children: attribute.options.map((option) {
      // Custom rendering for material swatches
      return Container(
        // Your custom UI
      );
    }).toList(),
  );
}

// Then in _buildOptionsGrid:
if (_isColorAttribute(attribute)) {
  return _buildColorOptions(attribute, selectedValue);
} else if (_isMaterialAttribute(attribute)) {
  return _buildMaterialOptions(attribute, selectedValue);
}
// ... etc
```

## Required Product Entity Updates

Add these fields to the Product entity:

```dart
class Product extends Equatable {
  // ... existing fields
  final List<ProductAttribute> attributes;
  final List<ProductVariation> variations;

  const Product({
    // ... existing params
    this.attributes = const [],
    this.variations = const [],
  });
}
```

## API Integration Example (WooCommerce)

```dart
// In WooProductsRepository
Future<Product> getProductById(String id) async {
  final response = await _apiClient.get('/products/$id');
  final json = response.data;

  return Product(
    // ... map other fields
    attributes: (json['attributes'] as List?)
      ?.map((a) => ProductAttribute.fromJson(a))
      .toList() ?? [],
    variations: await _fetchVariations(id),
  );
}

Future<List<ProductVariation>> _fetchVariations(String productId) async {
  final response = await _apiClient.get('/products/$productId/variations');
  return (response.data as List)
    .map((v) => ProductVariation.fromJson(v))
    .toList();
}
```

## Benefits

1. **Flexible** - Works with ANY attribute type without code changes
2. **Smart** - Only shows available combinations
3. **User-friendly** - Visual feedback for unavailable options
4. **Type-aware** - Special UI for common types (color, size)
5. **Extensible** - Easy to add custom rendering for new attribute types
6. **Reactive** - Price updates automatically when variation changes

## Testing Scenarios

1. **Single attribute** - Size only
2. **Multiple attributes** - Color + Size
3. **Complex attributes** - Color + Size + Material
4. **Out of stock variations** - Should be visually disabled
5. **No matching variation** - Should disable Add to Cart button
6. **Default selection** - Should auto-select first available combination
