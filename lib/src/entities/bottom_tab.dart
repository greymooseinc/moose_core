import 'package:flutter/material.dart';

/// Configuration for a bottom navigation tab
class BottomTab {
  final String id;
  final String label;
  final IconData icon;
  final IconData? activeIcon;
  final String route;
  final Map<String, dynamic>? routeArguments;
  final bool enabled;
  final Map<String, dynamic> extensions;

  const BottomTab({
    required this.id,
    required this.label,
    required this.icon,
    this.activeIcon,
    required this.route,
    this.routeArguments,
    this.enabled = true,
    this.extensions = const {},
  });

  factory BottomTab.fromJson(Map<String, dynamic> json) {
    return BottomTab(
      id: json['id'] as String? ?? '',
      label: json['label'] as String? ?? '',
      icon: _iconFromString(json['icon'] as String?),
      activeIcon: json['activeIcon'] != null
          ? _iconFromString(json['activeIcon'] as String?)
          : null,
      route: json['route'] as String? ?? '/',
      routeArguments: json['routeArguments'] as Map<String, dynamic>?,
      enabled: json['enabled'] as bool? ?? true,
      extensions: json['extensions'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'label': label,
      'icon': _iconToString(icon),
      if (activeIcon != null) 'activeIcon': _iconToString(activeIcon!),
      'route': route,
      if (routeArguments != null) 'routeArguments': routeArguments,
      'enabled': enabled,
      'extensions': extensions,
    };
  }

  BottomTab copyWith({
    String? id,
    String? label,
    IconData? icon,
    IconData? activeIcon,
    String? route,
    Map<String, dynamic>? routeArguments,
    bool? enabled,
    Map<String, dynamic>? extensions,
  }) {
    return BottomTab(
      id: id ?? this.id,
      label: label ?? this.label,
      icon: icon ?? this.icon,
      activeIcon: activeIcon ?? this.activeIcon,
      route: route ?? this.route,
      routeArguments: routeArguments ?? this.routeArguments,
      enabled: enabled ?? this.enabled,
      extensions: extensions ?? this.extensions,
    );
  }

  T? getExtension<T>(String key) {
    return extensions[key] as T?;
  }

  @override
  String toString() {
    return 'BottomTab(id: $id, label: $label, route: $route, enabled: $enabled)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is BottomTab &&
        other.id == id &&
        other.label == label &&
        other.icon == icon &&
        other.activeIcon == activeIcon &&
        other.route == route &&
        other.enabled == enabled;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        label.hashCode ^
        icon.hashCode ^
        activeIcon.hashCode ^
        route.hashCode ^
        enabled.hashCode;
  }

  static IconData _iconFromString(String? iconName) {
    if (iconName == null || iconName.isEmpty) {
      return Icons.home_outlined;
    }

    // Map common icon names to IconData
    switch (iconName.toLowerCase()) {
      case 'home':
      case 'home_outlined':
        return Icons.home_outlined;
      case 'home_filled':
        return Icons.home;
      case 'search':
      case 'search_outlined':
        return Icons.search_outlined;
      case 'search_filled':
        return Icons.search;
      case 'shopping_bag':
      case 'shopping_bag_outlined':
        return Icons.shopping_bag_outlined;
      case 'shopping_bag_filled':
        return Icons.shopping_bag;
      case 'person':
      case 'person_outlined':
        return Icons.person_outline;
      case 'person_filled':
        return Icons.person;
      case 'favorite':
      case 'favorite_outlined':
        return Icons.favorite_border;
      case 'favorite_filled':
        return Icons.favorite;
      case 'category':
      case 'category_outlined':
        return Icons.category_outlined;
      case 'category_filled':
        return Icons.category;
      case 'notifications':
      case 'notifications_outlined':
        return Icons.notifications_outlined;
      case 'notifications_filled':
        return Icons.notifications;
      case 'settings':
      case 'settings_outlined':
        return Icons.settings_outlined;
      case 'settings_filled':
        return Icons.settings;
      case 'menu':
        return Icons.menu;
      case 'more_horiz':
        return Icons.more_horiz;
      case 'more_vert':
        return Icons.more_vert;
      default:
        return Icons.home_outlined;
    }
  }

  static String _iconToString(IconData icon) {
    // Reverse mapping for common icons
    if (icon == Icons.home_outlined) return 'home_outlined';
    if (icon == Icons.home) return 'home_filled';
    if (icon == Icons.search_outlined) return 'search_outlined';
    if (icon == Icons.search) return 'search_filled';
    if (icon == Icons.shopping_bag_outlined) return 'shopping_bag_outlined';
    if (icon == Icons.shopping_bag) return 'shopping_bag_filled';
    if (icon == Icons.person_outline) return 'person_outlined';
    if (icon == Icons.person) return 'person_filled';
    if (icon == Icons.favorite_border) return 'favorite_outlined';
    if (icon == Icons.favorite) return 'favorite_filled';
    if (icon == Icons.category_outlined) return 'category_outlined';
    if (icon == Icons.category) return 'category_filled';
    if (icon == Icons.notifications_outlined) return 'notifications_outlined';
    if (icon == Icons.notifications) return 'notifications_filled';
    if (icon == Icons.settings_outlined) return 'settings_outlined';
    if (icon == Icons.settings) return 'settings_filled';
    if (icon == Icons.menu) return 'menu';
    if (icon == Icons.more_horiz) return 'more_horiz';
    if (icon == Icons.more_vert) return 'more_vert';
    return 'home_outlined';
  }
}
