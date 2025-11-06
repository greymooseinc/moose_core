import 'package:equatable/equatable.dart';

class Category extends Equatable {
  final String id;
  final String name;
  final String slug;
  final String? description;
  final String? image;
  final String? parentId;
  final int productCount;
  final int displayOrder;
  final Map<String, dynamic>? extensions;

  const Category({
    required this.id,
    required this.name,
    required this.slug,
    this.description,
    this.image,
    this.parentId,
    this.productCount = 0,
    this.displayOrder = 0,
    this.extensions,
  });

  Category copyWith({
    String? id,
    String? name,
    String? slug,
    String? description,
    String? image,
    String? parentId,
    int? productCount,
    int? displayOrder,
    Map<String, dynamic>? extensions,
  }) {
    return Category(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      description: description ?? this.description,
      image: image ?? this.image,
      parentId: parentId ?? this.parentId,
      productCount: productCount ?? this.productCount,
      displayOrder: displayOrder ?? this.displayOrder,
      extensions: extensions ?? this.extensions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'description': description,
      'image': image,
      'parent_id': parentId,
      'product_count': productCount,
      'display_order': displayOrder,
      'extensions': extensions,
    };
  }

  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      description: json['description'],
      image: json['image'],
      parentId: json['parent_id']?.toString(),
      productCount: json['product_count'] ?? 0,
      displayOrder: json['display_order'] ?? 0,
      extensions: json['extensions'] as Map<String, dynamic>?,
    );
  }

  @override
  List<Object?> get props => [id, name, slug];

  @override
  String toString() => 'Category(id: $id, name: $name, products: $productCount)';
}