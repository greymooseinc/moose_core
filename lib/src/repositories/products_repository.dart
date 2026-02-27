import '../entities/product.dart';
import '../entities/category.dart';
import '../entities/collection.dart';
import '../entities/collection_filters.dart';
import '../entities/product_variation.dart';
import '../entities/product_review.dart';
import '../entities/product_attribute.dart';
import '../entities/product_sort_option.dart';
import '../entities/product_filters.dart';
import '../entities/product_stock.dart';
import '../entities/product_review_stats.dart';
import '../entities/product_tag.dart';
import '../entities/product_availability.dart';
import 'repository.dart';

abstract class ProductsRepository extends CoreRepository {

  Future<ProductListResult> getProducts({
    ProductFilters? filters,
    Duration? cacheTTL,
  });

  Future<Product> getProductById(String id, {Duration? cacheTTL});

  Future<List<Product>> getProductsByIds(
    List<String> ids, {
    bool includeVariations = false,
    Duration? cacheTTL,
  });

  Future<List<Product>> getProductsBySKUs(List<String> skus, {Duration? cacheTTL});

  Future<List<Category>> getCategories({
    String? parentId,
    bool hideEmpty = false,
    String? orderBy,
    Duration? cacheTTL,
  });

  Future<Category> getCategoryById(String id, {Duration? cacheTTL});

  Future<List<Collection>> getCollections({
    CollectionFilters? filters,
    Duration? cacheTTL,
  });

  Future<List<ProductVariation>> getProductVariations(String productId, {Duration? cacheTTL});

  Future<ProductVariation> getProductVariation(
    String productId,
    String variationId, {
    Duration? cacheTTL,
  });

  Future<List<ProductAttribute>> getProductAttributes(String productId, {Duration? cacheTTL});

  Future<List<ProductReview>> getProductReviews(
    String productId, {
    int page = 1,
    int perPage = 10,
    String status = 'approved',
    Duration? cacheTTL,
  });

  Future<ProductReviewStats> getProductReviewStats(String productId, {Duration? cacheTTL});

  Future<List<Product>> getRelatedProducts(
    String productId, {
    int limit = 10,
    Duration? cacheTTL,
  });

  Future<List<Product>> getUpsellProducts(
    String productId, {
    int limit = 5,
    Duration? cacheTTL,
  });

  Future<List<Product>> getCrossSellProducts(
    String productId, {
    int limit = 5,
    Duration? cacheTTL,
  });

  Future<List<Product>> getFrequentlyBoughtTogether(
    String productId, {
    int limit = 3,
    Duration? cacheTTL,
  });

  Future<List<Product>> getFeaturedProducts({
    int limit = 10,
    String? categoryId,
    Duration? cacheTTL,
  });

  Future<ProductStock> getProductStock(
    String productId, {
    String? variationId,
    Duration? cacheTTL,
  });

  Future<List<ProductTag>> getProductTags({Duration? cacheTTL});

  Future<List<String>> getProductBrands({Duration? cacheTTL});

  Future<ProductAvailability> validateProductAvailability({
    required String productId,
    required int quantity,
    String? variationId,
    Duration? cacheTTL,
  });

  /// Create a new product review
  Future<ProductReview> createReview(ProductReview review);
}
