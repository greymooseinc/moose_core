/// Domain entities for moose_core package.
///
/// This module exports all domain entities used throughout the application.
/// Entities represent core business objects and are backend-agnostic.
library entities;

// Cart entities
export 'src/entities/cart.dart';
export 'src/entities/cart_item.dart';

// Category & Tags
export 'src/entities/category.dart';
export 'src/entities/product_tag.dart';

// Checkout & Orders
export 'src/entities/checkout.dart';
export 'src/entities/order.dart';

// Collections
export 'src/entities/collection.dart';
export 'src/entities/collection_filters.dart';

// Filters
export 'src/entities/filter_preset.dart';
export 'src/entities/product_filters.dart';
export 'src/entities/search_filters.dart';

// Posts
export 'src/entities/post.dart';
export 'src/entities/post_sort_option.dart';

// Products
export 'src/entities/product.dart';
export 'src/entities/product_attribute.dart';
export 'src/entities/product_availability.dart';
export 'src/entities/product_search_result.dart';
export 'src/entities/product_section.dart';
export 'src/entities/product_sort_option.dart';
export 'src/entities/product_stock.dart';
export 'src/entities/product_variation.dart';

// Reviews
export 'src/entities/product_review.dart';
export 'src/entities/product_review_stats.dart';

// Search
export 'src/entities/search_result.dart';
export 'src/entities/search_result_type.dart';

// Authentication
export 'src/entities/auth_credentials.dart';
export 'src/entities/auth_result.dart';
export 'src/entities/user.dart';

// Common entities
export 'src/entities/paginated_result.dart';
export 'src/entities/plugin_config.dart';
export 'src/entities/push_notification.dart';
export 'src/entities/section_config.dart';
export 'src/entities/user_interaction.dart';
