# Repository System

## Overview

Repositories are the data abstraction layer in `moose_core`. They define **contracts** (abstract interfaces) for all data operations. Backend adapters provide the concrete implementations. Plugins and sections consume repositories through the `AdapterRegistry` — they never depend on specific adapter implementations.

All repository interfaces are exported from `package:moose_core/repositories.dart`.

---

## CoreRepository

**File:** `lib/src/repositories/repository.dart`

```dart
abstract class CoreRepository {
  void initialize() {
    // Default: no-op. Override for synchronous setup.
  }
}
```

Every repository extends `CoreRepository`. The `initialize()` hook is synchronous — it is called automatically by `BackendAdapter.getRepository<T>()` / `getRepositoryAsync<T>()` immediately after instantiation, before the instance is cached. Use it for:

- Setting up listeners and subscriptions
- Initializing local state
- Registering hooks
- Triggering async operations fire-and-forget (do NOT `await` in `initialize()`)

---

## How Repositories Are Registered

Repositories are registered inside `BackendAdapter.initialize()` using factory functions:

```dart
// Synchronous factory (preferred — works in sync FeatureSection context)
registerRepositoryFactory<ProductsRepository>(
  () => WooProductsRepository(apiClient),
);

// Asynchronous factory (use when construction itself is async)
registerAsyncRepositoryFactory<CartRepository>(
  () async => WooCartRepository(await getApiClient()),
);
```

- Factories are registered by type — the **last registered adapter wins** for any given type.
- Instances are created **lazily** on first `getRepository<T>()` call and cached permanently.
- `initialize()` is called on the instance before caching.

---

## How Repositories Are Accessed

### From a plugin (`onInit` / `onStart`)

```dart
@override
Future<void> onInit() async {
  final products = adapterRegistry.getRepository<ProductsRepository>();
  // or async:
  final cart = await adapterRegistry.getRepositoryAsync<CartRepository>();
}
```

### From a FeatureSection (sync build context)

```dart
@override
Widget build(BuildContext context) {
  final adapters = adaptersOf(context);
  final products = adapters.getRepository<ProductsRepository>();

  return BlocProvider(
    create: (_) => ProductsBloc(products)..add(LoadProducts()),
    child: const ProductsList(),
  );
}
```

### Shortcut via MooseAppContext

```dart
final products = appContext.getRepository<ProductsRepository>();
// Equivalent to: appContext.adapterRegistry.getRepository<ProductsRepository>()
```

### Guard for optional repositories

```dart
if (adapterRegistry.hasRepository<PushNotificationRepository>()) {
  final pushRepo = adapterRegistry.getRepository<PushNotificationRepository>();
}
```

### Repository constructor injection (BLoC pattern)

BLoCs receive repositories via constructor — they never call `getRepository` directly:

```dart
class ProductsBloc extends Bloc<ProductsEvent, ProductsState> {
  ProductsBloc(this._repository) : super(ProductsInitial());

  final ProductsRepository _repository;
}
```

---

## Repository Reference

### ProductsRepository

**File:** `lib/src/repositories/products_repository.dart`

Catalog operations: products, categories, collections, variations, reviews, related items, and availability.

