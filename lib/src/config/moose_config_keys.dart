/// Static helpers for canonical moose_core config path strings.
///
/// Use these instead of inline string literals to ensure consistent
/// key formatting across all callers.
class MooseConfigKeys {
  MooseConfigKeys._();

  static String pluginSettings(String pluginName, String key) =>
      'plugins:$pluginName:settings:$key';

  static String pluginRoot(String pluginName) => 'plugins:$pluginName';

  static String adapterSettings(String adapterName, String key) =>
      'adapters:$adapterName:settings:$key';

  static String adapterRoot(String adapterName) => 'adapters:$adapterName';

  static const String pages = 'pages';
  static const String theme = 'theme';
}
