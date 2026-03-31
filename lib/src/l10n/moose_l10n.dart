import 'package:flutter/foundation.dart';

/// Runtime localisation for moose_core applications.
///
/// [MooseL10n] provides a two-layer string lookup:
///
///  1. **Plugin defaults** — registered by each [FeaturePlugin] during
///     [onRegister] via [registerDefaults]. These are the built-in English
///     strings; they are always present and act as the final fallback.
///  2. **Client overrides** — loaded from JSON files (one per locale) by the
///     `LocalizationPlugin`. They shadow the defaults for the active locale.
///
/// ## Key convention
///
/// Keys use dot-separated namespacing: `'<pluginId>.<camelCaseKey>'`.
/// The plugin-id prefix deduplicates keys across plugins without any
/// central registry:
///
/// ```
/// 'auth.signIn'
/// 'cart.emptyMessage'
/// 'products.noProductsFound'
/// ```
///
/// ## Template interpolation
///
/// Values may contain `{paramName}` placeholders. Pass named replacements
/// via the `params` argument:
///
/// ```dart
/// // String value: 'Hello, {name}!'
/// context.moose.l10n('auth.greeting', params: {'name': 'Alice'});
/// // → 'Hello, Alice!'
/// ```
///
/// ## Locale switching
///
/// Call [setLocale] whenever the active locale changes (typically from a
/// `moose.locale.event.changed` EventBus subscription in `LocalizationPlugin`).
/// The [call] operator immediately uses the new locale on the next call.
/// Widget rebuilds are driven by `LocaleManagerPlugin`'s `LocaleNotifier`
/// which updates `MaterialApp.locale`, causing a full subtree rebuild.
///
/// ## Usage in widgets
///
/// ```dart
/// // Simple lookup
/// Text(context.moose.l10n('cart.checkout'))
///
/// // With parameters
/// Text(context.moose.l10n('review.photoCount', params: {'count': '3'}))
///
/// // With explicit fallback (useful in third-party code)
/// Text(context.moose.l10n('myPlugin.title', fallback: 'My Plugin'))
/// ```
class MooseL10n extends ChangeNotifier {
  /// Plugin defaults, merged from all [registerDefaults] calls.
  ///
  /// Keys are fully-qualified (e.g. `'auth.signIn'`). Entries are never
  /// removed; a later registration for the same key overwrites the earlier one.
  final Map<String, String> _defaults = {};

  /// Per-locale override maps loaded from external JSON files.
  ///
  /// Top-level keys are IETF language tags (`'en'`, `'fr'`, `'ja'`). Inner
  /// maps use the same fully-qualified key space as [_defaults].
  final Map<String, Map<String, String>> _overrides = {};

  /// The currently active IETF language tag. Defaults to `'en'`.
  String _activeLocale = 'en';

  /// Incremented on every locale change or override load so [MooseScope] can
  /// detect that a rebuild propagating new strings is needed.
  int _generation = 0; // ignore: prefer_final_fields

  /// Monotonically increasing counter — changes whenever [setLocale] switches
  /// locale or [applyOverrides] loads new strings for the active locale.
  int get generation => _generation;

  // ---------------------------------------------------------------------------
  // Registration
  // ---------------------------------------------------------------------------

  /// Registers default (English) strings for [pluginId].
  ///
  /// Called by each [FeaturePlugin] at the top of [onRegister] to seed the
  /// default layer. [strings] maps bare camelCase keys to English values —
  /// the [pluginId] prefix is added automatically:
  ///
  /// ```dart
  /// appContext.l10n.registerDefaults('auth', {
  ///   'signIn': 'Sign In',
  ///   'signOut': 'Sign Out',
  ///   'greeting': 'Hello, {name}!',
  /// });
  /// // Registers: 'auth.signIn', 'auth.signOut', 'auth.greeting'
  /// ```
  ///
  /// Calling this multiple times for the same [pluginId] is safe — later
  /// entries overwrite earlier ones for duplicate keys.
  void registerDefaults(String pluginId, Map<String, String> strings) {
    for (final entry in strings.entries) {
      _defaults['$pluginId.${entry.key}'] = entry.value;
    }
  }

  // ---------------------------------------------------------------------------
  // Override management
  // ---------------------------------------------------------------------------

  /// Applies locale-specific string overrides loaded from an external file.
  ///
  /// Called by `LocalizationPlugin` after loading a JSON override file for
  /// [locale]. The [strings] map uses the same fully-qualified key format as
  /// [_defaults] (e.g. `'auth.signIn'`).
  ///
  /// Multiple calls for the same [locale] accumulate; later entries win.
  void applyOverrides(String locale, Map<String, String> strings) {
    _overrides[locale] = {
      ...?_overrides[locale],
      ...strings,
    };
    // If the overrides just loaded are for the active locale, notify listeners
    // so widgets rebuild with the newly available translated strings.
    if (locale == _activeLocale) {
      _generation++;
      notifyListeners();
    }
  }

  /// Returns `true` if at least one override map has been loaded for [locale].
  bool hasOverridesFor(String locale) => _overrides.containsKey(locale);

  // ---------------------------------------------------------------------------
  // Locale management
  // ---------------------------------------------------------------------------

  /// Sets the active locale to [locale].
  ///
  /// Immediately affects all subsequent [call] invocations. Typically called
  /// by `LocalizationPlugin` in response to a `moose.locale.event.changed`
  /// EventBus event.
  void setLocale(String locale) {
    if (_activeLocale == locale) return;
    _activeLocale = locale;
    _generation++;
    notifyListeners();
  }

  /// The currently active IETF language tag.
  String get activeLocale => _activeLocale;

  // ---------------------------------------------------------------------------
  // Lookup
  // ---------------------------------------------------------------------------

  /// Looks up [key] in the active locale, falling back through the layers.
  ///
  /// Resolution order:
  ///
  ///  1. Override for [_activeLocale] (e.g. French override for `'fr'`)
  ///  2. Default string (English, registered by the plugin)
  ///  3. [fallback] if provided
  ///  4. [key] itself (prevents blank UI; developer can see the missing key)
  ///
  /// After resolving the raw string, `{paramName}` placeholders are replaced
  /// with the corresponding values from [params].
  ///
  /// ```dart
  /// // Simple
  /// context.moose.l10n('cart.checkout')           // → 'Checkout'
  ///
  /// // With params
  /// context.moose.l10n('cart.itemCount', params: {'count': '3'})
  /// // → '3 items' (if value is '{count} items')
  ///
  /// // With fallback
  /// context.moose.l10n('unknown.key', fallback: 'Fallback')  // → 'Fallback'
  /// ```
  String call(
    String key, {
    String? fallback,
    Map<String, String> params = const {},
  }) {
    final raw =
        _overrides[_activeLocale]?[key] ?? _defaults[key] ?? fallback ?? key;
    return _interpolate(raw, params);
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  /// Replaces `{paramName}` placeholders in [template] with values from [params].
  ///
  /// Unmatched placeholders (no entry in [params]) are left as-is so partial
  /// replacement is safe and the output is always valid.
  String _interpolate(String template, Map<String, String> params) {
    if (params.isEmpty) return template;
    return template.replaceAllMapped(
      RegExp(r'\{(\w+)\}'),
      (match) => params[match.group(1)!] ?? match.group(0)!,
    );
  }
}
