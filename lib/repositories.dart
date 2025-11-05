/// Repository interfaces for moose_core package.
///
/// This module exports all repository interfaces that define contracts for data operations.
/// Repositories are implemented by backend adapters and provide abstraction over data sources.
library repositories;

// Base repository
export 'src/repositories/repository.dart';

// Feature repositories
export 'src/repositories/auth_repository.dart';
export 'src/repositories/cart_repository.dart';
export 'src/repositories/post_repository.dart';
export 'src/repositories/products_repository.dart';
export 'src/repositories/push_notification_repository.dart';
export 'src/repositories/review_repository.dart';
export 'src/repositories/search_repository.dart';
