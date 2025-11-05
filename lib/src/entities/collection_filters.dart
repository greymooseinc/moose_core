class CollectionFilters {
  // Pagination
  final int page;
  final int perPage;

  // Filters
  final String? search;
  final Map<String, dynamic>? metadataFilter;

  const CollectionFilters({
    this.page = 1,
    this.perPage = 20,
    this.search,
    this.metadataFilter,
  });

  CollectionFilters copyWith({
    int? page,
    int? perPage,
    String? search,
    Map<String, dynamic>? metadataFilter,
  }) {
    return CollectionFilters(
      page: page ?? this.page,
      perPage: perPage ?? this.perPage,
      search: search ?? this.search,
      metadataFilter: metadataFilter ?? this.metadataFilter,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'page': page,
      'perPage': perPage,
      if (search != null) 'search': search,
      if (metadataFilter != null) 'metadataFilter': metadataFilter,
    };
  }

  factory CollectionFilters.fromJson(Map<String, dynamic> json) {
    return CollectionFilters(
      page: json['page'] as int? ?? 1,
      perPage: json['perPage'] as int? ?? 20,
      search: json['search'] as String?,
      metadataFilter: json['metadataFilter'] as Map<String, dynamic>?,
    );
  }
}
