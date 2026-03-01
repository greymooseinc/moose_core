# Entity Extensions

## Overview

Every domain entity in `moose_core` extends `CoreEntity`, which provides an `extensions` field (`Map<String, dynamic>?`). This is the standard mechanism for adapters to carry backend-specific or platform-specific data alongside an entity — without subclassing, modifying core, or creating parallel entity hierarchies.

**The rule**: if the data is universal to all backends, it belongs in a core field. If it is specific to one backend or feature, it belongs in `extensions`.

---

## CoreEntity Base

```dart
@immutable
abstract class CoreEntity extends Equatable {
  final Map<String, dynamic>? extensions;

  const CoreEntity({this.extensions});

  T? getExtension<T>(String key) {
    if (extensions == null) return null;
    final value = extensions![key];
    if (value == null) return null;
    return value as T?;
  }
}
```

`getExtension<T>(key)` performs a typed cast. It returns `null` if `extensions` is null or the key is absent.

---

## Which Entities Have Extensions

All entities that extend `CoreEntity` carry the `extensions` field. The following table shows every entity in the package and its base class:

| Entity | Extends | Has `extensions` |
|---|---|---|
| `Product` | `CoreEntity` | Yes |
| `ProductVariation` | `CoreEntity` | Yes |
| `ProductAttribute` | `CoreEntity` | Yes |
| `ProductReview` | `CoreEntity` | Yes |
| `Category` | `CoreEntity` | Yes |
| `Collection` | `CoreEntity` | Yes |
| `Cart` | `CoreEntity` | Yes |
| `CartItem` | `CoreEntity` | Yes |
| `Order` | `CoreEntity` | Yes |
| `OrderLineItem` | `CoreEntity` | Yes |
| `User` | `CoreEntity` | Yes |
| `Address` | `CoreEntity` | Yes |
| `Post` | `CoreEntity` | Yes |
| `PromoBanner` | `CoreEntity` | Yes |
| `SearchResult` | `CoreEntity` | Yes |
| `CheckoutRequest` | `CoreEntity` | Yes |
| `PaymentMethod` | `CoreEntity` | Yes |
| `DeliveryMethod` | `CoreEntity` | Yes |
| `MediaItem` | `Equatable` | **No** |
| `PaginatedResult<T>` | `Equatable` | **No** |
| `CartAmount` | `Equatable` | **No** |
| `ShippingInfo` | `Equatable` | **No** |
| `AppliedCoupon` | `Equatable` | **No** |

`MediaItem`, `PaginatedResult`, `CartAmount`, `ShippingInfo`, and `AppliedCoupon` are value/wrapper types that do not extend `CoreEntity` and have no `extensions` field.

---

## Setting Extensions

Extensions are set via the entity constructor. Every `CoreEntity` subclass passes `extensions` to `super.extensions`.

```dart
final product = Product(
  id: '123',
  name: 'Slim Fit Tee',
  price: 29.99,
  media: [MediaItem(url: 'https://cdn.example.com/tee.jpg')],
  inStock: true,
  stockQuantity: 50,
  extensions: {
    'woocommerce': {
      'permalink': 'https://store.com/product/slim-fit-tee',
      'tax_status': 'taxable',
      'tax_class': 'standard',
      'weight': '0.4',
      'dimensions': {'length': '30', 'width': '20', 'height': '2'},
      'shipping_class': 'standard',
    },
  },
);
```

---

## Updating Extensions

### copyWith — replaces extensions entirely

Every `CoreEntity` subclass has `copyWith(extensions: ...)`. Passing a new map **replaces** the existing extensions map; it does not merge.

```dart
// Replaces extensions — previous keys are lost
final updated = product.copyWith(extensions: {
  'analytics': {'views': 500},
});
```

To preserve existing data, spread the original map:

```dart
final updated = product.copyWith(extensions: {
  ...?product.extensions,
  'analytics': {'views': 500},
});
```

### copyWithExtensions — merges extensions (Product only)

