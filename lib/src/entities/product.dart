import 'package:flutter/material.dart';

import 'core_entity.dart';
import 'media_item.dart';
import 'product_attribute.dart';
import 'product_section.dart';
import 'product_variation.dart';

/// Represents a product in the ecommerce system.
///
/// Platform-agnostic product entity that adapters convert from
/// backend-specific formats (WooCommerce, Shopify, etc.). Supports
/// simple and variable products with attributes, variations, and sections.
@immutable
class Product extends CoreEntity {
  final String id;
  final String name;
  final List<ProductSection> sections;
  final double price;
  final double? regularPrice;
  final double? salePrice;
  final bool onSale;
  final String? sku;
  final List<MediaItem> media;
  final bool inStock;
  final int stockQuantity;
  final String stockStatus;
  final List<String> categories;
  final List<String> tags;
  final String type;
  final bool featured;
  final double? averageRating;
  final int? ratingCount;
  final String? permalink;
  final DateTime? dateCreated;
  final DateTime? dateModified;
  final List<ProductAttribute> attributes;
  final List<ProductVariation> variations;
  final Map<String, String> defaultAttributes;

  const Product({
    required this.id,
    required this.name,
    this.sections = const [],
    required this.price,
    this.regularPrice,
    this.salePrice,
    this.onSale = false,
    this.sku,
    required this.media,
    required this.inStock,
    required this.stockQuantity,
    this.stockStatus = 'instock',
    this.categories = const [],
    this.tags = const [],
    this.type = 'simple',
    this.featured = false,
    this.averageRating,
    this.ratingCount,
    this.permalink,
    this.dateCreated,
    this.dateModified,
    super.extensions,
    this.attributes = const [],
    this.variations = const [],
    this.defaultAttributes = const {},
  });

  Product copyWith({
    String? id,
    String? name,
    List<ProductSection>? sections,
    double? price,
    double? regularPrice,
    double? salePrice,
    bool? onSale,
    String? sku,
    List<MediaItem>? media,
    bool? inStock,
    int? stockQuantity,
    String? stockStatus,
    List<String>? categories,
    List<String>? tags,
    String? type,
    bool? featured,
    double? averageRating,
    int? ratingCount,
    String? permalink,
    DateTime? dateCreated,
    DateTime? dateModified,
    Map<String, dynamic>? extensions,
    List<ProductAttribute>? attributes,
    List<ProductVariation>? variations,
    Map<String, String>? defaultAttributes,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      sections: sections ?? this.sections,
      price: price ?? this.price,
      regularPrice: regularPrice ?? this.regularPrice,
      salePrice: salePrice ?? this.salePrice,
      onSale: onSale ?? this.onSale,
      sku: sku ?? this.sku,
      media: media ?? this.media,
      inStock: inStock ?? this.inStock,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      stockStatus: stockStatus ?? this.stockStatus,
      categories: categories ?? this.categories,
      tags: tags ?? this.tags,
      type: type ?? this.type,
      featured: featured ?? this.featured,
      averageRating: averageRating ?? this.averageRating,
      ratingCount: ratingCount ?? this.ratingCount,
      permalink: permalink ?? this.permalink,
      dateCreated: dateCreated ?? this.dateCreated,
      dateModified: dateModified ?? this.dateModified,
      extensions: extensions ?? this.extensions,
      attributes: attributes ?? this.attributes,
      variations: variations ?? this.variations,
      defaultAttributes: defaultAttributes ?? this.defaultAttributes,
    );
  }

