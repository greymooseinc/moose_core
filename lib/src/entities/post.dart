import 'package:flutter/material.dart';

import 'core_entity.dart';

/// Represents a blog post or article with content and metadata.
@immutable
class Post extends CoreEntity {
  final String id;
  final String title;
  final String content;
  final String excerpt;
  final String? authorId;
  final String? authorName;
  final String? authorAvatar;
  final DateTime dateCreated;
  final DateTime dateModified;
  final String status;
  final String? featuredImage;
  final List<String> categories;
  final List<String> tags;
  final int commentCount;
  final int viewCount;

  const Post({
    required this.id,
    required this.title,
    required this.content,
    this.excerpt = '',
    this.authorId,
    this.authorName,
    this.authorAvatar,
    required this.dateCreated,
    required this.dateModified,
    this.status = 'published',
    this.featuredImage,
    this.categories = const [],
    this.tags = const [],
    this.commentCount = 0,
    this.viewCount = 0,
    super.extensions,
  });

  Post copyWith({
    String? id,
    String? title,
    String? content,
    String? excerpt,
    String? authorId,
    String? authorName,
    String? authorAvatar,
    DateTime? dateCreated,
    DateTime? dateModified,
    String? status,
    String? featuredImage,
    List<String>? categories,
    List<String>? tags,
    int? commentCount,
    int? viewCount,
    Map<String, dynamic>? extensions,
  }) {
    return Post(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      excerpt: excerpt ?? this.excerpt,
      authorId: authorId ?? this.authorId,
      authorName: authorName ?? this.authorName,
      authorAvatar: authorAvatar ?? this.authorAvatar,
      dateCreated: dateCreated ?? this.dateCreated,
      dateModified: dateModified ?? this.dateModified,
      status: status ?? this.status,
      featuredImage: featuredImage ?? this.featuredImage,
      categories: categories ?? this.categories,
      tags: tags ?? this.tags,
      commentCount: commentCount ?? this.commentCount,
      viewCount: viewCount ?? this.viewCount,
      extensions: extensions ?? this.extensions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'excerpt': excerpt,
      'author_id': authorId,
      'author_name': authorName,
      'author_avatar': authorAvatar,
      'date_created': dateCreated.toIso8601String(),
      'date_modified': dateModified.toIso8601String(),
      'status': status,
      'featured_image': featuredImage,
      'categories': categories,
      'tags': tags,
      'comment_count': commentCount,
      'view_count': viewCount,
      'extensions': extensions,
    };
  }

  @override
  List<Object?> get props => [
        id,
        title,
        content,
        excerpt,
        authorId,
        authorName,
        authorAvatar,
        dateCreated,
        dateModified,
        status,
        featuredImage,
        categories,
        tags,
        commentCount,
        viewCount,
        extensions,
      ];

  @override
  String toString() {
    return 'Post(id: $id, title: $title, status: $status, dateCreated: $dateCreated)';
  }
}
