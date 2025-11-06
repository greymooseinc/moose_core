# Event System Guide for AI Agents

> **Quick Reference**: Comprehensive guide for implementing event-driven architecture in moose_core

## TL;DR Decision Matrix

```
┌─────────────────────────────────────────────────────┐
│  Does the caller need a return value?               │
│                                                      │
│  YES ──▶ Use HookRegistry (synchronous)            │
│  NO  ──▶ Use EventBus (asynchronous)               │
└─────────────────────────────────────────────────────┘
```

## Two Event Systems

### HookRegistry - Data Transformation
- **Use when**: You need to transform/modify data and return a result
- **Pattern**: Synchronous callbacks with priority
- **Example**: Calculate price with discounts, filter search results

### EventBus - Notifications
- **Use when**: Fire-and-forget notifications and side effects
- **Pattern**: Asynchronous pub/sub messaging
- **Example**: Track analytics, send notifications, update cache

## Import Statement

```dart
import 'package:moose_core/services.dart';

// Now you have access to:
// - HookRegistry()
// - EventBus()
// - All common event types (AppCartItemAddedEvent, etc.)
```

## EventBus Quick Start

### 1. Define Event (or use pre-built)

```dart
// Use pre-built events from common_events.dart
import 'package:moose_core/services.dart';

// All events are prefixed with "App" to avoid BLoC confusion
```

### 2. Fire Events (from BLoC or Repository)

```dart
// In your BLoC after successful operation
EventBus().fire(AppCartItemAddedEvent(
  productId: 'product-123',
  quantity: 2,
  variationId: 'var-456',
  itemData: {
    'productName': 'Cool T-Shirt',
    'price': 29.99,
  },
  metadata: {
    'cartTotal': 59.99,
    'itemCount': 2,
  },
));
```

### 3. Subscribe to Events (in Plugin)

```dart
class MyPlugin extends FeaturePlugin {
  final List<EventSubscription> _subscriptions = [];

  @override
  Future<void> initialize() async {
    _subscriptions.add(
      EventBus().on<AppCartItemAddedEvent>((event) {
        print('Item added: ${event.productId}');
        // Handle event - track analytics, show notification, etc.
      }),
    );
  }

  // Clean up subscriptions when plugin is done
  Future<void> cleanup() async {
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
  }
}
```

## Pre-Built Event Types

**NOTE: All events prefixed with "App" to avoid BLoC event confusion**

### Cart Events
- `AppCartItemAddedEvent(productId, quantity, variationId, itemData, metadata)`
- `AppCartItemRemovedEvent(itemId, productId, previousQuantity, metadata)`
- `AppCartItemQuantityUpdatedEvent(itemId, productId, oldQuantity, newQuantity, metadata)`
- `AppCartClearedEvent(itemCount, totalValue)`
- `AppCartCouponAppliedEvent(couponCode, discountAmount, metadata)`

### Product Events
- `AppProductViewedEvent(productId, productName, price, metadata)`
- `AppProductSearchedEvent(searchQuery, resultCount, productIds, metadata)`
- `AppProductReviewedEvent(productId, reviewId, rating, comment, metadata)`

### Auth Events
- `AppUserLoggedInEvent(userId, email, displayName, userData, metadata)`
- `AppUserLoggedOutEvent(userId, reason, metadata)`
- `AppUserProfileUpdatedEvent(userId, updatedFields, metadata)`

### Order Events
- `AppOrderCreatedEvent(orderId, total, itemCount, orderData, metadata)`
- `AppOrderStatusChangedEvent(orderId, oldStatus, newStatus, metadata)`
- `AppPaymentCompletedEvent(orderId, paymentId, amount, paymentMethod, metadata)`

### Error Events
- `AppApplicationErrorEvent(errorMessage, errorCode, error, stackTrace, context, metadata)`
- `AppApiErrorEvent(endpoint, statusCode, errorMessage, requestData, metadata)`

### Navigation Events
- `AppScreenViewedEvent(screenName, previousScreen, parameters, metadata)`

### Notification Events
- `AppNotificationReceivedEvent(notificationId, title, body, data, metadata)`
- `AppNotificationTappedEvent(notificationId, data, metadata)`

## Where to Fire Events

### ✅ From BLoC (Business Logic)
```dart
class CartBloc extends Bloc<CartEvent, CartState> {
  Future<void> _onAddToCart(AddToCart event, Emitter emit) async {
    try {
      final cart = await _repository.addItem(...);

      // Fire EventBus event AFTER successful operation
      EventBus().fire(AppCartItemAddedEvent(...));

      emit(CartLoaded(cart: cart));
    } catch (e) {
      EventBus().fire(AppApplicationErrorEvent(...));
      emit(CartError(...));
    }
  }
}
```

