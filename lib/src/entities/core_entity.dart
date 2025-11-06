import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Base class for all core entities in the ecommerce system.
/// Provides common functionality including the extensions field for platform-specific data.
@immutable
abstract class CoreEntity extends Equatable {
  final Map<String, dynamic>? extensions;

  const CoreEntity({this.extensions});

  T? getExtension<T>(String key) {
    if (extensions == null) return null;
    final value = extensions![key];
    if (value == null) return null;
    return value as T?;
  }
}