import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Simple logger utility for the application
///
/// Uses dart:developer log in debug mode and is silent in release mode
/// to follow Flutter best practices.
class AppLogger {
  final String _name;

  AppLogger(this._name);

  /// Log debug information
  void debug(String message) {
    if (kDebugMode) {
      developer.log(message, name: _name, level: 500);
    }
  }

  /// Log informational messages
  void info(String message) {
    if (kDebugMode) {
      developer.log(message, name: _name, level: 800);
    }
  }

  /// Log warning messages
  void warning(String message) {
    if (kDebugMode) {
      developer.log(message, name: _name, level: 900);
    }
  }

  /// Log error messages
  void error(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      developer.log(
        message,
        name: _name,
        level: 1000,
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  /// Log success messages (info level with emoji prefix)
  void success(String message) {
    info('✅ $message');
  }
}
