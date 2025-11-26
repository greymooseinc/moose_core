import 'package:flutter/material.dart';
import 'package:moose_core/entities.dart';
import 'package:moose_core/src/entities/core_entity.dart';

@immutable
class CheckoutRequest extends CoreEntity {
  final String cartId;
  final Address? billingAddress;
  final Address? shippingAddress;
  final String? shippingMethodId;
  final String? paymentMethodId;
  final String? customerNote;
  final List<String>? couponCodes;

  const CheckoutRequest({
    required this.cartId,
    this.billingAddress,
    this.shippingAddress,
    this.shippingMethodId,
    this.paymentMethodId,
    this.customerNote,
    this.couponCodes,
    super.extensions,
  });

  CheckoutRequest copyWith({
    String? cartId,
    Address? billingAddress,
    Address? shippingAddress,
    String? shippingMethodId,
    String? paymentMethodId,
    String? customerNote,
    List<String>? couponCodes,
    Map<String, dynamic>? extensions,
  }) {
    return CheckoutRequest(
      cartId: cartId ?? this.cartId,
      billingAddress: billingAddress ?? this.billingAddress,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      shippingMethodId: shippingMethodId ?? this.shippingMethodId,
      paymentMethodId: paymentMethodId ?? this.paymentMethodId,
      customerNote: customerNote ?? this.customerNote,
      couponCodes: couponCodes ?? this.couponCodes,
      extensions: extensions ?? this.extensions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cart_id': cartId,
      'billing_address': billingAddress?.toJson(),
      'shipping_address': shippingAddress?.toJson(),
      'shipping_method_id': shippingMethodId,
      'payment_method_id': paymentMethodId,
      'customer_note': customerNote,
      'coupon_codes': couponCodes,
      'extensions': extensions,
    };
  }

  factory CheckoutRequest.fromJson(Map<String, dynamic> json) {
    return CheckoutRequest(
      cartId: json['cart_id'] ?? '',
      billingAddress: json['billing_address'] != null
          ? Address.fromJson(json['billing_address'] as Map<String, dynamic>)
          : null,
      shippingAddress: json['shipping_address'] != null
          ? Address.fromJson(json['shipping_address'] as Map<String, dynamic>)
          : null,
      shippingMethodId: json['shipping_method_id'],
      paymentMethodId: json['payment_method_id'],
      customerNote: json['customer_note'],
      couponCodes: (json['coupon_codes'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      extensions: json['extensions'] as Map<String, dynamic>?,
    );
  }

  @override
  List<Object?> get props => [
        cartId,
        billingAddress,
        shippingAddress,
        shippingMethodId,
        paymentMethodId,
      ];
}

class PaymentMethod extends CoreEntity {
  final String id;
  final String title;
  final String description;
  final bool enabled;
  final int order;
  final Map<String, dynamic>? settings;

  /// Optional addon widget key to display when this method is selected
  /// Example: 'stripe.card_form', 'paypal.redirect_info'
  /// The addon will be loaded from WidgetRegistry when method is selected
  final String? addonKey;

  const PaymentMethod({
    required this.id,
    required this.title,
    required this.description,
    this.enabled = true,
    this.order = 0,
    this.settings,
    this.addonKey,
    super.extensions
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'enabled': enabled,
      'order': order,
      'settings': settings,
      'addon_key': addonKey,
    };
  }

  factory PaymentMethod.fromJson(Map<String, dynamic> json) {
    return PaymentMethod(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      enabled: json['enabled'] ?? true,
      order: json['order'] ?? 0,
      settings: json['settings'] as Map<String, dynamic>?,
      addonKey: json['addon_key'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, title, enabled, order, addonKey];
}

/// DeliveryMethod represents a method of delivering products to the customer.
/// This can be traditional shipping (FedEx, UPS, USPS), local delivery,
/// pickup, digital delivery, or any custom delivery method.
class DeliveryMethod extends CoreEntity {
  final String id;
  final String title;
  final String description;
  final double cost;
  final String? taxStatus;
  final bool enabled;
  final int order;
  final Map<String, dynamic>? settings;

  /// Optional addon widget key to display when this method is selected
  /// Example: 'fedex.delivery_window', 'pickup.location_selector'
  /// The addon will be loaded from WidgetRegistry when method is selected
  final String? addonKey;

  const DeliveryMethod({
    required this.id,
    required this.title,
    required this.description,
    required this.cost,
    this.taxStatus,
    this.enabled = true,
    this.order = 0,
    this.settings,
    this.addonKey,
    super.extensions
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'cost': cost,
      'tax_status': taxStatus,
      'enabled': enabled,
      'order': order,
      'settings': settings,
      'addon_key': addonKey,
    };
  }

  factory DeliveryMethod.fromJson(Map<String, dynamic> json) {
    return DeliveryMethod(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      cost: (json['cost'] is String)
          ? double.tryParse(json['cost']) ?? 0.0
          : (json['cost'] as num?)?.toDouble() ?? 0.0,
      taxStatus: json['tax_status'],
      enabled: json['enabled'] ?? true,
      order: json['order'] ?? 0,
      settings: json['settings'] as Map<String, dynamic>?,
      addonKey: json['addon_key'] as String?,
    );
  }

  @override
  List<Object?> get props => [id, title, cost, enabled, order, addonKey];
}

/// @deprecated Use DeliveryMethod instead. Will be removed in future versions.
/// This alias is provided for backward compatibility.
typedef ShippingMethod = DeliveryMethod;

/// @deprecated Use Address instead. Will be removed in future versions.
/// This alias is provided for backward compatibility.
typedef BillingAddress = Address;

/// @deprecated Use Address instead. Will be removed in future versions.
/// This alias is provided for backward compatibility.
typedef ShippingAddress = Address;
