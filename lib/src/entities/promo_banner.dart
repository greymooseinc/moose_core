import 'package:flutter/material.dart';

import 'core_entity.dart';
import 'user_interaction.dart';

/// Represents a marketing banner or hero promotion that can be displayed
/// inside carousel sections, hero areas, or inline placements.
@immutable
class PromoBanner extends CoreEntity {
  /// Unique identifier for the banner. Typically matches the backend ID.
  final String id;

  /// Headline shown on top of the banner artwork.
  final String title;

  /// Optional supporting copy placed under the title.
  final String? subtitle;

  /// Optional longer description for accessibility or detail screens.
  final String? description;

  /// Image or video thumbnail URL that will be rendered in the UI.
  final String imageUrl;

  /// Structured action invoked when the banner is tapped.
  final UserInteraction? action;

  /// Arbitrary metadata sent alongside analytics events.
  final Map<String, dynamic>? metadata;

  /// Optional scheduling fields that adapters can use to filter active banners.
  final DateTime? startDate;
  final DateTime? endDate;

  const PromoBanner({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.subtitle,
    this.description,
    this.action,
    this.metadata,
    this.startDate,
    this.endDate,
    super.extensions,
  });

  /// Convenience parser for adapters that receive JSON payloads.
  factory PromoBanner.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      if (value is DateTime) return value;
      if (value is int) {
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      if (value is String && value.isNotEmpty) {
        return DateTime.tryParse(value);
      }
      return null;
    }

    return PromoBanner(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString(),
      description: json['description']?.toString(),
      imageUrl: json['image']?.toString() ??
          json['imageUrl']?.toString() ??
          json['asset']?.toString() ??
          '',
      action: _parseAction(json),
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>(),
      startDate: parseDate(json['startDate']),
      endDate: parseDate(json['endDate']),
      extensions: json,
    );
  }

  PromoBanner copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? description,
    String? imageUrl,
    UserInteraction? action,
    Map<String, dynamic>? metadata,
    DateTime? startDate,
    DateTime? endDate,
    Map<String, dynamic>? extensions,
  }) {
    return PromoBanner(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      action: action ?? this.action,
      metadata: metadata ?? this.metadata,
      startDate: startDate ?? this.startDate,
      endDate: endDate ?? this.endDate,
      extensions: extensions ?? this.extensions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'description': description,
      'imageUrl': imageUrl,
      'action': action?.toJson(),
      'metadata': metadata,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'extensions': extensions,
    };
  }

  /// Whether the banner should be considered active at the provided [moment].
  bool isActive({DateTime? moment}) {
    final now = moment ?? DateTime.now();
    final startsOk = startDate == null || !now.isBefore(startDate!);
    final endsOk = endDate == null || !now.isAfter(endDate!);
    return startsOk && endsOk;
  }

  @override
  List<Object?> get props => [
        id,
        title,
        subtitle,
        description,
        imageUrl,
        action,
        metadata,
        startDate,
        endDate,
        extensions,
      ];

  @override
  String toString() {
    return 'PromoBanner(id: $id, title: $title, action: $action)';
  }
}

UserInteraction? _parseAction(Map<String, dynamic> json) {
  final actionValue = json['action'];
  if (actionValue is Map<String, dynamic>) {
    return UserInteraction.fromJson(actionValue);
  }

  final route = json['actionRoute'] ?? json['route'];
  if (route is String && route.isNotEmpty) {
    final params = (json['actionParams'] ?? json['parameters']) as Map?;
    return UserInteraction.internal(
      route: route,
      parameters: params?.cast<String, dynamic>(),
    );
  }

  final urlValue = json['actionUrl'] ?? json['href'] ?? json['deeplink'];
  if (urlValue is String && urlValue.isNotEmpty) {
    final params = (json['actionParams'] ?? json['parameters']) as Map?;
    return UserInteraction.external(
      url: urlValue,
      parameters: params?.cast<String, dynamic>(),
    );
  }

  final customId = json['actionId'] ?? json['customActionId'];
  if (customId is String && customId.isNotEmpty) {
    final params = (json['actionParams'] ?? json['parameters']) as Map?;
    return UserInteraction.custom(
      actionId: customId,
      parameters: params?.cast<String, dynamic>(),
    );
  }

  return null;
}
