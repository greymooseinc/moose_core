import 'package:flutter/material.dart';

/// Helper class for color operations and conversions
///
/// This class provides utilities for converting hex color strings to Flutter Color objects
/// and other color-related operations. Designed to allow colors to be configured via JSON
/// or other text-based configuration formats.
class ColorHelper {
  ColorHelper._(); // Private constructor to prevent instantiation

  /// Convert a hex color string to a Color object
  ///
  /// Supports multiple hex formats:
  /// - 6 digits: #RRGGBB or RRGGBB
  /// - 8 digits: #AARRGGBB or AARRGGBB (with alpha)
  /// - 3 digits: #RGB or RGB (shorthand)
  ///
  /// Examples:
  /// ```dart
  /// ColorHelper.fromHex('#FF5733')      // Red-orange
  /// ColorHelper.fromHex('FF5733')       // Same as above
  /// ColorHelper.fromHex('#80FF5733')    // Red-orange with 50% opacity
  /// ColorHelper.fromHex('#F57')         // Shorthand for #FF5577
  /// ```
  ///
  /// Returns [defaultColor] if parsing fails (defaults to Colors.black)
  static Color fromHex(
    String hexString, {
    Color defaultColor = Colors.black,
  }) {
    try {
      // Remove # if present
      final hex = hexString.replaceAll('#', '');

      // Handle shorthand hex (e.g., #RGB -> #RRGGBB)
      String fullHex;
      if (hex.length == 3) {
        fullHex = hex.split('').map((c) => c + c).join();
      } else {
        fullHex = hex;
      }

      // Parse based on length
      if (fullHex.length == 6) {
        // RGB format - add full opacity
        return Color(int.parse('FF$fullHex', radix: 16));
      } else if (fullHex.length == 8) {
        // ARGB format
        return Color(int.parse(fullHex, radix: 16));
      } else {
        // Invalid format
        return defaultColor;
      }
    } catch (e) {
      // Return default color if parsing fails
      return defaultColor;
    }
  }

  /// Convert a Color object to a hex string
  ///
  /// [includeAlpha] - If true, includes alpha channel (AARRGGBB format)
  /// [includeHashSymbol] - If true, prepends # to the hex string
  ///
  /// Examples:
  /// ```dart
  /// ColorHelper.toHex(Colors.red)                          // 'FFF44336'
  /// ColorHelper.toHex(Colors.red, includeAlpha: false)     // 'F44336'
  /// ColorHelper.toHex(Colors.red, includeHashSymbol: true) // '#FFF44336'
  /// ```
  static String toHex(
    Color color, {
    bool includeAlpha = true,
    bool includeHashSymbol = false,
  }) {
    final alpha = (color.a * 255).round().toRadixString(16).padLeft(2, '0').toUpperCase();
    final red = (color.r * 255).round().toRadixString(16).padLeft(2, '0').toUpperCase();
    final green = (color.g * 255).round().toRadixString(16).padLeft(2, '0').toUpperCase();
    final blue = (color.b * 255).round().toRadixString(16).padLeft(2, '0').toUpperCase();

    final hex = includeAlpha ? '$alpha$red$green$blue' : '$red$green$blue';
    return includeHashSymbol ? '#$hex' : hex;
  }

  /// Parse color from various string formats
  ///
  /// Supports:
  /// - Hex strings: '#FF5733', 'FF5733', '#F57'
  /// - Material color names: 'red', 'blue', 'green', etc.
  /// - RGBA format: 'rgba(255, 87, 51, 1.0)' or 'rgb(255, 87, 51)'
  ///
  /// Examples:
  /// ```dart
  /// ColorHelper.parse('#FF5733')           // From hex
  /// ColorHelper.parse('red')               // From color name
  /// ColorHelper.parse('rgba(255,87,51,1)') // From RGBA
  /// ```
  static Color parse(
    String colorString, {
    Color defaultColor = Colors.black,
  }) {
    final trimmed = colorString.trim().toLowerCase();

    // Try hex format first
    if (trimmed.startsWith('#') || _isHexString(trimmed)) {
      return fromHex(trimmed, defaultColor: defaultColor);
    }

    // Try RGBA/RGB format
    if (trimmed.startsWith('rgba(') || trimmed.startsWith('rgb(')) {
      return _parseRgba(trimmed, defaultColor);
    }

    // Try named colors
    final namedColor = _getNamedColor(trimmed);
    if (namedColor != null) {
      return namedColor;
    }

    return defaultColor;
  }

  /// Check if a string is a valid hex color string
  static bool _isHexString(String str) {
    final hexPattern = RegExp(r'^[0-9A-Fa-f]{3}$|^[0-9A-Fa-f]{6}$|^[0-9A-Fa-f]{8}$');
    return hexPattern.hasMatch(str);
  }

