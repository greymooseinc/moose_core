import 'package:flutter/material.dart';
import 'package:moose_core/src/entities/core_entity.dart';
import 'package:moose_core/src/entities/country.dart';

/// Represents a physical address.
///
/// This entity can be used for shipping addresses, billing addresses,
/// customer addresses, and store locations. Supports both structured
/// address formats and free-form address lines.
@immutable
class Address extends CoreEntity {
  /// Unique identifier for the address
  final String? id;

  /// Address type (e.g., 'shipping', 'billing', 'home', 'work', 'store')
  final String? type;

  /// First name of the recipient/person
  final String? firstName;

  /// Last name of the recipient/person
  final String? lastName;

  /// Company name (optional)
  final String? company;

  /// Address line 1 (street address, P.O. Box, etc.)
  final String? address1;

  /// Address line 2 (apartment, suite, unit, building, floor, etc.)
  final String? address2;

  /// City or locality
  final String? city;

  /// State, province, or region
  final String? state;

  /// State/province code (e.g., 'CA' for California)
  final String? stateCode;

  /// Postal code or ZIP code
  final String? postalCode;

  /// Country information
  final Country? country;

  /// Phone number
  final String? phone;

  /// Email address
  final String? email;

  /// Geographic latitude coordinate
  final double? latitude;

  /// Geographic longitude coordinate
  final double? longitude;

  /// Whether this is the default address
  final bool isDefault;

  /// Whether this address has been verified
  final bool isVerified;

  /// Any special delivery instructions
  final String? instructions;

  /// Formatted address as a single string (for display purposes)
  final String? formattedAddress;

  const Address({
    this.id,
    this.type,
    this.firstName,
    this.lastName,
    this.company,
    this.address1,
    this.address2,
    this.city,
    this.state,
    this.stateCode,
    this.postalCode,
    this.country,
    this.phone,
    this.email,
    this.latitude,
    this.longitude,
    this.isDefault = false,
    this.isVerified = false,
    this.instructions,
    this.formattedAddress,
    super.extensions,
  });

  /// Returns the full name (firstName + lastName)
  String get fullName {
    final parts = [firstName, lastName].where((p) => p != null && p.isNotEmpty);
    return parts.join(' ');
  }

  /// Returns a formatted single-line address string
  String get singleLineAddress {
    if (formattedAddress != null && formattedAddress!.isNotEmpty) {
      return formattedAddress!;
    }

    final parts = <String>[];
    if (address1 != null && address1!.isNotEmpty) parts.add(address1!);
    if (address2 != null && address2!.isNotEmpty) parts.add(address2!);
    if (city != null && city!.isNotEmpty) parts.add(city!);
    if (state != null && state!.isNotEmpty) parts.add(state!);
    if (postalCode != null && postalCode!.isNotEmpty) parts.add(postalCode!);
    if (country?.name != null) parts.add(country!.name);

    return parts.join(', ');
  }

  /// Returns a multi-line formatted address
  List<String> get multiLineAddress {
    final lines = <String>[];

    if (fullName.isNotEmpty) lines.add(fullName);
    if (company != null && company!.isNotEmpty) lines.add(company!);
    if (address1 != null && address1!.isNotEmpty) lines.add(address1!);
    if (address2 != null && address2!.isNotEmpty) lines.add(address2!);

    final cityStateZip = <String>[];
    if (city != null && city!.isNotEmpty) cityStateZip.add(city!);
    if (state != null && state!.isNotEmpty) cityStateZip.add(state!);
    if (postalCode != null && postalCode!.isNotEmpty) cityStateZip.add(postalCode!);
    if (cityStateZip.isNotEmpty) lines.add(cityStateZip.join(', '));

    if (country?.name != null) lines.add(country!.name);

    return lines;
  }

  Address copyWith({
    String? id,
    String? type,
    String? firstName,
    String? lastName,
    String? company,
    String? address1,
    String? address2,
    String? city,
    String? state,
    String? stateCode,
    String? postalCode,
    Country? country,
    String? phone,
    String? email,
    double? latitude,
    double? longitude,
    bool? isDefault,
    bool? isVerified,
    String? instructions,
    String? formattedAddress,
    Map<String, dynamic>? extensions,
  }) {
    return Address(
      id: id ?? this.id,
      type: type ?? this.type,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      company: company ?? this.company,
      address1: address1 ?? this.address1,
      address2: address2 ?? this.address2,
      city: city ?? this.city,
      state: state ?? this.state,
      stateCode: stateCode ?? this.stateCode,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      isDefault: isDefault ?? this.isDefault,
      isVerified: isVerified ?? this.isVerified,
      instructions: instructions ?? this.instructions,
      formattedAddress: formattedAddress ?? this.formattedAddress,
      extensions: extensions ?? this.extensions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'firstName': firstName,
      'lastName': lastName,
      'company': company,
      'address1': address1,
      'address2': address2,
      'city': city,
      'state': state,
      'stateCode': stateCode,
      'postalCode': postalCode,
      'country': country?.toJson(),
      'phone': phone,
      'email': email,
      'latitude': latitude,
      'longitude': longitude,
      'isDefault': isDefault,
      'isVerified': isVerified,
      'instructions': instructions,
      'formattedAddress': formattedAddress,
      'extensions': extensions,
    };
  }

  factory Address.fromJson(Map<String, dynamic> json) {
    return Address(
      id: json['id'] as String?,
      type: json['type'] as String?,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      company: json['company'] as String?,
      address1: json['address1'] as String?,
      address2: json['address2'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      stateCode: json['stateCode'] as String?,
      postalCode: json['postalCode'] as String?,
      country: json['country'] != null
          ? Country.fromJson(json['country'] as Map<String, dynamic>)
          : null,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      latitude: json['latitude'] as double?,
      longitude: json['longitude'] as double?,
      isDefault: json['isDefault'] as bool? ?? false,
      isVerified: json['isVerified'] as bool? ?? false,
      instructions: json['instructions'] as String?,
      formattedAddress: json['formattedAddress'] as String?,
      extensions: json['extensions'] as Map<String, dynamic>?,
    );
  }

  @override
  List<Object?> get props => [
        id,
        type,
        firstName,
        lastName,
        company,
        address1,
        address2,
        city,
        state,
        stateCode,
        postalCode,
        country,
        phone,
        email,
        latitude,
        longitude,
        isDefault,
        isVerified,
        instructions,
        formattedAddress,
        extensions,
      ];
}
