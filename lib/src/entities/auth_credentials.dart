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

  const EmailPasswordCredentials({
    required this.email,
    required this.password,
  });
}

/// Credentials for phone number authentication
class PhoneCredentials extends AuthCredentials {
  final String phoneNumber;
  final String? verificationCode;

  const PhoneCredentials({
    required this.phoneNumber,
    this.verificationCode,
  });
}

/// Credentials for OAuth providers (Google, Facebook, etc.)
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
  });
}

/// Credentials for custom token authentication
class CustomTokenCredentials extends AuthCredentials {
  final String token;

  const CustomTokenCredentials({
    required this.token,
  });
}

/// Credentials for anonymous authentication
class AnonymousCredentials extends AuthCredentials {
  const AnonymousCredentials();
}
