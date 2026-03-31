import 'package:flutter/material.dart';

/// Unified app-level notifier that drives [MaterialApp] rebuilds.
///
/// Plugins push changes into this notifier via setters; `app.dart` listens
/// once with a single [ListenableBuilder] instead of nesting multiple
/// [ValueListenableBuilder]s for each concern.
///
/// ## Built-in fields
///
/// - [themeMode] — set by `ThemeManagerPlugin`
/// - [locale] — set by `LocaleManagerPlugin`
///
/// ## Adding new app-level state
///
/// Add a private field, a getter, and a setter that guards against no-ops and
/// calls [notifyListeners]. Then call the setter from the relevant plugin's
/// `onRegister()`.
///
/// ```dart
/// // In MooseAppNotifier:
/// String _shopBranch = 'default';
/// String get shopBranch => _shopBranch;
/// void setShopBranch(String branch) {
///   if (_shopBranch == branch) return;
///   _shopBranch = branch;
///   notifyListeners();
/// }
///
/// // In ShopBranchPlugin.onRegister():
/// appContext.appNotifier.setShopBranch(initialBranch);
/// _notifier.addListener(() {
///   appContext.appNotifier.setShopBranch(_notifier.value);
/// });
/// ```
class MooseAppNotifier extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.system;
  Locale _locale = const Locale('en');

  /// The active [ThemeMode] — set by `ThemeManagerPlugin`.
  ThemeMode get themeMode => _themeMode;

  /// The active [Locale] — set by `LocaleManagerPlugin`.
  Locale get locale => _locale;

  /// Updates [themeMode] and notifies listeners if the value changed.
  void setThemeMode(ThemeMode mode) {
    if (_themeMode == mode) return;
    _themeMode = mode;
    notifyListeners();
  }

  /// Updates [locale] and notifies listeners if the value changed.
  void setLocale(Locale locale) {
    if (_locale == locale) return;
    _locale = locale;
    notifyListeners();
  }
}
