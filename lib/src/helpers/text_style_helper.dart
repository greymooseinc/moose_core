import 'package:flutter/material.dart';
import 'color_helper.dart';

/// Helper class for converting JSON to TextStyle objects
///
/// This class provides utilities for converting JSON/Map data from API responses
/// into Flutter TextStyle objects. Supports all TextStyle parameters and provides
/// intelligent parsing with sensible defaults.
///
/// Example JSON:
/// ```json
/// {
///   "fontSize": 16,
///   "color": "#FF5733",
///   "fontWeight": "bold",
///   "fontStyle": "italic",
///   "letterSpacing": 1.5,
///   "wordSpacing": 2.0,
///   "height": 1.5,
///   "decoration": "underline",
///   "decorationColor": "#000000",
///   "decorationStyle": "solid",
///   "decorationThickness": 2.0
/// }
/// ```
class TextStyleHelper {
  TextStyleHelper._(); // Private constructor to prevent instantiation

  /// Convert a JSON map to a TextStyle object
  ///
  /// Supports all TextStyle parameters:
  /// - fontSize (num)
  /// - fontWeight (String: 'normal', 'bold', 'w100'-'w900', or num: 100-900)
  /// - fontStyle (String: 'normal', 'italic')
  /// - color (String: hex, color name, rgba)
  /// - backgroundColor (String: hex, color name, rgba)
  /// - letterSpacing (num)
  /// - wordSpacing (num)
  /// - height (num) - line height multiplier
  /// - decoration (String: 'none', 'underline', 'overline', 'lineThrough')
  /// - decorationColor (String: hex, color name, rgba)
  /// - decorationStyle (String: 'solid', 'double', 'dotted', 'dashed', 'wavy')
  /// - decorationThickness (num)
  /// - fontFamily (String)
  /// - shadows (List of shadow objects)
  /// - fontFeatures (List of font feature objects)
  /// - fontVariations (List of font variation objects)
  /// - overflow (String: 'clip', 'fade', 'ellipsis', 'visible')
  ///
  /// Example:
  /// ```dart
  /// final json = {'fontSize': 16, 'color': '#FF5733', 'fontWeight': 'bold'};
  /// final style = TextStyleHelper.fromJson(json);
  /// ```
  static TextStyle fromJson(
    Map<String, dynamic> json, {
    TextStyle? baseStyle,
  }) {
    return TextStyle(
      inherit: json['inherit'] as bool? ?? true,
      color: _parseColor(json['color']),
      backgroundColor: _parseColor(json['backgroundColor']),
      fontSize: (json['fontSize'] as num?)?.toDouble(),
      fontWeight: _parseFontWeight(json['fontWeight']),
      fontStyle: _parseFontStyle(json['fontStyle']),
      letterSpacing: (json['letterSpacing'] as num?)?.toDouble(),
      wordSpacing: (json['wordSpacing'] as num?)?.toDouble(),
      textBaseline: _parseTextBaseline(json['textBaseline']),
      height: (json['height'] as num?)?.toDouble(),
      leadingDistribution: _parseLeadingDistribution(json['leadingDistribution']),
      locale: _parseLocale(json['locale']),
      foreground: null, // Cannot be serialized/deserialized easily
      background: null, // Cannot be serialized/deserialized easily
      shadows: _parseShadows(json['shadows']),
      fontFeatures: _parseFontFeatures(json['fontFeatures']),
      fontVariations: _parseFontVariations(json['fontVariations']),
      decoration: _parseTextDecoration(json['decoration']),
      decorationColor: _parseColor(json['decorationColor']),
      decorationStyle: _parseTextDecorationStyle(json['decorationStyle']),
      decorationThickness: (json['decorationThickness'] as num?)?.toDouble(),
      debugLabel: json['debugLabel'] as String?,
      fontFamily: json['fontFamily'] as String?,
      fontFamilyFallback: _parseFontFamilyFallback(json['fontFamilyFallback']),
      overflow: _parseTextOverflow(json['overflow']),
    ).merge(baseStyle);
  }

