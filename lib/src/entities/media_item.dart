import 'package:equatable/equatable.dart';

/// MediaItem - Represents a media asset (image, video, etc.)
///
/// Used in product galleries and anywhere media needs to be displayed
class MediaItem extends Equatable {
  final String url;
  final String type; // 'image', 'video', 'gif', etc.
  final String? thumbnail; // Optional thumbnail URL for videos
  final String? alt; // Alt text for accessibility
  final Map<String, dynamic>? metadata; // Additional metadata

  const MediaItem({
    required this.url,
    this.type = 'image',
    this.thumbnail,
    this.alt,
    this.metadata,
  });

  factory MediaItem.fromJson(Map<String, dynamic> json) {
    return MediaItem(
      url: json['url'] as String? ?? '',
      type: json['type'] as String? ?? 'image',
      thumbnail: json['thumbnail'] as String?,
      alt: json['alt'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'type': type,
      if (thumbnail != null) 'thumbnail': thumbnail,
      if (alt != null) 'alt': alt,
      if (metadata != null) 'metadata': metadata,
    };
  }

  /// Create a MediaItem from a simple URL string (defaults to image type)
  factory MediaItem.fromUrl(String url, {String type = 'image'}) {
    return MediaItem(url: url, type: type);
  }

  /// Helper to detect media type from URL extension
  static String detectTypeFromUrl(String url) {
    final lowerUrl = url.toLowerCase();

    // Video extensions
    if (lowerUrl.contains('.mp4') ||
        lowerUrl.contains('.mov') ||
        lowerUrl.contains('.avi') ||
        lowerUrl.contains('.webm') ||
        lowerUrl.contains('.m4v') ||
        lowerUrl.contains('.mkv')) {
      return 'video';
    }

    // GIF
    if (lowerUrl.contains('.gif')) {
      return 'gif';
    }

    // Default to image
    return 'image';
  }

  MediaItem copyWith({
    String? url,
    String? type,
    String? thumbnail,
    String? alt,
    Map<String, dynamic>? metadata,
  }) {
    return MediaItem(
      url: url ?? this.url,
      type: type ?? this.type,
      thumbnail: thumbnail ?? this.thumbnail,
      alt: alt ?? this.alt,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  List<Object?> get props => [url, type, thumbnail, alt, metadata];
}
