import 'package:equatable/equatable.dart';

/// Push notification entity
///
/// Platform-agnostic representation of a push notification.
/// Adapters convert provider-specific formats (FCM, OneSignal, etc.) into this entity.
class PushNotification extends Equatable {
  /// Unique notification ID
  final String id;

  /// Notification title
  final String title;

  /// Notification body/message
  final String body;

  /// Notification image URL (optional)
  final String? imageUrl;

  /// Custom data payload
  /// Use this for deep linking, tracking, or custom actions
  final Map<String, dynamic>? data;

  /// Notification type (e.g., 'order', 'promotion', 'chat', 'general')
  /// Used for categorization and filtering
  final String? type;

  /// Deep link or route to navigate to when tapped
  final String? route;

  /// Route parameters for navigation
  final Map<String, dynamic>? routeParameters;

  /// External URL to open (if not using in-app routing)
  final String? externalUrl;

  /// When the notification was received
  final DateTime receivedAt;

  /// Whether the notification has been read
  final bool isRead;

  /// Whether the notification was received while app was in foreground
  final bool receivedInForeground;

  /// Priority level (high, default, low)
  final NotificationPriority priority;

  /// Badge count (for iOS)
  final int? badge;

  /// Sound to play
  final String? sound;

  /// Channel ID (for Android)
  final String? channelId;
  final Map<String, dynamic>? extensions;

  const PushNotification({
    required this.id,
    required this.title,
    required this.body,
    this.imageUrl,
    this.data,
    this.type,
    this.route,
    this.routeParameters,
    this.externalUrl,
    required this.receivedAt,
    this.isRead = false,
    this.receivedInForeground = false,
    this.priority = NotificationPriority.defaultPriority,
    this.badge,
    this.sound,
    this.channelId,
    this.extensions,
  });

  /// Create a copy with modified fields
  PushNotification copyWith({
    String? id,
    String? title,
    String? body,
    String? imageUrl,
    Map<String, dynamic>? data,
    String? type,
    String? route,
    Map<String, dynamic>? routeParameters,
    String? externalUrl,
    DateTime? receivedAt,
    bool? isRead,
    bool? receivedInForeground,
    NotificationPriority? priority,
    int? badge,
    String? sound,
    String? channelId,
    Map<String, dynamic>? extensions,
  }) {
    return PushNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      body: body ?? this.body,
      imageUrl: imageUrl ?? this.imageUrl,
      data: data ?? this.data,
      type: type ?? this.type,
      route: route ?? this.route,
      routeParameters: routeParameters ?? this.routeParameters,
      externalUrl: externalUrl ?? this.externalUrl,
      receivedAt: receivedAt ?? this.receivedAt,
      isRead: isRead ?? this.isRead,
      receivedInForeground: receivedInForeground ?? this.receivedInForeground,
      priority: priority ?? this.priority,
      badge: badge ?? this.badge,
      sound: sound ?? this.sound,
      channelId: channelId ?? this.channelId,
      extensions: extensions ?? this.extensions,
    );
  }

  /// Mark notification as read
  PushNotification markAsRead() {
    return copyWith(isRead: true);
  }

  /// Check if notification has a navigation action
  bool get hasNavigationAction => route != null || externalUrl != null;

  /// Get the notification summary (for display in lists)
  String get summary => body.length > 100 ? '${body.substring(0, 100)}...' : body;

  @override
  List<Object?> get props => [
        id,
        title,
        body,
        imageUrl,
        data,
        type,
        route,
        routeParameters,
        externalUrl,
        receivedAt,
        isRead,
        receivedInForeground,
        priority,
        badge,
        sound,
        channelId,
      ];

  @override
  String toString() {
    return 'PushNotification(id: $id, title: $title, type: $type, isRead: $isRead)';
  }
}

/// Notification priority levels
enum NotificationPriority {
  low,
  defaultPriority,
  high,
}

/// Notification permission status
enum NotificationPermissionStatus {
  /// Permission not yet requested
  notDetermined,

  /// Permission denied by user
  denied,

  /// Permission granted
  authorized,

  /// Permission granted with restrictions (iOS only)
  provisional,
}

/// Notification settings for the app
class NotificationSettings extends Equatable {
  final bool enabled;
  final bool showInForeground;
  final bool playSound;
  final bool showBadge;
  final Set<String> enabledTypes;
  final Map<String, dynamic>? extensions;

  const NotificationSettings({
    this.enabled = true,
    this.showInForeground = true,
    this.playSound = true,
    this.showBadge = true,
    this.enabledTypes = const {},
    this.extensions,
  });

  NotificationSettings copyWith({
    bool? enabled,
    bool? showInForeground,
    bool? playSound,
    bool? showBadge,
    Set<String>? enabledTypes,
    Map<String, dynamic>? extensions,
  }) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      showInForeground: showInForeground ?? this.showInForeground,
      playSound: playSound ?? this.playSound,
      showBadge: showBadge ?? this.showBadge,
      enabledTypes: enabledTypes ?? this.enabledTypes,
      extensions: extensions ?? this.extensions,
    );
  }

  /// Check if a specific notification type is enabled
  bool isTypeEnabled(String type) {
    if (!enabled) return false;
    if (enabledTypes.isEmpty) return true; // If no types specified, all enabled
    return enabledTypes.contains(type);
  }

  @override
  List<Object?> get props => [
        enabled,
        showInForeground,
        playSound,
        showBadge,
        enabledTypes,
      ];
}
