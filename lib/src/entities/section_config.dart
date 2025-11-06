class SectionConfig {
  final String name;
  final String description;
  final Map<String, dynamic> settings;
  final Map<String, dynamic>? extensions;

  const SectionConfig({
    required this.name,
    required this.description,
    this.settings = const {},
    this.extensions,
  });

  factory SectionConfig.fromJson(Map<String, dynamic> json) {
    return SectionConfig(
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      settings: json['settings'] as Map<String, dynamic>? ?? {},
      extensions: json['extensions'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'settings': settings,
      'extensions': extensions,
    };
  }

  SectionConfig copyWith({
    String? name,
    String? description,
    Map<String, dynamic>? settings,
    Map<String, dynamic>? extensions,
  }) {
    return SectionConfig(
      name: name ?? this.name,
      description: description ?? this.description,
      settings: settings ?? this.settings,
      extensions: extensions ?? this.extensions,
    );
  }

  @override
  String toString() {
    return 'SectionConfig(name: $name, description: $description, settings: $settings)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is SectionConfig &&
        other.name == name &&
        other.description == description &&
        _mapsEqual(other.settings, settings);
  }

  @override
  int get hashCode => name.hashCode ^ description.hashCode ^ settings.hashCode;

  bool _mapsEqual(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) return false;
    }
    return true;
  }
}
