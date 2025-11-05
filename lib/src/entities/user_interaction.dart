/// Type of interaction action to perform
enum UserInteractionType {
  /// Navigate to an internal route within the app
  internal,

  /// Open an external URL (browser or webview)
  external,

  /// No action - display only
  none,

  /// Custom action type - handled by registered custom handlers
  custom,
}

/// Defines the action to perform when an entity is interacted with
/// This is a generic class that can be used with any entity type (collections, products, etc.)
class UserInteraction {
  /// Type of interaction to perform
  final UserInteractionType interactionType;

  /// Internal route path (used when interactionType is internal)
  /// Example: '/products/category/123'
  final String? route;

  /// External URL (used when interactionType is external)
  /// Example: 'https://example.com/sale'
  final String? url;

  /// Parameters to pass with the interaction
  /// For internal routes: route arguments
  /// For external URLs: query parameters
  /// For custom handlers: custom data
  final Map<String, dynamic>? parameters;

  /// Custom action identifier (used when interactionType is custom)
  /// Example: 'camera', 'share', 'download'
  final String? customActionId;

  const UserInteraction({
    required this.interactionType,
    this.route,
    this.url,
    this.parameters,
    this.customActionId,
  });

  /// Create an internal navigation action
  factory UserInteraction.internal({
    required String route,
    Map<String, dynamic>? parameters,
  }) {
    return UserInteraction(
      interactionType: UserInteractionType.internal,
      route: route,
      parameters: parameters,
    );
  }

  /// Create an external URL action
  factory UserInteraction.external({
    required String url,
    Map<String, dynamic>? parameters,
  }) {
    return UserInteraction(
      interactionType: UserInteractionType.external,
      url: url,
      parameters: parameters,
    );
  }

  /// Create a no-action instance
  factory UserInteraction.none() {
    return const UserInteraction(
      interactionType: UserInteractionType.none,
    );
  }

  /// Create a custom action
  factory UserInteraction.custom({
    required String actionId,
    Map<String, dynamic>? parameters,
  }) {
    return UserInteraction(
      interactionType: UserInteractionType.custom,
      customActionId: actionId,
      parameters: parameters,
    );
  }

  UserInteraction copyWith({
    UserInteractionType? interactionType,
    String? route,
    String? url,
    Map<String, dynamic>? parameters,
    String? customActionId,
  }) {
    return UserInteraction(
      interactionType: interactionType ?? this.interactionType,
      route: route ?? this.route,
      url: url ?? this.url,
      parameters: parameters ?? this.parameters,
      customActionId: customActionId ?? this.customActionId,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'interactionType': interactionType.name,
      if (route != null) 'route': route,
      if (url != null) 'url': url,
      if (parameters != null) 'parameters': parameters,
      if (customActionId != null) 'customActionId': customActionId,
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
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserInteraction &&
          runtimeType == other.runtimeType &&
          interactionType == other.interactionType &&
          route == other.route &&
          url == other.url &&
          customActionId == other.customActionId &&
          _mapEquals(parameters, other.parameters);

  @override
  int get hashCode =>
      interactionType.hashCode ^
      route.hashCode ^
      url.hashCode ^
      customActionId.hashCode ^
      parameters.hashCode;

  bool _mapEquals(Map<String, dynamic>? a, Map<String, dynamic>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }

  @override
  String toString() {
    return 'UserInteraction(interactionType: $interactionType, route: $route, url: $url, customActionId: $customActionId, parameters: $parameters)';
  }

  /// Check if this interaction is valid and can be executed
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

  /// Get a user-friendly description of the interaction
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
}
