import 'user.dart';

/// Result of an authentication operation
class AuthResult {
  /// Whether the authentication was successful
  final bool success;

  /// The authenticated user (if successful)
  final User? user;

  /// Authentication token (JWT, session token, etc.)
  final String? token;

  /// Refresh token for renewing the auth token
  final String? refreshToken;

  /// Token expiration time
  final DateTime? expiresAt;

  /// Error message (if failed)
  final String? errorMessage;

  /// Error code for programmatic handling
  final String? errorCode;

  /// Whether additional user action is required (e.g., email verification)
  final bool requiresAdditionalAction;

  /// Type of additional action required
  final String? additionalActionType;

  /// Additional data specific to the auth provider
  final Map<String, dynamic>? extensions;

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
    this.extensions,
  });

  /// Create a successful authentication result
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

  /// Create a failed authentication result
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

  /// Create a result that requires additional user action
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
}

/// Result of a password reset operation
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

/// Result of an email verification operation
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
