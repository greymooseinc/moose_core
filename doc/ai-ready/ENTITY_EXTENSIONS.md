# Entity Extensions Guide for AI Agents

> **Quick Reference**: How to use the `extensions` field in core entities to store backend-specific data without modifying entity definitions

## TL;DR

All core entities extend from `CoreEntity` which provides an `extensions` field (`Map<String, dynamic>?`) that allows storing platform-specific data from different backends (WooCommerce, Shopify, custom APIs) without needing to modify or extend the entity classes.

**CoreEntity** provides a type-safe helper method to access extensions data:
- `getExtension<T>(key)` - Get an extension value with type casting

```dart
// Use core entities directly - no need to create custom entities
final product = Product(
  id: '123',
  name: 'T-Shirt',
  price: 29.99,
  extensions: {
    'woocommerce': {
      'weight': '0.5',
      'dimensions': {'length': '10', 'width': '8', 'height': '2'},
      'shipping_class': 'standard',
    },
    'shopify': {
      'handle': 'cool-t-shirt',
      'vendor': 'Cool Brand',
      'tags': ['summer', 'casual'],
    },
    'custom_data': {
      'internal_sku': 'TSHIRT-001',
      'warehouse_location': 'A-12',
    },
  },
);
```

## Core Entity Base Class

All core entities extend from `CoreEntity`, which provides the `extensions` field and a type-safe getter:

```dart
abstract class CoreEntity extends Equatable {
  final Map<String, dynamic>? extensions;

  const CoreEntity({this.extensions});

  // Type-safe getter for extensions
  T? getExtension<T>(String key);
}
```

## What is the Extensions Field?

The `extensions` field is a `Map<String, dynamic>?` property inherited from `CoreEntity` and available on all core entities:
- **Product**
- **Category**
- **Cart** & **CartItem**
- **Order** & **OrderLineItem**
- **User**
- **ProductVariation**
- **ProductAttribute**
- **ProductReview**
- **Collection**
- **Post**
- **SearchResult**
- And all other core entities

### Purpose

Store backend-specific or custom data that doesn't fit into the standard entity fields, allowing you to:
- ✅ Use core entities without creating custom subclasses
- ✅ Support multiple backends with different data requirements
- ✅ Add platform-specific features without modifying core
- ✅ Maintain clean separation between core and adapter logic

## When to Use Extensions

### ✅ DO Use Extensions For:

1. **Backend-Specific Data**
   ```dart
   extensions: {
     'woocommerce': {
       'permalink': 'https://store.com/product/123',
       'tax_class': 'standard',
       'shipping_class_id': '5',
     },
   }
   ```

2. **Custom Business Logic Data**
   ```dart
   extensions: {
     'loyalty_points': 150,
     'membership_tier': 'gold',
     'last_purchased': '2025-01-15',
   }
   ```

3. **Additional Metadata Not in Core**
   ```dart
   extensions: {
     'seo': {
       'meta_title': 'Best T-Shirt Ever',
       'meta_description': '...',
       'keywords': ['tshirt', 'fashion'],
     },
   }
   ```

4. **Adapter-Specific IDs**
   ```dart
   extensions: {
     'shopify_variant_id': 'gid://shopify/ProductVariant/123',
     'stripe_price_id': 'price_1ABC123',
   }
   ```

### ❌ DON'T Use Extensions For:

1. **Data That Should Be Core Fields**
   ```dart
   // ❌ BAD - price should be a core field (and it is!)
   extensions: {
     'price': 29.99,
   }

   // ✅ GOOD - use core fields
   price: 29.99,
   ```

2. **Large Binary Data**
   ```dart
   // ❌ BAD - don't store images as base64
   extensions: {
     'image_base64': 'data:image/png;base64,iVBORw0...',
   }

   // ✅ GOOD - use URLs
   images: ['https://cdn.example.com/image.png'],
   ```

3. **Sensitive Information**
   ```dart
   // ❌ BAD - don't store sensitive data
   extensions: {
     'credit_card': '4111-1111-1111-1111',
     'password': 'secret123',
   }
   ```

## Using Extensions in Adapters

### Pattern 1: Storing Backend-Specific Data

