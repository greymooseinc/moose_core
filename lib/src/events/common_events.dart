import 'event_bus.dart';

/// Common event types that can be used across different parts of the application
/// These are base event types - extend them for specific use cases
///
/// NOTE: All events are prefixed with "App" to avoid confusion with BLoC events

// ============================================================================
// User/Authentication Events
// ============================================================================

/// Base class for all authentication-related events
abstract class AppAuthEvent extends Event {
  AppAuthEvent({super.timestamp, super.metadata});
}

/// Fired when a user successfully logs in
class AppUserLoggedInEvent extends AppAuthEvent {
  final String userId;
  final String? email;
  final String? displayName;
  final Map<String, dynamic>? userData;

  AppUserLoggedInEvent({
    required this.userId,
    this.email,
    this.displayName,
    this.userData,
    super.timestamp,
    super.metadata,
  });
}

/// Fired when a user logs out
class AppUserLoggedOutEvent extends AppAuthEvent {
  final String? userId;
  final String? reason;

  AppUserLoggedOutEvent({
    this.userId,
    this.reason,
    super.timestamp,
    super.metadata,
  });
}

/// Fired when user profile is updated
class AppUserProfileUpdatedEvent extends AppAuthEvent {
  final String userId;
  final Map<String, dynamic> updatedFields;

  AppUserProfileUpdatedEvent({
    required this.userId,
    required this.updatedFields,
    super.timestamp,
    super.metadata,
  });
}

// ============================================================================
// Cart Events
// ============================================================================

/// Base class for all cart-related events
abstract class AppCartEvent extends Event {
  AppCartEvent({super.timestamp, super.metadata});
}

/// Fired when an item is added to the cart
class AppCartItemAddedEvent extends AppCartEvent {
  final String productId;
  final String? variationId;
  final int quantity;
  final Map<String, dynamic>? itemData;

  AppCartItemAddedEvent({
    required this.productId,
    this.variationId,
    required this.quantity,
    this.itemData,
    super.timestamp,
    super.metadata,
  });
}

/// Fired when an item is removed from the cart
class AppCartItemRemovedEvent extends AppCartEvent {
  final String itemId;
  final String productId;
  final int previousQuantity;

  AppCartItemRemovedEvent({
    required this.itemId,
    required this.productId,
    required this.previousQuantity,
    super.timestamp,
    super.metadata,
  });
}

/// Fired when cart item quantity is updated
class AppCartItemQuantityUpdatedEvent extends AppCartEvent {
  final String itemId;
  final String productId;
  final int oldQuantity;
  final int newQuantity;

  AppCartItemQuantityUpdatedEvent({
    required this.itemId,
    required this.productId,
    required this.oldQuantity,
    required this.newQuantity,
    super.timestamp,
    super.metadata,
  });
}

/// Fired when the entire cart is cleared
class AppCartClearedEvent extends AppCartEvent {
  final int itemCount;
  final double totalValue;

  AppCartClearedEvent({
    required this.itemCount,
    required this.totalValue,
    super.timestamp,
    super.metadata,
  });
}

/// Fired when a coupon is applied to the cart
class AppCartCouponAppliedEvent extends AppCartEvent {
  final String couponCode;
  final double discountAmount;

  AppCartCouponAppliedEvent({
    required this.couponCode,
    required this.discountAmount,
    super.timestamp,
    super.metadata,
  });
}

// ============================================================================
// Order Events
// ============================================================================

/// Base class for all order-related events
abstract class AppOrderEvent extends Event {
  AppOrderEvent({super.timestamp, super.metadata});
}

/// Fired when an order is created
class AppOrderCreatedEvent extends AppOrderEvent {
  final String orderId;
  final double total;
  final int itemCount;
  final Map<String, dynamic>? orderData;

  AppOrderCreatedEvent({
    required this.orderId,
    required this.total,
    required this.itemCount,
    this.orderData,
    super.timestamp,
    super.metadata,
  });
}

/// Fired when order status changes
class AppOrderStatusChangedEvent extends AppOrderEvent {
  final String orderId;
  final String oldStatus;
  final String newStatus;

  AppOrderStatusChangedEvent({
    required this.orderId,
    required this.oldStatus,
    required this.newStatus,
    super.timestamp,
    super.metadata,
  });
}

/// Fired when payment is completed
class AppPaymentCompletedEvent extends AppOrderEvent {
  final String orderId;
  final String paymentId;
  final double amount;
  final String paymentMethod;

