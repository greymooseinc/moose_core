import 'package:equatable/equatable.dart';

class ProductAttribute extends Equatable {
  final String id;
  final String name;
  final String slug;
  final List<String> options;
  final bool visible;
  final bool variation;
  final int position;

  const ProductAttribute({
    required this.id,
    required this.name,
    required this.slug,
    required this.options,
    this.visible = true,
    this.variation = false,
    this.position = 0,
  });

  ProductAttribute copyWith({
    String? id,
    String? name,
    String? slug,
    List<String>? options,
    bool? visible,
    bool? variation,
    int? position,
  }) {
    return ProductAttribute(
      id: id ?? this.id,
      name: name ?? this.name,
      slug: slug ?? this.slug,
      options: options ?? this.options,
      visible: visible ?? this.visible,
      variation: variation ?? this.variation,
      position: position ?? this.position,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'slug': slug,
      'options': options,
      'visible': visible,
      'variation': variation,
      'position': position,
    };
  }

  factory ProductAttribute.fromJson(Map<String, dynamic> json) {
    return ProductAttribute(
      id: json['id']?.toString() ?? '',
      name: json['name'] ?? '',
      slug: json['slug'] ?? '',
      options: (json['options'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      visible: json['visible'] ?? true,
      variation: json['variation'] ?? false,
      position: json['position'] ?? 0,
    );
  }

  @override
  List<Object?> get props => [id, name, options];

  @override
  String toString() => 'ProductAttribute(name: $name, options: ${options.join(', ')})';
}