| Method | Returns | Description |
|---|---|---|
| `getProducts({filters, cacheTTL})` | `Future<ProductListResult>` | Paginated product list with optional filters |
| `getProductById(id, {cacheTTL})` | `Future<Product>` | Single product by ID |
| `getProductsByIds(ids, {includeVariations, cacheTTL})` | `Future<List<Product>>` | Batch fetch by IDs |
| `getProductsBySKUs(skus, {cacheTTL})` | `Future<List<Product>>` | Batch fetch by SKU strings |
| `getCategories({parentId, hideEmpty, orderBy, cacheTTL})` | `Future<List<Category>>` | Category tree, optionally filtered by parent |
| `getCategoryById(id, {cacheTTL})` | `Future<Category>` | Single category by ID |
| `getCollections({filters, cacheTTL})` | `Future<List<Collection>>` | Product collections (curated lists) |
| `getProductVariations(productId, {cacheTTL})` | `Future<List<ProductVariation>>` | All variations for a product |
| `getProductVariation(productId, variationId, {cacheTTL})` | `Future<ProductVariation>` | Single variation |
| `getProductAttributes(productId, {cacheTTL})` | `Future<List<ProductAttribute>>` | Attributes (color, size, etc.) |
| `getProductReviews(productId, {page, perPage, status, cacheTTL})` | `Future<List<ProductReview>>` | Paginated reviews for a product |
| `getProductReviewStats(productId, {cacheTTL})` | `Future<ProductReviewStats>` | Rating average and distribution |
| `getRelatedProducts(productId, {limit, cacheTTL})` | `Future<List<Product>>` | Related products |
| `getUpsellProducts(productId, {limit, cacheTTL})` | `Future<List<Product>>` | Upsell suggestions |
| `getCrossSellProducts(productId, {limit, cacheTTL})` | `Future<List<Product>>` | Cross-sell suggestions |
| `getFrequentlyBoughtTogether(productId, {limit, cacheTTL})` | `Future<List<Product>>` | Frequently bought together |
| `getFeaturedProducts({limit, categoryId, cacheTTL})` | `Future<List<Product>>` | Featured/promoted products |
| `getProductStock(productId, {variationId, cacheTTL})` | `Future<ProductStock>` | Stock quantity and status |
| `getProductTags({cacheTTL})` | `Future<List<ProductTag>>` | All product tags |
| `getProductBrands({cacheTTL})` | `Future<List<String>>` | All brand names |
| `validateProductAvailability({productId, quantity, variationId, cacheTTL})` | `Future<ProductAvailability>` | Check if quantity is purchasable |
| `createReview(review)` | `Future<ProductReview>` | Submit a product review |

**Key result types:**

- `ProductListResult` — contains `List<Product> products`, pagination metadata, and total count. Defined in `product_sort_option.dart`.
- `ProductFilters` — filter by category, price range, attributes, tags, etc.
- `CollectionFilters` — filter collections.
- `ProductStock` — stock quantity, status, manage-stock flag.
- `ProductAvailability` — available: bool, maxQuantity, message.

---

### CartRepository

**File:** `lib/src/repositories/cart_repository.dart`

Full commerce flow: cart management, checkout, order lifecycle, and payments.

**Cart operations:**

| Method | Returns | Description |
|---|---|---|
| `getCart({cartId, customerId})` | `Future<Cart>` | Retrieve current cart |
| `createCart({customerId})` | `Future<Cart>` | Create a new empty cart |
| `addItem({productId, variationId, quantity, metadata})` | `Future<Cart>` | Add product to cart |
| `updateItemQuantity({itemId, quantity})` | `Future<Cart>` | Update line item quantity |
| `removeItem({itemId})` | `Future<Cart>` | Remove line item |
| `clearCart()` | `Future<Cart>` | Empty the cart |
| `applyCoupon({couponCode})` | `Future<Cart>` | Apply coupon code |
| `removeCoupon({couponCode})` | `Future<Cart>` | Remove coupon code |
| `calculateTotals({shippingMethodId, shippingAddress})` | `Future<Cart>` | Recalculate totals |
| `setShippingMethod({shippingMethodId})` | `Future<Cart>` | Select shipping method |
| `getShippingMethods({shippingAddress})` | `Future<List<ShippingMethod>>` | Available shipping options |
| `getPaymentMethods()` | `Future<List<PaymentMethod>>` | Available payment methods |
| `validateCart()` | `Future<CartValidationResult>` | Check cart for errors or warnings |
| `checkout({checkoutRequest})` | `Future<CheckoutResult>` | Submit order |

**Order operations:**

| Method | Returns | Description |
|---|---|---|
| `getOrder({orderId})` | `Future<Order>` | Fetch a single order |
| `getCustomerOrders({customerId, page, perPage, status})` | `Future<List<Order>>` | Customer order history |
| `updateOrderStatus({orderId, status})` | `Future<Order>` | Update order status |
| `cancelOrder({orderId, reason})` | `Future<Order>` | Cancel an order |

**Payment operations:**