  /// Parse RGBA/RGB color string
  static Color _parseRgba(String rgba, Color defaultColor) {
    try {
      final pattern = RegExp(r'rgba?\((\d+),\s*(\d+),\s*(\d+)(?:,\s*([0-9.]+))?\)');
      final match = pattern.firstMatch(rgba);

      if (match != null) {
        final r = int.parse(match.group(1)!);
        final g = int.parse(match.group(2)!);
        final b = int.parse(match.group(3)!);
        final a = match.group(4) != null ? double.parse(match.group(4)!) : 1.0;

        return Color.fromRGBO(r, g, b, a);
      }
    } catch (e) {
      // Parsing failed
    }
    return defaultColor;
  }

  /// Get Material color by name
  static Color? _getNamedColor(String name) {
    final colorMap = <String, Color>{
      'red': Colors.red,
      'pink': Colors.pink,
      'purple': Colors.purple,
      'deeppurple': Colors.deepPurple,
      'indigo': Colors.indigo,
      'blue': Colors.blue,
      'lightblue': Colors.lightBlue,
      'cyan': Colors.cyan,
      'teal': Colors.teal,
      'green': Colors.green,
      'lightgreen': Colors.lightGreen,
      'lime': Colors.lime,
      'yellow': Colors.yellow,
      'amber': Colors.amber,
      'orange': Colors.orange,
      'deeporange': Colors.deepOrange,
      'brown': Colors.brown,
      'grey': Colors.grey,
      'gray': Colors.grey,
      'bluegrey': Colors.blueGrey,
      'bluegray': Colors.blueGrey,
      'black': Colors.black,
      'white': Colors.white,
      'transparent': Colors.transparent,
    };

    return colorMap[name];
  }

  /// Create a color with modified opacity
  ///
  /// [color] - The base color
  /// [opacity] - Opacity value between 0.0 (transparent) and 1.0 (opaque)
  ///
  /// Example:
  /// ```dart
  /// ColorHelper.withOpacity(Colors.red, 0.5) // 50% transparent red
  /// ```
  static Color withOpacity(Color color, double opacity) {
    return color.withValues(alpha: opacity.clamp(0.0, 1.0));
  }

  /// Darken a color by a given percentage
  ///
  /// [color] - The base color
  /// [amount] - Percentage to darken (0.0 to 1.0)
  ///
  /// Example:
  /// ```dart
  /// ColorHelper.darken(Colors.blue, 0.2) // 20% darker blue
  /// ```
  static Color darken(Color color, double amount) {
    assert(amount >= 0 && amount <= 1, 'Amount must be between 0 and 1');

    final hsl = HSLColor.fromColor(color);
    final darkened = hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0));
    return darkened.toColor();
  }

  /// Lighten a color by a given percentage
  ///
  /// [color] - The base color
  /// [amount] - Percentage to lighten (0.0 to 1.0)
  ///
  /// Example:
  /// ```dart
  /// ColorHelper.lighten(Colors.blue, 0.2) // 20% lighter blue
  /// ```
  static Color lighten(Color color, double amount) {
    assert(amount >= 0 && amount <= 1, 'Amount must be between 0 and 1');

    final hsl = HSLColor.fromColor(color);
    final lightened = hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0));
    return lightened.toColor();
  }

  /// Check if a color is considered light or dark
  ///
  /// Uses the luminance value to determine if a color is light or dark.
  /// Useful for determining whether to use light or dark text on a colored background.
  ///
  /// Returns true if the color is light (luminance > 0.5)
  ///
  /// Example:
  /// ```dart
  /// ColorHelper.isLight(Colors.yellow) // true
  /// ColorHelper.isLight(Colors.black)  // false
  /// ```
  static bool isLight(Color color) {
    return color.computeLuminance() > 0.5;
  }

  /// Get a contrasting color (black or white) for the given color
  ///
  /// Returns white for dark colors and black for light colors.
  /// Useful for text color on colored backgrounds.
  ///
  /// Example:
  /// ```dart
  /// ColorHelper.contrastColor(Colors.blue)   // Returns white
  /// ColorHelper.contrastColor(Colors.yellow) // Returns black
  /// ```
  static Color contrastColor(Color color) {
    return isLight(color) ? Colors.black : Colors.white;
  }

  /// Blend two colors together
  ///
  /// [color1] - First color
  /// [color2] - Second color
  /// [amount] - Amount of color2 to blend (0.0 to 1.0)
  ///
  /// Example:
  /// ```dart
  /// // 50% red, 50% blue = purple
  /// ColorHelper.blend(Colors.red, Colors.blue, 0.5)
  /// ```
  static Color blend(Color color1, Color color2, double amount) {
    assert(amount >= 0 && amount <= 1, 'Amount must be between 0 and 1');

    final r = ((color1.r + (color2.r - color1.r) * amount) * 255).round();
    final g = ((color1.g + (color2.g - color1.g) * amount) * 255).round();
    final b = ((color1.b + (color2.b - color1.b) * amount) * 255).round();
    final a = ((color1.a + (color2.a - color1.a) * amount) * 255).round();

    return Color.fromARGB(a, r, g, b);
  }
}
