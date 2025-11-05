import 'product_filters.dart';

class FilterPreset {
  final String id;
  final String name;
  final String description;
  final ProductFilters filters;
  final String icon;

  const FilterPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.filters,
    required this.icon,
  });
}
