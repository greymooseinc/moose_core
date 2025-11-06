import 'package:equatable/equatable.dart';

class CartItem extends Equatable {
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
  final Map<String, dynamic>? extensions;

  const CartItem({
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
    this.extensions,
  });

  CartItem copyWith({
    String? id,
    String? productId,
    String? variationId,
    String? name,
    String? sku,
    int? quantity,
    double? price,
    double? subtotal,
    double? total,
    String? imageUrl,
    Map<String, dynamic>? variationAttributes,
    Map<String, dynamic>? extensions,
  }) {
    return CartItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      variationId: variationId ?? this.variationId,
      name: name ?? this.name,
      sku: sku ?? this.sku,
      quantity: quantity ?? this.quantity,
      price: price ?? this.price,
      subtotal: subtotal ?? this.subtotal,
      total: total ?? this.total,
      imageUrl: imageUrl ?? this.imageUrl,
      variationAttributes: variationAttributes ?? this.variationAttributes,
      extensions: extensions ?? this.extensions,
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

  factory CartItem.fromJson(Map<String, dynamic> json) {
    return CartItem(
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

  @override
  String toString() {
    return 'CartItem(id: $id, productId: $productId, quantity: $quantity, total: \$$total)';
  }
}
