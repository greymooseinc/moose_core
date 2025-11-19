import 'package:flutter/material.dart';
import 'package:moose_core/src/entities/core_entity.dart';

/// Represents a postal code with associated location data.
///
/// Used for postal code lookup, address autocomplete, and validation.
/// Contains geographic and administrative information for a postal code.
@immutable
class PostalCode extends CoreEntity {
  /// The postal code value (e.g., '90210', 'SW1A 1AA', 'M5H 2N2')
  final String code;

  /// Country code (ISO 3166-1 alpha-2)
  final String countryCode;

  /// City or locality name
  final String? city;

  /// State, province, or region name
  final String? state;

  /// State/province code
  final String? stateCode;

  /// County or district name
  final String? county;

  /// Geographic latitude coordinate
  final double? latitude;

  /// Geographic longitude coordinate
  final double? longitude;

  /// Timezone identifier (e.g., 'America/Los_Angeles')
  final String? timezone;

  /// Accuracy of the coordinates (in meters)
  final double? accuracy;

  const PostalCode({
    required this.code,
    required this.countryCode,
    this.city,
    this.state,
    this.stateCode,
    this.county,
    this.latitude,
    this.longitude,
    this.timezone,
    this.accuracy,
    super.extensions,
  });

  /// Returns true if this postal code has valid geographic coordinates
  bool get hasCoordinates => latitude != null && longitude != null;

  PostalCode copyWith({
    String? code,
    String? countryCode,
    String? city,
    String? state,
    String? stateCode,
    String? county,
    double? latitude,
    double? longitude,
    String? timezone,
    double? accuracy,
    Map<String, dynamic>? extensions,
  }) {
    return PostalCode(
      code: code ?? this.code,
      countryCode: countryCode ?? this.countryCode,
      city: city ?? this.city,
      state: state ?? this.state,
      stateCode: stateCode ?? this.stateCode,
      county: county ?? this.county,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      timezone: timezone ?? this.timezone,
      accuracy: accuracy ?? this.accuracy,
      extensions: extensions ?? this.extensions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'countryCode': countryCode,
      'city': city,
      'state': state,
      'stateCode': stateCode,
      'county': county,
      'latitude': latitude,
      'longitude': longitude,
      'timezone': timezone,
      'accuracy': accuracy,
      'extensions': extensions,
    };
  }

  factory PostalCode.fromJson(Map<String, dynamic> json) {
    return PostalCode(
      code: json['code'] as String,
      countryCode: json['countryCode'] as String,
      city: json['city'] as String?,
      state: json['state'] as String?,
      stateCode: json['stateCode'] as String?,
      county: json['county'] as String?,
      latitude: json['latitude'] as double?,
      longitude: json['longitude'] as double?,
      timezone: json['timezone'] as String?,
      accuracy: json['accuracy'] as double?,
      extensions: json['extensions'] as Map<String, dynamic>?,
    );
  }

  @override
  List<Object?> get props => [
        code,
        countryCode,
        city,
        state,
        stateCode,
        county,
        latitude,
        longitude,
        timezone,
        accuracy,
        extensions,
      ];
}
