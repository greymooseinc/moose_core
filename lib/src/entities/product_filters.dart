import '../config/config_manager.dart';

class ProductFilters {
  // Pagination
  final int page;
  final int perPage;

  // Sorting
  final String? sortBy;
  final String? sortOrder;

  // Filters
  final String? categoryId;
  final String? search;
  final double? minPrice;
  final double? maxPrice;
  final bool? inStock;
  final bool? onSale;
  final bool? featured;
  final List<String>? brands;
  final List<String>? tags;
  final Map<String, List<String>>? attributes;
  final double? minRating;
  final Map<String, dynamic>? metadataFilter;

  const ProductFilters({
    this.page = 1,
    this.perPage = 20,
    this.sortBy,
    this.sortOrder,
    this.categoryId,
    this.search,
    this.minPrice,
    this.maxPrice,
    this.inStock,
    this.onSale,
    this.featured,
    this.brands,
    this.tags,
    this.attributes,
    this.minRating,
    this.metadataFilter,
  });
  
  factory ProductFilters.fromConfig(String key) {
    var config = ConfigManager().get(key);
    return ProductFilters(
      page: config['page'] as int? ?? 1,
      perPage: config['perPage'] as int? ?? 20,
      sortBy: config['sortBy'] as String?,
      sortOrder: config['sortOrder'] as String?,
      categoryId: config['categoryId'] as String?,
      search: config['search'] as String?,
      minPrice: _parseDouble(config['minPrice']),
      maxPrice: _parseDouble(config['maxPrice']),
      inStock: config['inStock'] as bool?,
      onSale: config['onSale'] as bool?,
      featured: config['featured'] as bool?,
      brands: _parseStringList(config['brands']),
      tags: _parseStringList(config['tags']),
      attributes: _parseAttributes(config['attributes']),
      minRating: _parseDouble(config['minRating']),
      metadataFilter: config['metadataFilter'] as Map<String, dynamic>?,
    );
  }

  /// Create ProductFilters from JSON
  factory ProductFilters.fromJson(Map<String, dynamic> json) {
    return ProductFilters(
      page: json['page'] as int? ?? 1,
      perPage: json['perPage'] as int? ?? 20,
      sortBy: json['sortBy'] as String?,
      sortOrder: json['sortOrder'] as String?,
      categoryId: json['categoryId'] as String?,
      search: json['search'] as String?,
      minPrice: _parseDouble(json['minPrice']),
      maxPrice: _parseDouble(json['maxPrice']),
      inStock: json['inStock'] as bool?,
      onSale: json['onSale'] as bool?,
      featured: json['featured'] as bool?,
      brands: _parseStringList(json['brands']),
      tags: _parseStringList(json['tags']),
      attributes: _parseAttributes(json['attributes']),
      minRating: _parseDouble(json['minRating']),
      metadataFilter: json['metadataFilter'] as Map<String, dynamic>?,
    );
  }

  /// Convert ProductFilters to JSON
  Map<String, dynamic> toJson() {
    return {
      'page': page,
      'perPage': perPage,
      if (sortBy != null) 'sortBy': sortBy,
      if (sortOrder != null) 'sortOrder': sortOrder,
      if (categoryId != null) 'categoryId': categoryId,
      if (search != null) 'search': search,
      if (minPrice != null) 'minPrice': minPrice,
      if (maxPrice != null) 'maxPrice': maxPrice,
      if (inStock != null) 'inStock': inStock,
      if (onSale != null) 'onSale': onSale,
      if (featured != null) 'featured': featured,
      if (brands != null) 'brands': brands,
      if (tags != null) 'tags': tags,
      if (attributes != null) 'attributes': attributes,
      if (minRating != null) 'minRating': minRating,
      if (metadataFilter != null) 'metadataFilter': metadataFilter,
    };
  }

