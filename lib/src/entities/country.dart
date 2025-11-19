import 'package:flutter/material.dart';
import 'package:moose_core/src/entities/core_entity.dart';

/// Represents a country with its code and name.
///
/// Used in address forms, shipping configurations, and location-based features.
/// Follows ISO 3166-1 alpha-2 country code standard.
@immutable
class Country extends CoreEntity {
  /// ISO 3166-1 alpha-2 country code (e.g., 'US', 'GB', 'CA')
  final String code;

  /// Full country name (e.g., 'United States', 'United Kingdom', 'Canada')
  final String name;

  /// ISO 3166-1 alpha-3 country code (e.g., 'USA', 'GBR', 'CAN')
  final String? code3;

  /// Numeric country code (e.g., '840' for US, '826' for GB)
  final String? numericCode;

  /// Phone calling code (e.g., '+1', '+44', '+91')
  final String? phoneCode;

  /// Currency code (e.g., 'USD', 'GBP', 'EUR')
  final String? currencyCode;

  /// Currency symbol (e.g., '$', '£', '€')
  final String? currencySymbol;

  /// Whether this country is available for shipping
  final bool isShippingAvailable;

  /// Whether this country is available for billing
  final bool isBillingAvailable;

  /// List of states/provinces/regions in this country
  final List<CountryState>? states;

  const Country({
    required this.code,
    required this.name,
    this.code3,
    this.numericCode,
    this.phoneCode,
    this.currencyCode,
    this.currencySymbol,
    this.isShippingAvailable = true,
    this.isBillingAvailable = true,
    this.states,
    super.extensions,
  });

  Country copyWith({
    String? code,
    String? name,
    String? code3,
    String? numericCode,
    String? phoneCode,
    String? currencyCode,
    String? currencySymbol,
    bool? isShippingAvailable,
    bool? isBillingAvailable,
    List<CountryState>? states,
    Map<String, dynamic>? extensions,
  }) {
    return Country(
      code: code ?? this.code,
      name: name ?? this.name,
      code3: code3 ?? this.code3,
      numericCode: numericCode ?? this.numericCode,
      phoneCode: phoneCode ?? this.phoneCode,
      currencyCode: currencyCode ?? this.currencyCode,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      isShippingAvailable: isShippingAvailable ?? this.isShippingAvailable,
      isBillingAvailable: isBillingAvailable ?? this.isBillingAvailable,
      states: states ?? this.states,
      extensions: extensions ?? this.extensions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'code3': code3,
      'numericCode': numericCode,
      'phoneCode': phoneCode,
      'currencyCode': currencyCode,
      'currencySymbol': currencySymbol,
      'isShippingAvailable': isShippingAvailable,
      'isBillingAvailable': isBillingAvailable,
      'states': states?.map((s) => s.toJson()).toList(),
      'extensions': extensions,
    };
  }

  factory Country.fromJson(Map<String, dynamic> json) {
    return Country(
      code: json['code'] as String,
      name: json['name'] as String,
      code3: json['code3'] as String?,
      numericCode: json['numericCode'] as String?,
      phoneCode: json['phoneCode'] as String?,
      currencyCode: json['currencyCode'] as String?,
      currencySymbol: json['currencySymbol'] as String?,
      isShippingAvailable: json['isShippingAvailable'] as bool? ?? true,
      isBillingAvailable: json['isBillingAvailable'] as bool? ?? true,
      states: json['states'] != null
          ? (json['states'] as List<dynamic>)
              .map((s) => CountryState.fromJson(s as Map<String, dynamic>))
              .toList()
          : null,
      extensions: json['extensions'] as Map<String, dynamic>?,
    );
  }

  @override
  List<Object?> get props => [
        code,
        name,
        code3,
        numericCode,
        phoneCode,
        currencyCode,
        currencySymbol,
        isShippingAvailable,
        isBillingAvailable,
        states,
        extensions,
      ];
}

/// Represents a state, province, or region within a country.
@immutable
class CountryState extends CoreEntity {
  /// State/province code (e.g., 'CA' for California, 'ON' for Ontario)
  final String code;

  /// Full state/province name (e.g., 'California', 'Ontario')
  final String name;

  /// Country code this state belongs to
  final String? countryCode;

  const CountryState({
    required this.code,
    required this.name,
    this.countryCode,
    super.extensions,
  });

  CountryState copyWith({
    String? code,
    String? name,
    String? countryCode,
    Map<String, dynamic>? extensions,
  }) {
    return CountryState(
      code: code ?? this.code,
      name: name ?? this.name,
      countryCode: countryCode ?? this.countryCode,
      extensions: extensions ?? this.extensions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'code': code,
      'name': name,
      'countryCode': countryCode,
      'extensions': extensions,
    };
  }

  factory CountryState.fromJson(Map<String, dynamic> json) {
    return CountryState(
      code: json['code'] as String,
      name: json['name'] as String,
      countryCode: json['countryCode'] as String?,
      extensions: json['extensions'] as Map<String, dynamic>?,
    );
  }

  @override
  List<Object?> get props => [
        code,
        name,
        countryCode,
        extensions,
      ];
}
