import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import 'cart_item.dart';
import 'core_entity.dart';

/// Represents an amount line item in the cart (shipping, tax, discount, etc.)
@immutable
class CartAmount extends Equatable {
  final double amount;
  final String type;
  final String title;
  final String? subtitle;
  final bool isDeduction;

  const CartAmount({
    required this.amount,
    required this.type,
    required this.title,
    this.subtitle,
    this.isDeduction = false,
  });

  Map<String, dynamic> toJson() {
    return {
      'amount': amount,
      'type': type,
      'title': title,
      'subtitle': subtitle,
      'is_deduction': isDeduction,
    };
  }

  factory CartAmount.fromJson(Map<String, dynamic> json) {
    return CartAmount(
      amount: (json['amount'] is String)
          ? double.tryParse(json['amount']) ?? 0.0
          : (json['amount'] as num?)?.toDouble() ?? 0.0,
      type: json['type'] ?? '',
      title: json['title'] ?? '',
      subtitle: json['subtitle'],
      isDeduction: json['is_deduction'] ?? false,
    );
  }

  @override
  List<Object?> get props => [amount, type, title, subtitle, isDeduction];
}

/// Represents a shopping cart.
///
/// Contains cart items, total amount, applied coupons, shipping information,
/// and a flexible list of amounts (fees, taxes, discounts, etc.).
@immutable
class Cart extends CoreEntity {
  final String id;
  final List<CartItem> items;
  final double total;
  final String currency;
  final List<AppliedCoupon>? appliedCoupons;
  final ShippingInfo? shippingInfo;
  final List<CartAmount> amounts;

  const Cart({
    required this.id,
    required this.items,
    required this.total,
    this.currency = 'USD',
    this.appliedCoupons,
    this.shippingInfo,
    this.amounts = const [],
    super.extensions,
  });

  int get itemCount => items.fold(0, (sum, item) => sum + item.quantity);

  bool get isEmpty => items.isEmpty;

  bool get isNotEmpty => items.isNotEmpty;

  Cart copyWith({
    String? id,
    List<CartItem>? items,
    double? total,
    String? currency,
    List<AppliedCoupon>? appliedCoupons,
    ShippingInfo? shippingInfo,
    List<CartAmount>? amounts,
    Map<String, dynamic>? extensions,
  }) {
    return Cart(
      id: id ?? this.id,
      items: items ?? this.items,
      total: total ?? this.total,
      currency: currency ?? this.currency,
      appliedCoupons: appliedCoupons ?? this.appliedCoupons,
      shippingInfo: shippingInfo ?? this.shippingInfo,
      amounts: amounts ?? this.amounts,
      extensions: extensions ?? this.extensions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'items': items.map((item) => item.toJson()).toList(),
      'total': total,
      'currency': currency,
      'applied_coupons': appliedCoupons?.map((c) => c.toJson()).toList(),
      'shipping_info': shippingInfo?.toJson(),
      'amounts': amounts.map((a) => a.toJson()).toList(),
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
      amounts: (json['amounts'] as List<dynamic>?)
              ?.map((a) => CartAmount.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
      extensions: json['extensions'] as Map<String, dynamic>?,
    );
  }

  factory Cart.empty() {
    return const Cart(
      id: '',
      items: [],
      total: 0.0,
    );
  }

  @override
  List<Object?> get props => [
        id,
        items,
        total,
        currency,
        amounts,
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
