class ProductReviewStats {
  final double averageRating;
  final int reviewCount;
  final Map<int, int> ratingDistribution;

  const ProductReviewStats({
    required this.averageRating,
    required this.reviewCount,
    required this.ratingDistribution,
  });
}
