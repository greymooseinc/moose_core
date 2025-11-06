class ProductReviewStats {
  final double averageRating;
  final int reviewCount;
  final Map<int, int> ratingDistribution;
  final Map<String, dynamic>? extensions;

  const ProductReviewStats({
    required this.averageRating,
    required this.reviewCount,
    required this.ratingDistribution,
    this.extensions,
  });
}
