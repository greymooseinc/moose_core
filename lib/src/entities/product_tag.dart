class ProductTag {
  final String id;
  final String name;
  final String slug;
  final int productCount;
  final Map<String, dynamic>? extensions;

  const ProductTag({
    required this.id,
    required this.name,
    required this.slug,
    required this.productCount,
    this.extensions,
  });
}