  /// Convert a TextStyle to JSON map
  ///
  /// Example:
  /// ```dart
  /// final style = TextStyle(fontSize: 16, color: Colors.red);
  /// final json = TextStyleHelper.toJson(style);
  /// // {'fontSize': 16.0, 'color': '#FFF44336'}
  /// ```
  static Map<String, dynamic> toJson(TextStyle style) {
    final json = <String, dynamic>{};

    json['inherit'] = style.inherit;
    if (style.color != null) {
      json['color'] = ColorHelper.toHex(style.color!, includeHashSymbol: true);
    }
    if (style.backgroundColor != null) {
      json['backgroundColor'] = ColorHelper.toHex(
        style.backgroundColor!,
        includeHashSymbol: true,
      );
    }
    if (style.fontSize != null) json['fontSize'] = style.fontSize;
    if (style.fontWeight != null) {
      json['fontWeight'] = _fontWeightToString(style.fontWeight!);
    }
    if (style.fontStyle != null) {
      json['fontStyle'] = style.fontStyle == FontStyle.italic ? 'italic' : 'normal';
    }
    if (style.letterSpacing != null) json['letterSpacing'] = style.letterSpacing;
    if (style.wordSpacing != null) json['wordSpacing'] = style.wordSpacing;
    if (style.textBaseline != null) {
      json['textBaseline'] = style.textBaseline == TextBaseline.alphabetic
          ? 'alphabetic'
          : 'ideographic';
    }
    if (style.height != null) json['height'] = style.height;
    if (style.decoration != null) {
      json['decoration'] = _textDecorationToString(style.decoration!);
    }
    if (style.decorationColor != null) {
      json['decorationColor'] = ColorHelper.toHex(
        style.decorationColor!,
        includeHashSymbol: true,
      );
    }
    if (style.decorationStyle != null) {
      json['decorationStyle'] = _decorationStyleToString(style.decorationStyle!);
    }
    if (style.decorationThickness != null) {
      json['decorationThickness'] = style.decorationThickness;
    }
    if (style.fontFamily != null) json['fontFamily'] = style.fontFamily;
    if (style.fontFamilyFallback != null && style.fontFamilyFallback!.isNotEmpty) {
      json['fontFamilyFallback'] = style.fontFamilyFallback;
    }
    if (style.overflow != null) {
      json['overflow'] = _textOverflowToString(style.overflow!);
    }

    return json;
  }

  static TextStyle getTextStyleFromList(List<dynamic> sources) {
    for (final source in sources) {
      if (source == null) continue;

      if (source is TextStyle) return source;

      if (source is Map<String, dynamic>) {
        return TextStyleHelper.fromJson(source);
      }
    }

    // TODO: use global from theme
    return const TextStyle();
  }

  static TextStyle getTextStyle([dynamic first, dynamic second, dynamic third, dynamic fourth, dynamic fifth]) {
    return getTextStyleFromList([first, second, third, fourth, fifth]);
  }

  // ============================================================================
  // PRIVATE HELPER METHODS
  // ============================================================================

