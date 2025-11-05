/// Represents an authenticated user in the e-commerce system
///
/// This entity contains core user information that can be extended
/// with additional platform-specific data via the metadata field.
class User {
  /// Unique identifier for the user
  final String id;

  /// User's email address
  final String? email;

  /// User's display name
  final String? displayName;

  /// User's phone number
  final String? phoneNumber;

  /// URL to user's profile photo
  final String? photoUrl;

  /// Whether the user's email has been verified
  final bool emailVerified;

  /// Whether the user's phone has been verified
  final bool phoneVerified;

  /// Whether the user account is active
  final bool isActive;

  /// Whether the user account is an admin
  final bool isAdmin;

  /// List of authentication providers (e.g., 'password', 'google.com', 'facebook.com')
  final List<String> providers;

  /// Provider-specific user data (e.g., Google user object, Facebook user data)
  /// Key: provider ID (e.g., 'google.com', 'facebook.com')
  /// Value: provider-specific user data as a map
  ///
  /// Example:
  /// ```dart
  /// {
  ///   'google.com': {
  ///     'uid': 'google_user_id',
  ///     'email': 'user@gmail.com',
  ///     'displayName': 'John Doe',
  ///     'photoURL': 'https://...',
  ///     'providerId': 'google.com',
  ///   },
  ///   'facebook.com': {
  ///     'uid': 'facebook_user_id',
  ///     'email': 'user@facebook.com',
  ///     'displayName': 'John Doe',
  ///     'photoURL': 'https://...',
  ///     'providerId': 'facebook.com',
  ///   }
  /// }
  /// ```
  final Map<String, Map<String, dynamic>>? providerData;

  /// When the user was created
  final DateTime? createdAt;

  /// When the user last logged in
  final DateTime? lastLoginAt;

  /// Platform-specific metadata (customer ID, custom fields, etc.)
  final Map<String, dynamic>? metadata;

  const User({
    required this.id,
    this.email,
    this.displayName,
    this.phoneNumber,
    this.photoUrl,
    this.emailVerified = false,
    this.phoneVerified = false,
    this.isActive = true,
    this.isAdmin = false,
    this.providers = const [],
    this.providerData,
    this.createdAt,
    this.lastLoginAt,
    this.metadata,
  });

  /// Create a copy of this user with modified fields
  User copyWith({
    String? id,
    String? email,
    String? displayName,
    String? phoneNumber,
    String? photoUrl,
    bool? emailVerified,
    bool? phoneVerified,
    bool? isActive,
    bool? isAdmin,
    List<String>? providers,
    Map<String, Map<String, dynamic>>? providerData,
    DateTime? createdAt,
    DateTime? lastLoginAt,
    Map<String, dynamic>? metadata,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      photoUrl: photoUrl ?? this.photoUrl,
      emailVerified: emailVerified ?? this.emailVerified,
      phoneVerified: phoneVerified ?? this.phoneVerified,
      isActive: isActive ?? this.isActive,
      isAdmin: isAdmin ?? this.isAdmin,
      providers: providers ?? this.providers,
      providerData: providerData ?? this.providerData,
      createdAt: createdAt ?? this.createdAt,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      metadata: metadata ?? this.metadata,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'photoUrl': photoUrl,
      'emailVerified': emailVerified,
      'phoneVerified': phoneVerified,
      'isActive': isActive,
      'isAdmin': isAdmin,
      'providers': providers,
      'providerData': providerData,
      'createdAt': createdAt?.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'metadata': metadata,
    };
  }

  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String?,
      displayName: json['displayName'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      photoUrl: json['photoUrl'] as String?,
      emailVerified: json['emailVerified'] as bool? ?? false,
      phoneVerified: json['phoneVerified'] as bool? ?? false,
      isActive: json['isActive'] as bool? ?? true,
      isAdmin: json['isAdmin'] as bool? ?? false,
      providers: (json['providers'] as List<dynamic>?)?.cast<String>() ?? [],
      providerData: json['providerData'] != null
          ? (json['providerData'] as Map<String, dynamic>).map(
              (key, value) => MapEntry(key, value as Map<String, dynamic>),
            )
          : null,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'] as String)
          : null,
      lastLoginAt: json['lastLoginAt'] != null
          ? DateTime.parse(json['lastLoginAt'] as String)
          : null,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }
}
