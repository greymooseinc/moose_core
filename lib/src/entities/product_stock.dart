class ProductStock {
  final bool inStock;
  final int? quantity;
  final String status;
  final bool backordersAllowed;
  final Map<String, dynamic>? extensions;

  const ProductStock({
    required this.inStock,
    this.quantity,
    required this.status,
    this.backordersAllowed = false,
    this.extensions,
  });
}
