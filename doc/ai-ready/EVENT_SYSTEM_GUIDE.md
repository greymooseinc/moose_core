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
- **Pattern**: Asynchronous pub/sub messaging with string-based events
- **Example**: Track analytics, send notifications, update cache

## Import Statement

```dart
import 'package:moose_core/services.dart';

// Now you have access to:
// - HookRegistry()
// - EventBus()
// - Event class
```

## EventBus Quick Start

**IMPORTANT**: EventBus uses **string-based events only**. No typed events, no shared event classes between plugins. This ensures true plugin independence!

### 1. Fire an Event (from BLoC or Repository)

```dart
// In your BLoC after successful operation
EventBus().fire(
  'cart.item.added',
  data: {
    'productId': 'product-123',
    'quantity': 2,
    'variationId': 'var-456',
    'itemData': {
      'productName': 'Cool T-Shirt',
      'price': 29.99,
    },
  },
  metadata: {
    'cartTotal': 59.99,
    'itemCount': 2,
  },
);
```

### 2. Subscribe to Events (in Plugin)

```dart
class MyPlugin extends FeaturePlugin {
  final List<EventSubscription> _subscriptions = [];

  @override
  Future<void> initialize() async {
    _subscriptions.add(
      EventBus().on('cart.item.added', (event) {
        // Access event data
        final productId = event.data['productId'];
        final quantity = event.data['quantity'];

        print('Item added: $productId (qty: $quantity)');
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

### 3. Async Event Handlers

For async operations (API calls, database writes, etc.):

```dart
EventBus().onAsync(
  'order.placed',
  (event) async {
    final orderId = event.data['orderId'];

    // Async operations
    await sendConfirmationEmail(orderId);
    await updateInventory(orderId);
  },
  onError: (error) {
    print('Error processing order: $error');
  },
);
```

## Event Naming Convention

**CRITICAL**: Use dot notation for event names

Format: `<domain>.<action>.<optional-detail>`

### ✅ Good Event Names:
```dart
'cart.item.added'
'user.profile.updated'
'payment.completed'
'notification.sent'
'product.viewed'
'order.status.changed'
'error.api'
```

### ❌ Bad Event Names:
```dart
'CartItemAdded'        // Don't use PascalCase
'cart_item_added'      // Don't use snake_case
'itemAdded'            // Too generic
'cart'                 // Not specific enough
```

## Common Event Patterns

### Cart Events
```dart
// Item added to cart
EventBus().fire('cart.item.added', data: {
  'productId': String,
  'quantity': int,
  'variationId': String?,
  'itemData': Map<String, dynamic>,
});

// Item removed from cart
EventBus().fire('cart.item.removed', data: {
  'itemId': String,
  'productId': String,
  'previousQuantity': int,
});

// Item quantity updated
EventBus().fire('cart.item.quantity.updated', data: {
  'itemId': String,
  'productId': String,
  'oldQuantity': int,
  'newQuantity': int,
});

// Cart cleared
EventBus().fire('cart.cleared', data: {
  'itemCount': int,
  'totalValue': double,
});

// Coupon applied
EventBus().fire('cart.coupon.applied', data: {
  'couponCode': String,
  'discountAmount': double,
});
```

### Product Events
```dart
// Product viewed
EventBus().fire('product.viewed', data: {
  'productId': String,
  'productName': String,
  'price': double,
});

// Product searched
EventBus().fire('product.searched', data: {
  'searchQuery': String,
  'resultCount': int,
  'productIds': List<String>,
});

// Product reviewed
EventBus().fire('product.reviewed', data: {
  'productId': String,
  'reviewId': String,
  'rating': double,
  'comment': String?,
});
```

### User Events
```dart
// User logged in
EventBus().fire('user.logged.in', data: {
  'userId': String,
  'email': String,
  'displayName': String?,
});

// User logged out
EventBus().fire('user.logged.out', data: {
  'userId': String,
  'reason': String?,
});