| Method | Returns | Description |
|---|---|---|
| `processPayment({orderId, paymentMethodId, paymentData})` | `Future<PaymentResult>` | Initiate payment |
| `verifyPayment({orderId, transactionId})` | `Future<PaymentStatus>` | Verify payment status |
| `requestRefund({orderId, amount, reason})` | `Future<RefundResult>` | Request a refund |

**Result types defined in `cart_repository.dart`:**

- `CartValidationResult` — `isValid`, `errors`, `warnings`, `metadata`; factory: `CartValidationResult.valid()`, `CartValidationResult.invalid(errors)`
- `CheckoutResult` — `success`, `order`, `errorMessage`, `paymentStatus`, `redirectUrl`; factory: `CheckoutResult.success(...)`, `CheckoutResult.failure(message)`
- `PaymentResult` — `success`, `transactionId`, `status`, `errorMessage`; factory: `PaymentResult.success(...)`, `PaymentResult.failure(message)`, `PaymentResult.pending()`
- `RefundResult` — `success`, `refundId`, `refundedAmount`, `errorMessage`; factory: `RefundResult.success(...)`, `RefundResult.failure(message)`
- `PaymentStatus` enum — `pending`, `processing`, `completed`, `failed`, `cancelled`, `refunded`

`ShippingMethod` and `PaymentMethod` are defined in `lib/src/entities/checkout.dart`.

---

### AuthRepository

**File:** `lib/src/repositories/auth_repository.dart`

User authentication, profile management, token lifecycle, and account linking.

**Authentication:**

| Method | Returns | Description |
|---|---|---|
| `signIn(credentials)` | `Future<AuthResult>` | Sign in with any credential type |
| `signUp(credentials, {displayName, photoUrl, metadata})` | `Future<AuthResult>` | Create new account |
| `signOut()` | `Future<void>` | Sign out current user |
| `getCurrentUser()` | `Future<User?>` | Get authenticated user, null if none |
| `authStateChanges` | `Stream<User?>` | Stream of auth state — emits User or null |

**Password management:**

| Method | Returns | Description |
|---|---|---|
| `sendPasswordResetEmail(email)` | `Future<PasswordResetResult>` | Send reset link |
| `confirmPasswordReset({code, newPassword})` | `Future<PasswordResetResult>` | Complete reset with code |
| `changePassword({currentPassword, newPassword})` | `Future<PasswordResetResult>` | Change password while signed in |

**Email / phone verification:**

| Method | Returns | Description |
|---|---|---|
| `sendEmailVerification()` | `Future<void>` | Send verification email |
| `verifyEmail(code)` | `Future<EmailVerificationResult>` | Confirm email with code |
| `sendPhoneVerificationCode(phoneNumber)` | `Future<void>` | Send SMS code |
| `verifyPhoneNumber({phoneNumber, verificationCode})` | `Future<EmailVerificationResult>` | Confirm phone with SMS code |

**Profile:**

| Method | Returns | Description |
|---|---|---|
| `updateProfile({displayName, photoUrl, metadata})` | `Future<User>` | Update profile fields |
| `updateEmail(newEmail)` | `Future<User>` | Change email address |
| `deleteAccount()` | `Future<void>` | Permanently delete account |

**Tokens:**

| Method | Returns | Description |
|---|---|---|
| `getIdToken({forceRefresh})` | `Future<String?>` | Get auth token; pass `forceRefresh: true` to renew |
| `refreshToken(refreshToken)` | `Future<AuthResult>` | Renew using refresh token |

**Account linking:**

| Method | Returns | Description |
|---|---|---|
| `linkCredential(credentials)` | `Future<AuthResult>` | Link additional auth method |
| `unlinkProvider(providerId)` | `Future<User>` | Remove linked provider |

**MFA (optional):**

| Method | Returns | Description |
|---|---|---|
| `enrollMFA({phoneNumber})` | `Future<void>` | Enable MFA |
| `unenrollMFA()` | `Future<void>` | Disable MFA |

**Credential types** (defined in `auth_credentials.dart`): `EmailPasswordCredentials`, `PhoneCredentials`, `OAuthCredentials`, `CustomTokenCredentials`, `AnonymousCredentials`.

