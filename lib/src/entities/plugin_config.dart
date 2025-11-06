/// Configuration for feature plugins in the application.
///
/// Controls plugin activation and stores plugin-specific settings.
/// If no plugin configuration is defined in environment.json, the plugin
/// is considered active by default.
class PluginConfig {
  final String name;
  final bool active;
  final Map<String, dynamic> settings;

  const PluginConfig({
    required this.name,
    this.active = true,
    this.settings = const {},
  });

  factory PluginConfig.fromJson(String name, Map<String, dynamic> json) {
    return PluginConfig(
      name: name,
      active: json['active'] as bool? ?? true,
      settings: json['settings'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'active': active,
      'settings': settings,
    };
  }

  PluginConfig copyWith({
    String? name,
    bool? active,
    Map<String, dynamic>? settings,
  }) {
    return PluginConfig(
      name: name ?? this.name,
      active: active ?? this.active,
      settings: settings ?? this.settings,
    );
  }

  @override
  String toString() {
    return 'PluginConfig(name: $name, active: $active, settings: $settings)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is PluginConfig &&
        other.name == name &&
        other.active == active &&
        _mapsEqual(other.settings, settings);
  }

  @override
  int get hashCode => name.hashCode ^ active.hashCode ^ settings.hashCode;

  bool _mapsEqual(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }

  /// Gets a setting value with type casting.
  T? getSetting<T>(String key) {
    if (!settings.containsKey(key)) return null;
    final value = settings[key];
    if (value == null) return null;
    return value as T?;
  }

  /// Checks if a setting exists.
  bool hasSetting(String key) => settings.containsKey(key);
}
