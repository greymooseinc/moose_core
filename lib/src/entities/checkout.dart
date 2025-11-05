import 'package:equatable/equatable.dart';

class CheckoutRequest extends Equatable {
  final String cartId;
  final BillingAddress billingAddress;
  final ShippingAddress shippingAddress;
  final String? shippingMethodId;
  final String? paymentMethodId;
  final String? customerNote;
  final List<String>? couponCodes;
  final Map<String, dynamic>? metadata;

  const CheckoutRequest({
    required this.cartId,
    required this.billingAddress,
    required this.shippingAddress,
    this.shippingMethodId,
    this.paymentMethodId,
    this.customerNote,
    this.couponCodes,
    this.metadata,
  });

  CheckoutRequest copyWith({
    String? cartId,
    BillingAddress? billingAddress,
    ShippingAddress? shippingAddress,
    String? shippingMethodId,
    String? paymentMethodId,
    String? customerNote,
    List<String>? couponCodes,
    Map<String, dynamic>? metadata,
  }) {
    return CheckoutRequest(
      cartId: cartId ?? this.cartId,
      billingAddress: billingAddress ?? this.billingAddress,
      shippingAddress: shippingAddress ?? this.shippingAddress,
      shippingMethodId: shippingMethodId ?? this.shippingMethodId,
      paymentMethodId: paymentMethodId ?? this.paymentMethodId,
      customerNote: customerNote ?? this.customerNote,
      couponCodes: couponCodes ?? this.couponCodes,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'cart_id': cartId,
      'billing_address': billingAddress.toJson(),
      'shipping_address': shippingAddress.toJson(),
      'shipping_method_id': shippingMethodId,
      'payment_method_id': paymentMethodId,
      'customer_note': customerNote,
      'coupon_codes': couponCodes,
      'metadata': metadata,
    };
  }

  factory CheckoutRequest.fromJson(Map<String, dynamic> json) {
    return CheckoutRequest(
      cartId: json['cart_id'] ?? '',
      billingAddress: BillingAddress.fromJson(
          json['billing_address'] as Map<String, dynamic>),
      shippingAddress: ShippingAddress.fromJson(
          json['shipping_address'] as Map<String, dynamic>),
      shippingMethodId: json['shipping_method_id'],
      paymentMethodId: json['payment_method_id'],
      customerNote: json['customer_note'],
      couponCodes: (json['coupon_codes'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      metadata: json['metadata'] as Map<String, dynamic>?,
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

class BillingAddress extends Equatable {
  final String firstName;
  final String lastName;
  final String? company;
  final String address1;
  final String? address2;
  final String city;
  final String state;
  final String postcode;
  final String country;
  final String email;
  final String phone;

  const BillingAddress({
    required this.firstName,
    required this.lastName,
    this.company,
    required this.address1,
    this.address2,
    required this.city,
    required this.state,
    required this.postcode,
    required this.country,
    required this.email,
    required this.phone,
  });

  Map<String, dynamic> toJson() {
    return {
      'first_name': firstName,
      'last_name': lastName,
      'company': company,
      'address_1': address1,
      'address_2': address2,
      'city': city,
      'state': state,
      'postcode': postcode,
      'country': country,
      'email': email,
      'phone': phone,
    };
  }

  factory BillingAddress.fromJson(Map<String, dynamic> json) {
    return BillingAddress(
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      company: json['company'],
      address1: json['address_1'] ?? '',
      address2: json['address_2'],
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      postcode: json['postcode'] ?? '',
      country: json['country'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
    );
  }

  @override
  List<Object?> get props => [
        firstName,
        lastName,
        address1,
        city,
        state,
        postcode,
        country,
        email,
        phone,
      ];
}

class ShippingAddress extends Equatable {
  final String firstName;
  final String lastName;
  final String? company;
  final String address1;
  final String? address2;
  final String city;
  final String state;
  final String postcode;
  final String country;

  const ShippingAddress({
    required this.firstName,
    required this.lastName,
    this.company,
    required this.address1,
    this.address2,
    required this.city,
    required this.state,
    required this.postcode,
    required this.country,
  });

  Map<String, dynamic> toJson() {
    return {
      'first_name': firstName,
      'last_name': lastName,
      'company': company,
      'address_1': address1,
      'address_2': address2,
      'city': city,
      'state': state,
      'postcode': postcode,
      'country': country,
    };
  }

  factory ShippingAddress.fromJson(Map<String, dynamic> json) {
    return ShippingAddress(
      firstName: json['first_name'] ?? '',
      lastName: json['last_name'] ?? '',
      company: json['company'],
      address1: json['address_1'] ?? '',
      address2: json['address_2'],
      city: json['city'] ?? '',
      state: json['state'] ?? '',
      postcode: json['postcode'] ?? '',
      country: json['country'] ?? '',
    );
  }

  @override
  List<Object?> get props => [
        firstName,
        lastName,
        address1,
        city,
        state,
        postcode,
        country,
      ];
}

class PaymentMethod extends Equatable {
  final String id;
  final String title;
  final String description;
  final bool enabled;
  final int order;
  final Map<String, dynamic>? settings;

  const PaymentMethod({
    required this.id,
    required this.title,
    required this.description,
    this.enabled = true,
    this.order = 0,
    this.settings,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'enabled': enabled,
      'order': order,
      'settings': settings,
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
    );
  }

  @override
  List<Object?> get props => [id, title, enabled, order];
}

class ShippingMethod extends Equatable {
  final String id;
  final String title;
  final String description;
  final double cost;
  final String? taxStatus;
  final bool enabled;
  final Map<String, dynamic>? settings;

  const ShippingMethod({
    required this.id,
    required this.title,
    required this.description,
    required this.cost,
    this.taxStatus,
    this.enabled = true,
    this.settings,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'cost': cost,
      'tax_status': taxStatus,
      'enabled': enabled,
      'settings': settings,
    };
  }

  factory ShippingMethod.fromJson(Map<String, dynamic> json) {
    return ShippingMethod(
      id: json['id'] ?? '',
      title: json['title'] ?? '',
      description: json['description'] ?? '',
      cost: (json['cost'] is String)
          ? double.tryParse(json['cost']) ?? 0.0
          : (json['cost'] as num?)?.toDouble() ?? 0.0,
      taxStatus: json['tax_status'],
      enabled: json['enabled'] ?? true,
      settings: json['settings'] as Map<String, dynamic>?,
    );
  }

  @override
  List<Object?> get props => [id, title, cost, enabled];
}
