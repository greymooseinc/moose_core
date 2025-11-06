import 'package:flutter/material.dart';
import 'package:moose_core/src/entities/core_entity.dart';

/// Base class for authentication credentials.
///
/// Different authentication methods extend this class to provide
/// their specific credential types. All credential types support
/// the extensions field for storing additional backend-specific data.
abstract class AuthCredentials extends CoreEntity {
  const AuthCredentials({
    super.extensions
  });
}

/// Credentials for email/password authentication.
@immutable
class EmailPasswordCredentials extends AuthCredentials {
  final String email;
  final String password;

  const EmailPasswordCredentials({
    required this.email,
    required this.password,
    super.extensions,
  });

  @override
  List<Object?> get props => [email, password];
}

/// Credentials for phone number authentication.
///
/// Supports verification code for two-step authentication.
@immutable
class PhoneCredentials extends AuthCredentials {
  final String phoneNumber;
  final String? verificationCode;

  const PhoneCredentials({
    required this.phoneNumber,
    this.verificationCode,
    super.extensions,
  });

  @override
  List<Object?> get props => [phoneNumber, verificationCode];
}

/// Credentials for OAuth providers (Google, Facebook, Apple, etc.).
///
/// Supports access tokens, ID tokens, and additional provider-specific data.
@immutable
class OAuthCredentials extends AuthCredentials {
  final String provider;
  final String? accessToken;
  final String? idToken;
  final Map<String, dynamic>? additionalData;

  const OAuthCredentials({
    required this.provider,
    this.accessToken,
    this.idToken,
    this.additionalData,
    super.extensions,
  });

  @override
  List<Object?> get props => [provider, accessToken, idToken];
}

/// Credentials for custom token authentication.
///
/// Used for custom authentication implementations or third-party auth systems.
@immutable
class CustomTokenCredentials extends AuthCredentials {
  final String token;

  const CustomTokenCredentials({
    required this.token,
    super.extensions,
  });

  @override
  List<Object?> get props => [token];
}

/// Credentials for anonymous authentication.
///
/// Used for guest or temporary user sessions.
@immutable
class AnonymousCredentials extends AuthCredentials {
  const AnonymousCredentials();

  @override
  List<Object?> get props => [];
}
