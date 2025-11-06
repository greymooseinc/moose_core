import 'product.dart';

class ProductSearchResult {
  final List<Product> products;
  final int totalResults;
  final int currentPage;
  final int totalPages;
  final Map<String, List<String>>? facets;
  final Map<String, dynamic>? extensions;

  const ProductSearchResult({
    required this.products,
    required this.totalResults,
    required this.currentPage,
    required this.totalPages,
    this.facets,
    this.extensions,
  });
}
