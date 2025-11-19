import 'package:flutter/material.dart';
import 'package:moose_core/src/entities/core_entity.dart';

enum UserInteractionType {
  internal,
  external,
  none,
  custom,
}

/// Represents a user interaction action for navigation and deep linking.
/// Supports internal routes, external URLs, and custom action handlers.
@immutable
class UserInteraction extends CoreEntity {
  final UserInteractionType interactionType;
  final String? route;
  final String? url;
  final Map<String, dynamic>? parameters;
  final String? customActionId;

  const UserInteraction({
    required this.interactionType,
    this.route,
    this.url,
    this.parameters,
    this.customActionId,
    super.extensions,
  });

  factory UserInteraction.internal({
    required String route,
    Map<String, dynamic>? parameters,
    Map<String, dynamic>? extensions,
  }) {
    return UserInteraction(
      interactionType: UserInteractionType.internal,
      route: route,
      parameters: parameters,
      extensions: extensions,
    );
  }

  factory UserInteraction.external({
    required String url,
    Map<String, dynamic>? parameters,
    Map<String, dynamic>? extensions,
  }) {
    return UserInteraction(
      interactionType: UserInteractionType.external,
      url: url,
      parameters: parameters,
      extensions: extensions,
    );
  }

  factory UserInteraction.none() {
    return const UserInteraction(
      interactionType: UserInteractionType.none,
    );
  }

  factory UserInteraction.custom({
    required String actionId,
    Map<String, dynamic>? parameters,
    Map<String, dynamic>? extensions,
  }) {
    return UserInteraction(
      interactionType: UserInteractionType.custom,
      customActionId: actionId,
      parameters: parameters,
      extensions: extensions,
    );
  }

  UserInteraction copyWith({
    UserInteractionType? interactionType,
    String? route,
    String? url,
    Map<String, dynamic>? parameters,
    String? customActionId,
    Map<String, dynamic>? extensions,
  }) {
    return UserInteraction(
      interactionType: interactionType ?? this.interactionType,
      route: route ?? this.route,
      url: url ?? this.url,
      parameters: parameters ?? this.parameters,
      customActionId: customActionId ?? this.customActionId,
      extensions: extensions ?? this.extensions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'interactionType': interactionType.name,
      if (route != null) 'route': route,
      if (url != null) 'url': url,
      if (parameters != null) 'parameters': parameters,
      if (customActionId != null) 'customActionId': customActionId,
      'extensions': extensions,
    };
  }

  factory UserInteraction.fromJson(Map<String, dynamic> json) {
    final typeStr = json['interactionType'] as String? ?? 'none';
    final interactionType = UserInteractionType.values.firstWhere(
      (e) => e.name == typeStr,
      orElse: () => UserInteractionType.none,
    );

    return UserInteraction(
      interactionType: interactionType,
      route: json['route'] as String?,
      url: json['url'] as String?,
      parameters: json['parameters'] as Map<String, dynamic>?,
      customActionId: json['customActionId'] as String?,
      extensions: json['extensions'] as Map<String, dynamic>?,
    );
  }

  @override
  String toString() {
    return 'UserInteraction(interactionType: $interactionType, route: $route, url: $url, customActionId: $customActionId, parameters: $parameters)';
  }

  bool get isValid {
    switch (interactionType) {
      case UserInteractionType.internal:
        return route != null && route!.isNotEmpty;
      case UserInteractionType.external:
        return url != null && url!.isNotEmpty;
      case UserInteractionType.custom:
        return customActionId != null && customActionId!.isNotEmpty;
      case UserInteractionType.none:
        return true;
    }
  }

  String get description {
    switch (interactionType) {
      case UserInteractionType.internal:
        return 'Navigate to ${route ?? "unknown route"}';
      case UserInteractionType.external:
        return 'Open ${url ?? "unknown URL"}';
      case UserInteractionType.custom:
        return 'Custom action: ${customActionId ?? "unknown"}';
      case UserInteractionType.none:
        return 'No action';
    }
  }
  
  @override
  List<Object?> get props => [interactionType, route, url];
}
