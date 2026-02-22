import 'package:flutter/material.dart';
import 'package:moose_core/adapters.dart';
import 'package:moose_core/services.dart';

import '../app/moose_scope.dart';

/// Abstract base class for all feature sections in the application.
///
/// Feature sections are special, reusable, and configurable UI components
/// that can be placed in various screens (home, category, etc.) and configured
/// via JSON settings. They differ from typical Flutter widgets in that they are
/// specifically designed to be used as configurable building blocks for screens.
///
/// All feature sections should extend this class and use the BLoC pattern
/// for state management to ensure architectural consistency.
///
/// ## Examples of Feature Sections:
/// - CollectionsSection
/// - NewArrivalsSection
/// - FeaturedProductsSection
/// - CategoriesSection
/// - HeroSection
/// - PromoSection
///
/// ## Implementation Guide
///
/// When creating a new feature section:
///
/// 1. Extend this abstract class
/// 2. Implement `getDefaultSettings()` to provide default configuration
/// 3. Implement `build()` method
/// 4. Use `getSetting<T>(key)` to retrieve configuration values
/// 5. Use BLoC pattern for state management (BlocProvider + BlocBuilder)
/// 6. Accept optional `settings` parameter using `super.settings`
///
/// ## Complete Example
///
/// ```dart
/// class MySection extends FeatureSection {
///   const MySection({super.key, super.settings});
///
///   @override
///   Map<String, dynamic> getDefaultSettings() {
///     return {
///       'title': 'My Section',
///       'titleFontSize': 16.0,
///       'horizontalPadding': 20.0,
///       'showBorder': true,
///     };
///   }
///
///   @override
///   Widget build(BuildContext context) {
///     final repository = adapter.getRepository<MyRepository>();
///
///     return BlocProvider(
///       create: (context) => MySectionBloc(repository)
///         ..add(LoadData()),
///       child: Padding(
///         padding: EdgeInsets.symmetric(
///           horizontal: getSetting<double>('horizontalPadding'),
///         ),
///         child: Column(
///           children: [
///             Text(
///               getSetting<String>('title'),
///               style: TextStyle(
///                 fontSize: getSetting<double>('titleFontSize'),
///               ),
///             ),
///             BlocBuilder<MySectionBloc, MySectionState>(
///               builder: (context, state) {
///                 if (state is Loading) return CircularProgressIndicator();
///                 if (state is Loaded) return _buildContent(state.data);
///                 if (state is Error) return _buildError(state.message);
///                 return SizedBox.shrink();
///               },
///             ),
///           ],
///         ),
///       ),
///     );
///   }
/// }
/// ```
///
/// ## Configuration in environment.json
///
/// Feature widgets are configured in `assets/config/environment.json`:
///
/// ```json
/// {
///   "plugins": {
///     "home": {
///       "sections": [
///         {
///           "name": "my.section",
///           "description": "My custom section",
///           "settings": {
///             "title": "Custom Title",
///             "titleFontSize": 18,
///             "horizontalPadding": 24,
///             "showBorder": false
///           }
///         }
///       ]
///     }
///   }
/// }
/// ```
///
/// ## Settings Priority
///
/// Settings are merged with the following priority:
/// 1. Settings passed via constructor (highest priority)
/// 2. Default settings from getDefaultSettings() (fallback)
///
/// ## BLoC Pattern Requirement
///
/// All feature sections MUST use the BLoC pattern for state management:
/// - Create a dedicated BLoC for the section (e.g., MySectionBloc)
/// - Define Events and States
/// - Use BlocProvider to provide the BLoC
/// - Use BlocBuilder to render based on state
/// - Keep business logic in BLoC, not in the section
///
abstract class FeatureSection extends StatelessWidget {
  /// Optional settings/configuration for this section.
  ///
  /// Settings are typically provided from environment.json configuration
  /// but can be passed directly when instantiating the section.
  ///
  /// If null, the section will use values from [getDefaultSettings].
  final Map<String, dynamic>? settings;

  const FeatureSection({super.key, this.settings});

  /// Returns the scoped [AdapterRegistry] from the nearest [MooseScope].
  ///
  /// Call this inside [build] to access repositories:
  ///
  /// ```dart
  /// @override
  /// Widget build(BuildContext context) {
  ///   return BlocProvider(
  ///     create: (_) => MyBloc(
  ///       repository: adaptersOf(context).getRepository<MyRepository>(),
  ///     )..add(LoadData()),
  ///     child: ...,
  ///   );
  /// }
  /// ```
  AdapterRegistry adaptersOf(BuildContext context) =>
      MooseScope.adapterRegistryOf(context);

  /// Returns the default settings for this feature section.
  ///
  /// This method MUST return a map with all supported configuration options
  /// and their default values. These defaults are used when:
  /// - No settings are provided via the constructor
  /// - A specific setting key is missing from the provided settings
  ///
  /// **Important**: All numeric values should be doubles (e.g., 16.0 not 16)
  /// to avoid type conversion issues.
  ///
  /// Example:
  /// ```dart
  /// @override
  /// Map<String, dynamic> getDefaultSettings() {
  ///   return {
  ///     'title': 'Default Title',
  ///     'titleFontSize': 16.0,        // Use double
  ///     'horizontalPadding': 20.0,    // Use double
  ///     'showBorder': true,
  ///     'itemCount': 10,               // int is fine for counts
  ///   };
  /// }
  /// ```
  Map<String, dynamic> getDefaultSettings();

  /// Helper method to get a setting value from settings or default settings.
  ///
  /// This method safely retrieves configuration values with proper type casting.
  /// It merges settings with default settings, where provided settings override
  /// defaults.
  ///
  /// **Fail-fast behavior**: Throws an exception if:
  /// - The key is not found in either settings or default settings
  /// - The value cannot be cast to the expected type
  ///
  /// This ensures configuration errors are caught early during development.
  ///
  /// Usage:
  /// ```dart
  /// final title = getSetting<String>('title');
  /// final fontSize = getSetting<double>('titleFontSize');
  /// final itemCount = getSetting<int>('itemCount');
  /// final filters = getSetting<Map<String, dynamic>>('filters');
  /// final showBadge = getSetting<bool>('showBadge');
  /// ```
  ///
  /// Throws:
  /// - [Exception] if the key is not found in settings or defaults
  /// - [Exception] if the value cannot be cast to type T
  T getSetting<T>(String key) {
    // Merge defaults with provided settings (settings override defaults)
    final config = {...getDefaultSettings(), ...(settings ?? {})};

    final value = config[key];

    // Fail fast if key not found
    if (value == null) {
      throw Exception(
        'Setting "$key" not found in $runtimeType. '
        'Ensure the key exists in getDefaultSettings() or settings.',
      );
    }

    // Handle automatic number conversions
    if (T == double && value is num) {
      return value.toDouble() as T;
    }

    if (T == int && value is num) {
      return value.toInt() as T;
    }

    if (T == Color) {
      return ColorHelper.parse(value) as T;
    }

    // Direct type match
    if (value is T) {
      return value;
    }

    // Fail fast if type mismatch
    throw Exception(
      'Setting "$key" in $runtimeType has type ${value.runtimeType} '
      'but expected type $T',
    );
  }
}
