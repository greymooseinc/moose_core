# Product Sections System

> Dynamic, extensible content system for product information

## Table of Contents
- [Overview](#overview)
- [Core Architecture](#core-architecture)
- [ProductSection Entity](#productsection-entity)
- [Implementation Guide](#implementation-guide)
- [Backend Adapter Integration](#backend-adapter-integration)
- [UI Rendering Patterns](#ui-rendering-patterns)
- [Standard Section Types](#standard-section-types)
- [Advanced Usage](#advanced-usage)
- [Migration from Legacy Fields](#migration-from-legacy-fields)
- [Best Practices](#best-practices)

## Overview

The Product Sections system replaces the legacy `description` and `shortDescription` fields with a flexible, dynamic list of content sections. This enables:

- **Backend Flexibility**: Different backends can define custom product information
- **Extensibility**: Add new section types without modifying core entities
- **Consistent Rendering**: Single UI pattern for all content types
- **Custom Ordering**: Control display sequence with `order` field
- **Metadata Support**: Pass rendering hints via `metadata` field

### What Changed

**Legacy System (Deprecated):**
```dart
Product(
  id: '123',
  name: 'T-Shirt',
  description: 'Full product description',
  shortDescription: 'Brief summary',
  // ...
)
```

**New System (Current):**
```dart
Product(
  id: '123',
  name: 'T-Shirt',
  sections: [
    ProductSection(
      type: 'short_description',
      content: 'Brief summary',
      order: 0,
    ),
    ProductSection(
      type: 'description',
      title: 'Description',
      content: 'Full product description',
      order: 1,
    ),
  ],
  // ...
)
```

## Core Architecture

### System Design

```
Product Entity
  └── List<ProductSection> sections
        ├── ProductSection (type: 'short_description', order: 0)
        ├── ProductSection (type: 'description', order: 1)
        ├── ProductSection (type: 'care_instructions', order: 2)
        ├── ProductSection (type: 'specifications', order: 3)
        └── ProductSection (type: 'custom_type', order: N)
```

### Data Flow

```
Backend API Response
        ↓
Backend-Specific DTO
        ↓
Adapter Mapper (converts to sections)
        ↓
Product Entity (with sections)
        ↓
UI Layer (renders sections dynamically)
```

## ProductSection Entity

**Location:** `lib/src/entities/product_section.dart`

### Class Definition

```dart
class ProductSection extends Equatable {
  /// Unique identifier for the section type
  /// Examples: 'description', 'care_instructions', 'specifications'
  final String type;

  /// The actual content of the section (text or HTML)
  final String content;

  /// Optional display title (falls back to type if null)
  final String? title;

  /// Display order (lower numbers appear first)
  final int order;

  /// Optional metadata for rendering configuration
  final Map<String, dynamic>? metadata;

  const ProductSection({
    required this.type,
    required this.content,
    this.title,
    this.order = 0,
    this.metadata,
  });
}
```

### Field Descriptions

| Field | Type | Required | Purpose |
|-------|------|----------|---------|
| `type` | String | Yes | Section identifier (e.g., 'description') |
| `content` | String | Yes | Section content (text/HTML) |
| `title` | String? | No | Display title (defaults to type) |
| `order` | int | No | Display order (default: 0) |
| `metadata` | Map? | No | Rendering hints (collapsible, icon, etc.) |

### Methods

```dart
// Copy with modifications
ProductSection copyWith({
  String? type,
  String? content,
  String? title,
  int? order,
  Map<String, dynamic>? metadata,
})

// Serialization
Map<String, dynamic> toJson()
factory ProductSection.fromJson(Map<String, dynamic> json)
```

## Implementation Guide

### Creating Products with Sections

```dart
final product = Product(
  id: '123',
  name: 'Premium Cotton T-Shirt',
  sections: [
    // Short description (no title, shown prominently)
    ProductSection(
      type: 'short_description',
      content: 'Soft, comfortable, and stylish cotton t-shirt',
      order: 0,
    ),

    // Full description
    ProductSection(
      type: 'description',
      title: 'Description',
      content: 'Made from 100% organic cotton, this t-shirt...',
      order: 1,
    ),

    // Custom sections
    ProductSection(
      type: 'care_instructions',
      title: 'Care Instructions',
      content: 'Machine wash cold, tumble dry low',
      order: 2,
      metadata: {
        'icon': 'care_icon',
        'collapsible': true,
      },
    ),
  ],
  price: 29.99,
  images: ['https://...'],
  inStock: true,
  stockQuantity: 100,
);
```

### Section Ordering Strategy

Use multiples of 10 for base sections to allow insertion:

```dart
0  - short_description (always first)
10 - description
20 - care_instructions
30 - specifications
40 - materials
50 - design
60 - shipping_info
70 - size_guide
80 - warranty
90+ - custom sections
```

**Why multiples of 10?** Allows adding sections between existing ones:

```dart
// Original sections: 0, 10, 20
// Need to add section between description and care_instructions?
ProductSection(type: 'ingredients', order: 15) // Perfect fit!
```

## Backend Adapter Integration

### Adapter Implementation Pattern

```dart
class YourBackendProductMapper {
  static Product toEntity(YourBackendDTO dto) {
    final sections = <ProductSection>[];

    // Map standard fields
    if (dto.shortDescription?.isNotEmpty ?? false) {
      sections.add(ProductSection(
        type: 'short_description',
        content: dto.shortDescription!,
        order: 0,
      ));
    }

    if (dto.description?.isNotEmpty ?? false) {
      sections.add(ProductSection(
        type: 'description',
        title: 'Description',
        content: dto.description!,
        order: 10,
      ));
    }

    // Map custom backend fields
    if (dto.careInstructions?.isNotEmpty ?? false) {
      sections.add(ProductSection(
        type: 'care_instructions',
        title: 'Care Instructions',
        content: dto.careInstructions!,
        order: 20,
      ));
    }

    return Product(
      id: dto.id.toString(),
      name: dto.name,
      sections: sections,
      price: dto.price,
      // ... other mappings
    );
  }
}
```

### WooCommerce Example

**Location:** `lib/adapters/woocommerce/products/mappers/woo_product_mapper.dart`

```dart
class WooProductMapper {
  static Product toEntity(WooProductDTO dto) {
    final sections = <ProductSection>[];

    if (dto.shortDescription.isNotEmpty) {
      sections.add(ProductSection(
        type: 'short_description',
        content: dto.shortDescription,
        order: 0,
      ));
    }

    if (dto.description.isNotEmpty) {
      sections.add(ProductSection(
        type: 'description',
        title: 'Description',
        content: dto.description,
        order: 1,
      ));
    }

    return Product(
      id: dto.id.toString(),
      name: dto.name,
      sections: sections,
      // ... other fields
    );
  }

  // Reverse mapping for updates
  static WooProductDTO toDTO(Product entity) {
    final descSection = entity.sections.firstWhere(
      (s) => s.type == 'description',
      orElse: () => const ProductSection(type: 'description', content: ''),
    );

    final shortDescSection = entity.sections.firstWhere(
      (s) => s.type == 'short_description',
      orElse: () => const ProductSection(type: 'short_description', content: ''),
    );

    return WooProductDTO(
      id: int.parse(entity.id),
      name: entity.name,
      description: descSection.content,
      shortDescription: shortDescSection.content,
      // ... other fields
    );
  }
}
```

### Shopify Example

**Location:** `lib/adapters/shopify/products/mappers/shopify_product_mapper.dart`

```dart
class ShopifyProductMapper {
  static Product toProduct(Map<String, dynamic> shopifyProduct, String storeUrl) {
    final description = shopifyProduct['description'] as String? ?? '';

    final sections = description.isNotEmpty
        ? <ProductSection>[
            ProductSection(
              type: 'description',
              title: 'Description',
              content: description,
              order: 0,
            ),
          ]
        : const <ProductSection>[];

    return Product(
      id: _extractIdFromGid(shopifyProduct['id']),
      name: shopifyProduct['title'],
      sections: sections,
      // ... other mappings
    );
  }
}
```

## UI Rendering Patterns

### Generic Rendering (Recommended)

**Location:** `lib/plugins/products/presentation/screens/product_detail_screen.dart`

```dart
Widget _buildProductSections(BuildContext context, Product product) {
  // Sort sections by order
  final sortedSections = List<ProductSection>.from(product.sections)
    ..sort((a, b) => a.order.compareTo(b.order));

  return Padding(
    padding: const EdgeInsets.symmetric(horizontal: 20),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: sortedSections
          .map((section) => _buildSection(context, section))
          .toList(),
    ),
  );
}

Widget _buildSection(BuildContext context, ProductSection section) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 32),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          (section.title ?? section.type).toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 1.5,
            color: Colors.grey[800],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          section.content,
          style: GoogleFonts.inter(
            fontSize: 15,
            height: 1.7,
            color: Colors.grey[800],
            letterSpacing: 0.1,
          ),
        ),
      ],
    ),
  );
}
```

### Type-Specific Rendering (Advanced)

```dart
Widget _buildSection(BuildContext context, ProductSection section) {
  switch (section.type) {
    case 'short_description':
      return _buildShortDescription(context, section);

    case 'care_instructions':
      return _buildCareInstructions(context, section);

    case 'specifications':
      return _buildSpecifications(context, section);

    default:
      return _buildGenericSection(context, section);
  }
}

Widget _buildCareInstructions(BuildContext context, ProductSection section) {
  final isCollapsible = section.metadata?['collapsible'] == true;
  final icon = section.metadata?['icon'] as String?;

  if (isCollapsible) {
    return ExpansionTile(
      leading: Icon(Icons.local_laundry_service),
      title: Text(section.title ?? 'Care Instructions'),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(section.content),
        ),
      ],
    );
  }

  return Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (icon != null) Icon(Icons.local_laundry_service),
      Expanded(child: Text(section.content)),
    ],
  );
}
```

### Using Metadata for Rendering

```dart
ProductSection(
  type: 'specifications',
  title: 'Technical Specifications',
  content: 'Weight: 200g\nDimensions: 30x20x5cm',
  metadata: {
    'renderAsTable': true,
    'separator': '\n',
    'backgroundColor': '#F5F5F5',
    'collapsible': true,
    'defaultExpanded': false,
    'icon': 'specifications_icon',
  },
)

// In UI
Widget _buildSection(BuildContext context, ProductSection section) {
  final renderAsTable = section.metadata?['renderAsTable'] == true;
  final backgroundColor = section.metadata?['backgroundColor'] as String?;

  if (renderAsTable) {
    return _buildTableSection(context, section);
  }

  return Container(
    color: backgroundColor != null ? HexColor(backgroundColor) : null,
    child: _buildGenericSection(context, section),
  );
}
```

## Standard Section Types

### Conventions (Not Enforced)

| Type | Purpose | Typical Order | Title |
|------|---------|---------------|-------|
| `short_description` | Brief summary | 0 | None (shown without title) |
| `description` | Full description | 10 | "Description" |
| `care_instructions` | Care/maintenance | 20 | "Care Instructions" |
| `specifications` | Technical specs | 30 | "Specifications" |
| `materials` | Material composition | 40 | "Materials" |
| `design` | Design details | 50 | "Design Details" |
| `shipping_info` | Shipping details | 60 | "Shipping Information" |
| `size_guide` | Sizing information | 70 | "Size Guide" |
| `warranty` | Warranty details | 80 | "Warranty" |

### Adding Custom Types

Custom types can be added without core changes:

```dart
// In your adapter
sections.add(ProductSection(
  type: 'sustainability_info',  // Custom type
  title: 'Sustainability',
  content: 'Made from recycled materials...',
  order: 85,
  metadata: {
    'icon': 'eco',
    'highlight': true,
  },
));

// In UI (optional custom rendering)
case 'sustainability_info':
  return _buildSustainabilityInfo(context, section);
```

## Advanced Usage

### Accessing Specific Sections

```dart
// Get a specific section
final description = product.sections
    .firstWhere(
      (s) => s.type == 'description',
      orElse: () => const ProductSection(type: 'description', content: ''),
    )
    .content;

// Check if section exists
final hasDescription = product.sections.any((s) => s.type == 'description');

// Get all sections of a type
final allSpecs = product.sections
    .where((s) => s.type == 'specifications')
    .toList();

// Filter sections by metadata
final collapsibleSections = product.sections
    .where((s) => s.metadata?['collapsible'] == true)
    .toList();
```

### Modifying Sections

```dart
// Add a section
final updatedProduct = product.copyWith(
  sections: [
    ...product.sections,
    ProductSection(
      type: 'new_section',
      content: 'New content',
      order: 100,
    ),
  ],
);

// Remove a section
final withoutCare = product.copyWith(
  sections: product.sections
      .where((s) => s.type != 'care_instructions')
      .toList(),
);

// Update a section
final updatedSections = product.sections.map((section) {
  if (section.type == 'description') {
    return section.copyWith(content: 'Updated content');
  }
  return section;
}).toList();
```

## Migration from Legacy Fields

### For AI Agents: Converting Old Code

**Pattern 1: Direct Field Access**

```dart
// Old code
Text(product.description)
Text(product.shortDescription)

// New code
Text(
  product.sections
      .firstWhere(
        (s) => s.type == 'description',
        orElse: () => const ProductSection(type: 'description', content: ''),
      )
      .content
)
```

**Pattern 2: Conditional Rendering**

```dart
// Old code
if (product.description.isNotEmpty) {
  _buildDescription(product.description);
}

// New code
if (product.sections.isNotEmpty) {
  _buildProductSections(context, product);
}
```

**Pattern 3: Creating Products**

```dart
// Old code
Product(
  description: 'Full description',
  shortDescription: 'Brief summary',
)

// New code
Product(
  sections: [
    ProductSection(type: 'short_description', content: 'Brief summary', order: 0),
    ProductSection(type: 'description', title: 'Description', content: 'Full description', order: 1),
  ],
)
```

## Best Practices

### DO

✅ **Check for empty content before creating sections**
```dart
if (dto.description.isNotEmpty) {
  sections.add(ProductSection(...));
}
```

✅ **Use multiples of 10 for order values**
```dart
order: 0, 10, 20, 30  // Allows insertion
```

✅ **Provide titles for most sections**
```dart
ProductSection(
  type: 'care_instructions',
  title: 'Care Instructions',  // Clear display title
  content: '...',
)
```

✅ **Use metadata for rendering hints only**
```dart
metadata: {
  'collapsible': true,  // UI configuration
  'icon': 'care_icon',  // Display hint
}
```

✅ **Sort sections before rendering**
```dart
final sorted = List.from(sections)..sort((a, b) => a.order.compareTo(b.order));
```

### DON'T

❌ **Don't create empty sections**
```dart
// Bad
sections.add(ProductSection(
  type: 'description',
  content: dto.description ?? '',  // Could be empty!
));
```

❌ **Don't use metadata for business logic**
```dart
// Bad
metadata: {
  'price': 29.99,  // Use Product fields instead
  'inStock': true, // Use Product fields instead
}
```

❌ **Don't hardcode order values consecutively**
```dart
// Bad - no room for insertion
order: 0, 1, 2, 3, 4

// Good - allows insertion
order: 0, 10, 20, 30, 40
```

❌ **Don't access legacy fields**
```dart
// Bad - will not compile
product.description
product.shortDescription
```

### Validation Patterns

```dart
// Validate section before adding
void addSectionIfValid(List<ProductSection> sections, String? content, String type) {
  if (content != null && content.trim().isNotEmpty) {
    sections.add(ProductSection(
      type: type,
      content: content.trim(),
      order: sections.length * 10,
    ));
  }
}

// Use in adapter
final sections = <ProductSection>[];
addSectionIfValid(sections, dto.shortDescription, 'short_description');
addSectionIfValid(sections, dto.description, 'description');
addSectionIfValid(sections, dto.careInfo, 'care_instructions');
```

## Testing

### Unit Tests

```dart
test('Product sections are sorted by order', () {
  final product = Product(
    id: '1',
    name: 'Test',
    sections: [
      ProductSection(type: 'c', content: 'C', order: 30),
      ProductSection(type: 'a', content: 'A', order: 10),
      ProductSection(type: 'b', content: 'B', order: 20),
    ],
    price: 10,
    images: [],
    inStock: true,
    stockQuantity: 0,
  );

  final sorted = List<ProductSection>.from(product.sections)
    ..sort((a, b) => a.order.compareTo(b.order));

  expect(sorted[0].type, 'a');
  expect(sorted[1].type, 'b');
  expect(sorted[2].type, 'c');
});

test('Empty sections are not added', () {
  final sections = <ProductSection>[];

  final emptyContent = '';
  if (emptyContent.isNotEmpty) {
    sections.add(ProductSection(type: 'test', content: emptyContent));
  }

  expect(sections, isEmpty);
});
```

### Widget Tests

```dart
testWidgets('Renders all product sections', (tester) async {
  final product = Product(
    id: '1',
    name: 'Test',
    sections: [
      ProductSection(type: 'description', title: 'Description', content: 'Test description'),
      ProductSection(type: 'care', title: 'Care', content: 'Test care'),
    ],
    // ... required fields
  );

  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        body: ProductDetailScreen(product: product),
      ),
    ),
  );

  expect(find.text('DESCRIPTION'), findsOneWidget);
  expect(find.text('Test description'), findsOneWidget);
  expect(find.text('CARE'), findsOneWidget);
  expect(find.text('Test care'), findsOneWidget);
});
```

## Related Documentation

- **[ADAPTER_PATTERN.md](./ADAPTER_PATTERN.md)** - Backend adapter implementation
- **[ARCHITECTURE.md](./ARCHITECTURE.md)** - Core architectural patterns
- **[../CHANGELOG_PRODUCT_SECTIONS.md](../CHANGELOG_PRODUCT_SECTIONS.md)** - Migration changelog
- **[../ai_agent_quick_reference.md](../ai_agent_quick_reference.md)** - Quick reference guide

## Summary

The Product Sections system provides:

- ✅ **Flexibility** - Any number and type of content sections
- ✅ **Extensibility** - Add new types without core changes
- ✅ **Backend Agnostic** - Each backend maps its own structure
- ✅ **Ordered Display** - Control rendering sequence
- ✅ **Metadata Support** - Pass rendering configuration
- ✅ **Type Safety** - Strongly typed with Equatable
- ✅ **Serialization** - Full JSON support

**Next Steps:**
1. Review adapter examples: [woo_product_mapper.dart](../../lib/adapters/woocommerce/products/mappers/woo_product_mapper.dart)
2. See UI implementation: [product_detail_screen.dart](../../lib/plugins/products/presentation/screens/product_detail_screen.dart)
3. Check quick reference: [ai_agent_quick_reference.md](../ai_agent_quick_reference.md)
