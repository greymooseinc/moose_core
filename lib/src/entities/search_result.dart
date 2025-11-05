import 'package:equatable/equatable.dart';
import 'search_result_type.dart';

/// Generic search result that can represent any searchable entity
class SearchResult extends Equatable {
  final String id;
  final String title;
  final String? description;
  final String? imageUrl;
  final SearchResultType type;
  final Map<String, dynamic> metadata;

  const SearchResult({
    required this.id,
    required this.title,
    this.description,
    this.imageUrl,
    required this.type,
    this.metadata = const {},
  });

  factory SearchResult.fromJson(Map<String, dynamic> json) {
    return SearchResult(
      id: json['id']?.toString() ?? '',
      title: json['title'] ?? '',
      description: json['description'],
      imageUrl: json['image_url'],
      type: _parseType(json['type']),
      metadata: json['metadata'] as Map<String, dynamic>? ?? {},
    );
  }

  static SearchResultType _parseType(dynamic type) {
    if (type is String) {
      switch (type.toLowerCase()) {
        case 'product':
          return SearchResultType.product;
        case 'category':
          return SearchResultType.category;
        case 'tag':
          return SearchResultType.tag;
        case 'collection':
          return SearchResultType.collection;
        case 'post':
          return SearchResultType.post;
        case 'page':
          return SearchResultType.page;
        default:
          return SearchResultType.product;
      }
    }
    return SearchResultType.product;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'image_url': imageUrl,
      'type': type.name,
      'metadata': metadata,
    };
  }

  @override
  List<Object?> get props => [id, title, type];

  @override
  String toString() {
    return 'SearchResult(id: $id, title: $title, type: ${type.label})';
  }
}
