import '../entities/search_result.dart';
import '../entities/search_filters.dart';
import 'repository.dart';

/// Abstract repository for search functionality
/// Can be implemented for different platforms (WooCommerce, Shopify, etc.)
abstract class SearchRepository extends CoreRepository {
  SearchRepository({required super.hookRegistry, required super.eventBus});

  /// Search for items matching the query
  Future<List<SearchResult>> search({
    required String query,
    SearchFilters? filters,
  });

  /// Get search suggestions based on partial query
  Future<List<String>> getSuggestions({
    required String query,
    int limit = 5,
  });

  /// Get popular/trending search terms
  Future<List<String>> getPopularSearches({
    int limit = 10,
  });

  /// Get recent search history for the user
  Future<List<String>> getRecentSearches({
    int limit = 10,
  });

  /// Save a search term to history
  Future<void> saveSearchToHistory(String query);

  /// Clear search history
  Future<void> clearSearchHistory();
}
