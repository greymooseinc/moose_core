import 'package:flutter/material.dart';

import 'core_entity.dart';
import 'user_interaction.dart';

/// Represents a short-form content item similar to Instagram/Facebook Stories.
///
/// Shorts are typically displayed in a vertical scrolling gallery or
/// full-screen viewer with auto-advance functionality.
@immutable
class Short extends CoreEntity {
  /// Unique identifier for the short. Typically matches the backend ID.
  final String id;

  /// Title or caption for the short.
  final String title;

  /// Optional subtitle or secondary text.
  final String? subtitle;

  /// Optional longer description for accessibility.
  final String? description;

  /// Media URL (image or video) that will be displayed.
  final String mediaUrl;

  /// Type of media content (e.g., 'image', 'video', 'gif', etc.).
  /// Defaults to 'image' if not specified.
  final String type;

  /// Optional thumbnail URL for video content.
  /// Falls back to mediaUrl if not provided.
  final String? thumbnailUrl;

  /// Duration in seconds for how long the short should display.
  /// Used for auto-advance timing. Defaults to 5 seconds.
  final int duration;

  /// Structured action invoked when the short is tapped.
  final UserInteraction? action;

  /// Arbitrary metadata sent alongside analytics events.
  final Map<String, dynamic>? metadata;

  const Short({
    required this.id,
    required this.title,
    required this.mediaUrl,
    this.type = 'image',
    this.subtitle,
    this.description,
    this.thumbnailUrl,
    this.duration = 5,
    this.action,
    this.metadata,
    super.extensions,
  });

  /// Convenience parser for adapters that receive JSON payloads.
  factory Short.fromJson(Map<String, dynamic> json) {
    return Short(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      subtitle: json['subtitle']?.toString(),
      description: json['description']?.toString(),
      mediaUrl: json['media']?.toString() ??
          json['mediaUrl']?.toString() ??
          json['image']?.toString() ??
          json['imageUrl']?.toString() ??
          json['video']?.toString() ??
          json['videoUrl']?.toString() ??
          json['asset']?.toString() ??
          '',
      type: json['type']?.toString() ?? 'image',
      thumbnailUrl: json['thumbnail']?.toString() ?? json['thumbnailUrl']?.toString(),
      duration: _parseDuration(json['duration']),
      action: _parseAction(json),
      metadata: (json['metadata'] as Map?)?.cast<String, dynamic>(),
      extensions: json,
    );
  }

  static int _parseDuration(dynamic value) {
    if (value == null) return 5;
    if (value is int) return value > 0 ? value : 5;
    if (value is num) return value.toInt() > 0 ? value.toInt() : 5;
    if (value is String) {
      final parsed = int.tryParse(value);
      return parsed != null && parsed > 0 ? parsed : 5;
    }
    return 5;
  }

  Short copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? description,
    String? mediaUrl,
    String? type,
    String? thumbnailUrl,
    int? duration,
    UserInteraction? action,
    Map<String, dynamic>? metadata,
    Map<String, dynamic>? extensions,
  }) {
    return Short(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      description: description ?? this.description,
      mediaUrl: mediaUrl ?? this.mediaUrl,
      type: type ?? this.type,
      thumbnailUrl: thumbnailUrl ?? this.thumbnailUrl,
      duration: duration ?? this.duration,
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
      'mediaUrl': mediaUrl,
      'type': type,
      'thumbnailUrl': thumbnailUrl,
      'duration': duration,
      'action': action?.toJson(),
      'metadata': metadata,
      'extensions': extensions,
    };
  }

  /// Get the URL to display (thumbnail for videos, mediaUrl for images).
  String get displayUrl => thumbnailUrl ?? mediaUrl;

  @override
  List<Object?> get props => [
        id,
        title,
        subtitle,
        description,
        mediaUrl,
        type,
        thumbnailUrl,
        duration,
        action,
        metadata,
        extensions,
      ];

  @override
  String toString() {
    return 'Short(id: $id, title: $title, type: $type, duration: ${duration}s)';
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