```dart
class WooProductsRepository extends CoreRepository implements ProductsRepository {
  @override
  Future<Product> getProductById(String id) async {
    final wooProduct = await _apiClient.get('/products/$id');

    return Product(
      id: wooProduct['id'].toString(),
      name: wooProduct['name'],
      price: double.parse(wooProduct['price']),
      images: (wooProduct['images'] as List).map((i) => i['src'] as String).toList(),
      // ... other core fields

      extensions: {
        'woocommerce': {
          'permalink': wooProduct['permalink'],
          'tax_status': wooProduct['tax_status'],
          'tax_class': wooProduct['tax_class'],
          'weight': wooProduct['weight'],
          'dimensions': wooProduct['dimensions'],
          'shipping_class': wooProduct['shipping_class'],
          'shipping_class_id': wooProduct['shipping_class_id'],
          'reviews_allowed': wooProduct['reviews_allowed'],
          'purchase_note': wooProduct['purchase_note'],
          'menu_order': wooProduct['menu_order'],
        },
      },
    );
  }
}
```

### Pattern 2: Reading Extensions Data

```dart
// In your UI or business logic
final product = await productsRepo.getProductById('123');

// Option 1: Direct access
final wooData = product.extensions?['woocommerce'] as Map<String, dynamic>?;
final permalink = wooData?['permalink'] as String?;
final weight = wooData?['weight'] as String?;

// Option 2: Using CoreEntity getExtension (type-safe)
final wooData = product.getExtension<Map<String, dynamic>>('woocommerce');
final permalink = wooData?['permalink'] as String?;
final weight = wooData?['weight'] as String?;
final loyaltyPoints = product.getExtension<int>('loyalty_points');

// Check if extension exists
if (product.extensions?.containsKey('woocommerce') ?? false) {
  final wooData = product.getExtension<Map<String, dynamic>>('woocommerce');
  // Use wooData...
}
```

### Pattern 3: Using copyWithExtensions

```dart
// Product has a special helper method
final updatedProduct = product.copyWithExtensions({
  'user_preferences': {
    'favorite': true,
    'notify_on_sale': true,
  },
});

// The helper merges new extensions with existing ones
// Result: extensions contains both 'woocommerce' and 'user_preferences'
```

### Pattern 4: Multi-Backend Support

```dart
class UnifiedProductsRepository extends CoreRepository implements ProductsRepository {
  final WooCommerceAdapter _wooAdapter;
  final ShopifyAdapter _shopifyAdapter;

  @override
  Future<Product> getProductById(String id) async {
    // Get from both backends
    final wooProduct = await _wooAdapter.getProduct(id);
    final shopifyProduct = await _shopifyAdapter.getProduct(id);

    return Product(
      id: id,
      name: wooProduct.name, // Use WooCommerce as primary
      price: wooProduct.price,
      images: wooProduct.images,

      // Store both backends' data
      extensions: {
        'woocommerce': wooProduct.extensions?['woocommerce'],
        'shopify': shopifyProduct.extensions?['shopify'],
        'sync': {
          'last_synced': DateTime.now().toIso8601String(),
          'source': 'woocommerce',
        },
      },
    );
  }
}
```

## Common Patterns

### Pattern 1: SEO Data

```dart
extensions: {
  'seo': {
    'meta_title': 'Best Product Title',
    'meta_description': 'Description for search engines',
    'keywords': ['keyword1', 'keyword2'],
    'og_image': 'https://example.com/og-image.png',
  },
}
```

### Pattern 2: Inventory Management

```dart
extensions: {
  'inventory': {
    'warehouse_locations': ['A-12', 'B-5'],
    'reorder_point': 10,
    'supplier_id': 'SUP-001',
    'lead_time_days': 7,
  },
}
```

### Pattern 3: Analytics Tracking

```dart
extensions: {
  'analytics': {
    'views_count': 1250,
    'conversion_rate': 0.12,
    'average_time_on_page': 45,
    'last_viewed': '2025-01-15T10:30:00Z',
  },
}
```

### Pattern 4: User Preferences

```dart
extensions: {
  'user_preferences': {
    'favorite': true,
    'notify_on_stock': true,
    'notify_on_price_drop': true,
    'added_to_wishlist': '2025-01-10',
  },
}
```

## Best Practices

### DO:

✅ **Organize by namespace**
```dart
extensions: {
  'backend_name': { /* backend data */ },
  'feature_name': { /* feature data */ },
}
```

