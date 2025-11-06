import 'package:flutter/material.dart';

import 'cart_item.dart';
import 'checkout.dart';
import 'core_entity.dart';

/// Represents a customer order.
///
/// Contains order details including status, line items, pricing,
/// billing/shipping addresses, and payment information.
@immutable
class Order extends CoreEntity {
  final String id;
  final String orderNumber;
  final String status;
  final String currency;
  final DateTime dateCreated;
  final DateTime? datePaid;
  final DateTime? dateCompleted;
  final double subtotal;
  final double tax;
  final double shipping;
  final double discount;
  final double total;
  final List<OrderLineItem> lineItems;
  final BillingAddress billingAddress;
  final ShippingAddress shippingAddress;
  final String? paymentMethod;
  final String? paymentMethodTitle;
  final String? shippingMethod;
  final String? shippingMethodTitle;
  final String? transactionId;
  final String? customerNote;

  const Order({
    required this.id,
    required this.orderNumber,
    required this.status,
    this.currency = 'USD',
    required this.dateCreated,
    this.datePaid,
    this.dateCompleted,
    required this.subtotal,
    this.tax = 0.0,
    this.shipping = 0.0,
    this.discount = 0.0,
    required this.total,
    required this.lineItems,
    required this.billingAddress,
    required this.shippingAddress,
    this.paymentMethod,
    this.paymentMethodTitle,
    this.shippingMethod,
    this.shippingMethodTitle,
    this.transactionId,
    this.customerNote,
    super.extensions,
  });

  bool get isPaid => datePaid != null;

  bool get isCompleted => status == 'completed';

  bool get isPending => status == 'pending';

  bool get isProcessing => status == 'processing';

  bool get isCancelled => status == 'cancelled';

  bool get isRefunded => status == 'refunded';

  bool get isFailed => status == 'failed';

  Order copyWith({
    String? id,
    String? orderNumber,
    String? status,
    String? currency,
    DateTime? dateCreated,
    DateTime? datePaid,
    DateTime? dateCompleted,
    double? subtotal,
    double? tax,
    double? shipping,
    double? discount,
    double? total,
    List<OrderLineItem>? lineItems,
    BillingAddress? billingAddress,
    ShippingAddress? shippingAddress,
    String? paymentMethod,
    String? paymentMethodTitle,
    String? shippingMethod,
    String? shippingMethodTitle,
    String? transactionId,
    String? customerNote,
    Map<String, dynamic>? extensions,
  }) {
    return Order(
      id: id ?? this.id,
      orderNumber: orderNumber ?? this.orderNumber,
      status: status ?? this.status,
      currency: currency ?? this.currency,
      dateCreated: dateCreated ?? this.dateCreated,
      datePaid: datePaid ?? this.datePaid,
      dateCompleted: dateCompleted ?? this.dateCompleted,
      subtotal: subtotal ?? this.subtotal,
      tax: tax ?? this.tax,
      shipping: shipping ?? this.shipping,
      discount: discount ?? this.discount,
      total: total ?? this.total,
      lineItems: lineItems ?? this.lineItems,
      billingAddress: billingAddress ?? this.billingAddress,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      paymentMethodTitle: paymentMethodTitle ?? this.paymentMethodTitle,
      shippingMethod: shippingMethod ?? this.shippingMethod,
      shippingMethodTitle: shippingMethodTitle ?? this.shippingMethodTitle,
      transactionId: transactionId ?? this.transactionId,
      customerNote: customerNote ?? this.customerNote,
      extensions: extensions ?? super.extensions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'order_number': orderNumber,
      'status': status,
      'currency': currency,
      'date_created': dateCreated.toIso8601String(),
      'date_paid': datePaid?.toIso8601String(),
      'date_completed': dateCompleted?.toIso8601String(),
      'subtotal': subtotal,
      'tax': tax,
      'shipping': shipping,
      'discount': discount,
      'total': total,
      'line_items': lineItems.map((item) => item.toJson()).toList(),
      'billing_address': billingAddress.toJson(),
      'shipping_address': shippingAddress.toJson(),
      'payment_method': paymentMethod,
      'payment_method_title': paymentMethodTitle,
      'shipping_method': shippingMethod,
      'shipping_method_title': shippingMethodTitle,
      'transaction_id': transactionId,
      'customer_note': customerNote,
      'extensions': extensions,
    };
  }