// User profile updated
EventBus().fire('user.profile.updated', data: {
  'userId': String,
  'updatedFields': List<String>,
});
```

### Order Events
```dart
// Order created
EventBus().fire('order.created', data: {
  'orderId': String,
  'total': double,
  'itemCount': int,
  'orderData': Map<String, dynamic>,
});

// Order status changed
EventBus().fire('order.status.changed', data: {
  'orderId': String,
  'oldStatus': String,
  'newStatus': String,
});

// Payment completed
EventBus().fire('payment.completed', data: {
  'orderId': String,
  'paymentId': String,
  'amount': double,
  'paymentMethod': String,
});
```

### Navigation Events
```dart
// Screen viewed
EventBus().fire('screen.viewed', data: {
  'screenName': String,
  'previousScreen': String?,
  'parameters': Map<String, dynamic>?,
});
```

### Error Events
```dart
// Application error
EventBus().fire('error.application', data: {
  'errorMessage': String,
  'errorCode': String?,
  'context': Map<String, dynamic>?,
});

// API error
EventBus().fire('error.api', data: {
  'endpoint': String,
  'statusCode': int,
  'errorMessage': String,
  'requestData': Map<String, dynamic>?,
});
```

### Notification Events
```dart
// Notification received
EventBus().fire('notification.received', data: {
  'notificationId': String,
  'title': String,
  'body': String,
  'data': Map<String, dynamic>?,
});

// Notification tapped
EventBus().fire('notification.tapped', data: {
  'notificationId': String,
  'data': Map<String, dynamic>?,
});
```

## Best Practices

### 1. Always Include Required Context

```dart
// ✅ Good - includes all necessary context
EventBus().fire('order.placed', data: {
  'orderId': 'order-123',
  'userId': 'user-456',
  'total': 99.99,
  'items': [...],
});

// ❌ Bad - missing important context
EventBus().fire('order.placed', data: {
  'orderId': 'order-123',
});
```

### 2. Use Metadata for Non-Essential Data

```dart
EventBus().fire(
  'product.viewed',
  data: {
    // Essential data
    'productId': 'prod-123',
    'productName': 'Cool Shirt',
    'price': 29.99,
  },
  metadata: {
    // Additional context
    'source': 'search_results',
    'position': 3,
    'sessionId': 'sess-789',
  },
);
```

### 3. Check for Subscribers (Performance Optimization)

```dart
// Avoid expensive computations if no one is listening
if (EventBus().hasSubscribers('analytics.detailed')) {
  final expensiveData = await computeAnalytics();
  EventBus().fire('analytics.detailed', data: expensiveData);
}
```

### 4. Handle Errors in Async Handlers

```dart
EventBus().onAsync(
  'order.placed',
  (event) async {
    try {
      await processOrder(event.data['orderId']);
    } catch (e) {
      // Fire error event
      EventBus().fire('error.order.processing', data: {
        'orderId': event.data['orderId'],
        'error': e.toString(),
      });
    }
  },
  onError: (error) {
    print('Handler error: $error');
  },
);
```

### 5. Clean Up Subscriptions

```dart
class MyPlugin extends FeaturePlugin {
  final List<EventSubscription> _subscriptions = [];

  @override
  Future<void> initialize() async {
    _subscriptions.add(EventBus().on('some.event', (_) {}));
  }