**Result types** (defined in `auth_result.dart`): `AuthResult` (extends `CoreEntity`), `PasswordResetResult`, `EmailVerificationResult`.

**Note:** Not all methods need to be implemented — throw `UnimplementedError` for unsupported features.

---

### SearchRepository

**File:** `lib/src/repositories/search_repository.dart`

Full-text search with suggestions, trending terms, and local search history.

| Method | Returns | Description |
|---|---|---|
| `search({query, filters})` | `Future<List<SearchResult>>` | Search all content types |
| `getSuggestions({query, limit})` | `Future<List<String>>` | Autocomplete suggestions for partial query |
| `getPopularSearches({limit})` | `Future<List<String>>` | Trending/popular search terms |
| `getRecentSearches({limit})` | `Future<List<String>>` | User's local search history |
| `saveSearchToHistory(query)` | `Future<void>` | Persist a search term to history |
| `clearSearchHistory()` | `Future<void>` | Wipe local search history |

`SearchFilters` (defined in `search_filters.dart`) allows filtering by type, category, price range, etc.
`SearchResult` (defined in `search_result.dart`) includes `id`, `type`, `title`, `description`, `imageUrl`, `url`, `price`, `metadata`, and `extensions`.

---

### ReviewRepository

**File:** `lib/src/repositories/review_repository.dart`

Entity-agnostic reviews — products, posts, or any entity type.

| Method | Returns | Description |
|---|---|---|
| `getReviews({entityType, entityId, page, perPage, status, sortBy})` | `Future<PaginatedResult<ProductReview>>` | Paginated reviews for any entity |
| `createReview(review)` | `Future<ProductReview>` | Submit a new review |
| `getReviewStats({entityType, entityId})` | `Future<ProductReviewStats>` | Average rating, count, distribution |
| `getReviewImages(reviewId)` | `Future<List<String>>` | Image URLs for a specific review |
| `getProductReviewImages({entityType, entityId})` | `Future<List<Map<String, dynamic>>>` | All review images for an entity (gallery use) |
| `getReviewById(reviewId)` | `Future<ProductReview>` | Fetch a single review by ID |

**`getReviews` parameters:**
- `entityType`: `'product'`, `'post'`, `'article'`, or any string your backend supports
- `status`: `'approved'` (default), `'pending'`, `'all'`
- `sortBy`: `'newest'` (default), `'oldest'`, `'highest_rating'`, `'lowest_rating'`

**Note:** `ProductsRepository` also has `getProductReviews` and `createReview` — those are product-specific. `ReviewRepository` is the general-purpose review interface for any entity type.

---

### PostRepository

**File:** `lib/src/repositories/post_repository.dart`

Blog posts, pages, articles, and any CMS content type.

| Method | Returns | Description |
|---|---|---|
| `getPosts({page, perPage, postType, categoryId, authorId, search, sortBy, sortOrder, status, metadataFilter})` | `Future<PaginatedResult<Post>>` | Paginated posts with rich filtering |
| `getPostById(id)` | `Future<Post>` | Single post by ID |

**`getPosts` parameters:**
- `postType`: `'post'` (default), `'page'`, `'article'`, or any custom type your CMS supports
- `status`: `'publish'` (default), `'draft'`, `'pending'`, etc.
- `sortBy` / `sortOrder`: backend-specific field name and `'asc'` / `'desc'`
- `metadataFilter`: arbitrary map of extra backend filters

---

### BannerRepository

**File:** `lib/src/repositories/banner_repository.dart`

Promotional banners with placement targeting and engagement tracking.

| Method | Returns | Description |
|---|---|---|
| `fetchBanners({placement, locale, filters})` | `Future<List<PromoBanner>>` | Load banners for a placement slot |
| `trackBannerClick(bannerId, {metadata})` | `Future<void>` | Report a banner click to the backend |

**Parameters:**
- `placement`: slot identifier, e.g. `'home_hero'`, `'cart_footer'`, `'product_sidebar'`
- `locale`: locale/language hint for localized campaigns, e.g. `'en'`, `'fr'`
- `filters`: adapter-specific filter map (tags, customer group, etc.)