  /// Parse color from JSON value
  static Color? _parseColor(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      return ColorHelper.parse(value);
    }
    return null;
  }

  /// Parse FontWeight from JSON value
  static FontWeight? _parseFontWeight(dynamic value) {
    if (value == null) return null;

    // Handle string values
    if (value is String) {
      switch (value.toLowerCase()) {
        case 'thin':
        case 'w100':
          return FontWeight.w100;
        case 'extralight':
        case 'w200':
          return FontWeight.w200;
        case 'light':
        case 'w300':
          return FontWeight.w300;
        case 'normal':
        case 'regular':
        case 'w400':
          return FontWeight.w400;
        case 'medium':
        case 'w500':
          return FontWeight.w500;
        case 'semibold':
        case 'w600':
          return FontWeight.w600;
        case 'bold':
        case 'w700':
          return FontWeight.w700;
        case 'extrabold':
        case 'w800':
          return FontWeight.w800;
        case 'black':
        case 'w900':
          return FontWeight.w900;
        default:
          return null;
      }
    }

    // Handle numeric values (100-900)
    if (value is num) {
      final weight = value.toInt();
      switch (weight) {
        case 100:
          return FontWeight.w100;
        case 200:
          return FontWeight.w200;
        case 300:
          return FontWeight.w300;
        case 400:
          return FontWeight.w400;
        case 500:
          return FontWeight.w500;
        case 600:
          return FontWeight.w600;
        case 700:
          return FontWeight.w700;
        case 800:
          return FontWeight.w800;
        case 900:
          return FontWeight.w900;
        default:
          return null;
      }
    }

    return null;
  }

  /// Convert FontWeight to string
  static String _fontWeightToString(FontWeight weight) {
    if (weight == FontWeight.w100) return 'w100';
    if (weight == FontWeight.w200) return 'w200';
    if (weight == FontWeight.w300) return 'w300';
    if (weight == FontWeight.w400) return 'w400';
    if (weight == FontWeight.w500) return 'w500';
    if (weight == FontWeight.w600) return 'w600';
    if (weight == FontWeight.w700) return 'w700';
    if (weight == FontWeight.w800) return 'w800';
    if (weight == FontWeight.w900) return 'w900';
    return 'w400';
  }

  /// Parse FontStyle from JSON value
  static FontStyle? _parseFontStyle(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      switch (value.toLowerCase()) {
        case 'italic':
          return FontStyle.italic;
        case 'normal':
          return FontStyle.normal;
        default:
          return null;
      }
    }
    return null;
  }

  /// Parse TextBaseline from JSON value
  static TextBaseline? _parseTextBaseline(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      switch (value.toLowerCase()) {
        case 'alphabetic':
          return TextBaseline.alphabetic;
        case 'ideographic':
          return TextBaseline.ideographic;
        default:
          return null;
      }
    }
    return null;
  }

  /// Parse TextLeadingDistribution from JSON value
  static TextLeadingDistribution? _parseLeadingDistribution(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      switch (value.toLowerCase()) {
        case 'proportional':
          return TextLeadingDistribution.proportional;
        case 'even':
          return TextLeadingDistribution.even;
        default:
          return null;
      }
    }
    return null;
  }

  /// Parse Locale from JSON value
  static Locale? _parseLocale(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final parts = value.split('_');
      if (parts.length == 2) {
        return Locale(parts[0], parts[1]);
      } else if (parts.length == 1) {
        return Locale(parts[0]);
      }
    }
    return null;
  }

  /// Parse TextDecoration from JSON value
  static TextDecoration? _parseTextDecoration(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      switch (value.toLowerCase()) {
        case 'none':
          return TextDecoration.none;
        case 'underline':
          return TextDecoration.underline;
        case 'overline':
          return TextDecoration.overline;
        case 'linethrough':
        case 'line-through':
          return TextDecoration.lineThrough;
        default:
          return null;
      }
    }
    return null;
  }

  /// Convert TextDecoration to string
  static String _textDecorationToString(TextDecoration decoration) {
    if (decoration == TextDecoration.none) return 'none';
    if (decoration == TextDecoration.underline) return 'underline';
    if (decoration == TextDecoration.overline) return 'overline';
    if (decoration == TextDecoration.lineThrough) return 'lineThrough';
    return 'none';
  }

  /// Parse TextDecorationStyle from JSON value
  static TextDecorationStyle? _parseTextDecorationStyle(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      switch (value.toLowerCase()) {
        case 'solid':
          return TextDecorationStyle.solid;
        case 'double':
          return TextDecorationStyle.double;
        case 'dotted':
          return TextDecorationStyle.dotted;
        case 'dashed':
          return TextDecorationStyle.dashed;
        case 'wavy':
          return TextDecorationStyle.wavy;
        default:
          return null;
      }
    }
    return null;
  }

  /// Convert TextDecorationStyle to string
  static String _decorationStyleToString(TextDecorationStyle style) {
    if (style == TextDecorationStyle.solid) return 'solid';
    if (style == TextDecorationStyle.double) return 'double';
    if (style == TextDecorationStyle.dotted) return 'dotted';
    if (style == TextDecorationStyle.dashed) return 'dashed';
    if (style == TextDecorationStyle.wavy) return 'wavy';
    return 'solid';
  }

  /// Parse TextOverflow from JSON value
  static TextOverflow? _parseTextOverflow(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      switch (value.toLowerCase()) {
        case 'clip':
          return TextOverflow.clip;
        case 'fade':
          return TextOverflow.fade;
        case 'ellipsis':
          return TextOverflow.ellipsis;
        case 'visible':
          return TextOverflow.visible;
        default:
          return null;
      }
    }
    return null;
  }

  /// Convert TextOverflow to string
  static String _textOverflowToString(TextOverflow overflow) {
    if (overflow == TextOverflow.clip) return 'clip';
    if (overflow == TextOverflow.fade) return 'fade';
    if (overflow == TextOverflow.ellipsis) return 'ellipsis';
    if (overflow == TextOverflow.visible) return 'visible';
    return 'clip';
  }

  /// Parse list of Shadow objects from JSON
  static List<Shadow>? _parseShadows(dynamic value) {
    if (value == null) return null;
    if (value is! List) return null;

    return value.map((item) {
      if (item is! Map<String, dynamic>) return null;
      return Shadow(
        color: _parseColor(item['color']) ?? const Color(0xFF000000),
        offset: _parseOffset(item['offset']) ?? Offset.zero,
        blurRadius: (item['blurRadius'] as num?)?.toDouble() ?? 0.0,
      );
    }).whereType<Shadow>().toList();
  }

  /// Parse Offset from JSON
  static Offset? _parseOffset(dynamic value) {
    if (value == null) return null;
    if (value is Map<String, dynamic>) {
      final dx = (value['dx'] as num?)?.toDouble() ?? 0.0;
      final dy = (value['dy'] as num?)?.toDouble() ?? 0.0;
      return Offset(dx, dy);
    }
    if (value is List && value.length >= 2) {
      final dx = (value[0] as num?)?.toDouble() ?? 0.0;
      final dy = (value[1] as num?)?.toDouble() ?? 0.0;
      return Offset(dx, dy);
    }
    return null;
  }

  /// Parse list of FontFeature objects from JSON
  static List<FontFeature>? _parseFontFeatures(dynamic value) {
    if (value == null) return null;
    if (value is! List) return null;

    return value.map((item) {
      if (item is! Map<String, dynamic>) return null;
      final feature = item['feature'] as String?;
      final featureValue = item['value'] as int? ?? 1;
      if (feature != null) {
        return FontFeature(feature, featureValue);
      }
      return null;
    }).whereType<FontFeature>().toList();
  }

  /// Parse list of FontVariation objects from JSON
  static List<FontVariation>? _parseFontVariations(dynamic value) {
    if (value == null) return null;
    if (value is! List) return null;

    return value.map((item) {
      if (item is! Map<String, dynamic>) return null;
      final axis = item['axis'] as String?;
      final variationValue = (item['value'] as num?)?.toDouble();
      if (axis != null && variationValue != null) {
        return FontVariation(axis, variationValue);
      }
      return null;
    }).whereType<FontVariation>().toList();
  }

  /// Parse font family fallback list
  static List<String>? _parseFontFamilyFallback(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      return value.whereType<String>().toList();
    }
    if (value is String) {
      return [value];
    }
    return null;
  }
}
