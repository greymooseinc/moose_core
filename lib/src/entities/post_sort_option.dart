import 'post.dart';
import 'paginated_result.dart';
import 'package:equatable/equatable.dart';

class PostSortOption extends Equatable {
  final String id;
  final String label;
  final String sortBy;
  final String sortOrder;
  final bool isDefault;

  const PostSortOption({
    required this.id,
    required this.label,
    required this.sortBy,
    required this.sortOrder,
    this.isDefault = false,
  });

  PostSortOption copyWith({
    String? id,
    String? label,
    String? sortBy,
    String? sortOrder,
    bool? isDefault,
  }) {
    return PostSortOption(
      id: id ?? this.id,
      label: label ?? this.label,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
      isDefault: isDefault ?? this.isDefault,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'sort_by': sortBy,
      'sort_order': sortOrder,
      'is_default': isDefault,
    };
  }

  factory PostSortOption.fromJson(Map<String, dynamic> json) {
    return PostSortOption(
      id: json['id'] as String,
      label: json['label'] as String,
      sortBy: json['sort_by'] as String,
      sortOrder: json['sort_order'] as String,
      isDefault: json['is_default'] as bool? ?? false,
    );
  }

  @override
  List<Object?> get props => [id, label, sortBy, sortOrder, isDefault];

  @override
  String toString() {
    return 'PostSortOption(id: $id, label: $label, sortBy: $sortBy, sortOrder: $sortOrder, isDefault: $isDefault)';
  }
}

/// PostListResult - Wrapper for paginated posts with sort options
///
/// This class combines PaginatedResult<Post> with post-specific extensions
/// like sort options. It provides a convenient interface for post listing
/// features while using the generic pagination underneath.
///
/// Migration Note: This replaces the old PostListResult class that duplicated
/// pagination logic. Now it wraps PaginatedResult<Post> and adds sort options.
class PostListResult {
  final PaginatedResult<Post> paginatedPosts;
  final List<PostSortOption> sortOptions;

  const PostListResult({
    required this.paginatedPosts,
    required this.sortOptions,
  });

  // Convenience getters that delegate to paginatedPosts
  List<Post> get posts => paginatedPosts.items;
  int get totalResults => paginatedPosts.totalCount;
  int get currentPage => paginatedPosts.currentPage;
  int get totalPages => paginatedPosts.totalPages;
  bool get hasMore => paginatedPosts.hasMore;
  int get perPage => paginatedPosts.perPage;

  PostListResult copyWith({
    PaginatedResult<Post>? paginatedPosts,
    List<PostSortOption>? sortOptions,
  }) {
    return PostListResult(
      paginatedPosts: paginatedPosts ?? this.paginatedPosts,
      sortOptions: sortOptions ?? this.sortOptions,
    );
  }

  PostSortOption? get defaultSortOption {
    try {
      return sortOptions.firstWhere((option) => option.isDefault);
    } catch (e) {
      return sortOptions.isNotEmpty ? sortOptions.first : null;
    }
  }

  PostSortOption? getSortOptionById(String id) {
    try {
      return sortOptions.firstWhere((option) => option.id == id);
    } catch (e) {
      return null;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'posts': posts,
      'sort_options': sortOptions.map((option) => option.toJson()).toList(),
      'total_results': totalResults,
      'current_page': currentPage,
      'total_pages': totalPages,
    };
  }

  @override
  String toString() {
    return 'PostListResult(posts: ${posts.length} items, sortOptions: ${sortOptions.length} options, totalResults: $totalResults, currentPage: $currentPage, totalPages: $totalPages)';
  }
}
