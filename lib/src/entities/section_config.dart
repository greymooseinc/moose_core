// ignore_for_file: public_member_api_docs
/// Configuration for product or content sections.
class SectionConfig {
  final String name;
  final String description;
  final bool active;
  final Map<String, dynamic> settings;

  const SectionConfig({
    required this.name,
    required this.description,
    this.active = true,
    this.settings = const {}
  });

  factory SectionConfig.fromJson(Map<String, dynamic> json) {
    return SectionConfig(
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      active: json['active'] as bool? ?? true,
      settings: json['settings'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'active': active,
      'settings': settings,
    };
  }

  SectionConfig copyWith({
    String? name,
    String? description,
    bool? active,
    Map<String, dynamic>? settings,
    Map<String, dynamic>? extensions,
  }) {
    return SectionConfig(
      name: name ?? this.name,
      description: description ?? this.description,
      active: active ?? this.active,
      settings: settings ?? this.settings,
    );
  }

  @override
  String toString() {
    return 'SectionConfig(name: $name, description: $description, active: $active, settings: $settings)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SectionConfig &&
        other.name == name &&
        other.description == description &&
        other.active == active &&
        _mapsEqual(other.settings, settings);
  }

  @override
  int get hashCode => name.hashCode ^ description.hashCode ^ active.hashCode ^ settings.hashCode;

  bool _mapsEqual(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }
}
