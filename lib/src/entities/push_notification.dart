import 'package:flutter/material.dart';
import 'package:moose_core/src/entities/core_entity.dart';

@immutable
class PushNotification extends CoreEntity {
  final String id;
  final String title;
  final String body;
  final String? imageUrl;
  final Map<String, dynamic>? data;
  final String? type;
  final String? route;
  final Map<String, dynamic>? routeParameters;
  final String? externalUrl;
  final DateTime receivedAt;
  final bool isRead;
  final bool receivedInForeground;
  final NotificationPriority priority;
  final int? badge;
  final String? sound;
  final String? channelId;

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
    super.extensions,
  });

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

  PushNotification markAsRead() {
    return copyWith(isRead: true);
  }

  bool get hasNavigationAction => route != null || externalUrl != null;

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

enum NotificationPriority {
  low,
  defaultPriority,
  high,
}

enum NotificationPermissionStatus {
  notDetermined,
  denied,
  authorized,
  provisional,
}

/// Represents notification settings and preferences for the user.
@immutable
class NotificationSettings extends CoreEntity {
  final bool enabled;
  final bool showInForeground;
  final bool playSound;
  final bool showBadge;
  final Set<String> enabledTypes;

  const NotificationSettings({
    this.enabled = true,
    this.showInForeground = true,
    this.playSound = true,
    this.showBadge = true,
    this.enabledTypes = const {},
    super.extensions,
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
