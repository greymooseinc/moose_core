class ProductAvailability {
  final bool isAvailable;
  final String message;
  final int availableQuantity;
  final bool canBackorder;
  final Map<String, dynamic>? extensions;

  const ProductAvailability({
    required this.isAvailable,
    required this.message,
    required this.availableQuantity,
    this.canBackorder = false,
    this.extensions,
  });
}