`PromoBanner` fields: `id`, `title`, `imageUrl`, `linkUrl`, `placement`, `active`, `startDate`, `endDate`, `metadata`, `extensions`.

---

### PushNotificationRepository

**File:** `lib/src/repositories/push_notification_repository.dart`

Device token management, permission handling, topic subscriptions, and notification streams.

**Required (must implement):**

| Method | Returns | Description |
|---|---|---|
| `requestPermission()` | `Future<NotificationPermissionStatus>` | Request OS notification permission |
| `getPermissionStatus()` | `Future<NotificationPermissionStatus>` | Check permission without prompting |
| `getDeviceToken()` | `Future<String?>` | Device push token (null if unavailable) |
| `onTokenRefresh` | `Stream<String>` | Stream of token refresh events |
| `onNotificationReceived` | `Stream<PushNotification>` | Foreground notification stream |
| `onNotificationTapped` | `Stream<PushNotification>` | Notification tap/open stream (background/terminated) |
| `subscribeToTopic(topic)` | `Future<void>` | Subscribe to a named topic |
| `unsubscribeFromTopic(topic)` | `Future<void>` | Unsubscribe from a topic |
| `getBadgeCount()` | `Future<int?>` | Current badge count (null if unsupported) |
| `setBadgeCount(count)` | `Future<void>` | Set badge count (0 to clear) |
| `clearAllNotifications()` | `Future<void>` | Clear all from notification center |
| `getInitialNotification()` | `Future<PushNotification?>` | Notification that launched the app (if any) |

**Optional (default no-op implementations provided):**

| Method | Returns | Description |
|---|---|---|
| `syncSettings(settings)` | `Future<void>` | Sync preferences with backend |
| `getNotificationHistory({limit, offset})` | `Future<List<PushNotification>>` | Notification history (if provider supports) |
| `markAsRead(notificationId)` | `Future<PushNotification?>` | Track read status |
| `deleteNotification(notificationId)` | `Future<void>` | Remove from history |
| `setForegroundPresentationOptions({showAlert, playSound, showBadge})` | `Future<void>` | Configure foreground display |

**Types:**
- `NotificationPermissionStatus` enum — defined in `push_notification.dart`
- `NotificationSettings` — `enabled`, `enabledTypes` set (extends `CoreEntity`)
- `PushNotification` — `id`, `title`, `body`, `data`, `route`, `imageUrl`, etc.

---

### ShortsRepository

**File:** `lib/src/repositories/shorts_repository.dart`

Short-form content (stories, reels, short videos) with pagination.

| Method | Returns | Description |
|---|---|---|
| `getShorts({page, perPage, status, filters})` | `Future<PaginatedResult<Short>>` | Paginated list of shorts |
| `getShortById(id)` | `Future<Short>` | Single short by ID |
| `refreshShorts()` | `Future<void>` | Invalidate cache (default: no-op) |

**`filters` map keys (adapter-specific):**
- `'category'`: filter by category ID or slug
- `'tag'`: filter by tag
- `'author'`: filter by author ID
- `'search'`: text search
- `'sortBy'` / `'sortOrder'`: sorting

`Short` entity fields: `id`, `title`, `description`, `videoUrl`, `thumbnailUrl`, `duration`, `likes`, `views`, `metadata`.

---

### StoreRepository

**File:** `lib/src/repositories/store_repository.dart`

Store metadata, physical locations, legal policy links, contact information, social media, and operating hours.

**Store info:**

| Method | Returns | Description |
|---|---|---|
| `getStoreInfo()` | `Future<Map<String, dynamic>>` | Full metadata map |
| `getStoreName()` | `Future<String>` | Display name |
| `getStoreDescription()` | `Future<String?>` | Description or tagline |
| `getStoreLogoUrl()` | `Future<String?>` | Logo image URL |
| `getStoreCurrency()` | `Future<String>` | Default currency code (e.g. `'USD'`) |
| `getStoreTimezone()` | `Future<String?>` | Timezone identifier (e.g. `'America/New_York'`) |

**Locations:**