  AppPaymentCompletedEvent({
    required this.orderId,
    required this.paymentId,
    required this.amount,
    required this.paymentMethod,
    super.timestamp,
    super.metadata,
  });
}

// ============================================================================
// Product Events
// ============================================================================

/// Base class for all product-related events
abstract class AppProductEvent extends Event {
  AppProductEvent({super.timestamp, super.metadata});
}

/// Fired when a product is viewed
class AppProductViewedEvent extends AppProductEvent {
  final String productId;
  final String productName;
  final double? price;

  AppProductViewedEvent({
    required this.productId,
    required this.productName,
    this.price,
    super.timestamp,
    super.metadata,
  });
}

/// Fired when a product is searched
class AppProductSearchedEvent extends AppProductEvent {
  final String searchQuery;
  final int resultCount;
  final List<String>? productIds;

  AppProductSearchedEvent({
    required this.searchQuery,
    required this.resultCount,
    this.productIds,
    super.timestamp,
    super.metadata,
  });
}

/// Fired when a product review is submitted
class AppProductReviewedEvent extends AppProductEvent {
  final String productId;
  final String reviewId;
  final double rating;
  final String? comment;

  AppProductReviewedEvent({
    required this.productId,
    required this.reviewId,
    required this.rating,
    this.comment,
    super.timestamp,
    super.metadata,
  });
}

// ============================================================================
// Navigation Events
// ============================================================================

/// Base class for all navigation-related events
abstract class AppNavigationEvent extends Event {
  AppNavigationEvent({super.timestamp, super.metadata});
}

/// Fired when user navigates to a new screen/page
class AppScreenViewedEvent extends AppNavigationEvent {
  final String screenName;
  final String? previousScreen;
  final Map<String, dynamic>? parameters;

  AppScreenViewedEvent({
    required this.screenName,
    this.previousScreen,
    this.parameters,
    super.timestamp,
    super.metadata,
  });
}

// ============================================================================
// Error Events
// ============================================================================

/// Base class for all error-related events
abstract class AppErrorEvent extends Event {
  AppErrorEvent({super.timestamp, super.metadata});
}

/// Fired when an error occurs in the application
class AppApplicationErrorEvent extends AppErrorEvent {
  final String errorMessage;
  final String? errorCode;
  final Object? error;
  final StackTrace? stackTrace;
  final String? context;

  AppApplicationErrorEvent({
    required this.errorMessage,
    this.errorCode,
    this.error,
    this.stackTrace,
    this.context,
    super.timestamp,
    super.metadata,
  });
}

/// Fired when an API call fails
class AppApiErrorEvent extends AppErrorEvent {
  final String endpoint;
  final int? statusCode;
  final String errorMessage;
  final Map<String, dynamic>? requestData;

  AppApiErrorEvent({
    required this.endpoint,
    this.statusCode,
    required this.errorMessage,
    this.requestData,
    super.timestamp,
    super.metadata,
  });
}

// ============================================================================
// Analytics Events
// ============================================================================

/// Base class for all analytics-related events
abstract class AppAnalyticsEvent extends Event {
  AppAnalyticsEvent({super.timestamp, super.metadata});
}

/// Generic analytics tracking event
class AppTrackingEvent extends AppAnalyticsEvent {
  final String eventName;
  final Map<String, dynamic>? properties;

  AppTrackingEvent({
    required this.eventName,
    this.properties,
    super.timestamp,
    super.metadata,
  });
}

// ============================================================================
// Notification Events
// ============================================================================

/// Base class for all notification-related events
abstract class AppNotificationEvent extends Event {
  AppNotificationEvent({super.timestamp, super.metadata});
}

/// Fired when a notification is received
class AppNotificationReceivedEvent extends AppNotificationEvent {
  final String notificationId;
  final String title;
  final String? body;
  final Map<String, dynamic>? data;

  AppNotificationReceivedEvent({
    required this.notificationId,
    required this.title,
    this.body,
    this.data,
    super.timestamp,
    super.metadata,
  });
}

/// Fired when a notification is tapped
class AppNotificationTappedEvent extends AppNotificationEvent {
  final String notificationId;
  final Map<String, dynamic>? data;

  AppNotificationTappedEvent({
    required this.notificationId,
    this.data,
    super.timestamp,
    super.metadata,
  });
}
