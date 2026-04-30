// ignore_for_file: public_member_api_docs
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

  /// Type of banner content (e.g., 'image', 'video', 'gif', etc.).
  /// Defaults to 'image' if not specified.
  final String type;

  /// Structured action invoked when the banner is tapped.
  final UserInteraction? action;

  /// Arbitrary metadata sent alongside analytics events.
  final Map<String, dynamic>? metadata;

  const PromoBanner({
    required this.id,
    required this.title,
    required this.imageUrl,
    this.type = 'image',
    this.subtitle,
    this.description,
    this.action,
    this.metadata,
    super.extensions,
  });

  /// Convenience parser for adapters that receive JSON payloads.
  factory PromoBanner.fromJson(Map<String, dynamic> json) {
    return PromoBanner(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString(),
      description: json['description']?.toString(),
      imageUrl: json['image']?.toString() ??
          json['imageUrl']?.toString() ??
          json['asset']?.toString() ??
          '',
      type: json['type']?.toString() ?? 'image',
      action: _parseAction(json),
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>(),
      extensions: json,
    );
  }

  PromoBanner copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? description,
    String? imageUrl,
    String? type,
    UserInteraction? action,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? extensions,
  }) {
    return PromoBanner(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      description: description ?? this.description,
      imageUrl: imageUrl ?? this.imageUrl,
      type: type ?? this.type,
      action: action ?? this.action,
      metadata: metadata ?? this.metadata,
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
      'type': type,
      'action': action?.toJson(),
      'metadata': metadata,
      'extensions': extensions,
    };
  }

  @override
  List<Object?> get props => [
        id,
        title,
        subtitle,
        description,
        imageUrl,
        type,
        action,
        metadata,
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
