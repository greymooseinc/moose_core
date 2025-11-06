import 'cart_item.dart';
import 'package:equatable/equatable.dart';

class Cart extends Equatable {
  final String id;
  final List<CartItem> items;
  final double subtotal;
  final double tax;
  final double shipping;
  final double discount;
  final double total;
  final String currency;
  final List<AppliedCoupon>? appliedCoupons;
  final ShippingInfo? shippingInfo;
  final Map<String, dynamic>? extensions;

  const Cart({
    required this.id,
    required this.items,
    required this.subtotal,
    this.tax = 0.0,
    this.shipping = 0.0,
    this.discount = 0.0,
    required this.total,
    this.currency = 'USD',
    this.appliedCoupons,
    this.shippingInfo,
    this.extensions,
  });

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  bool get isEmpty => items.isEmpty;

  bool get isNotEmpty => items.isNotEmpty;

  Cart copyWith({
    String? id,
    List<CartItem>? items,
    double? subtotal,
    double? tax,
    double? shipping,
    double? discount,
    double? total,
    String? currency,
    List<AppliedCoupon>? appliedCoupons,
    ShippingInfo? shippingInfo,
    Map<String, dynamic>? extensions,
  }) {
    return Cart(
      id: id ?? this.id,
      items: items ?? this.items,
      subtotal: subtotal ?? this.subtotal,
      tax: tax ?? this.tax,
      shipping: shipping ?? this.shipping,
      discount: discount ?? this.discount,
      total: total ?? this.total,
      currency: currency ?? this.currency,
      appliedCoupons: appliedCoupons ?? this.appliedCoupons,
      shippingInfo: shippingInfo ?? this.shippingInfo,
      extensions: extensions ?? this.extensions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'items': items.map((item) => item.toJson()).toList(),
      'subtotal': subtotal,
      'tax': tax,
      'shipping': shipping,
      'discount': discount,
      'total': total,
      'currency': currency,
      'applied_coupons': appliedCoupons?.map((c) => c.toJson()).toList(),
      'shipping_info': shippingInfo?.toJson(),
      'extensions': extensions,
    };
  }

  factory Cart.fromJson(Map<String, dynamic> json) {
    return Cart(
      id: json['id']?.toString() ?? '',
      items: (json['items'] as List<dynamic>?)
              ?.map((item) => CartItem.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
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
      currency: json['currency'] ?? 'USD',
      appliedCoupons: (json['applied_coupons'] as List<dynamic>?)
          ?.map((c) => AppliedCoupon.fromJson(c as Map<String, dynamic>))
          .toList(),
      shippingInfo: json['shipping_info'] != null
          ? ShippingInfo.fromJson(json['shipping_info'] as Map<String, dynamic>)
          : null,
      extensions: json['extensions'] as Map<String, dynamic>?,
    );
  }

  factory Cart.empty() {
    return const Cart(
      id: '',
      items: [],
      subtotal: 0.0,
      tax: 0.0,
      shipping: 0.0,
      discount: 0.0,
      total: 0.0,
    );
  }

  @override
  List<Object?> get props => [
        id,
        items,
        subtotal,
        tax,
        shipping,
        discount,
        total,
        currency,
      ];

  @override
  String toString() {
    return 'Cart(id: $id, items: ${items.length}, total: \$$total)';
  }
}

class AppliedCoupon extends Equatable {
  final String code;
  final double discountAmount;
  final String discountType;
  final String? description;

  const AppliedCoupon({
    required this.code,
    required this.discountAmount,
    required this.discountType,
    this.description,
  });

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'discount_amount': discountAmount,
      'discount_type': discountType,
      'description': description,
    };
  }

  factory AppliedCoupon.fromJson(Map<String, dynamic> json) {
    return AppliedCoupon(
      code: json['code'] ?? '',
      discountAmount: (json['discount_amount'] is String)
          ? double.tryParse(json['discount_amount']) ?? 0.0
          : (json['discount_amount'] as num?)?.toDouble() ?? 0.0,
      discountType: json['discount_type'] ?? 'fixed',
      description: json['description'],
    );
  }

  @override
  List<Object?> get props => [code, discountAmount, discountType];
}

class ShippingInfo extends Equatable {
  final String? methodId;
  final String? methodTitle;
  final double cost;
  final Map<String, dynamic>? details;

  const ShippingInfo({
    this.methodId,
    this.methodTitle,
    required this.cost,
    this.details,
  });

  Map<String, dynamic> toJson() {
    return {
      'method_id': methodId,
      'method_title': methodTitle,
      'cost': cost,
      'details': details,
    };
  }

  factory ShippingInfo.fromJson(Map<String, dynamic> json) {
    return ShippingInfo(
      methodId: json['method_id'],
      methodTitle: json['method_title'],
      cost: (json['cost'] is String)
          ? double.tryParse(json['cost']) ?? 0.0
          : (json['cost'] as num?)?.toDouble() ?? 0.0,
      details: json['details'] as Map<String, dynamic>?,
    );
  }

  @override
  List<Object?> get props => [methodId, methodTitle, cost];
}
