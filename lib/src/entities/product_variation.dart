import 'package:equatable/equatable.dart';

class ProductVariation extends Equatable {
  final String id;
  final String productId;
  final String? sku;
  final double price;
  final double? regularPrice;
  final double? salePrice;
  final bool onSale;
  final String? image;
  final bool inStock;
  final int stockQuantity;
  final String stockStatus;
  final Map<String, String> attributes;
  final Map<String, dynamic>? metadata;

  const ProductVariation({
    required this.id,
    required this.productId,
    this.sku,
    required this.price,
    this.regularPrice,
    this.salePrice,
    this.onSale = false,
    this.image,
    required this.inStock,
    required this.stockQuantity,
    this.stockStatus = 'instock',
    required this.attributes,
    this.metadata,
  });

  ProductVariation copyWith({
    String? id,
    String? productId,
    String? sku,
    double? price,
    double? regularPrice,
    double? salePrice,
    bool? onSale,
    String? image,
    bool? inStock,
    int? stockQuantity,
    String? stockStatus,
    Map<String, String>? attributes,
    Map<String, dynamic>? metadata,
  }) {
    return ProductVariation(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      sku: sku ?? this.sku,
      price: price ?? this.price,
      regularPrice: regularPrice ?? this.regularPrice,
      salePrice: salePrice ?? this.salePrice,
      onSale: onSale ?? this.onSale,
      image: image ?? this.image,
      inStock: inStock ?? this.inStock,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      stockStatus: stockStatus ?? this.stockStatus,
      attributes: attributes ?? this.attributes,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'sku': sku,
      'price': price,
      'regular_price': regularPrice,
      'sale_price': salePrice,
      'on_sale': onSale,
      'image': image,
      'in_stock': inStock,
      'stock_quantity': stockQuantity,
      'stock_status': stockStatus,
      'attributes': attributes,
      'metadata': metadata,
    };
  }

  factory ProductVariation.fromJson(Map<String, dynamic> json) {
    return ProductVariation(
      id: json['id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      sku: json['sku'],
      price: (json['price'] is String)
          ? double.tryParse(json['price']) ?? 0.0
          : (json['price'] as num?)?.toDouble() ?? 0.0,
      regularPrice: json['regular_price'] != null
          ? (json['regular_price'] is String
              ? double.tryParse(json['regular_price'])
              : (json['regular_price'] as num?)?.toDouble())
          : null,
      salePrice: json['sale_price'] != null
          ? (json['sale_price'] is String
              ? double.tryParse(json['sale_price'])
              : (json['sale_price'] as num?)?.toDouble())
          : null,
      onSale: json['on_sale'] ?? false,
      image: json['image'],
      inStock: json['in_stock'] ?? true,
      stockQuantity: json['stock_quantity'] ?? 0,
      stockStatus: json['stock_status'] ?? 'instock',
      attributes: Map<String, String>.from(json['attributes'] ?? {}),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  List<Object?> get props => [id, productId, attributes, price];

  @override
  String toString() => 'ProductVariation(id: $id, attributes: $attributes, price: \$$price)';
}