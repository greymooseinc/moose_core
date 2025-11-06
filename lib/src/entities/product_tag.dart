import 'package:flutter/material.dart';
import 'package:moose_core/src/entities/core_entity.dart';

/// Represents a product tag for categorization and filtering.
@immutable
class ProductTag extends CoreEntity {
  final String id;
  final String name;
  final String slug;
  final int productCount;

  const ProductTag({
    required this.id,
    required this.name,
    required this.slug,
    required this.productCount,
    super.extensions,
  });
  
  @override
  List<Object?> get props => [id, name, slug, productCount];
}
