import 'package:flutter/material.dart';
import 'package:moose_core/services.dart';

import 'core_entity.dart';
import 'user_interaction.dart';

/// Represents a collection of products grouped together.
@immutable
class Collection extends CoreEntity {
  final String id;
  final String title;
  final String? subtitle;
  final String? featuredImage;
  final List<String>? images;
  final UserInteraction? action;
  final TextStyle? cardTitleStyle;
  final TextStyle? cardSubtitleStyle;

  const Collection({
    required this.id,
    required this.title,
    this.subtitle,
    this.featuredImage,
    this.images,
    super.extensions,
    this.action,
    this.cardTitleStyle,
    this.cardSubtitleStyle,
  });

  Collection copyWith({
    String? id,
    String? title,
    String? subtitle,
    String? featuredImage,
    List<String>? images,
    Map<String, dynamic>? extensions,
    UserInteraction? action,
    TextStyle? cardTitleStyle,
    TextStyle? cardSubtitleStyle,
  }) {
    return Collection(
      id: id ?? this.id,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      featuredImage: featuredImage ?? this.featuredImage,
      images: images ?? this.images,
      extensions: extensions ?? this.extensions,
      action: action ?? this.action,
      cardTitleStyle: cardTitleStyle ?? this.cardTitleStyle,
      cardSubtitleStyle: cardSubtitleStyle ?? this.cardSubtitleStyle,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      if (subtitle != null) 'subtitle': subtitle,
      if (featuredImage != null) 'featuredImage': featuredImage,
      if (images != null) 'images': images,
      if (extensions != null) 'extensions': extensions,
      if (action != null) 'action': action!.toJson(),
      if (cardTitleStyle != null) 'titleStyle': TextStyleHelper.toJson(cardTitleStyle!),
      if (cardSubtitleStyle != null) 'cardSubtitleStyle': TextStyleHelper.toJson(cardSubtitleStyle!),
    };
  }

  factory Collection.fromJson(Map<String, dynamic> json) {
    return Collection(
      id: json['id']?.toString() ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String?,
      featuredImage: json['featuredImage'] as String?,
      images: (json['images'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      extensions: json['extensions'] as Map<String, dynamic>?,
      action: json['action'] != null
          ? UserInteraction.fromJson(json['action'] as Map<String, dynamic>)
          : null,
      cardTitleStyle: json['cardTitleStyle'] != null
          ? TextStyleHelper.fromJson(json['cardTitleStyle'] as Map<String, dynamic>)
          : null,
      cardSubtitleStyle: json['cardSubtitleStyle'] != null
          ? TextStyleHelper.fromJson(json['cardSubtitleStyle'] as Map<String, dynamic>)
          : null,
    );
  }

  @override
  List<Object?> get props => [id, title, subtitle, featuredImage, images, extensions, action];
}
