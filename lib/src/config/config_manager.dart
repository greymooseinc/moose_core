class ConfigManager {
  static final ConfigManager _instance = ConfigManager._internal();
  factory ConfigManager() => _instance;
  ConfigManager._internal();

  Map<String, dynamic> _config = {};

  void initialize(Map<String, dynamic> config) {
    _config = config;
  }

  Map<String, dynamic> get config => _config;


  dynamic get(String key, {dynamic defaultValue}) {
    if (key.contains('.') || key.contains(':')) {
      return _getNestedValue(key) ?? defaultValue;
    }
    return _config[key] ?? defaultValue;
  }

  dynamic _getNestedValue(String key) {
    final parts = key.split(RegExp(r'[.:]'));
    dynamic current = _config;

    for (final part in parts) {
      if (current is Map) {
        current = current[part];
      } else {
        return null;
      }
    }

    return current;
  }

  String get platform => _config['platform'] ?? '';

  String get baseUrl => _config['baseUrl'] ?? '';

  bool has(String key) {
    if (key.contains('.') || key.contains(':')) {
      return _getNestedValue(key) != null;
    }
    return _config.containsKey(key);
  }
}
