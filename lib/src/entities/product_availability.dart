import 'package:flutter/material.dart';
import 'package:moose_core/src/entities/core_entity.dart';

/// Represents product availability status and stock information.
@immutable
class ProductAvailability extends CoreEntity {
  final bool isAvailable;
  final String message;
  final int availableQuantity;
  final bool canBackorder;

  const ProductAvailability({
    required this.isAvailable,
    required this.message,
    required this.availableQuantity,
    this.canBackorder = false,
    super.extensions,
  });
  
  @override
  List<Object?> get props => [isAvailable, message, availableQuantity, canBackorder];
}