`Product` has an additional helper that performs a shallow merge automatically:

```dart
// Merges: existing keys are preserved, new keys are added
final updated = product.copyWithExtensions({
  'analytics': {'views': 500},
});
// Result: extensions contains both 'woocommerce' and 'analytics'
```

`copyWithExtensions` is **only available on `Product`**. All other entities must use `copyWith` with a manual spread if merging is needed.

---

## Reading Extensions

### Direct map access

```dart
final wooData = product.extensions?['woocommerce'] as Map<String, dynamic>?;
final permalink = wooData?['permalink'] as String?;
```

### Type-safe access via getExtension

```dart
final wooData = product.getExtension<Map<String, dynamic>>('woocommerce');
final permalink = wooData?['permalink'] as String?;

final loyaltyPoints = user.getExtension<int>('loyalty_points');
```

`getExtension<T>` returns `null` for absent or null values. It does not throw; an incorrect type cast will throw a `TypeError` at runtime, so ensure the type parameter matches what was stored.

---

## Serialization

Every entity's `toJson()` includes the extensions field, and `fromJson()` restores it. Extensions round-trip transparently through JSON.

```dart
final json = product.toJson();
// json['extensions'] contains the map

final restored = Product.fromJson(json);
// restored.extensions is identical to the original
```

`SearchResult` initialises `extensions` to `const {}` (empty map, not null) by default, unlike other entities where it defaults to `null`.

`PromoBanner.fromJson` stores the full raw JSON payload as `extensions: json` — this means the entire backend response is preserved verbatim in extensions, making it straightforward to access any field not mapped to a core property.

---

## Usage in Adapters

The pattern for repository implementations is:

1. Fetch raw data from the backend API.
2. Map known fields to core entity fields.
3. Place backend-specific or supplemental data in `extensions`, namespaced by backend name or feature area.

```dart
class WooProductsRepository extends CoreRepository implements ProductsRepository {
  final ApiClient _api;

  WooProductsRepository(this._api);

  @override
  Future<Product> getProductById(String id) async {
    final raw = await _api.get('/products/$id');

    return Product(
      id: raw['id'].toString(),
      name: raw['name'] as String,
      price: double.tryParse(raw['price'].toString()) ?? 0.0,
      media: (raw['images'] as List? ?? [])
          .map((img) => MediaItem(url: img['src'] as String))
          .toList(),
      inStock: raw['in_stock'] as bool? ?? false,
      stockQuantity: raw['stock_quantity'] as int? ?? 0,
      extensions: {
        'woocommerce': {
          'permalink': raw['permalink'],
          'tax_status': raw['tax_status'],
          'weight': raw['weight'],
          'dimensions': raw['dimensions'],
          'shipping_class': raw['shipping_class'],
          'menu_order': raw['menu_order'],
        },
      },
    );
  }
}
```

---

## Namespacing Convention

Use a top-level key to namespace extensions by backend or feature. This avoids key collisions when extensions from multiple sources coexist on one entity.

```dart
extensions: {
  'woocommerce': { /* WooCommerce-specific fields */ },
  'seo':         { /* SEO metadata */ },
  'analytics':   { /* tracking data */ },
  'loyalty':     { /* loyalty programme data */ },
}
```

Avoid flat, unnamespaced keys unless the data is genuinely global to all adapters of a plugin (e.g., `'loyalty_points': 150`).

---

## What to Store in Extensions vs Core Fields

| Situation | Where it goes |
|---|---|
| Field present in every backend (price, name, status) | Core field |
| Backend-specific identifier or raw response field | `extensions` |
| Platform feature data (SEO, loyalty, analytics) | `extensions` |
| Data shared across all adapters for a plugin | `extensions` (namespaced by plugin) |
| Non-serialisable objects (functions, Widgets) | Neither — do not store |
| Sensitive credentials or card numbers | Neither — do not store |
| Data that duplicates a core field | Do not duplicate — use the core field |

---

## Examples by Entity

### Product

