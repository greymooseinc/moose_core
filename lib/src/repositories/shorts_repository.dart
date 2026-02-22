import 'package:moose_core/repositories.dart';

import '../entities/paginated_result.dart';
import '../entities/short.dart';

/// Repository interface for fetching short-form content (stories).
///
/// Adapters implement this to provide shorts from various backends:
/// - WordPress custom post types
/// - Shopify metafields or blog posts
/// - Custom API endpoints
/// - Static JSON files
///
/// ## Example Implementation:
/// ```dart
/// class WordPressShortsRepository implements ShortsRepository {
///   @override
///   Future<PaginatedResult<Short>> getShorts({
///     int page = 1,
///     int perPage = 20,
///     String? status,
///     Map<String, dynamic>? filters,
///   }) async {
///     // Fetch from WordPress REST API with post_type=shorts
///     final response = await http.get(...);
///     return PaginatedResult<Short>(...);
///   }
///
///   @override
///   Future<Short> getShortById(String id) async {
///     final response = await http.get('/wp-json/wp/v2/shorts/$id');
///     return Short.fromJson(response.data);
///   }
/// }
/// ```
abstract class ShortsRepository extends CoreRepository {
  ShortsRepository({required super.hookRegistry, required super.eventBus});

  /// Fetch a paginated list of shorts.
  ///
  /// Parameters:
  /// - [page]: Current page number (1-indexed)
  /// - [perPage]: Number of items per page
  /// - [status]: Filter by publication status ('publish', 'draft', etc.)
  /// - [filters]: Additional adapter-specific filters
  ///   - 'category': Filter by category ID or slug
  ///   - 'tag': Filter by tag ID or slug
  ///   - 'author': Filter by author ID
  ///   - 'search': Search query string
  ///   - 'sortBy': Sort field ('date', 'title', 'order', etc.)
  ///   - 'sortOrder': Sort direction ('asc' or 'desc')
  ///
  /// Returns a [PaginatedResult] containing shorts and pagination metadata.
  Future<PaginatedResult<Short>> getShorts({
    int page = 1,
    int perPage = 20,
    String? status,
    Map<String, dynamic>? filters,
  });

  /// Fetch a single short by its unique ID.
  ///
  /// Throws an exception if the short is not found or cannot be fetched.
  Future<Short> getShortById(String id);

  /// Optional: Refresh/invalidate cache for shorts data.
  ///
  /// Adapters that implement caching can override this to clear stale data.
  /// Default implementation is a no-op.
  Future<void> refreshShorts() async {
    // Default: no-op
    // Adapters with caching should override this
  }
}
