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
import 'repository_options.dart';

abstract class ProductsRepository extends CoreRepository {

  Future<ProductListResult> getProducts({
    ProductFilters? filters,
    RepositoryOptions? options,
  });

  Future<Product> getProductById(String id, {RepositoryOptions? options});

  Future<List<Product>> getProductsByIds(
    List<String> ids, {
    bool includeVariations = false,
    RepositoryOptions? options,
  });

  Future<List<Product>> getProductsBySKUs(
    List<String> skus, {
    RepositoryOptions? options,
  });

  Future<List<Category>> getCategories({
    String? parentId,
    bool hideEmpty = false,
    String? orderBy,
    RepositoryOptions? options,
  });

  Future<Category> getCategoryById(String id, {RepositoryOptions? options});

  Future<List<Collection>> getCollections({
    CollectionFilters? filters,
    RepositoryOptions? options,
  });

  Future<List<ProductVariation>> getProductVariations(
    String productId, {
    RepositoryOptions? options,
  });

  Future<ProductVariation> getProductVariation(
    String productId,
    String variationId, {
    RepositoryOptions? options,
  });

  Future<List<ProductAttribute>> getProductAttributes(
    String productId, {
    RepositoryOptions? options,
  });

  Future<List<ProductReview>> getProductReviews(
    String productId, {
    int page = 1,
    int perPage = 10,
    String status = 'approved',
    RepositoryOptions? options,
  });

  Future<ProductReviewStats> getProductReviewStats(
    String productId, {
    RepositoryOptions? options,
  });

  Future<List<Product>> getRelatedProducts(
    String productId, {
    int limit = 10,
    RepositoryOptions? options,
  });

  Future<List<Product>> getUpsellProducts(
    String productId, {
    int limit = 5,
    RepositoryOptions? options,
  });

  Future<List<Product>> getCrossSellProducts(
    String productId, {
    int limit = 5,
    RepositoryOptions? options,
  });

  Future<List<Product>> getFrequentlyBoughtTogether(
    String productId, {
    int limit = 3,
    RepositoryOptions? options,
  });

  Future<List<Product>> getFeaturedProducts({
    int limit = 10,
    String? categoryId,
    RepositoryOptions? options,
  });

  Future<ProductStock> getProductStock(
    String productId, {
    String? variationId,
    RepositoryOptions? options,
  });

  Future<List<ProductTag>> getProductTags({RepositoryOptions? options});

  Future<List<String>> getProductBrands({RepositoryOptions? options});

  Future<ProductAvailability> validateProductAvailability({
    required String productId,
    required int quantity,
    String? variationId,
    RepositoryOptions? options,
  });

  Future<ProductReview> createReview(
    ProductReview review, {
    RepositoryOptions? options,
  });
}
