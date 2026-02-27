import '../entities/promo_banner.dart';
import 'repository.dart';

/// Repository responsible for retrieving promotional banners and reporting
/// engagement metrics (views/clicks) back to the backend.
abstract class BannerRepository extends CoreRepository {

  /// Load banners for a placement (e.g. `home_hero`, `cart_footer`).
  ///
  /// [placement] - Optional identifier describing where the banners will render.
  /// [locale] - Optional locale/language hint for localized campaigns.
  /// [filters] - Extra backend-specific filters (e.g., tags, customer group).
  Future<List<PromoBanner>> fetchBanners({
    String? placement,
    String? locale,
    Map<String, dynamic>? filters,
  });

  /// Track when the user taps/clicks a banner.
  Future<void> trackBannerClick(
    String bannerId, {
    Map<String, dynamic>? metadata,
  });
}