### ✅ From Repository (Data Layer)
```dart
class ShopifyAuthRepository extends AuthRepository {
  @override
  Future<AuthResult> signIn(AuthCredentials credentials) async {
    try {
      final user = await _authenticate(...);

      // Fire EventBus event AFTER successful operation
      EventBus().fire(AppUserLoggedInEvent(
        userId: user.id,
        email: user.email,
        displayName: user.displayName,
      ));

      return AuthResult.success(user: user);
    } catch (e) {
      EventBus().fire(AppApplicationErrorEvent(...));
      return AuthResult.failure(...);
    }
  }
}
```

### ❌ NOT from UI Layer
```dart
// WRONG - Don't fire from widgets
class ProductDetailScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // ❌ BAD - don't fire events from UI
    // EventBus().fire(AppProductViewedEvent(...));
  }
}
```

## Common Patterns

### Pattern 1: Analytics Plugin
```dart
class AnalyticsPlugin extends FeaturePlugin {
  final List<EventSubscription> _subscriptions = [];

  @override
  Future<void> initialize() async {
    // Subscribe to all cart events
    _subscriptions.add(
      EventBus().on<AppCartItemAddedEvent>((event) {
        _trackEvent('cart_item_added', {
          'product_id': event.productId,
          'quantity': event.quantity,
          ...?event.metadata,
        });
      }),
    );

    // Subscribe to all user events
    _subscriptions.add(
      EventBus().on<AppUserLoggedInEvent>((event) {
        _trackEvent('user_logged_in', {
          'user_id': event.userId,
          'email': event.email,
        });
      }),
    );

    // Subscribe to errors
    _subscriptions.add(
      EventBus().on<AppApplicationErrorEvent>((event) {
        _trackError(event.errorMessage, event.context);
      }),
    );
  }

  void _trackEvent(String name, Map<String, dynamic> properties) {
    // Send to analytics service
    print('📊 Analytics: $name - $properties');
  }

  void _trackError(String message, String? context) {
    // Send to error tracking service
    print('❌ Error: $message in $context');
  }
}
```

### Pattern 2: Cart with Events
```dart
class CartBloc extends Bloc<CartEvent, CartState> {
  Future<void> _onAddToCart(AddToCart event, Emitter emit) async {
    try {
      final cart = await _repository.addItem(
        productId: event.productId,
        quantity: event.quantity,
      );

      // Fire success event
      EventBus().fire(AppCartItemAddedEvent(
        productId: event.productId,
        quantity: event.quantity,
        itemData: {
          'productName': cart.items.last.name,
          'price': cart.items.last.price,
        },
        metadata: {
          'cartTotal': cart.total,
          'itemCount': cart.items.length,
        },
      ));

      emit(CartLoaded(cart: cart));
    } catch (e) {
      // Fire error event
      EventBus().fire(AppApplicationErrorEvent(
        errorMessage: 'Failed to add item to cart',
        errorCode: 'cart_add_failed',
        error: e,
        context: 'CartBloc._onAddToCart',
        metadata: {
          'productId': event.productId,
          'quantity': event.quantity,
        },
      ));

      emit(CartError(message: e.toString()));
    }
  }
}
```

### Pattern 3: Multi-Plugin Communication
```dart
// AuthPlugin fires event
class AuthPlugin {
  Future<void> signIn() async {
    final user = await _repository.signIn();
    EventBus().fire(AppUserLoggedInEvent(userId: user.id));
  }
}

// CachePlugin reacts to event
class CachePlugin extends FeaturePlugin {
  @override
  Future<void> initialize() async {
    EventBus().on<AppUserLoggedInEvent>((event) {
      _initializeUserCache(event.userId);
    });
  }
}

// AnalyticsPlugin reacts to event
class AnalyticsPlugin extends FeaturePlugin {
  @override
  Future<void> initialize() async {
    EventBus().on<AppUserLoggedInEvent>((event) {
      _trackLogin(event.userId);
    });
  }
}
```

## HookRegistry Quick Start

### 1. Register Hook (for transformations)
```dart
class PricingPlugin extends FeaturePlugin {
  @override
  void onRegister() {
    hookRegistry.register('product:calculate_price', (product) {
      // Transform the product price
      if (_isPremiumUser()) {
        return product.copyWith(price: product.price * 0.9); // 10% off
      }
      return product;
    }, priority: 10); // Higher priority runs first
  }
}
```

### 2. Execute Hook
```dart
// Get transformed data
final pricedProduct = hookRegistry.execute(
  'product:calculate_price',
  originalProduct,
);
```

## Common Mistakes to Avoid

