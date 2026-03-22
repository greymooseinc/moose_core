/// UI style facades for moose_core plugins.
///
/// Exports hook-calling style helpers that delegate to whichever palette plugin
/// is active. Import this instead of concrete style classes:
///
/// ```dart
/// import 'package:moose_core/ui.dart';
///
/// Text('Title', style: AppTextStyles.appBarTitle(context))
/// ```
library;

export 'src/ui/style_hook_data.dart';
export 'src/ui/app_text_styles.dart';
export 'src/ui/app_button_styles.dart';
export 'src/ui/app_input_styles.dart';
export 'src/ui/app_background_styles.dart';
export 'src/ui/app_custom_styles.dart';
export 'src/ui/moose_app_bar.dart';