  // IMPORTANT: Always cancel subscriptions!
  Future<void> dispose() async {
    for (final sub in _subscriptions) {
      await sub.cancel();
    }
    _subscriptions.clear();
  }
}
```

## Plugin Communication Example

### Payment Plugin (Publisher)
```dart
class PaymentPlugin extends FeaturePlugin {
  Future<void> processPayment(String orderId, double amount) async {
    // Process payment...

    // Fire event - no dependency on other plugins!
    EventBus().fire('payment.completed', data: {
      'orderId': orderId,
      'amount': amount,
      'paymentMethod': 'stripe',
    });
  }
}
```

### Analytics Plugin (Subscriber)
```dart
class AnalyticsPlugin extends FeaturePlugin {
  @override
  Future<void> initialize() async {
    // Listen to payment events - no dependency on PaymentPlugin!
    EventBus().on('payment.completed', (event) {
      final orderId = event.data['orderId'];
      final amount = event.data['amount'];

      _trackPurchase(orderId, amount);
    });
  }
}
```

### Email Plugin (Another Subscriber)
```dart
class EmailPlugin extends FeaturePlugin {
  @override
  Future<void> initialize() async {
    // Also listens to same event - no coupling!
    EventBus().onAsync('payment.completed', (event) async {
      final orderId = event.data['orderId'];
      await sendPaymentConfirmation(orderId);
    });
  }
}
```

## BLoC Integration

### Fire Events from BLoC

```dart
class ProductsBloc extends Bloc<ProductsEvent, ProductsState> {
  Future<void> _onLoadProduct(
    LoadProduct event,
    Emitter<ProductsState> emit,
  ) async {
    final product = await repository.getProduct(event.productId);
    emit(ProductLoaded(product));

    // Fire event after state change
    EventBus().fire('product.viewed', data: {
      'productId': product.id,
      'productName': product.name,
      'price': product.price,
    });
  }
}
```

### Listen to Events in BLoC

```dart
class RecentlyViewedBloc extends Bloc<RecentlyViewedEvent, RecentlyViewedState> {
  EventSubscription? _eventSubscription;

  RecentlyViewedBloc() : super(RecentlyViewedInitial()) {
    on<LoadRecentlyViewed>(_onLoadRecentlyViewed);

    // Subscribe to product.viewed events
    _eventSubscription = EventBus().on('product.viewed', (event) {
      // Add event to reload the list
      add(LoadRecentlyViewed());
    });
  }

  @override
  Future<void> close() {
    _eventSubscription?.cancel();
    return super.close();
  }
}
```

## Testing Events

```dart
void main() {
  late EventBus eventBus;

  setUp(() {
    eventBus = EventBus();
  });

  tearDown(() async {
    await eventBus.reset();
  });

  test('should receive event', () async {
    bool eventReceived = false;

    eventBus.on('test.event', (event) {
      eventReceived = true;
      expect(event.data['value'], equals(42));
    });

    eventBus.fire('test.event', data: {'value': 42});

    // Wait for microtasks
    await Future.delayed(Duration.zero);

    expect(eventReceived, isTrue);
  });
}
```

## Common Pitfalls

### ❌ DON'T: Create typed event classes
```dart
// WRONG - Don't do this!
class ProductViewedEvent {
  final String productId;
  ProductViewedEvent(this.productId);
}

EventBus().fire(ProductViewedEvent('123')); // ❌ Wrong!
```

### ✅ DO: Use string names with data
```dart
// CORRECT - Do this!
EventBus().fire('product.viewed', data: {
  'productId': '123',
}); // ✅ Correct!
```

### ❌ DON'T: Forget to cancel subscriptions
```dart
// WRONG - Memory leak!
class MyWidget extends StatefulWidget {
  @override
  void initState() {
    EventBus().on('some.event', (_) {});  // ❌ Never cancelled!
  }
}
```

### ✅ DO: Cancel in dispose/close
```dart
// CORRECT
class MyBloc extends Bloc {
  EventSubscription? _sub;

  MyBloc() : super(InitialState()) {
    _sub = EventBus().on('some.event', (_) {});
  }

  @override
  Future<void> close() {
    _sub?.cancel();  // ✅ Properly cleaned up!
    return super.close();
  }
}
```

---

**Remember:** EventBus is for **fire-and-forget** notifications. If you need a return value, use HookRegistry instead!

**See Also:**
- [ARCHITECTURE.md](./ARCHITECTURE.md) - Complete architectural guide
- [PLUGIN_SYSTEM.md](./PLUGIN_SYSTEM.md) - Plugin development
- [ANTI_PATTERNS.md](./ANTI_PATTERNS.md) - What NOT to do

---

**Last Updated:** 2025-11-09
**Version:** 2.0.0 (String-based events only)
