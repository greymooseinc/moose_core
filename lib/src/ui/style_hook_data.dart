import 'package:flutter/material.dart';

/// Typed data carrier passed to `styles:text`, `styles:button`, and
/// `styles:input` hooks.
///
/// Hook authors receive a [StyleHookData] and cast it once — no untyped map
/// access and no risk of an invalid [BuildContext] cast at runtime.
///
/// ```dart
/// hookRegistry.register('styles:text', (data) {
///   final d = data as StyleHookData;
///   return MyTextStyles.resolve(d.name, d.context);
/// });
/// ```
///
/// Additional per-hook fields (e.g. [labelText] for input hooks) are nullable;
/// hooks that do not need them can ignore them.
class StyleHookData {
  /// The style variant name (e.g. `'appBarTitle'`, `'primary'`, `'outlined'`).
  final String name;

  /// The [BuildContext] at the call site — safe to use with [Theme.of] and
  /// [MediaQuery.of].
  final BuildContext context;

  /// Input-hook only: label text for the form field, if provided.
  final String? labelText;

  /// Input-hook only: hint text for the form field, if provided.
  final String? hintText;

  /// Input-hook only: suffix icon widget, if provided.
  final Widget? suffixIcon;

  /// Input-hook only: prefix icon widget, if provided.
  final Widget? prefixIcon;

  const StyleHookData({
    required this.name,
    required this.context,
    this.labelText,
    this.hintText,
    this.suffixIcon,
    this.prefixIcon,
  });
}