```dart
Product(
  id: '123',
  name: 'Slim Fit Tee',
  price: 29.99,
  media: [MediaItem(url: 'https://cdn.example.com/tee.jpg')],
  inStock: true,
  stockQuantity: 50,
  extensions: {
    'woocommerce': {
      'permalink': 'https://store.com/product/slim-fit-tee',
      'tax_class': 'standard',
      'weight': '0.4',
    },
    'seo': {
      'meta_title': 'Slim Fit Tee — Best Price',
      'meta_description': 'Premium slim fit cotton tee.',
    },
  },
);
```

### Category

```dart
Category(
  id: '5',
  name: 'Clothing',
  slug: 'clothing',
  extensions: {
    'display': {
      'icon': 'tshirt',
      'accent_color': '#FF5722',
      'banner_image': 'https://cdn.example.com/clothing-banner.jpg',
    },
    'filters': {
      'show_size_filter': true,
      'show_color_filter': true,
    },
  },
);
```

### Cart

```dart
Cart(
  id: 'cart-abc',
  items: [...],
  extensions: {
    'checkout': {
      'gift_message': 'Happy Birthday!',
      'gift_wrap': true,
    },
    'promotions': {
      'auto_applied_coupons': ['SAVE10'],
    },
  },
);
```

### User

```dart
User(
  id: 'user-123',
  email: 'user@example.com',
  displayName: 'Jane Smith',
  extensions: {
    'woocommerce': {
      'customer_id': '456',
    },
    'loyalty': {
      'points': 1500,
      'tier': 'gold',
    },
  },
);
```

### Order

```dart
Order(
  id: 'order-789',
  status: 'processing',
  total: 89.99,
  lineItems: [...],
  extensions: {
    'woocommerce': {
      'payment_method': 'stripe',
      'transaction_id': 'txn_abc123',
      'customer_ip': '192.168.1.1',
    },
  },
);
```

### PromoBanner

`PromoBanner.fromJson` stores the entire raw JSON payload as extensions, so all backend fields are accessible even if not mapped to a core property:

```dart
// In your repository
final banner = PromoBanner.fromJson(rawApiResponse);

// Access unmapped backend fields via extensions
final campaignId = banner.extensions?['campaign_id'] as String?;
final impressionUrl = banner.extensions?['impression_tracking_url'] as String?;
```

---

## Testing with Extensions

```dart
test('extensions round-trip through serialization', () {
  final product = Product(
    id: '1',
    name: 'Test Product',
    price: 10.0,
    media: [],
    inStock: true,
    stockQuantity: 5,
    extensions: {
      'test_backend': {
        'custom_field': 'value',
        'numeric_field': 42,
      },
    },
  );

  final json = product.toJson();
  final restored = Product.fromJson(json);

  expect(restored.extensions?['test_backend'], isNotNull);
  expect(restored.extensions?['test_backend']['custom_field'], equals('value'));
  expect(restored.extensions?['test_backend']['numeric_field'], equals(42));
});

test('copyWith replaces extensions', () {
  final product = Product(/* ... */, extensions: {'old': 'data'});
  final updated = product.copyWith(extensions: {'new': 'data'});

  expect(updated.extensions?.containsKey('old'), isFalse);
  expect(updated.extensions?['new'], equals('data'));
});

test('copyWithExtensions merges extensions (Product only)', () {
  final product = Product(/* ... */, extensions: {'woocommerce': {'weight': '0.4'}});
  final updated = product.copyWithExtensions({'analytics': {'views': 100}});

  expect(updated.extensions?.containsKey('woocommerce'), isTrue);
  expect(updated.extensions?.containsKey('analytics'), isTrue);
});
```

---

## Related

- [ADAPTER_SYSTEM.md](./ADAPTER_SYSTEM.md) — how adapters populate entities from backend responses
- [ARCHITECTURE.md](./ARCHITECTURE.md) — overall layer structure and data flow
- [API.md](./API.md) — full API reference for all entity classes
