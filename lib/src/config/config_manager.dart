

class ConfigManager {
  ConfigManager();

  Map<String, dynamic> _config = {};
  final Map<String, Map<String, dynamic>> _pluginDefaults = {};
  final Map<String, Map<String, dynamic>> _adapterDefaults = {};

  void initialize(Map<String, dynamic> config) {
    _config = config;
  }

  Map<String, dynamic> get config => _config;

  /// Registers default settings for a plugin.
  ///
  /// These defaults will be used as fallback when accessing plugin settings
  /// that don't exist in environment.json.
  ///
  /// **Parameters:**
  /// - [pluginName]: Name of the plugin
  /// - [defaults]: Default settings map from plugin.getDefaultSettings()
  ///
  /// **Example:**
  /// ```dart
  /// configManager.registerPluginDefaults('products', {
  ///   'cache': {'productsTTL': 300},
  ///   'display': {'itemsPerPage': 20},
  /// });
  /// ```
  void registerPluginDefaults(String pluginName, Map<String, dynamic> defaults) {
    _pluginDefaults[pluginName] = defaults;
  }

  /// Registers default settings for an adapter.
  ///
  /// These defaults will be used as fallback when accessing adapter settings
  /// that don't exist in environment.json.
  ///
  /// **Parameters:**
  /// - [adapterName]: Name of the adapter
  /// - [defaults]: Default settings map from adapter.getDefaultSettings()
  ///
  /// **Example:**
  /// ```dart
  /// configManager.registerAdapterDefaults('shopify', {
  ///   'apiVersion': '2024-01',
  /// });
  /// ```
  void registerAdapterDefaults(String adapterName, Map<String, dynamic> defaults) {
    _adapterDefaults[adapterName] = defaults;
  }

  dynamic get(String key, {dynamic defaultValue}) {
    if (key.contains('.') || key.contains(':')) {
      final value = _getNestedValue(key);

      // If value found in config, return it
      if (value != null) return value;

      // Try to get from plugin/adapter defaults
      final defaultFromRegistry = _getDefaultValue(key);
      if (defaultFromRegistry != null) return defaultFromRegistry;

      // Fallback to provided defaultValue
      return defaultValue;
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

  /// Gets default value from registered plugin/adapter defaults.
  ///
  /// Supports keys like:
  /// - 'plugins:products:settings:cache:productsTTL'
  /// - 'adapters:shopify:apiVersion'
  dynamic _getDefaultValue(String key) {
    final parts = key.split(RegExp(r'[.:]'));

    // Check if it's a plugin settings key
    if (parts.length >= 3 && parts[0] == 'plugins') {
      final pluginName = parts[1];

      // Get plugin defaults
      final pluginDefaults = _pluginDefaults[pluginName];
      if (pluginDefaults == null) return null;

      // Navigate to the specific setting
      // Skip 'plugins', pluginName, and 'settings' to get to actual config path
      final settingsIndex = parts.indexOf('settings');
      if (settingsIndex == -1) return null;

      dynamic current = pluginDefaults;
      for (var i = settingsIndex + 1; i < parts.length; i++) {
        if (current is Map) {
          current = current[parts[i]];
        } else {
          return null;
        }
      }

      return current;
    }

    // Check if it's an adapter settings key
    if (parts.length >= 2 && parts[0] == 'adapters') {
      final adapterName = parts[1];

      // Get adapter defaults
      final adapterDefaults = _adapterDefaults[adapterName];
      if (adapterDefaults == null) return null;

      // Navigate to the specific setting
      dynamic current = adapterDefaults;
      for (var i = 2; i < parts.length; i++) {
        if (current is Map) {
          current = current[parts[i]];
        } else {
          return null;
        }
      }

      return current;
    }

    return null;
  }

  bool has(String key) {
    if (key.contains('.') || key.contains(':')) {
      return _getNestedValue(key) != null;
    }
    return _config.containsKey(key);
  }
}
