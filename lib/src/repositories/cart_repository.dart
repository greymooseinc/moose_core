import 'package:moose_core/entities.dart';

import 'repository.dart';
import 'repository_options.dart';

abstract class CartRepository extends CoreRepository {

  Future<Cart> getCart({
    String? cartId,
    String? customerId,
    RepositoryOptions? options,
  });

  Future<Cart> createCart({
    String? customerId,
    RepositoryOptions? options,
  });

  Future<Cart> addItem({
    required String productId,
    String? variationId,
    int quantity = 1,
    Map<String, dynamic>? metadata,
    RepositoryOptions? options,
  });

  Future<Cart> updateItemQuantity({
    required String itemId,
    required int quantity,
    RepositoryOptions? options,
  });

  Future<Cart> removeItem({
    required String itemId,
    RepositoryOptions? options,
  });

  Future<Cart> clearCart({RepositoryOptions? options});

  Future<Cart> applyCoupon({
    required String couponCode,
    RepositoryOptions? options,
  });

  Future<Cart> removeCoupon({
    required String couponCode,
    RepositoryOptions? options,
  });

  Future<Cart> calculateTotals({
    String? shippingMethodId,
    Address? shippingAddress,
    RepositoryOptions? options,
  });

  Future<Cart> setShippingMethod({
    required String shippingMethodId,
    RepositoryOptions? options,
  });

  /// Get available shipping methods based on shipping address
  Future<List<ShippingMethod>> getShippingMethods({
    required Address shippingAddress,
    RepositoryOptions? options,
  });

  /// Get available payment methods
  Future<List<PaymentMethod>> getPaymentMethods({RepositoryOptions? options});

  Future<CartValidationResult> validateCart({RepositoryOptions? options});

  Future<CheckoutResult> checkout({
    required CheckoutRequest checkoutRequest,
    RepositoryOptions? options,
  });

  Future<Order> getOrder({
    required String orderId,
    RepositoryOptions? options,
  });

  Future<List<Order>> getCustomerOrders({
    required String customerId,
    int page = 1,
    int perPage = 10,
    String? status,
    RepositoryOptions? options,
  });

  Future<Order> updateOrderStatus({
    required String orderId,
    required String status,
    RepositoryOptions? options,
  });

  Future<PaymentResult> processPayment({
    required String orderId,
    required String paymentMethodId,
    Map<String, dynamic>? paymentData,
    RepositoryOptions? options,
  });

  Future<PaymentStatus> verifyPayment({
    required String orderId,
    required String transactionId,
    RepositoryOptions? options,
  });

  Future<Order> cancelOrder({
    required String orderId,
    String? reason,
    RepositoryOptions? options,
  });

  Future<RefundResult> requestRefund({
    required String orderId,
    double? amount,
    String? reason,
    RepositoryOptions? options,
  });
}

class CartValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;
  final Map<String, dynamic>? metadata;

  const CartValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
    this.metadata,
  });

  factory CartValidationResult.valid() {
    return const CartValidationResult(isValid: true);
  }

  factory CartValidationResult.invalid(List<String> errors) {
    return CartValidationResult(
      isValid: false,
      errors: errors,
    );
  }
}

class CheckoutResult {
  final bool success;
  final Order? order;
  final String? errorMessage;
  final PaymentStatus? paymentStatus;
  final String? redirectUrl;
  final Map<String, dynamic>? metadata;

  const CheckoutResult({
    required this.success,
    this.order,
    this.errorMessage,
    this.paymentStatus,
    this.redirectUrl,
    this.metadata,
  });

  factory CheckoutResult.success({
    required Order order,
    PaymentStatus? paymentStatus,
    String? redirectUrl,
  }) {
    return CheckoutResult(
      success: true,
      order: order,
      paymentStatus: paymentStatus,
      redirectUrl: redirectUrl,
    );
  }

  factory CheckoutResult.failure(String errorMessage) {
    return CheckoutResult(
      success: false,
      errorMessage: errorMessage,
    );
  }
}

class PaymentResult {
  final bool success;
  final String? transactionId;
  final String? errorMessage;
  final PaymentStatus status;
  final Map<String, dynamic>? metadata;

  const PaymentResult({
    required this.success,
    this.transactionId,
    this.errorMessage,
    required this.status,
    this.metadata,
  });

  factory PaymentResult.success({
    required String transactionId,
    PaymentStatus status = PaymentStatus.completed,
  }) {
    return PaymentResult(
      success: true,
      transactionId: transactionId,
      status: status,
    );
  }

  factory PaymentResult.failure(String errorMessage) {
    return PaymentResult(
      success: false,
      errorMessage: errorMessage,
      status: PaymentStatus.failed,
    );
  }

  factory PaymentResult.pending({String? transactionId}) {
    return PaymentResult(
      success: true,
      transactionId: transactionId,
      status: PaymentStatus.pending,
    );
  }
}

enum PaymentStatus {
  pending,
  processing,
  completed,
  failed,
  cancelled,
  refunded,
}

class RefundResult {
  final bool success;
  final String? refundId;
  final double? refundedAmount;
  final String? errorMessage;
  final Map<String, dynamic>? metadata;

  const RefundResult({
    required this.success,
    this.refundId,
    this.refundedAmount,
    this.errorMessage,
    this.metadata,
  });

  factory RefundResult.success({
    required String refundId,
    required double refundedAmount,
  }) {
    return RefundResult(
      success: true,
      refundId: refundId,
      refundedAmount: refundedAmount,
    );
  }

  factory RefundResult.failure(String errorMessage) {
    return RefundResult(
      success: false,
      errorMessage: errorMessage,
    );
  }
}