  Product copyWithExtensions(Map<String, dynamic> newExtensions) {
    return Product(
      id: id,
      name: name,
      sections: sections,
      price: price,
      regularPrice: regularPrice,
      salePrice: salePrice,
      onSale: onSale,
      sku: sku,
      media: media,
      inStock: inStock,
      stockQuantity: stockQuantity,
      stockStatus: stockStatus,
      categories: categories,
      tags: tags,
      type: type,
      featured: featured,
      averageRating: averageRating,
      ratingCount: ratingCount,
      permalink: permalink,
      dateCreated: dateCreated,
      dateModified: dateModified,
      extensions: {
        ...?extensions,
        ...newExtensions,
      },
      attributes: attributes,
      variations: variations,
      defaultAttributes: defaultAttributes,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'sections': sections.map((s) => s.toJson()).toList(),
      'price': price,
      'regular_price': regularPrice,
      'sale_price': salePrice,
      'on_sale': onSale,
      'sku': sku,
      'media': media.map((m) => m.toJson()).toList(),
      'in_stock': inStock,
      'stock_quantity': stockQuantity,
      'stock_status': stockStatus,
      'categories': categories,
      'tags': tags,
      'type': type,
      'featured': featured,
      'average_rating': averageRating,
      'rating_count': ratingCount,
      'permalink': permalink,
      'date_created': dateCreated?.toIso8601String(),
      'date_modified': dateModified?.toIso8601String(),
      'extensions': extensions,
      'attributes': attributes.map((a) => a.toJson()).toList(),
      'variations': variations.map((v) => v.toJson()).toList(),
      'default_attributes': defaultAttributes,
    };
  }

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      sections: (json['sections'] as List<dynamic>?)
              ?.map((s) => ProductSection.fromJson(s as Map<String, dynamic>))
              .toList() ??
          [],
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
      sku: json['sku'],
      media: _parseMedia(json['media'], json['images']),
      inStock: json['in_stock'] ?? true,
      stockQuantity: json['stock_quantity'] ?? 0,
      stockStatus: json['stock_status'] ?? 'instock',
      categories: (json['categories'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      tags: (json['tags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      type: json['type'] ?? 'simple',
      featured: json['featured'] ?? false,
      averageRating: json['average_rating'] != null
          ? (json['average_rating'] is String
              ? double.tryParse(json['average_rating'])
              : (json['average_rating'] as num?)?.toDouble())
          : null,
      ratingCount: json['rating_count'],
      permalink: json['permalink'],
      dateCreated: json['date_created'] != null
          ? DateTime.tryParse(json['date_created'])
          : null,
      dateModified: json['date_modified'] != null
          ? DateTime.tryParse(json['date_modified'])
          : null,
      extensions: json['extensions'] as Map<String, dynamic>?,
      attributes: (json['attributes'] as List<dynamic>?)
              ?.map((a) => ProductAttribute.fromJson(a as Map<String, dynamic>))
              .toList() ??
          [],
      variations: (json['variations'] as List<dynamic>?)
              ?.map((v) => ProductVariation.fromJson(v as Map<String, dynamic>))
              .toList() ??
          [],
      defaultAttributes: _parseDefaultAttributes(json['default_attributes']),
    );
  }

  static Map<String, String> _parseDefaultAttributes(dynamic defaultAttributesJson) {
    if (defaultAttributesJson == null) return {};
    if (defaultAttributesJson is Map<String, dynamic>) {
      return defaultAttributesJson.map((key, value) => MapEntry(key, value.toString()));
    }

    return {};
  }

  /// Parse media from JSON, supporting both new media format and legacy images array
  static List<MediaItem> _parseMedia(dynamic mediaJson, dynamic imagesJson) {
    // If media field exists and is populated, use it
    if (mediaJson != null && mediaJson is List && mediaJson.isNotEmpty) {
      return mediaJson
          .map((m) => m is Map<String, dynamic>
              ? MediaItem.fromJson(m)
              : MediaItem.fromUrl(m.toString()))
          .toList();
    }

    // Fallback to legacy images field for backward compatibility
    if (imagesJson != null && imagesJson is List) {
      return imagesJson
          .map((url) => MediaItem.fromUrl(
                url.toString(),
                type: MediaItem.detectTypeFromUrl(url.toString()),
              ))
          .toList();
    }

    return [];
  }

  /// Helper getter for backward compatibility - returns list of image/thumbnail URLs
  List<String> get images {
    return media.map((m) => m.thumbnail ?? m.url).toList();
  }

  /// Helper getter - returns the first media item's URL or thumbnail
  String? get primaryImageUrl {
    if (media.isEmpty) return null;
    return media.first.thumbnail ?? media.first.url;
  }

  @override
  List<Object?> get props => [
    id,
    name,
    price,
    regularPrice,
    salePrice,
    onSale,
    inStock,
    stockQuantity,
    stockStatus,
    categories,
    tags,
    featured,
    averageRating,
    ratingCount,
    attributes,
    variations,
    defaultAttributes
  ];

  @override
  String toString() {
    return 'Product(id: $id, name: $name, price: \$$price, inStock: $inStock)';
  }
}
