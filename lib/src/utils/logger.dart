// ignore_for_file: public_member_api_docs
import 'dart:developer' as developer;
import 'package:flutter/foundation.dart';

/// Signature for a log sink that can receive log events in release builds.
typedef MooseLogSink = void Function(
  String level,
  String tag,
  String message, [
  Object? error,
  StackTrace? stackTrace,
]);

/// Simple logger utility for the application
///
/// Uses dart:developer log in debug mode and is silent in release mode
/// to follow Flutter best practices.
class AppLogger {
  final String _name;

  AppLogger(this._name);

  /// Optional log sink for release builds.
  ///
  /// In debug builds all output goes to [developer.log]. In release builds all
  /// output is suppressed unless you assign this sink — for example to forward
  /// errors to Crashlytics:
  ///
  /// ```dart
  /// AppLogger.releaseSink = (level, tag, msg, [err, stack]) {
  ///   FirebaseCrashlytics.instance.log('[$level][$tag] $msg');
  ///   if (err != null) FirebaseCrashlytics.instance.recordError(err, stack);
  /// };
  /// ```
  static MooseLogSink? releaseSink;

  /// Log debug information
  void debug(String message) {
    if (kDebugMode) {
      developer.log(message, name: _name, level: 500);
    } else {
      AppLogger.releaseSink?.call('DEBUG', _name, message);
    }
  }

  /// Log informational messages
  void info(String message) {
    if (kDebugMode) {
      developer.log(message, name: _name, level: 800);
    } else {
      AppLogger.releaseSink?.call('INFO', _name, message);
    }
  }

  /// Log warning messages
  void warning(String message, [Object? error, StackTrace? stackTrace]) {
    if (kDebugMode) {
      developer.log(
        message,
        name: _name,
        level: 900,
        error: error,
        stackTrace: stackTrace,
      );
    } else {
      AppLogger.releaseSink?.call('WARNING', _name, message, error, stackTrace);
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
    } else {
      AppLogger.releaseSink?.call('ERROR', _name, message, error, stackTrace);
    }
  }

  /// Log success messages (info level with emoji prefix)
  void success(String message) {
    info('✅ $message');
  }
}