### ❌ Mistake 1: Using Hooks for Notifications
```dart
// WRONG - hooks are for transformations, not side effects
hookRegistry.register('cart:item_added', (cart) {
  _showNotification('Item added');  // Side effect!
  return cart;  // Didn't transform anything
});

// RIGHT - use EventBus for notifications
EventBus().fire(AppCartItemAddedEvent(...));
```

### ❌ Mistake 2: Using EventBus for Transformations
```dart
// WRONG - EventBus can't return values
EventBus().fire(CalculatePriceEvent(product: product));
// How do I get the calculated price? I CAN'T!

// RIGHT - use HookRegistry for transformations
final pricedProduct = hookRegistry.execute('product:calculate_price', product);
```

### ❌ Mistake 3: Firing Events from UI
```dart
// WRONG - fire from BLoC, not UI
class ProductDetailScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    if (state is ProductDetailLoaded) {
      EventBus().fire(AppProductViewedEvent(...)); // ❌ BAD
    }
  }
}

// RIGHT - fire from BLoC
class ProductsBloc extends Bloc<ProductsEvent, ProductsState> {
  Future<void> _onLoadProductDetail(event, emit) async {
    final product = await repository.getProductById(event.productId);
    EventBus().fire(AppProductViewedEvent(...)); // ✅ GOOD
    emit(ProductDetailLoaded(product));
  }
}
```

### ❌ Mistake 4: Not Cleaning Up Subscriptions
```dart
// WRONG - memory leak
class MyPlugin extends FeaturePlugin {
  @override
  Future<void> initialize() async {
    EventBus().on<AppCartItemAddedEvent>((event) {
      // Handle event
    });
    // Subscription never cancelled!
  }
}

// RIGHT - track and cancel subscriptions
class MyPlugin extends FeaturePlugin {
  final List<EventSubscription> _subscriptions = [];

  @override
  Future<void> initialize() async {
    _subscriptions.add(
      EventBus().on<AppCartItemAddedEvent>((event) {
        // Handle event
      }),
    );
  }

  Future<void> cleanup() async {
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
  }
}
```

## Testing Events

### Test EventBus
```dart
test('event notifies subscribers', () async {
  final eventBus = EventBus();
  AppCartItemAddedEvent? received;

  final sub = eventBus.on<AppCartItemAddedEvent>((event) {
    received = event;
  });

  eventBus.fire(AppCartItemAddedEvent(
    productId: 'p1',
    quantity: 2,
  ));

  await Future.delayed(Duration.zero);

  expect(received, isNotNull);
  expect(received!.productId, equals('p1'));

  await sub.cancel();
});
```

### Test HookRegistry
```dart
test('hook transforms product price', () {
  final hookRegistry = HookRegistry();

  hookRegistry.register('product:calculate_price', (product) {
    return product.copyWith(price: product.price * 0.9);
  });

  final product = Product(id: '1', price: 100.0);
  final result = hookRegistry.execute('product:calculate_price', product);

  expect(result.price, equals(90.0));
});
```

## Decision Table

| Scenario | System | Why |
|----------|--------|-----|
| Calculate product price with discounts | HookRegistry | Need return value |
| Notify analytics of user action | EventBus | Fire-and-forget |
| Filter search results | HookRegistry | Transform data |
| Send email confirmation | EventBus | Side effect |
| Apply user-specific pricing | HookRegistry | Need result |
| Update recommendation engine | EventBus | Notification |
| Modify API request headers | HookRegistry | Transform request |
| Log error to monitoring | EventBus | Side effect |
| Validate cart before checkout | HookRegistry | Return validation result |
| Clear cache on logout | EventBus | Notification |

## Performance Notes

- **HookRegistry**: Synchronous, fast, blocks until all hooks complete
- **EventBus**: Asynchronous, slight overhead, non-blocking

**Rule of Thumb**: If it needs to happen immediately and return a value, use HookRegistry. Everything else, use EventBus.

## Summary Checklist

### When implementing events:
- [ ] Fire events from BLoC or Repository, NOT from UI
- [ ] Use App-prefixed event names to avoid BLoC confusion
- [ ] Subscribe to events in Plugin's `initialize()` method
- [ ] Store subscriptions in a list for cleanup
- [ ] Fire events AFTER successful operations
- [ ] Fire error events in catch blocks
- [ ] Include relevant metadata for analytics
- [ ] Use HookRegistry for transformations (return values)
- [ ] Use EventBus for notifications (fire-and-forget)
- [ ] Clean up subscriptions to prevent memory leaks

---

**Version:** 2.0.0
**Last Updated:** 2025-11-05
**Note**: All event names now prefixed with "App" to distinguish from BLoC events