| Method | Returns | Description |
|---|---|---|
| `getStoreLocations({locationType})` | `Future<List<Address>>` | All physical locations |
| `getStoreLocation({locationId})` | `Future<Address?>` | Single location by ID |
| `findNearestStores({latitude, longitude, radius, limit})` | `Future<List<Address>>` | Nearby locations sorted by distance |

**Legal/policy:**

| Method | Returns | Description |
|---|---|---|
| `getTermsOfServiceUrl()` | `Future<String?>` | ToS URL |
| `getPrivacyPolicyUrl()` | `Future<String?>` | Privacy policy URL |
| `getReturnPolicyUrl()` | `Future<String?>` | Return policy URL |
| `getShippingPolicyUrl()` | `Future<String?>` | Shipping policy URL |
| `getRefundPolicyUrl()` | `Future<String?>` | Refund policy URL |
| `getCookiePolicyUrl()` | `Future<String?>` | Cookie policy URL |
| `getAllPolicyUrls()` | `Future<Map<String, String>>` | All policies; keys: `'terms'`, `'privacy'`, `'return'`, `'shipping'`, `'refund'`, `'cookie'` |

**Contact & social:**

| Method | Returns | Description |
|---|---|---|
| `getContactEmail()` | `Future<String?>` | Primary contact email |
| `getContactPhone()` | `Future<String?>` | Primary contact phone |
| `getSupportEmail()` | `Future<String?>` | Support email |
| `getSupportPhone()` | `Future<String?>` | Support phone |
| `getSocialMediaLinks()` | `Future<Map<String, String>>` | Platform → URL map |
| `getSocialMediaLink({platform})` | `Future<String?>` | Single platform URL |

**Hours:**

| Method | Returns | Description |
|---|---|---|
| `getOperatingHours()` | `Future<Map<String, String>?>` | Day → hours string map |
| `isStoreOpen({locationId})` | `Future<bool>` | Whether store is currently open |

**Custom settings:**

| Method | Returns | Description |
|---|---|---|
| `getSetting({key, defaultValue})` | `Future<dynamic>` | Any custom store setting |
| `getSettings({keys})` | `Future<Map<String, dynamic>>` | Multiple settings at once |
| `getAllSettings()` | `Future<Map<String, dynamic>>` | All available settings |

---

### LocationRepository

**File:** `lib/src/repositories/location_repository.dart`

Address autocomplete, postal code lookup, geocoding, country lists, and customer address management.

**Address autocomplete:**

| Method | Returns | Description |
|---|---|---|
| `searchAddresses({query, countryCode, limit})` | `Future<List<Address>>` | Autocomplete suggestions |
| `getAddressDetails({placeId})` | `Future<Address>` | Full address from a place ID |

**Postal code:**

| Method | Returns | Description |
|---|---|---|
| `lookupPostalCode({postalCode, countryCode})` | `Future<PostalCode?>` | Geographic data for postal code |
| `validatePostalCode({postalCode, countryCode})` | `Future<bool>` | Format validation |

**Geocoding:**

| Method | Returns | Description |
|---|---|---|
| `getAddressFromCoordinates({latitude, longitude})` | `Future<Address?>` | Reverse geocoding |
| `getCoordinatesFromAddress({address})` | `Future<Map<String, double>?>` | Forward geocoding; returns `{'latitude': ..., 'longitude': ...}` |

**Countries:**

| Method | Returns | Description |
|---|---|---|
| `getCountries({shippingOnly, billingOnly})` | `Future<List<Country>>` | Available countries |
| `getCountry({countryCode})` | `Future<Country?>` | Country by ISO alpha-2 code |
| `getStates({countryCode})` | `Future<List<CountryState>>` | States/provinces for a country |

**Customer addresses:**

| Method | Returns | Description |
|---|---|---|
| `getCustomerAddresses({customerId})` | `Future<List<Address>>` | All saved addresses |
| `getCustomerAddress({customerId, addressId})` | `Future<Address?>` | Single address |
| `saveCustomerAddress({customerId, address})` | `Future<Address>` | Save new address, returns with ID |
| `updateCustomerAddress({customerId, addressId, address})` | `Future<Address>` | Update existing address |
| `deleteCustomerAddress({customerId, addressId})` | `Future<bool>` | Delete address |
| `setDefaultAddress({customerId, addressId})` | `Future<Address>` | Mark address as default |

