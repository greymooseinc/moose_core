class User {
  final String id;
  final String? email;
  final String? displayName;
  final String? phoneNumber;
  final String? photoUrl;
  final bool emailVerified;
  final bool phoneVerified;
  final bool isActive;
  final bool isAdmin;
  final List<String> providers;
  final Map<String, Map<String, dynamic>>? providerData;
  final DateTime? createdAt;
  final DateTime? lastLoginAt;
  final Map<String, dynamic>? extensions;

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
    this.extensions,
  });

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
    Map<String, dynamic>? extensions,
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
      extensions: extensions ?? this.extensions,
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
      'extensions': extensions,
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
      extensions: json['extensions'] as Map<String, dynamic>?,
    );
  }
}
