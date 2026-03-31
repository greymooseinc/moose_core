/// App-scoped architecture: MooseApp, MooseAppContext, MooseScope, and MooseBootstrapper.
///
/// Import this to access the new scoped registry system:
/// ```dart
/// import 'package:moose_core/app.dart';
/// ```
///
/// Or import the full library:
/// ```dart
/// import 'package:moose_core/moose_core.dart';
/// ```
library app;

export 'src/app/moose_app_context.dart';
export 'src/app/moose_app_notifier.dart';
export 'src/app/moose_scope.dart';
export 'src/app/moose_bootstrapper.dart';
export 'src/app/moose_lifecycle_observer.dart';
export 'src/app/moose_app.dart';
export 'src/theme/moose_theme.dart';
export 'src/app/page_screen.dart';
