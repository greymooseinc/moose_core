import '../entities/search_result.dart';
import '../entities/search_filters.dart';
import 'repository.dart';
import 'repository_options.dart';

/// Abstract repository for search functionality
/// Can be implemented for different platforms (WooCommerce, Shopify, etc.)
abstract class SearchRepository extends CoreRepository {

  /// Search for items matching the query
  Future<List<SearchResult>> search({
    required String query,
    SearchFilters? filters,
    RepositoryOptions? options,
  });

  /// Get search suggestions based on partial query
  Future<List<String>> getSuggestions({
    required String query,
    int limit = 5,
    RepositoryOptions? options,
  });

  /// Get popular/trending search terms
  Future<List<String>> getPopularSearches({
    int limit = 10,
    RepositoryOptions? options,
  });

  /// Get recent search history for the user
  Future<List<String>> getRecentSearches({
    int limit = 10,
    RepositoryOptions? options,
  });

  /// Save a search term to history
  Future<void> saveSearchToHistory(String query, {RepositoryOptions? options});

  /// Clear search history
  Future<void> clearSearchHistory({RepositoryOptions? options});
}
