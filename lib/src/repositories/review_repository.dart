import '../entities/product_review.dart';
import '../entities/product_review_stats.dart';
import '../entities/paginated_result.dart';
import 'repository.dart';

/// ReviewRepository - Abstract interface for review operations
///
/// This repository handles ALL review-related operations including:
/// - Loading paginated reviews for any entity (products, posts, etc.)
/// - Creating new reviews
/// - Getting review statistics
///
/// Design Philosophy:
/// - Entity-agnostic: Reviews can be for products, posts, or any entity
/// - Backend-agnostic: Implementations in adapters (WooCommerce, Shopify, etc.)
/// - Returns domain entities, never DTOs
/// - Supports pagination for large review lists
///
/// Usage:
/// - BLoCs receive this repository via constructor
/// - Adapter implementations handle backend-specific logic
/// - The 'entityType' and 'entityId' pattern allows reviews for any entity type
abstract class ReviewRepository extends CoreRepository {
  /// Load paginated reviews for a specific entity
  ///
  /// [entityType] - Type of entity: 'product', 'post', 'article', etc.
  /// [entityId] - ID of the entity to get reviews for
  /// [page] - Page number for pagination (default: 1)
  /// [perPage] - Number of reviews per page (default: 10)
  /// [status] - Review status filter: 'approved', 'pending', 'all' (default: 'approved')
  ///
  /// Returns PaginatedResult<ProductReview> with:
  /// - List of reviews for current page (sorted by date, newest first)
  /// - Pagination metadata (currentPage, totalPages, hasMore, etc.)
  /// - Total count of reviews
  ///
  /// Throws exception if loading fails
  Future<PaginatedResult<ProductReview>> getReviews({
    required String entityType,
    required String entityId,
    int page = 1,
    int perPage = 10,
    String status = 'approved',
  });

  /// Create a new review
  ///
  /// [review] - The review to create (includes entityId, entityType in metadata)
  ///
  /// Returns the created review with server-generated ID
  /// Throws exception if creation fails
  Future<ProductReview> createReview(ProductReview review);

  /// Get review statistics for an entity
  ///
  /// [entityType] - Type of entity: 'product', 'post', etc.
  /// [entityId] - ID of the entity
  ///
  /// Returns statistics including average rating, count, distribution
  /// Throws exception if loading fails
  Future<ProductReviewStats> getReviewStats({
    required String entityType,
    required String entityId,
  });

  /// Get review images for a specific review
  ///
  /// [reviewId] - The ID of the review to get images for
  ///
  /// Returns a list of image URLs associated with the review
  /// Returns an empty list if the review has no images or if loading fails
  ///
  /// This method allows lazy-loading of review images separately from the review content,
  /// which can improve performance when displaying review lists
  Future<List<String>> getReviewImages(String reviewId);

  /// Get all review images for a product
  ///
  /// [entityType] - Type of entity: 'product', 'post', etc.
  /// [entityId] - ID of the entity to get review images for
  ///
  /// Returns a list of maps containing:
  /// - 'reviewId': The ID of the review
  /// - 'imageUrl': The URL of the image
  /// - 'reviewer': The name of the reviewer
  /// - 'rating': The rating given in the review
  ///
  /// This is useful for displaying a gallery of all review images for a product
  /// in a dedicated section on the product details page
  ///
  /// Returns an empty list if there are no images or if loading fails
  Future<List<Map<String, dynamic>>> getProductReviewImages({
    required String entityType,
    required String entityId,
  });

  /// Get a specific review by its ID
  ///
  /// [reviewId] - The ID of the review to fetch
  ///
  /// Returns the ProductReview entity
  /// Throws exception if the review is not found or if loading fails
  Future<ProductReview> getReviewById(String reviewId);
}
