import 'package:flutter/material.dart';
import 'user_interaction.dart';
import '../helpers/text_style_helper.dart';

class Collection {
  final String id;
  final String title;
  final String? subtitle;
  final String? featuredImage;
  final List<String>? images;
  final Map<String, dynamic>? metadata;
  final UserInteraction? action;
  final TextStyle? cardTitleStyle;
  final TextStyle? cardSubtitleStyle;

  const Collection({
    required this.id,
    required this.title,
    this.subtitle,
    this.featuredImage,
    this.images,
    this.metadata,
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
    Map<String, dynamic>? metadata,
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
      metadata: metadata ?? this.metadata,
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
      if (metadata != null) 'metadata': metadata,
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
      metadata: json['metadata'] as Map<String, dynamic>?,
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
}