✅ **Use type-safe access**
```dart
final wooData = product.extensions?['woocommerce'] as Map<String, dynamic>?;
final permalink = wooData?['permalink'] as String?;
```

✅ **Document extension structure**
```dart
/// Extensions structure:
/// {
///   'woocommerce': {
///     'permalink': String,
///     'tax_status': String,
///     'weight': String,
///   },
/// }
```

✅ **Validate extension data**
```dart
if (product.extensions != null) {
  final wooData = product.extensions!['woocommerce'];
  if (wooData is Map<String, dynamic>) {
    // Safe to use
  }
}
```

### DON'T:

❌ **Don't duplicate core fields**
```dart
// ❌ BAD
extensions: {
  'name': 'Product Name',  // Already in core
  'price': 29.99,          // Already in core
}
```

❌ **Don't store functions or complex objects**
```dart
// ❌ BAD
extensions: {
  'callback': () => print('test'),  // Can't serialize
  'widget': Container(),             // Can't serialize
}
```

❌ **Don't use for critical data**
```dart
// ❌ BAD - stock status is critical, should be in core (and it is!)
extensions: {
  'stock_status': 'in_stock',
}
```

## Examples by Entity

### Product Extensions

```dart
Product(
  id: '123',
  name: 'T-Shirt',
  price: 29.99,
  extensions: {
    'woocommerce': {
      'weight': '0.5',
      'dimensions': {'length': '10', 'width': '8', 'height': '2'},
      'tax_class': 'standard',
    },
    'seo': {
      'meta_title': 'Cool T-Shirt',
      'keywords': ['tshirt', 'fashion'],
    },
  },
);
```

### Category Extensions

```dart
Category(
  id: '5',
  name: 'Clothing',
  slug: 'clothing',
  extensions: {
    'display': {
      'icon': 'tshirt',
      'color': '#FF5722',
      'banner_image': 'https://...',
    },
    'filters': {
      'show_size_filter': true,
      'show_color_filter': true,
    },
  },
);
```

### User Extensions

```dart
User(
  id: 'user123',
  email: 'user@example.com',
  displayName: 'John Doe',
  extensions: {
    'woocommerce': {
      'customer_id': '456',
      'billing_address': {...},
    },
    'loyalty': {
      'points': 150,
      'tier': 'gold',
      'rewards': [...],
    },
  },
);
```

### Cart Extensions

```dart
Cart(
  id: 'cart123',
  items: [...],
  total: 99.99,
  extensions: {
    'checkout': {
      'gift_message': 'Happy Birthday!',
      'gift_wrap': true,
      'delivery_instructions': 'Leave at door',
    },
    'promotions': {
      'auto_applied_coupons': ['SAVE10'],
      'available_offers': [...],
    },
  },
);
```

## Testing with Extensions

```dart
test('should preserve extensions through serialization', () {
  final product = Product(
    id: '1',
    name: 'Test Product',
    price: 10.0,
    images: [],
    inStock: true,
    stockQuantity: 5,
    extensions: {
      'test_data': {
        'custom_field': 'value',
      },
    },
  );

  final json = product.toJson();
  final restored = Product.fromJson(json);

  expect(restored.extensions?['test_data'], isNotNull);
  expect(restored.extensions?['test_data']['custom_field'], equals('value'));
});
```

## Migration from Old Metadata Field

If you have existing code using `metadata`, it has been renamed to `extensions`:

```dart
// OLD (before migration)
product.metadata?['woocommerce']

// NEW (after migration)
product.extensions?['woocommerce']

// Old helper method
product.copyWithMetadata({...})

// New helper method
product.copyWithExtensions({...})
```

## Summary

- ✅ All core entities have an `extensions` field
- ✅ Use it for backend-specific, custom, or additional data
- ✅ Organize by namespace (backend name, feature name)
- ✅ Type-safe access with null-safety
- ✅ No need to create custom entity classes
- ❌ Don't duplicate core fields
- ❌ Don't store sensitive or critical data
- ❌ Don't store non-serializable objects

---

**Version:** 1.0.0
**Last Updated:** 2025-11-05
**Related**: [ADAPTER_SYSTEM.md](./ADAPTER_SYSTEM.md), [ARCHITECTURE.md](./ARCHITECTURE.md)
