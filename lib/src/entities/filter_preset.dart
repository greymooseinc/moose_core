import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

import 'product_filters.dart';

/// Represents a saved filter preset for quick product filtering.
@immutable
class FilterPreset extends Equatable {
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
  
  @override
  List<Object?> get props => [id, name, description];
}
