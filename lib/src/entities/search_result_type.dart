/// Types of search results supported by the system.
enum SearchResultType {
  product,
  category,
  tag,
  collection,
  post,
  page,
}

extension SearchResultTypeExtension on SearchResultType {
  String get label {
    switch (this) {
      case SearchResultType.product:
        return 'Product';
      case SearchResultType.category:
        return 'Category';
      case SearchResultType.tag:
        return 'Tag';
      case SearchResultType.collection:
        return 'Collection';
      case SearchResultType.post:
        return 'Post';
      case SearchResultType.page:
        return 'Page';
    }
  }

  String get pluralLabel {
    switch (this) {
      case SearchResultType.product:
        return 'Products';
      case SearchResultType.category:
        return 'Categories';
      case SearchResultType.tag:
        return 'Tags';
      case SearchResultType.collection:
        return 'Collections';
      case SearchResultType.post:
        return 'Posts';
      case SearchResultType.page:
        return 'Pages';
    }
  }
}