  factory Order.fromJson(Map<String, dynamic> json) {
    return Order(
      id: json['id']?.toString() ?? '',
      orderNumber: json['order_number'] ?? json['id']?.toString() ?? '',
      status: json['status'] ?? 'pending',
      currency: json['currency'] ?? 'USD',
      dateCreated: json['date_created'] != null
          ? DateTime.parse(json['date_created'])
          : DateTime.now(),
      datePaid: json['date_paid'] != null
          ? DateTime.parse(json['date_paid'])
          : null,
      dateCompleted: json['date_completed'] != null
          ? DateTime.parse(json['date_completed'])
          : null,
      subtotal: (json['subtotal'] is String)
          ? double.tryParse(json['subtotal']) ?? 0.0
          : (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      tax: (json['tax'] is String)
          ? double.tryParse(json['tax']) ?? 0.0
          : (json['tax'] as num?)?.toDouble() ?? 0.0,
      shipping: (json['shipping'] is String)
          ? double.tryParse(json['shipping']) ?? 0.0
          : (json['shipping'] as num?)?.toDouble() ?? 0.0,
      discount: (json['discount'] is String)
          ? double.tryParse(json['discount']) ?? 0.0
          : (json['discount'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] is String)
          ? double.tryParse(json['total']) ?? 0.0
          : (json['total'] as num?)?.toDouble() ?? 0.0,
      lineItems: (json['line_items'] as List<dynamic>?)
              ?.map((item) =>
                  OrderLineItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      billingAddress: BillingAddress.fromJson(
          json['billing_address'] as Map<String, dynamic>),
      shippingAddress: ShippingAddress.fromJson(
          json['shipping_address'] as Map<String, dynamic>),
      paymentMethod: json['payment_method'],
      paymentMethodTitle: json['payment_method_title'],
      shippingMethod: json['shipping_method'],
      shippingMethodTitle: json['shipping_method_title'],
      transactionId: json['transaction_id'],
      customerNote: json['customer_note'],
      extensions: json['extensions'] as Map<String, dynamic>?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        orderNumber,
        status,
        total,
        dateCreated,
      ];

  @override
  String toString() {
    return 'Order(id: $id, orderNumber: $orderNumber, status: $status, total: \$$total)';
  }
}

@immutable
class OrderLineItem extends CoreEntity {
  final String id;
  final String productId;
  final String? variationId;
  final String name;
  final String? sku;
  final int quantity;
  final double price;
  final double subtotal;
  final double total;
  final String? imageUrl;
  final Map<String, dynamic>? variationAttributes;

  const OrderLineItem({
    required this.id,
    required this.productId,
    this.variationId,
    required this.name,
    this.sku,
    required this.quantity,
    required this.price,
    required this.subtotal,
    required this.total,
    this.imageUrl,
    this.variationAttributes,
    super.extensions,
  });

  factory OrderLineItem.fromCartItem(CartItem item) {
    return OrderLineItem(
      id: item.id,
      productId: item.productId,
      variationId: item.variationId,
      name: item.name,
      sku: item.sku,
      quantity: item.quantity,
      price: item.price,
      subtotal: item.subtotal,
      total: item.total,
      imageUrl: item.imageUrl,
      variationAttributes: item.variationAttributes,
      extensions: item.extensions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'variation_id': variationId,
      'name': name,
      'sku': sku,
      'quantity': quantity,
      'price': price,
      'subtotal': subtotal,
      'total': total,
      'image_url': imageUrl,
      'variation_attributes': variationAttributes,
      'extensions': extensions,
    };
  }

  factory OrderLineItem.fromJson(Map<String, dynamic> json) {
    return OrderLineItem(
      id: json['id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      variationId: json['variation_id']?.toString(),
      name: json['name'] ?? '',
      sku: json['sku'],
      quantity: json['quantity'] ?? 1,
      price: (json['price'] is String)
          ? double.tryParse(json['price']) ?? 0.0
          : (json['price'] as num?)?.toDouble() ?? 0.0,
      subtotal: (json['subtotal'] is String)
          ? double.tryParse(json['subtotal']) ?? 0.0
          : (json['subtotal'] as num?)?.toDouble() ?? 0.0,
      total: (json['total'] is String)
          ? double.tryParse(json['total']) ?? 0.0
          : (json['total'] as num?)?.toDouble() ?? 0.0,
      imageUrl: json['image_url'],
      variationAttributes: json['variation_attributes'] as Map<String, dynamic>?,
      extensions: json['extensions'] as Map<String, dynamic>?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        productId,
        variationId,
        quantity,
        price,
        total,
      ];
}
