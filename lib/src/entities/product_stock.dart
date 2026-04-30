// ignore_for_file: public_member_api_docs
import 'package:flutter/material.dart';
import 'package:moose_core/src/entities/core_entity.dart';

/// Represents product stock status and inventory information.
@immutable
class ProductStock extends CoreEntity {
  final bool inStock;
  final int? quantity;
  final String status;
  final bool backordersAllowed;

  const ProductStock({
    required this.inStock,
    this.quantity,
    required this.status,
    this.backordersAllowed = false,
    super.extensions,
  });
  
  @override
  List<Object?> get props => [inStock, quantity, status];
}
