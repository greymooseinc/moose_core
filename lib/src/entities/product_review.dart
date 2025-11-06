import 'package:equatable/equatable.dart';

class ProductReview extends Equatable {
  final String id;
  final String productId;
  final String reviewer;
  final String? reviewerEmail;
  final String? reviewerAvatar;
  final String content;
  final double rating;
  final DateTime dateCreated;
  final bool verified;
  final String status;
  final List<String>? photos; // Photo URLs or local paths
  final Map<String, dynamic>? extensions;

  const ProductReview({
    required this.id,
    required this.productId,
    required this.reviewer,
    this.reviewerEmail,
    this.reviewerAvatar,
    required this.content,
    required this.rating,
    required this.dateCreated,
    this.verified = false,
    this.status = 'approved',
    this.photos,
    this.extensions,
  });

  ProductReview copyWith({
    String? id,
    String? productId,
    String? reviewer,
    String? reviewerEmail,
    String? reviewerAvatar,
    String? content,
    double? rating,
    DateTime? dateCreated,
    bool? verified,
    String? status,
    List<String>? photos,
    Map<String, dynamic>? extensions,
  }) {
    return ProductReview(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      reviewer: reviewer ?? this.reviewer,
      reviewerEmail: reviewerEmail ?? this.reviewerEmail,
      reviewerAvatar: reviewerAvatar ?? this.reviewerAvatar,
      content: content ?? this.content,
      rating: rating ?? this.rating,
      dateCreated: dateCreated ?? this.dateCreated,
      verified: verified ?? this.verified,
      status: status ?? this.status,
      photos: photos ?? this.photos,
      extensions: extensions ?? this.extensions,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'product_id': productId,
      'reviewer': reviewer,
      'reviewer_email': reviewerEmail,
      'reviewer_avatar': reviewerAvatar,
      'content': content,
      'rating': rating,
      'date_created': dateCreated.toIso8601String(),
      'verified': verified,
      'status': status,
      'photos': photos,
      'extensions': extensions,
    };
  }

  factory ProductReview.fromJson(Map<String, dynamic> json) {
    return ProductReview(
      id: json['id']?.toString() ?? '',
      productId: json['product_id']?.toString() ?? '',
      reviewer: json['reviewer'] ?? 'Anonymous',
      reviewerEmail: json['reviewer_email'],
      reviewerAvatar: json['reviewer_avatar'],
      content: json['content'] ?? '',
      rating: (json['rating'] is String)
          ? double.tryParse(json['rating']) ?? 0.0
          : (json['rating'] as num?)?.toDouble() ?? 0.0,
      dateCreated: json['date_created'] != null
          ? DateTime.tryParse(json['date_created']) ?? DateTime.now()
          : DateTime.now(),
      verified: json['verified'] ?? false,
      status: json['status'] ?? 'approved',
      photos: json['photos'] != null
          ? List<String>.from(json['photos'])
          : null,
      extensions: json['extensions'] as Map<String, dynamic>?,
    );
  }

  @override
  List<Object?> get props => [id, productId, rating, dateCreated];

  @override
  String toString() => 'ProductReview(id: $id, rating: $rating, reviewer: $reviewer)';
}