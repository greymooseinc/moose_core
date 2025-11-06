import 'package:flutter/material.dart';
import 'package:moose_core/src/entities/core_entity.dart';

import 'product.dart';

/// Represents search results for products with pagination and facets.
@immutable
class ProductSearchResult extends CoreEntity {
  final List<Product> products;
  final int totalResults;
  final int currentPage;
  final int totalPages;
  final Map<String, List<String>>? facets;

  const ProductSearchResult({
    required this.products,
    required this.totalResults,
    required this.currentPage,
    required this.totalPages,
    this.facets,
    super.extensions,
  });
  
  @override
  List<Object?> get props => [totalResults, currentPage, totalPages];
}