---

## Implementing a Repository

Concrete implementations live in the adapter package, not in `moose_core`. A concrete repository:

1. Extends the abstract interface and `CoreRepository` (already extended by the interface).
2. Takes its dependencies (API client, `CacheManager`, `EventBus`, `HookRegistry`) as constructor parameters.
3. Overrides `initialize()` for synchronous setup.

```dart
class WooProductsRepository extends ProductsRepository {
  WooProductsRepository(this._client, {
    required this.cache,
    required this.eventBus,
  });

  final WooApiClient _client;
  final CacheManager cache;
  final EventBus eventBus;

  @override
  void initialize() {
    // Synchronous setup — fire-and-forget async preload here if needed
  }

  @override
  Future<ProductListResult> getProducts({
    ProductFilters? filters,
    Duration? cacheTTL,
  }) async {
    // Implementation here
  }

  // ... implement all abstract methods
}
```

Registered inside `BackendAdapter.initialize()`:

```dart
@override
Future<void> initialize(Map<String, dynamic> config) async {
  _client = WooApiClient(
    baseUrl: config['baseUrl'] as String,
    consumerKey: config['consumerKey'] as String,
    consumerSecret: config['consumerSecret'] as String,
  );

  registerRepositoryFactory<ProductsRepository>(
    () => WooProductsRepository(
      _client,
      cache: cache,
      eventBus: eventBus,
    ),
  );

  registerRepositoryFactory<CartRepository>(
    () => WooCartRepository(
      _client,
      cache: cache,
      eventBus: eventBus,
    ),
  );
}
```

---

## Repository Selection Rules

1. **Multiple adapters, same repository type** — the last adapter registered wins (factory is overwritten; any previously resolved instance is invalidated).
2. **Optional repositories** — use `hasRepository<T>()` before calling `getRepository<T>()` for repositories that may not be registered (e.g. `PushNotificationRepository` may not be provided by a commerce adapter).
3. **Async factories** — if you used `registerAsyncRepositoryFactory`, you must use `getRepositoryAsync<T>()` or the request will throw.
4. **Not all repositories need implementing** — adapters only register the repository types they support. An adapter that doesn't provide `PostRepository` simply doesn't call `registerRepositoryFactory<PostRepository>`.

---

## Quick Reference

| Repository | Import path | Key feature |
|---|---|---|
| `CoreRepository` | `repositories.dart` | Base class; `initialize()` hook |
| `ProductsRepository` | `repositories.dart` | Catalog, categories, variations, reviews |
| `CartRepository` | `repositories.dart` | Cart, checkout, orders, payments |
| `AuthRepository` | `repositories.dart` | Auth, profile, tokens, MFA |
| `SearchRepository` | `repositories.dart` | Full-text search, suggestions, history |
| `ReviewRepository` | `repositories.dart` | Entity-agnostic reviews (any entity type) |
| `PostRepository` | `repositories.dart` | CMS posts, pages, articles |
| `BannerRepository` | `repositories.dart` | Promo banners with click tracking |
| `PushNotificationRepository` | `repositories.dart` | Device tokens, topics, notification streams |
| `ShortsRepository` | `repositories.dart` | Short-form video/story content |
| `StoreRepository` | `repositories.dart` | Store info, policies, locations, hours |
| `LocationRepository` | `repositories.dart` | Geocoding, autocomplete, country/address data |

---

## Related

- [ADAPTER_SYSTEM.md](./ADAPTER_SYSTEM.md) — Full adapter implementation guide including `initialize()` and `registerRepositoryFactory`
- [REGISTRIES.md](./REGISTRIES.md) — AdapterRegistry API and lazy factory pattern
- [PLUGIN_SYSTEM.md](./PLUGIN_SYSTEM.md) — How plugins consume repositories via `adapterRegistry`
- [ENTITIES.md](./ENTITIES.md) — Entity classes returned by repositories
