import 'product.dart';
import 'paginated_result.dart';
import 'package:equatable/equatable.dart';

class ProductSortOption extends Equatable {
  final String id;
  final String label;
  final String sortBy;
  final String sortOrder;
  final bool isDefault;

  const ProductSortOption({
    required this.id,
    required this.label,
    required this.sortBy,
    required this.sortOrder,
    this.isDefault = false,
  });

  ProductSortOption copyWith({
    String? id,
    String? label,
    String? sortBy,
    String? sortOrder,
    bool? isDefault,
  }) {
    return ProductSortOption(
      id: id ?? this.id,
      label: label ?? this.label,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'sort_by': sortBy,
      'sort_order': sortOrder,
      'is_default': isDefault,
    };
  }

  factory ProductSortOption.fromJson(Map<String, dynamic> json) {
    return ProductSortOption(
      id: json['id'] as String,
      label: json['label'] as String,
      sortBy: json['sort_by'] as String,
      sortOrder: json['sort_order'] as String,
      isDefault: json['is_default'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [id, label, sortBy, sortOrder, isDefault];

  @override
  String toString() {
    return 'ProductSortOption(id: $id, label: $label, sortBy: $sortBy, sortOrder: $sortOrder, isDefault: $isDefault)';
  }
}

/// ProductListResult - Wrapper for paginated products with sort options
///
/// This class combines PaginatedResult<Product> with product-specific metadata
/// like sort options. It provides a convenient interface for product listing
/// features while using the generic pagination underneath.
///
/// Migration Note: This replaces the old ProductListResult class that duplicated
/// pagination logic. Now it wraps PaginatedResult<Product> and adds sort options.
class ProductListResult {
  final PaginatedResult<Product> paginatedProducts;
  final List<ProductSortOption> sortOptions;

  const ProductListResult({
    required this.paginatedProducts,
    required this.sortOptions,
  });

  // Convenience getters that delegate to paginatedProducts
  List<Product> get products => paginatedProducts.items;
  int get totalResults => paginatedProducts.totalCount;
  int get currentPage => paginatedProducts.currentPage;
  int get totalPages => paginatedProducts.totalPages;
  bool get hasMore => paginatedProducts.hasMore;
  int get perPage => paginatedProducts.perPage;

  ProductListResult copyWith({
    PaginatedResult<Product>? paginatedProducts,
    List<ProductSortOption>? sortOptions,
  }) {
    return ProductListResult(
      paginatedProducts: paginatedProducts ?? this.paginatedProducts,
      sortOptions: sortOptions ?? this.sortOptions,
    );
  }

  ProductSortOption? get defaultSortOption {
    try {
      return sortOptions.firstWhere((option) => option.isDefault);
    } catch (e) {
      return sortOptions.isNotEmpty ? sortOptions.first : null;
    }
  }

  ProductSortOption? getSortOptionById(String id) {
    try {
      return sortOptions.firstWhere((option) => option.id == id);
    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'products': products,
      'sort_options': sortOptions.map((option) => option.toJson()).toList(),
      'total_results': totalResults,
      'current_page': currentPage,
      'total_pages': totalPages,
    };
  }

  @override
  String toString() {
    return 'ProductListResult(products: ${products.length} items, sortOptions: ${sortOptions.length} options, totalResults: $totalResults, currentPage: $currentPage, totalPages: $totalPages)';
  }
}
