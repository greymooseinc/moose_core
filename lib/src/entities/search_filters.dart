import 'package:equatable/equatable.dart';
import 'search_result_type.dart';

/// Filters for search queries
class SearchFilters extends Equatable {
  final List<SearchResultType>? types;
  final int? limit;
  final String? categoryId;
  final String? tagId;
  final Map<String, dynamic>? customFilters;

  const SearchFilters({
    this.types,
    this.limit = 20,
    this.categoryId,
    this.tagId,
    this.customFilters,
  });

  SearchFilters copyWith({
    List<SearchResultType>? types,
    int? limit,
    String? categoryId,
    String? tagId,
    Map<String, dynamic>? customFilters,
  }) {
    return SearchFilters(
      types: types ?? this.types,
      limit: limit ?? this.limit,
      categoryId: categoryId ?? this.categoryId,
      tagId: tagId ?? this.tagId,
      customFilters: customFilters ?? this.customFilters,
    );
  }

  @override
  List<Object?> get props => [types, limit, categoryId, tagId, customFilters];
}
