import 'package:flutter/material.dart';

import 'core_entity.dart';
import 'user.dart';

/// Result of an authentication operation.
///
/// Encapsulates the outcome of login, signup, or other auth operations.
/// Contains user data, tokens, and error information.
@immutable
class AuthResult extends CoreEntity {
  final bool success;
  final User? user;
  final String? token;
  final String? refreshToken;
  final DateTime? expiresAt;
  final String? errorMessage;
  final String? errorCode;
  final bool requiresAdditionalAction;
  final String? additionalActionType;

  const AuthResult({
    required this.success,
    this.user,
    this.token,
    this.refreshToken,
    this.expiresAt,
    this.errorMessage,
    this.errorCode,
    this.requiresAdditionalAction = false,
    this.additionalActionType,
    super.extensions,
  });

  factory AuthResult.success({
    required User user,
    String? token,
    String? refreshToken,
    DateTime? expiresAt,
    Map<String, dynamic>? extensions,
  }) {
    return AuthResult(
      success: true,
      user: user,
      token: token,
      refreshToken: refreshToken,
      expiresAt: expiresAt,
      extensions: extensions,
    );
  }

  factory AuthResult.failure({
    required String errorMessage,
    String? errorCode,
    Map<String, dynamic>? extensions,
  }) {
    return AuthResult(
      success: false,
      errorMessage: errorMessage,
      errorCode: errorCode,
      extensions: extensions,
    );
  }

  factory AuthResult.requiresAction({
    required String actionType,
    User? user,
    String? message,
    Map<String, dynamic>? extensions,
  }) {
    return AuthResult(
      success: false,
      user: user,
      requiresAdditionalAction: true,
      additionalActionType: actionType,
      errorMessage: message,
      extensions: extensions,
    );
  }
  
  @override
  List<Object?> get props => [success, user, token, refreshToken, expiresAt, requiresAdditionalAction];
}

class PasswordResetResult {
  final bool success;
  final String? message;
  final String? errorMessage;
  final String? resetToken;
  final Map<String, dynamic>? extensions;

  const PasswordResetResult({
    required this.success,
    this.message,
    this.errorMessage,
    this.resetToken,
    this.extensions,
  });

  factory PasswordResetResult.success({
    String? message,
    String? resetToken,
  }) {
    return PasswordResetResult(
      success: true,
      message: message ?? 'Password reset email sent successfully',
      resetToken: resetToken,
    );
  }

  factory PasswordResetResult.failure(String errorMessage) {
    return PasswordResetResult(
      success: false,
      errorMessage: errorMessage,
    );
  }
}

class EmailVerificationResult {
  final bool success;
  final String? message;
  final String? errorMessage;
  final Map<String, dynamic>? extensions;

  const EmailVerificationResult({
    required this.success,
    this.message,
    this.errorMessage,
    this.extensions,
  });

  factory EmailVerificationResult.success({String? message}) {
    return EmailVerificationResult(
      success: true,
      message: message ?? 'Email verified successfully',
    );
  }

  factory EmailVerificationResult.failure(String errorMessage) {
    return EmailVerificationResult(
      success: false,
      errorMessage: errorMessage,
    );
  }
}