  /// Parse a value to double, handling both int and double types
  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is int) return value.toDouble();
    if (value is String) return double.tryParse(value);
    return null;
  }

  /// Parse a list of strings from various input types
  static List<String>? _parseStringList(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    if (value is String) {
      // Support comma-separated strings
      return value.split(',').map((e) => e.trim()).toList();
    }
    return null;
  }

  /// Parse attributes map with list values
  static Map<String, List<String>>? _parseAttributes(dynamic value) {
    if (value == null) return null;
    if (value is! Map) return null;

    final result = <String, List<String>>{};
    value.forEach((key, val) {
      final list = _parseStringList(val);
      if (list != null && list.isNotEmpty) {
        result[key.toString()] = list;
      }
    });

    return result.isNotEmpty ? result : null;
  }

  ProductFilters copyWith({
    int? page,
    int? perPage,
    String? sortBy,
    String? sortOrder,
    String? categoryId,
    String? search,
    double? minPrice,
    double? maxPrice,
    bool? inStock,
    bool? onSale,
    bool? featured,
    List<String>? brands,
    List<String>? tags,
    Map<String, List<String>>? attributes,
    double? minRating,
    Map<String, dynamic>? metadataFilter,
  }) {
    return ProductFilters(
      page: page ?? this.page,
      perPage: perPage ?? this.perPage,
      sortBy: sortBy ?? this.sortBy,
      sortOrder: sortOrder ?? this.sortOrder,
      categoryId: categoryId ?? this.categoryId,
      search: search ?? this.search,
      minPrice: minPrice ?? this.minPrice,
      maxPrice: maxPrice ?? this.maxPrice,
      inStock: inStock ?? this.inStock,
      onSale: onSale ?? this.onSale,
      featured: featured ?? this.featured,
      brands: brands ?? this.brands,
      tags: tags ?? this.tags,
      attributes: attributes ?? this.attributes,
      minRating: minRating ?? this.minRating,
      metadataFilter: metadataFilter ?? this.metadataFilter,
    );
  }

  ProductFilters clearFilter(String filterKey) {
    switch (filterKey) {
      case 'categoryId':
        return copyWith(categoryId: null);
      case 'search':
        return copyWith(search: null);
      case 'price':
        return copyWith(minPrice: null, maxPrice: null);
      case 'inStock':
        return copyWith(inStock: null);
      case 'onSale':
        return copyWith(onSale: null);
      case 'featured':
        return copyWith(featured: null);
      case 'brands':
        return copyWith(brands: []);
      case 'tags':
        return copyWith(tags: []);
      case 'attributes':
        return copyWith(attributes: {});
      case 'minRating':
        return copyWith(minRating: null);
      case 'metadataFilter':
        return copyWith(metadataFilter: {});
      default:
        return this;
    }
  }

  bool get hasActiveFilters {
    return categoryId != null ||
        search != null ||
        minPrice != null ||
        maxPrice != null ||
        inStock != null ||
        onSale != null ||
        featured != null ||
        (brands != null && brands!.isNotEmpty) ||
        (tags != null && tags!.isNotEmpty) ||
        (attributes != null && attributes!.isNotEmpty) ||
        minRating != null ||
        (metadataFilter != null && metadataFilter!.isNotEmpty);
  }

  int get activeFilterCount {
    int count = 0;
    if (categoryId != null) count++;
    if (search != null) count++;
    if (minPrice != null || maxPrice != null) count++;
    if (inStock != null) count++;
    if (onSale != null) count++;
    if (featured != null) count++;
    if (brands != null && brands!.isNotEmpty) count++;
    if (tags != null && tags!.isNotEmpty) count++;
    if (attributes != null && attributes!.isNotEmpty) count++;
    if (minRating != null) count++;
    if (metadataFilter != null && metadataFilter!.isNotEmpty) count++;
    return count;
  }

  List<Object?> get props => [
        page,
        perPage,
        sortBy,
        sortOrder,
        categoryId,
        search,
        minPrice,
        maxPrice,
        inStock,
        onSale,
        featured,
        brands,
        tags,
        attributes,
        minRating,
        metadataFilter,
      ];

  Map<String, dynamic> toQueryParams() {
    final params = <String, dynamic>{};
    if (categoryId != null) {
      params['category_id'] = categoryId.toString();
    }
    if (search != null) {
      params['search'] = search.toString();
    }
    if (minPrice != null) {
      params['min_price'] = minPrice.toString();
    }
    if (maxPrice != null) {
      params['max_price'] = maxPrice.toString();
    }
    if (inStock != null) {
      params['in_stock'] = inStock.toString();
    }
    if (onSale != null) {
      params['on_sale'] = onSale.toString();
    }
    if (featured != null) {
      params['featured'] = featured.toString();
    }
    if (brands != null && brands!.isNotEmpty) {
      params['brands'] = brands!.join(',');
    }
    if (tags != null && tags!.isNotEmpty) {
      params['tags'] = tags!.join(',');
    }
    if (minRating != null) {
      params['min_rating'] = minRating.toString();
    }
    if (attributes != null && attributes!.isNotEmpty) {
      attributes!.forEach((key, values) {
        if (values.isNotEmpty) {
          params['attribute_$key'] = values.join(',');
        }
      });
    }
    if (metadataFilter != null && metadataFilter!.isNotEmpty) {
      metadataFilter!.forEach((key, value) {
        params['metadata_$key'] = value.toString();
      });
    }
    return params;
  }

  String getFilterSummary() {
    final parts = <String>[];
    if (minPrice != null || maxPrice != null) {
      final min = minPrice != null ? '\$${minPrice!.toStringAsFixed(0)}' : '\$0';
      final max = maxPrice != null ? '\$${maxPrice!.toStringAsFixed(0)}' : '∞';
      parts.add('Price: $min - $max');
    }
    if (inStock == true) {
      parts.add('In Stock');
    }
    if (onSale == true) {
      parts.add('On Sale');
    }
    if (featured == true) {
      parts.add('Featured');
    }
    if (minRating != null) {
      parts.add('Rating: ${minRating!.toStringAsFixed(1)}+');
    }
    if (brands != null && brands!.isNotEmpty) {
      parts.add('Brands: ${brands!.join(", ")}');
    }
    if (tags != null && tags!.isNotEmpty) {
      parts.add('Tags: ${tags!.join(", ")}');
    }
    if (attributes != null && attributes!.isNotEmpty) {
      attributes!.forEach((key, values) {
        if (values.isNotEmpty) {
          parts.add('$key: ${values.join(", ")}');
        }
      });
    }
    if (metadataFilter != null && metadataFilter!.isNotEmpty) {
      metadataFilter!.forEach((key, value) {
        parts.add('$key: $value');
      });
    }
    return parts.isEmpty ? 'No filters applied' : parts.join(' • ');
  }

  ProductFilters merge(ProductFilters other) {
    return ProductFilters(
      page: other.page,
      perPage: other.perPage,
      sortBy: other.sortBy ?? sortBy,
      sortOrder: other.sortOrder ?? sortOrder,
      categoryId: other.categoryId ?? categoryId,
      search: other.search ?? search,
      minPrice: other.minPrice ?? minPrice,
      maxPrice: other.maxPrice ?? maxPrice,
      inStock: other.inStock ?? inStock,
      onSale: other.onSale ?? onSale,
      featured: other.featured ?? featured,
      brands: other.brands ?? brands,
      tags: other.tags ?? tags,
      attributes: other.attributes ?? attributes,
      minRating: other.minRating ?? minRating,
      metadataFilter: other.metadataFilter ?? metadataFilter,
    );
  }
}
