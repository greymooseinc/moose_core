import 'package:flutter/material.dart';
import 'package:moose_core/src/entities/core_entity.dart';

import 'search_result_type.dart';

/// Filters for search queries across different content types.
@immutable
class SearchFilters extends CoreEntity {
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
    super.extensions,
  });

  SearchFilters copyWith({
    List<SearchResultType>? types,
    int? limit,
    String? categoryId,
    String? tagId,
    Map<String, dynamic>? customFilters,
    Map<String, dynamic>? extensions,
  }) {
    return SearchFilters(
      types: types ?? this.types,
      limit: limit ?? this.limit,
      categoryId: categoryId ?? this.categoryId,
      tagId: tagId ?? this.tagId,
      customFilters: customFilters ?? this.customFilters,
      extensions: extensions ?? this.extensions,
    );
  }

  @override
  List<Object?> get props => [types, limit, categoryId, tagId, customFilters];
}
