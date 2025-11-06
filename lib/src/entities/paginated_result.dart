import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Wrapper for paginated data with metadata about pages and items.
@immutable
class PaginatedResult<T> extends Equatable {
  final List<T> items;
  final int currentPage;
  final int totalPages;
  final int totalCount;
  final int perPage;
  final bool hasMore;

  const PaginatedResult({
    required this.items,
    required this.currentPage,
    required this.totalPages,
    required this.totalCount,
    required this.perPage,
  }) : hasMore = currentPage < totalPages;

  factory PaginatedResult.fromList({
    required List<T> items,
    required int page,
    required int perPage,
    required int totalCount,
  }) {
    final totalPages = totalCount > 0 ? (totalCount / perPage).ceil() : 0;
    return PaginatedResult<T>(
      items: items,
      currentPage: page,
      totalPages: totalPages,
      totalCount: totalCount,
      perPage: perPage,
    );
  }

  factory PaginatedResult.empty({int perPage = 10}) {
    return PaginatedResult<T>(
      items: const [],
      currentPage: 1,
      totalPages: 0,
      totalCount: 0,
      perPage: perPage,
    );
  }

  bool get isFirstPage => currentPage == 1;
  bool get isLastPage => currentPage >= totalPages || totalPages == 0;
  int? get nextPage => hasMore ? currentPage + 1 : null;
  int? get previousPage => currentPage > 1 ? currentPage - 1 : null;
  bool get isEmpty => items.isEmpty;
  bool get isNotEmpty => items.isNotEmpty;
  int get itemCount => items.length;

  PaginatedResult<T> copyWith({
    List<T>? items,
    int? currentPage,
    int? totalPages,
    int? totalCount,
    int? perPage,
  }) {
    return PaginatedResult<T>(
      items: items ?? this.items,
      currentPage: currentPage ?? this.currentPage,
      totalPages: totalPages ?? this.totalPages,
      totalCount: totalCount ?? this.totalCount,
      perPage: perPage ?? this.perPage,
    );
  }

  PaginatedResult<T> appendPage(PaginatedResult<T> nextPageResult) {
    return PaginatedResult<T>(
      items: [...items, ...nextPageResult.items],
      currentPage: nextPageResult.currentPage,
      totalPages: nextPageResult.totalPages,
      totalCount: nextPageResult.totalCount,
      perPage: perPage,
    );
  }

  PaginatedResult<R> map<R>(R Function(T item) mapper) {
    return PaginatedResult<R>(
      items: items.map(mapper).toList(),
      currentPage: currentPage,
      totalPages: totalPages,
      totalCount: totalCount,
      perPage: perPage,
    );
  }

  @override
  List<Object?> get props => [
        items,
        currentPage,
        totalPages,
        totalCount,
        perPage,
      ];

  @override
  String toString() {
    return 'PaginatedResult<$T>(page: $currentPage/$totalPages, items: ${items.length}/$totalCount, hasMore: $hasMore)';
  }
}
