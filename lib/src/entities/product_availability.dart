class ProductAvailability {
  final bool isAvailable;
  final String message;
  final int availableQuantity;
  final bool canBackorder;

  const ProductAvailability({
    required this.isAvailable,
    required this.message,
    required this.availableQuantity,
    this.canBackorder = false,
  });
}
