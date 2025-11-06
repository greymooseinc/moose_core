import 'package:flutter/material.dart';

import 'core_entity.dart';

/// Represents a product content section for organizing product information.
@immutable
class ProductSection extends CoreEntity {
  final String type;
  final String content;
  final String? title;
  final int order;

  const ProductSection({
    required this.type,
    required this.content,
    this.title,
    this.order = 0,
    super.extensions,
  });

  ProductSection copyWith({
    String? type,
    String? content,
    String? title,
    int? order,
    Map<String, dynamic>? extensions,
  }) {
    return ProductSection(
      type: type ?? this.type,
      content: content ?? this.content,
      title: title ?? this.title,
      order: order ?? this.order,
      extensions: extensions ?? this.extensions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'content': content,
      'title': title,
      'order': order,
      'extensions': extensions,
    };
  }

  factory ProductSection.fromJson(Map<String, dynamic> json) {
    return ProductSection(
      type: json['type'] ?? '',
      content: json['content'] ?? '',
      title: json['title'],
      order: json['order'] ?? 0,
      extensions: json['extensions'] as Map<String, dynamic>?,
    );
  }

  @override
  List<Object?> get props => [type, content, title, order, extensions];

  @override
  String toString() {
    return 'ProductSection(type: $type, title: $title, order: $order)';
  }
}
