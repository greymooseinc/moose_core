import 'package:equatable/equatable.dart';

/// Represents a dynamic section of product information
/// This allows different backends (Shopify, WooCommerce, etc.) to define
/// custom sections for product details like description, care instructions,
/// design details, specifications, etc.
class ProductSection extends Equatable {
  /// Unique identifier for the section type (e.g., 'description', 'care_instructions', 'design', 'specifications')
  final String type;

  /// The content of the section
  final String content;

  /// Optional title for the section (can be used for display)
  final String? title;

  /// Order/priority for displaying sections (lower numbers appear first)
  final int order;

  /// Optional metadata for additional section-specific configuration
  final Map<String, dynamic>? metadata;

  const ProductSection({
    required this.type,
    required this.content,
    this.title,
    this.order = 0,
    this.metadata,
  });

  ProductSection copyWith({
    String? type,
    String? content,
    String? title,
    int? order,
    Map<String, dynamic>? metadata,
  }) {
    return ProductSection(
      type: type ?? this.type,
      content: content ?? this.content,
      title: title ?? this.title,
      order: order ?? this.order,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'content': content,
      'title': title,
      'order': order,
      'metadata': metadata,
    };
  }

  factory ProductSection.fromJson(Map<String, dynamic> json) {
    return ProductSection(
      type: json['type'] ?? '',
      content: json['content'] ?? '',
      title: json['title'],
      order: json['order'] ?? 0,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  @override
  List<Object?> get props => [type, content, title, order, metadata];

  @override
  String toString() {
    return 'ProductSection(type: $type, title: $title, order: $order)';
  }
}
