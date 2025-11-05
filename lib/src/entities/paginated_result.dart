import 'package:equatable/equatable.dart';

/// PaginatedResult<T> - Generic wrapper for paginated results
///
/// This generic class provides a consistent structure for ALL paginated data in the app.
/// It replaces entity-specific wrappers like ProductListResult, PostListResult, PaginatedReviews, etc.
///
/// Type parameter T: The type of items in the list (Product, ProductReview, Post, etc.)
///
/// Usage examples:
/// - PaginatedResult<Product> for product lists
/// - PaginatedResult<ProductReview> for review lists
/// - PaginatedResult<Post> for blog post lists
/// - PaginatedResult<SearchResult> for search results
///
/// Benefits:
/// - Single source of truth for pagination logic
/// - Consistent API across all features
/// - Type-safe with generics
/// - Reusable helper methods
/// - Easy to maintain and extend
class PaginatedResult<T> extends Equatable {
  /// The list of items for the current page
  final List<T> items;

  /// Current page number (1-indexed)
  final int currentPage;

  /// Total number of pages available
  final int totalPages;

  /// Total number of items across all pages
  final int totalCount;

  /// Number of items per page
  final int perPage;

  /// Whether there are more pages to load
  final bool hasMore;

  const PaginatedResult({
    required this.items,
    required this.currentPage,
    required this.totalPages,
    required this.totalCount,
    required this.perPage,
  }) : hasMore = currentPage < totalPages;

  /// Create paginated result from list with pagination metadata
  ///
  /// [items] - List of items for current page
  /// [page] - Current page number (1-indexed)
  /// [perPage] - Number of items per page
  /// [totalCount] - Total number of items across all pages
  factory PaginatedResult.fromList({
    required List<T> items,
    required int page,
    required int perPage,
    required int totalCount,
  }) {
    final totalPages = totalCount > 0 ? (totalCount / perPage).ceil() : 0;
    return PaginatedResult<T>(
      items: items,
      currentPage: page,
      totalPages: totalPages,
      totalCount: totalCount,
      perPage: perPage,
    );
  }

  /// Create empty paginated result
  ///
  /// Useful for initial states or when no data is available
  /// [perPage] - Number of items per page (default: 10)
  factory PaginatedResult.empty({int perPage = 10}) {
    return PaginatedResult<T>(
      items: const [],
      currentPage: 1,
      totalPages: 0,
      totalCount: 0,
      perPage: perPage,
    );
  }

  /// Check if this is the first page
  bool get isFirstPage => currentPage == 1;

  /// Check if this is the last page
  bool get isLastPage => currentPage >= totalPages || totalPages == 0;

  /// Get next page number (or null if no more pages)
  int? get nextPage => hasMore ? currentPage + 1 : null;

  /// Get previous page number (or null if on first page)
  int? get previousPage => currentPage > 1 ? currentPage - 1 : null;

  /// Check if result is empty (no items)
  bool get isEmpty => items.isEmpty;

  /// Check if result is not empty
  bool get isNotEmpty => items.isNotEmpty;

  /// Get number of items in current page
  int get itemCount => items.length;

  /// Copy with new values (useful for appending pages)
  PaginatedResult<T> copyWith({
    List<T>? items,
    int? currentPage,
    int? totalPages,
    int? totalCount,
    int? perPage,
  }) {
    return PaginatedResult<T>(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      totalCount: totalCount ?? this.totalCount,
      perPage: perPage ?? this.perPage,
    );
  }

  /// Append items from another page
  ///
  /// Useful for infinite scroll: combines current items with new page items
  /// Returns new PaginatedResult with combined items and updated metadata
  PaginatedResult<T> appendPage(PaginatedResult<T> nextPageResult) {
    return PaginatedResult<T>(
      items: [...items, ...nextPageResult.items],
      currentPage: nextPageResult.currentPage,
      totalPages: nextPageResult.totalPages,
      totalCount: nextPageResult.totalCount,
      perPage: perPage,
    );
  }

  /// Map items to a different type
  ///
  /// Useful for transforming data:
  /// ```dart
  /// PaginatedResult<Product> products = ...;
  /// PaginatedResult<ProductViewModel> viewModels = products.map(
  ///   (product) => ProductViewModel.fromProduct(product)
  /// );
  /// ```
  PaginatedResult<R> map<R>(R Function(T item) mapper) {
    return PaginatedResult<R>(
      items: items.map(mapper).toList(),
      currentPage: currentPage,
      totalPages: totalPages,
      totalCount: totalCount,
      perPage: perPage,
    );
  }

  @override
  List<Object?> get props => [
        items,
        currentPage,
        totalPages,
        totalCount,
        perPage,
      ];

  @override
  String toString() {
    return 'PaginatedResult<$T>(page: $currentPage/$totalPages, items: ${items.length}/$totalCount, hasMore: $hasMore)';
  }
}
