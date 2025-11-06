import 'package:flutter/material.dart';
import 'package:moose_core/src/entities/core_entity.dart';

/// Represents aggregated product review statistics and rating distribution.
@immutable
class ProductReviewStats extends CoreEntity {
  final double averageRating;
  final int reviewCount;
  final Map<int, int> ratingDistribution;

  const ProductReviewStats({
    required this.averageRating,
    required this.reviewCount,
    required this.ratingDistribution,
    super.extensions,
  });
  
  @override
  List<Object?> get props => [averageRating, reviewCount];
}
