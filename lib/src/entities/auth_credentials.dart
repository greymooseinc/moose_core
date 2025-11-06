/// Base class for authentication credentials
///
/// Different authentication methods extend this class to provide
/// their specific credential types.
abstract class AuthCredentials {
  const AuthCredentials();
}

/// Credentials for email/password authentication
class EmailPasswordCredentials extends AuthCredentials {
  final String email;
  final String password;
  final Map<String, dynamic>? extensions;

  const EmailPasswordCredentials({
    required this.email,
    required this.password,
    this.extensions,
  });
}

/// Credentials for phone number authentication
class PhoneCredentials extends AuthCredentials {
  final String phoneNumber;
  final String? verificationCode;
  final Map<String, dynamic>? extensions;

  const PhoneCredentials({
    required this.phoneNumber,
    this.verificationCode,
    this.extensions,
  });
}

/// Credentials for OAuth providers (Google, Facebook, etc.)
class OAuthCredentials extends AuthCredentials {
  final String provider;
  final String? accessToken;
  final String? idToken;
  final Map<String, dynamic>? additionalData;
  final Map<String, dynamic>? extensions;

  const OAuthCredentials({
    required this.provider,
    this.accessToken,
    this.idToken,
    this.additionalData,
    this.extensions,
  });
}

/// Credentials for custom token authentication
class CustomTokenCredentials extends AuthCredentials {
  final String token;
  final Map<String, dynamic>? extensions;

  const CustomTokenCredentials({
    required this.token,
    this.extensions,
  });
}

/// Credentials for anonymous authentication
class AnonymousCredentials extends AuthCredentials {
  const AnonymousCredentials();
}
