import '../entities/post.dart';
import '../entities/paginated_result.dart';
import 'repository.dart';

abstract class PostRepository extends CoreRepository {
  /// Get paginated posts with optional filters
  ///
  /// [page] - Page number for pagination (default: 1)
  /// [perPage] - Number of posts per page (default: 20)
  /// [postType] - Type of post to retrieve: 'post', 'page', 'article', etc. (default: 'post')
  /// [categoryId] - Filter by category ID
  /// [authorId] - Filter by author ID
  /// [search] - Search query string
  /// [sortBy] - Field to sort by (e.g., 'date', 'title', 'modified')
  /// [sortOrder] - Sort order: 'asc' or 'desc'
  /// [status] - Post status filter: 'publish', 'draft', 'pending', etc.
  /// [metadataFilter] - Additional metadata filters
  ///
  /// Returns PaginatedResult<Post> with posts and pagination metadata
  Future<PaginatedResult<Post>> getPosts({
    int page = 1,
    int perPage = 20,
    String postType = 'post',
    String? categoryId,
    String? authorId,
    String? search,
    String? sortBy,
    String? sortOrder,
    String? status,
    Map<String, dynamic>? metadataFilter,
  });

  Future<Post> getPostById(String id);
}
