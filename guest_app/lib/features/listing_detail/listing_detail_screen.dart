import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:share_plus/share_plus.dart';
import 'package:staynaija_shared/core/theme/bold_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:staynaija_shared/core/theme/app_theme.dart';
import 'package:staynaija_shared/core/widgets/app_image.dart';
import 'package:staynaija_shared/core/widgets/api_error_view.dart';
import 'package:staynaija_shared/core/widgets/app_refresh.dart';
import 'package:staynaija_shared/auth/auth_provider.dart';
import 'package:staynaija/features/discovery/discovery_provider.dart';
import 'package:staynaija/core/widgets/animated_favorite_icon.dart';
import 'package:staynaija/core/widgets/sign_in_prompt.dart';
import 'package:staynaija/features/discovery/favorites_provider.dart';
import 'package:staynaija/features/discovery/services/external_maps.dart';
import 'package:staynaija/features/discovery/widgets/listing_card.dart';
import 'package:staynaija_shared/core/map/brand_tile_layer.dart';
import 'package:staynaija_shared/core/widgets/map_markers.dart';
import 'package:staynaija_shared/messaging/message_repository.dart';
import 'package:staynaija_shared/reviews/review_repository.dart';
import 'package:staynaija_shared/models/listing.dart';
import 'package:staynaija_shared/models/review.dart';
import 'package:staynaija_shared/models/stay_type.dart';

final _listingProvider = FutureProvider.family(
  (ref, String id) => ref.watch(listingRepositoryProvider).getById(id),
);
final _reviewsProvider = FutureProvider.family(
  (ref, String listingId) => ReviewRepository().listForListing(listingId),
);

// The photo's natural height - shared between _ParallaxPhotoHeaderDelegate
// (which sizes and scrolls it) and _PhotoHeader itself.
const _photoHeaderHeight = 320.0;

// How far the rounded white "lip" overlaps the photo's own bottom edge.
// Genuinely overlaps - both are painted in the same Stack inside the header
// sliver - unlike a plain seam between two adjacent slivers, which can only
// ever reveal whatever's behind the *sliver*, not the photo, however the
// corners are clipped or shadowed.
const _photoSheetLipHeight = 22.0;

class ListingDetailScreen extends ConsumerStatefulWidget {
  const ListingDetailScreen({super.key, required this.listingId});

  final String listingId;

  @override
  ConsumerState<ListingDetailScreen> createState() =>
      _ListingDetailScreenState();
}

class _ListingDetailScreenState extends ConsumerState<ListingDetailScreen> {
  @override
  void initState() {
    super.initState();
    // Opening a listing is the commonest signal we have and the backbone of the
    // recommendation feed. Recorded once per open rather than per rebuild, which
    // is why this screen is stateful at all.
    ref
        .read(listingRepositoryProvider)
        .recordInteraction(widget.listingId, InteractionKind.view);
  }

  @override
  Widget build(BuildContext context) {
    final listingId = widget.listingId;
    final listingAsync = ref.watch(_listingProvider(listingId));

    return Scaffold(
      backgroundColor: Colors.white,
      body: listingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(
          child: ApiErrorView(
            error: error,
            onRetry: () => ref.invalidate(_listingProvider(listingId)),
          ),
        ),
        data: (listing) => _ParallaxListingBody(listing: listing),
      ),
      bottomNavigationBar: listingAsync.maybeWhen(
        data: (_) => ListingReserveBar(listingId: listingId),
        orElse: () => null,
      ),
    );
  }
}

/// The photo sits above a rounded white sheet and drifts upward slower than
/// the sheet scrolls - the parallax effect - rather than scrolling away at
/// the same 1:1 rate as everything else. The back/save buttons sit in their
/// own layer on top of both, so they stay in place and stay tappable
/// regardless of scroll position.
class _ParallaxListingBody extends ConsumerStatefulWidget {
  const _ParallaxListingBody({required this.listing});

  final Listing listing;

  @override
  ConsumerState<_ParallaxListingBody> createState() =>
      _ParallaxListingBodyState();
}

class _ParallaxListingBodyState extends ConsumerState<_ParallaxListingBody> {
  // Tracks overall scroll purely to fade in the button-row backdrop below -
  // separate from the photo header's own shrinkOffset (which drives the
  // parallax/white-fade inside _ParallaxPhotoHeaderDelegate), since the
  // backdrop lives in this outer Stack, not inside that sliver. For a single
  // non-pinned leading sliver the two happen to track the same range, so the
  // same threshold curve is reused for both, to read as one transition
  // rather than two independently-timed ones.
  double _scrollOffset = 0;

  @override
  Widget build(BuildContext context) {
    final listing = widget.listing;
    final reviewsAsync = ref.watch(_reviewsProvider(listing.id));
    final topPadding = MediaQuery.paddingOf(context).top;
    final collapseProgress = (_scrollOffset / _photoHeaderHeight).clamp(
      0.0,
      1.0,
    );
    // Binary, not a fade: the backdrop shouldn't show at all until the sheet
    // has *fully* covered the photo, not creep in partway through like the
    // photo's own white-fade does.
    final showBackdrop = collapseProgress >= 1.0;

    return Stack(
      children: [
        AppRefresh(
          onRefresh: () async {
            ref.invalidate(_listingProvider(listing.id));
            ref.invalidate(_reviewsProvider(listing.id));
            // Wait for the refetch, otherwise the indicator disappears before
            // the new data has landed.
            await ref.read(_listingProvider(listing.id).future);
          },
          displacement: topPadding + 80,
          child: NotificationListener<ScrollNotification>(
            onNotification: (notification) {
              // Scroll notifications bubble up from *any* descendant
              // Scrollable, not just this outer vertical one - without this
              // check, swiping the horizontal "More stays nearby" carousel
              // further down the page fired notifications too, and its
              // small horizontal pixel offset was overwriting _scrollOffset
              // as if the page had scrolled back up, making the backdrop
              // disappear mid-swipe on the carousel.
              if (notification.metrics.axis != Axis.vertical) {
                return false;
              }
              final offset = notification.metrics.pixels.clamp(
                0.0,
                _photoHeaderHeight,
              );
              if (offset != _scrollOffset) {
                setState(() => _scrollOffset = offset);
              }
              return false;
            },
            child: CustomScrollView(
              slivers: [
                // The photo has to live inside this same CustomScrollView, as a
                // sliver, rather than as a separate Positioned layer behind it -
                // a separate Stack layer put the scroll view's hit-testing in
                // front of the photo's PageView, which silently ate every swipe
                // before the carousel underneath ever saw it. Nested inside the
                // one scrollable like this, Flutter's gesture arena resolves
                // horizontal swipes (carousel) vs vertical drags (page scroll)
                // the normal way nested scrollables always do.
                //
                // A SliverPersistentHeader rather than a plain SliverToBoxAdapter
                // for a reason that matters: a SliverToBoxAdapter always scrolls
                // 1:1 with everything else, so content inside it can shift
                // *within* its own box but can never lag behind the scroll the
                // way true parallax needs. A persistent header's shrinkOffset is
                // what lets the photo visually trail the real scroll instead -
                // and unlike SliverToBoxAdapter, it always hands its delegate a
                // bounded (finite) extent, so it doesn't have the
                // unbounded-height-in/infinite-size-out failure mode a bare
                // OverflowBox hits under a SliverToBoxAdapter.
                SliverPersistentHeader(
                  delegate: _ParallaxPhotoHeaderDelegate(listing: listing),
                ),
                SliverToBoxAdapter(
                  child: _DetailSheet(
                    listing: listing,
                    reviewsAsync: reviewsAsync,
                  ),
                ),
              ],
            ),
          ),
        ),
        // Appears behind the button row only once the sheet has fully
        // covered the photo, so the buttons (plain white circles) stay
        // legible once they're sitting over the white sheet instead of the
        // photo - without this they'd be near-invisible white-on-white past
        // that point.
        if (showBackdrop)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topPadding + 56,
            child: const IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(bottom: BorderSide(color: Color(0x14000000))),
                ),
              ),
            ),
          ),
        Positioned(
          top: topPadding + 8,
          left: 12,
          right: 12,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _CircleButton(
                icon: LucideIcons.arrowLeft,
                onTap: () => context.pop(),
              ),
              Row(
                children: [
                  _CircleButton(
                    icon: LucideIcons.share,
                    onTap: () => SharePlus.instance.share(
                      ShareParams(
                        text: '${listing.title} on iStay - check it out!',
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Consumer(
                    builder: (context, ref, _) {
                      final isFavorite = ref.watch(
                        favoritesProvider.select(
                          (ids) => ids.contains(listing.id),
                        ),
                      );
                      return _CircleButton(
                        child: AnimatedFavoriteIcon(
                          isFavorite: isFavorite,
                          inactiveColor: AppColors.textPrimary,
                          size: 20,
                        ),
                        onTap: () {
                          if (isSignedOut(ref)) {
                            promptSignIn(
                              context,
                              title: 'Save this place',
                              message:
                                  'Sign in to keep a wishlist of stays you like across your devices.',
                            );
                            return;
                          }
                          ref
                              .read(favoritesProvider.notifier)
                              .toggle(listing.id);
                        },
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Gives the photo sliver its parallax drift: `shrinkOffset` is how far the
/// header has scrolled (0 at rest, up to `maxExtent` once fully collapsed).
/// The photo is rendered at its full natural height and shifted up by only a
/// fraction of that, so it visibly lags behind the real scroll rather than
/// tracking it 1:1 - a plain SliverToBoxAdapter can't do this, since it
/// always moves exactly with the rest of the scroll regardless of what's
/// drawn inside it.
class _ParallaxPhotoHeaderDelegate extends SliverPersistentHeaderDelegate {
  _ParallaxPhotoHeaderDelegate({required this.listing});

  final Listing listing;

  static const _parallaxFactor = 0.45;

  @override
  double get maxExtent => _photoHeaderHeight;

  @override
  double get minExtent => 0;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // The outer Stack is sized by the sliver itself - it's what naturally
    // shrinks from `_photoHeaderHeight` down to 0 as shrinkOffset grows.
    // The lip is positioned against *that* (bottom: 0 of the actual current
    // header box), not against the photo's own fixed-height content inside
    // it - anchoring it to the photo's content instead was the actual bug:
    // with the photo's box topCenter-aligned, any shrink crops from the
    // bottom first, which is exactly where a bottom-anchored lip sits, so it
    // was getting clipped away after just ~_photoSheetLipHeight of scroll,
    // well before the photo itself visibly shrank at all.
    final collapseProgress = (shrinkOffset / maxExtent).clamp(0.0, 1.0);
    // Starts early and is fully white well before the header finishes
    // collapsing, rather than tracking the collapse all the way to 100%.
    const fadeStart = 0.3;
    const fadeEnd = 0.7;
    final whiteFade = ((collapseProgress - fadeStart) / (fadeEnd - fadeStart))
        .clamp(0.0, 1.0);
    return Stack(
      fit: StackFit.expand,
      children: [
        // SliverPersistentHeader always hands its delegate a bounded extent
        // (clamped to [minExtent, maxExtent]), so unlike a bare OverflowBox
        // under a SliverToBoxAdapter, this never resolves against an
        // unbounded constraint - no risk of the infinite-size failure that
        // broke this before.
        ClipRect(
          child: OverflowBox(
            minHeight: _photoHeaderHeight,
            maxHeight: _photoHeaderHeight,
            alignment: Alignment.topCenter,
            child: Transform.translate(
              offset: Offset(0, -shrinkOffset * _parallaxFactor),
              child: _PhotoHeader(listing: listing),
            ),
          ),
        ),
        // Eases the photo to white right before the header fully collapses,
        // rather than letting it just vanish - the "lip" is already white, so
        // by the time this reaches full opacity the whole header already
        // reads as part of the sheet below it.
        if (whiteFade > 0)
          IgnorePointer(
            child: Opacity(
              opacity: whiteFade,
              child: const ColoredBox(color: Colors.white),
            ),
          ),
        // Painted on top of the photo above (same Stack, later child), so
        // its rounded corners genuinely reveal photo pixels underneath
        // rather than whatever's behind the sliver.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: _photoSheetLipHeight,
          child: const DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(36),
                topRight: Radius.circular(36),
              ),
            ),
          ),
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(covariant _ParallaxPhotoHeaderDelegate oldDelegate) =>
      oldDelegate.listing != listing;
}

/// Every text section, in plain white, continuing straight down from the
/// rounded "lip" painted over the photo above (see
/// _ParallaxPhotoHeaderDelegate) - the lip is what supplies the curve, so
/// this is a flat-topped box, not a rounded one itself.
class _DetailSheet extends StatelessWidget {
  const _DetailSheet({required this.listing, required this.reviewsAsync});

  final Listing listing;
  final AsyncValue<List<Review>> reviewsAsync;

  @override
  Widget build(BuildContext context) {
    final stayNote = stayTypeGuestNote(listing.propertyType);

    return ColoredBox(
      color: Colors.white,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _TitleBlock(listing: listing, reviewsAsync: reviewsAsync),
            const SizedBox(height: 24),
            _FactsRow(listing: listing),
            const SizedBox(height: 22),
            _HostCard(listing: listing),
            if (stayNote != null) ...[
              const SizedBox(height: 16),
              _StayTypeBanner(note: stayNote),
            ],
            const SizedBox(height: 22),
            _Section(
              title: 'About this place',
              child: _ExpandableText(text: listing.description),
            ),
            // Power/security and amenities were two parallel lists under
            // separate headings, which read as unrelated. They're one
            // question - "what does this place have?" - so they sit under
            // one heading, with the Nigeria-specific group kept first and
            // visually stronger because it's what guests filter on.
            if (_powerAndSecurity(listing).isNotEmpty ||
                listing.amenities.isNotEmpty ||
                listing.breakfastIncluded)
              _Section(
                title: 'What this place offers',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_powerAndSecurity(listing).isNotEmpty) ...[
                      const _SubHeading('Power & security'),
                      _FeatureList(
                        features: _powerAndSecurity(listing),
                        highlight: true,
                      ),
                    ],
                    if (listing.amenities.isNotEmpty ||
                        listing.breakfastIncluded) ...[
                      if (_powerAndSecurity(listing).isNotEmpty)
                        const SizedBox(height: 22),
                      const _SubHeading('Amenities'),
                      _FeatureList(
                        features: [
                          // Called out ahead of the generic amenities: it
                          // is the one detail actually named in three of
                          // the ten stay-type descriptions, and it changes
                          // what a guest expects to pay for separately.
                          if (listing.breakfastIncluded)
                            (LucideIcons.coffee, 'Breakfast included'),
                          for (final a in listing.amenities)
                            (_amenityIcon(a), _amenityLabel(a)),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            _Section(
              title: 'Where you\'ll be',
              child: _LocationPreview(listing: listing),
            ),
            _Section(
              title: 'House rules',
              // maxGuests is always known, so this line always shows - the
              // free-text house_rules underneath it is the part that's
              // sometimes empty.
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${listing.maxGuests} guest${listing.maxGuests == 1 ? '' : 's'} maximum',
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (listing.houseRules != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      listing.houseRules!,
                      style: const TextStyle(
                        height: 1.6,
                        color: AppColors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            reviewsAsync.when(
              loading: () => const _Section(
                title: 'Reviews',
                isLast: true,
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: LinearProgressIndicator(),
                ),
              ),
              error: (e, _) => _Section(
                title: 'Reviews',
                isLast: true,
                // No retry wired here specifically - pull-to-refresh on the
                // whole page already re-fetches this along with everything
                // else, so a second, narrower retry action would be redundant.
                child: ApiErrorView(error: e, compact: true),
              ),
              // The heading carries the score, so the rating at the top of
              // the page and the reviews at the bottom agree at a glance.
              data: (reviews) => _Section(
                title: reviews.isEmpty
                    ? 'Reviews'
                    : '${_averageRating(reviews).toStringAsFixed(1)} · '
                          '${reviews.length} review${reviews.length == 1 ? '' : 's'}',
                isLast: true,
                child: _ReviewsList(reviews: reviews),
              ),
            ),
            _NearbyListingsSection(currentListingId: listing.id),
            const SizedBox(height: 28),
          ],
        ),
      ),
    );
  }
}

/// Full-bleed photo carousel with the page dots and counter floating over
/// it. The back/save buttons used to live here too, but now sit in their own
/// layer above everything so they survive the photo scrolling out of view.
class _PhotoHeader extends ConsumerStatefulWidget {
  const _PhotoHeader({required this.listing});

  final Listing listing;

  @override
  ConsumerState<_PhotoHeader> createState() => _PhotoHeaderState();
}

class _PhotoHeaderState extends ConsumerState<_PhotoHeader> {
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final photos = widget.listing.photos;

    return Stack(
      fit: StackFit.expand,
      children: [
        if (photos.isEmpty)
          Container(
            color: Colors.grey.shade200,
            child: Icon(
              LucideIcons.house,
              size: 64,
              color: Colors.grey.shade400,
            ),
          )
        else
          PageView.builder(
            controller: _controller,
            itemCount: photos.length,
            onPageChanged: (index) => setState(() => _page = index),
            itemBuilder: (context, index) => AppImage(url: photos[index].url),
          ),
        if (photos.length > 1) ...[
          Positioned(
            // Pushed up clear of the rounded white lip painted over the
            // photo's bottom edge (see _ParallaxPhotoHeaderDelegate).
            bottom: _photoSheetLipHeight + 14,
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                '${_page + 1}/${photos.length}',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Positioned(
            bottom: _photoSheetLipHeight + 16,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < photos.length; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 3),
                    width: i == _page ? 18 : 6,
                    height: 6,
                    decoration: BoxDecoration(
                      color: i == _page ? Colors.white : Colors.white54,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _CircleButton extends StatelessWidget {
  const _CircleButton({this.icon, this.child, required this.onTap});

  final IconData? icon;
  final Widget? child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 2,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: child ?? Icon(icon, size: 20, color: AppColors.textPrimary),
          ),
        ),
      ),
    );
  }
}

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.listing, required this.reviewsAsync});

  final Listing listing;
  final AsyncValue<List<Review>> reviewsAsync;

  @override
  Widget build(BuildContext context) {
    final reviews = reviewsAsync.valueOrNull ?? const <Review>[];
    final average = reviews.isEmpty ? null : _averageRating(reviews);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // The title leads the block now that it's centred - everything else
        // reads as supporting detail underneath it, not a line it interrupts.
        SizedBox(
          width: double.infinity,
          child: Text(
            listing.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 23,
              fontWeight: FontWeight.w700,
              height: 1.25,
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Type and instant-book read as plain overline text rather than pills -
        // the whole screen avoids boxed chrome. Centred to sit under the
        // centred title rather than drifting to the left edge under it. Wrap
        // rather than Row so a long stay-type label on a narrow screen (or
        // with larger accessibility text sizes) drops to a second line
        // instead of overflowing.
        //
        // The SizedBox is load-bearing: inside a Column with
        // crossAxisAlignment.start, a bare Wrap shrink-wraps to its own
        // content width, so WrapAlignment.center has nothing wider to centre
        // *within* - it just sits flush left regardless. Forcing full width
        // first is what makes the centring actually visible.
        SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                stayTypeLabel(listing.propertyType).toUpperCase(),
                style: const TextStyle(
                  color: AppColors.primary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              if (listing.instantBook) ...[
                const Text(
                  '  ·  ',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 11,
                  ),
                ),
                Icon(LucideIcons.zap, size: 12, color: Colors.orange.shade700),
                const SizedBox(width: 4),
                Text(
                  'INSTANT BOOK',
                  style: TextStyle(
                    color: Colors.orange.shade800,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        // Matches the overline/rating rows above and below it: centred as a
        // group, wrapping onto a second line instead of forcing itself onto
        // one via an Expanded (which would also pin it flush left, breaking
        // the centred rhythm of this whole block).
        SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(
                LucideIcons.mapPin,
                size: 15,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 5),
              Text(
                '${listing.city} · ${listing.neighborhoodLandmark}',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        // Wrap for the same reason as the overline above - "4.8 · 128
        // reviews" is short in English but review counts and pluralisation
        // grow, and this keeps a long version from overflowing instead of
        // wrapping to a second line. Same SizedBox-forces-full-width need as
        // the overline above, for the same reason.
        SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Icon(LucideIcons.star, size: 15, color: AppColors.accent),
              const SizedBox(width: 5),
              Text(
                average != null ? average.toStringAsFixed(1) : 'New',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
              const SizedBox(width: 5),
              Text(
                average != null
                    ? '· ${reviews.length} review${reviews.length == 1 ? '' : 's'}'
                    : '· no reviews yet',
                style: const TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 13,
                ),
              ),
              if (listing.isGuestFavourite) ...[
                const SizedBox(width: 5),
                _GuestFavouriteBadge(),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// A small tappable pill next to the rating, for a listing whose average
/// ranks in the top slice of listings with enough reviews to rank fairly -
/// see `is_guest_favourite` in the backend's `get_listing`. Tapping it is the
/// only way to see *why*, rather than a dedicated section, since this is the
/// only piece of that reference screen's badge system backed by real data.
class _GuestFavouriteBadge extends StatelessWidget {
  const _GuestFavouriteBadge();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (context) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(LucideIcons.award, color: AppColors.primary, size: 20),
                  const SizedBox(width: 8),
                  const Text(
                    'Guest favourite',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Text(
                'This home is among the highest-rated on iStay, based on '
                'ratings and review count from guests who have actually stayed here.',
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 14,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(LucideIcons.award, size: 12, color: AppColors.primary),
            const SizedBox(width: 4),
            Text(
              'Guest favourite',
              style: TextStyle(
                color: AppColors.primary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bed / bath / guest counts as a plain icon-and-text line, dot separated.
class _FactsRow extends StatelessWidget {
  const _FactsRow({required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    final facts = [
      (
        LucideIcons.bedDouble,
        '${listing.bedrooms} ${listing.bedrooms == 1 ? 'bedroom' : 'bedrooms'}',
      ),
      (
        LucideIcons.bath,
        '${listing.bathrooms} ${listing.bathrooms == 1 ? 'bathroom' : 'bathrooms'}',
      ),
      (LucideIcons.users, 'Up to ${listing.maxGuests}'),
      // Worth surfacing before a guest gets to the date picker rather than
      // after: a Long stay listing's 30-night floor is a hard rejection, not
      // a preference, and finding that out only once you try to book is the
      // kind of thing that reads as the app being broken.
      if (listing.minimumNights > 1)
        (LucideIcons.calendarDays, '${listing.minimumNights}-night minimum'),
    ];

    // Matches the rest of this header block - centred as a group, same
    // full-width-SizedBox-plus-WrapAlignment.center pattern as the overline/
    // location/rating rows above it.
    return SizedBox(
      width: double.infinity,
      child: Wrap(
        alignment: WrapAlignment.center,
        spacing: 18,
        runSpacing: 10,
        children: [
          for (final fact in facts)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(fact.$1, size: 17, color: AppColors.primary),
                const SizedBox(width: 7),
                Text(
                  fact.$2,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// A compact, non-interactive card introducing the host - reads as a card,
/// not a titled section, so it sits directly in the flow rather than inside
/// `_Section`. There's no host-profile screen to link to yet, so unlike the
/// reference this doesn't tap through to anything; it's informational only.
class _HostCard extends StatelessWidget {
  const _HostCard({required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    final hasStats = listing.hostReviewCount > 0;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade200),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: listing.hostAvatarUrl != null
                ? AppImage(
                    url: listing.hostAvatarUrl,
                    width: 48,
                    height: 48,
                    fallbackIcon: LucideIcons.user,
                  )
                : Container(
                    width: 48,
                    height: 48,
                    color: AppColors.primary.withValues(alpha: 0.08),
                    child: Icon(
                      LucideIcons.user,
                      color: AppColors.primary,
                      size: 22,
                    ),
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Hosted by ${listing.hostName}',
                  style: const TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  hasStats
                      ? '${listing.hostReviewCount} review${listing.hostReviewCount == 1 ? '' : 's'}'
                            ' · ${listing.hostRating!.toStringAsFixed(1)} rating'
                            '${listing.hostYearsHosting > 0 ? ' · ${listing.hostYearsHosting} ${listing.hostYearsHosting == 1 ? 'year' : 'years'} hosting' : ''}'
                      : 'New host',
                  style: const TextStyle(
                    fontSize: 12.5,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Surfaces what's actually different about this stay type (shared hostel
/// facilities, a long-stay's monthly billing, a homestay's host presence) up
/// near the top, rather than leaving a guest to infer it from the amenities
/// list further down.
class _StayTypeBanner extends StatelessWidget {
  const _StayTypeBanner({required this.note});

  final String note;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.info, size: 16, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              note,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Sections are demarcated by a faint hairline below each one, rather than
/// whitespace alone - enough to separate the text blocks without reading as
/// a boxed or bordered layout.
class _Section extends StatelessWidget {
  const _Section({
    required this.title,
    required this.child,
    this.isLast = false,
  });

  final String title;
  final Widget child;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 17.5,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 14),
        child,
        if (!isLast) ...[
          const SizedBox(height: 26),
          const Divider(height: 1, thickness: 1, color: Color(0x14000000)),
          const SizedBox(height: 26),
        ],
      ],
    );
  }
}

/// A horizontal carousel of other recommended listings, reusing the same
/// feed that powers the home screen's "Places you may like"
/// (`recommendedListingsProvider`) with the current listing filtered out.
/// Builds its own leading divider rather than making Reviews above it
/// `isLast: false` unconditionally, so an empty/loading feed collapses to
/// nothing - no dangling divider before blank space.
class _NearbyListingsSection extends ConsumerWidget {
  const _NearbyListingsSection({required this.currentListingId});

  final String currentListingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nearby =
        ref
            .watch(recommendedListingsProvider)
            .valueOrNull
            ?.where((listing) => listing.id != currentListingId)
            .toList() ??
        const <Listing>[];
    if (nearby.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 26),
        const Divider(height: 1, thickness: 1, color: Color(0x14000000)),
        const SizedBox(height: 26),
        const Text(
          'More stays nearby',
          style: TextStyle(
            fontSize: 17.5,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.2,
          ),
        ),
        // Shorter than the usual 14 gap used elsewhere, since the ListView
        // below adds its own 12 of top padding (for the card shadow - see
        // its comment) that stacks with this one.
        const SizedBox(height: 2),
        SizedBox(
          // ListingCard's text block (title/location/facts/price) doesn't
          // have a fixed height, and 300 overflowed by ~10px in practice -
          // generous margin here rather than re-measuring exactly, since the
          // card's own content can vary slightly (e.g. the power/security
          // icon row only appears for some listings). The extra 24 on top of
          // that is the vertical padding below, so the card's own shadow has
          // room to render rather than being clipped by this box's edge.
          height: 344,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            // Clip.none plus this padding is what stops ListingCard's own
            // boxShadow from being clipped flat on every edge - a plain
            // ListView clips to its viewport by default, and with each card
            // sized to fit exactly, there was no room left for the shadow to
            // actually paint.
            clipBehavior: Clip.none,
            padding: const EdgeInsets.symmetric(vertical: 12),
            itemCount: nearby.length,
            separatorBuilder: (context, index) => const SizedBox(width: 16),
            itemBuilder: (context, index) {
              final listing = nearby[index];
              return SizedBox(
                width: 200,
                child: ListingCard(
                  listing: listing,
                  onTap: () => context.push('/listing/${listing.id}'),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

/// Two-column list of icon + label. No chips or boxes: the icon colour alone
/// distinguishes the highlighted power/security features from plain amenities.
class _SubHeading extends StatelessWidget {
  const _SubHeading(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Text(
      label.toUpperCase(),
      style: const TextStyle(
        fontSize: 10.5,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w700,
        color: AppColors.textSecondary,
      ),
    ),
  );
}

/// Seeded descriptions run long enough to push everything below them off the
/// first couple of screens, so the body is clamped until the guest asks for it.
class _ExpandableText extends StatefulWidget {
  const _ExpandableText({required this.text});

  final String text;

  static const collapsedLines = 3;

  @override
  State<_ExpandableText> createState() => _ExpandableTextState();
}

class _ExpandableTextState extends State<_ExpandableText> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      height: 1.6,
      color: AppColors.textSecondary,
      fontSize: 14,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        // Text merges its style into the inherited DefaultTextStyle, so measuring
        // the bare TextStyle here would use the platform font's metrics rather
        // than the theme's Poppins - narrower glyphs, so it concluded the text
        // fitted while the rendered text overflowed, hiding the toggle.
        final measuredStyle = DefaultTextStyle.of(context).style.merge(style);
        final painter = TextPainter(
          text: TextSpan(text: widget.text, style: measuredStyle),
          maxLines: _ExpandableText.collapsedLines,
          textDirection: Directionality.of(context),
          // Must match the rendered text's scale. Without this the measurement
          // uses unscaled glyphs, so on a phone with enlarged system fonts the
          // text overflows on screen while this decides it fits - truncating
          // the description with no "Show more" to expand it.
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: constraints.maxWidth);
        final overflows = painter.didExceedMaxLines;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.text,
              style: style,
              maxLines: _expanded ? null : _ExpandableText.collapsedLines,
              overflow: _expanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
            ),
            if (overflows)
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                behavior: HitTestBehavior.opaque,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    _expanded ? 'Show less' : 'Show more',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _FeatureList extends StatelessWidget {
  const _FeatureList({required this.features, this.highlight = false});

  final List<(IconData, String)> features;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Half the available width minus the gutter, floored a fraction below
        // so rounding never pushes the second column onto its own line.
        const gutter = 14.0;
        final columnWidth =
            ((constraints.maxWidth - gutter) / 2).floorToDouble() - 0.5;
        return Wrap(
          spacing: gutter,
          runSpacing: 16,
          children: [
            for (final feature in features)
              SizedBox(
                width: columnWidth,
                child: Row(
                  children: [
                    Icon(
                      feature.$1,
                      size: 18,
                      color: highlight
                          ? AppColors.primary
                          : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        feature.$2,
                        maxLines: 2,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.3,
                          fontWeight: highlight
                              ? FontWeight.w500
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Small non-interactive map so guests can place the landmark before booking.
class _LocationPreview extends ConsumerWidget {
  const _LocationPreview({required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final point = LatLng(listing.latitude, listing.longitude);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 170,
            child: FlutterMap(
              options: MapOptions(
                initialCenter: point,
                initialZoom: 15,
                interactionOptions: const InteractionOptions(
                  flags: InteractiveFlag.none,
                ),
              ),
              children: [
                const BrandTileLayer(
                  userAgentPackageName: 'com.staynaija.mobile',
                ),
                MarkerLayer(
                  markers: [
                    Marker(
                      point: point,
                      width: 46,
                      height: 46,
                      // Anchored at the tip so the pin points at the address
                      // rather than floating centred on it.
                      alignment: Alignment.topCenter,
                      child: const MapPin(icon: LucideIcons.house, size: 46),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        // This is the host's note on what the *property* is near, e.g. "Walking
        // distance to Jabi Lake Mall" - bare under the map it read as a claim
        // about the guest's own position, which it never was. A pin icon plus
        // "Near" ties the distance back to the property on the map above it.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Icon(
                LucideIcons.mapPin,
                size: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Near: ',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    TextSpan(text: listing.neighborhoodLandmark),
                  ],
                ),
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        // Each action is a single tap. An intermediate "choose how" sheet meant
        // two taps to do the thing most people open this section for. The
        // Explore card does show a sheet, because there the button competes
        // with "view details" and the choice of app is the point.
        //
        // Four options no longer fit as labelled pill buttons in one row, so
        // this reads as a row of app icons instead - the same brand marks used
        // in the Explore sheet, which also makes the two feel like one feature
        // rather than two different designs for the same job.
        Row(
          children: [
            Expanded(
              child: _GoAction(
                logo: 'assets/GoogleMap.jpg',
                label: 'Maps',
                onTap: () => _go(
                  ref,
                  () => ExternalMaps.openGoogleMaps(
                    latitude: listing.latitude,
                    longitude: listing.longitude,
                    label: listing.title,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _GoAction(
                logo: 'assets/Bolt.jpg',
                label: 'Bolt',
                onTap: () => _go(
                  ref,
                  () => ExternalMaps.openBolt(
                    latitude: listing.latitude,
                    longitude: listing.longitude,
                    address: _address(listing),
                  ),
                ),
              ),
            ),
            Expanded(
              child: _GoAction(
                logo: 'assets/Uber.jpg',
                label: 'Uber',
                onTap: () => _go(
                  ref,
                  () => ExternalMaps.openUber(
                    latitude: listing.latitude,
                    longitude: listing.longitude,
                    address: _address(listing),
                    nickname: listing.title,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _GoAction(
                logo: 'assets/Indrive.jpg',
                label: 'inDrive',
                onTap: () => _go(
                  ref,
                  () => ExternalMaps.openInDrive(
                    latitude: listing.latitude,
                    longitude: listing.longitude,
                    address: _address(listing),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  /// Hands off to the chosen app, recording the intent first. Asking how to get
  /// somewhere is the strongest interest signal short of booking, so it feeds
  /// the recommendation feed.
  Future<bool> _go(WidgetRef ref, Future<bool> Function() open) {
    ref
        .read(listingRepositoryProvider)
        .recordInteraction(listing.id, InteractionKind.directions);
    return open();
  }

  static String _address(Listing listing) => ExternalMaps.formatAddress(
    landmark: listing.neighborhoodLandmark,
    city: listing.city,
  );
}

/// One-tap handoff to a map or ride app: its brand mark, tappable, with the
/// app's name underneath.
class _GoAction extends StatelessWidget {
  const _GoAction({
    required this.logo,
    required this.label,
    required this.onTap,
  });

  final String logo;
  final String label;
  final Future<bool> Function() onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        final opened = await onTap();
        if (!opened && context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Could not open $label.')));
        }
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                width: 46,
                height: 46,
                child: Image.asset(logo, fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewsList extends StatelessWidget {
  const _ReviewsList({required this.reviews});

  final List<Review> reviews;

  @override
  Widget build(BuildContext context) {
    if (reviews.isEmpty) {
      return const Text(
        'No reviews yet - be the first to stay here.',
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 13.5,
          height: 1.5,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < reviews.length; index++) ...[
          if (index > 0) const SizedBox(height: 22),
          Row(
            children: [
              for (var i = 0; i < 5; i++)
                Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Icon(
                    LucideIcons.star,
                    size: 13,
                    color: i < reviews[index].average.round()
                        ? AppColors.accent
                        : Colors.grey.shade300,
                  ),
                ),
              const SizedBox(width: 6),
              Text(
                reviews[index].average.toStringAsFixed(1),
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          if (reviews[index].comment != null) ...[
            const SizedBox(height: 8),
            Text(
              reviews[index].comment!,
              style: const TextStyle(fontSize: 13.5, height: 1.6),
            ),
          ],
        ],
      ],
    );
  }
}

class ListingReserveBar extends ConsumerWidget {
  const ListingReserveBar({super.key, required this.listingId});

  final String listingId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listingAsync = ref.watch(_listingProvider(listingId));
    final currentUser = ref.watch(authProvider).user;

    return listingAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (listing) {
        final isOwnListing = currentUser?.id == listing.hostId;
        return DecoratedBox(
          decoration: const BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black12,
                blurRadius: 12,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Expanded(
                    child: Column(
                      // Scaffold lays bottomNavigationBar out with a loose
                      // height constraint, so a MainAxisSize.max Column here
                      // stretches to the full screen and squeezes the listing
                      // body down to nothing. Size to the content instead.
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            Text(
                              formatNaira(listing.displayRate),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 18,
                              ),
                            ),
                            Text(
                              ' / ${listing.displayUnitLabel}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                        // Only meaningful on a nightly rate - see the host
                        // form's note on why these are cleared for anything
                        // priced weekly or monthly.
                        if (listing.pricingUnit == PricingUnit.nightly &&
                            listing.weeklyDiscountPercent > 0)
                          Text(
                            '${listing.weeklyDiscountPercent.toStringAsFixed(0)}% off weekly stays',
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (!isOwnListing) ...[
                    _CircleButton(
                      icon: LucideIcons.messageSquare,
                      onTap: () async {
                        if (isSignedOut(ref)) {
                          promptSignIn(
                            context,
                            title: 'Message the host',
                            message:
                                'Sign in so the host can reply to you and you can keep the conversation.',
                          );
                          return;
                        }
                        final conversation = await MessageRepository()
                            .startConversation(listing.id);
                        if (context.mounted)
                          context.push('/chat/${conversation.id}');
                      },
                    ),
                    const SizedBox(width: 10),
                    // The app-wide ElevatedButton theme sets minimumSize to Size.fromHeight(50)
                    // (full-width buttons like "Log in"), which is Size(double.infinity, 50).
                    // A Row's non-flex children are measured with an unbounded max width, so
                    // combined with that infinite minimumSize this button would be asked to
                    // render at infinite width and crash layout. Overriding minimumSize here
                    // to a bounded value keeps it a normal inline button.
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(0, 48),
                        padding: const EdgeInsets.symmetric(horizontal: 22),
                      ),
                      onPressed: () {
                        if (isSignedOut(ref)) {
                          promptSignIn(
                            context,
                            title: 'Sign in to book',
                            message:
                                'We need an account to hold your booking, take payment securely and share '
                                'check-in details with the host.',
                          );
                          return;
                        }
                        context.push('/book/${listing.id}');
                      },
                      child: Text(
                        listing.instantBook ? 'Reserve' : 'Request to book',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

double _averageRating(List<Review> reviews) =>
    reviews.map((review) => review.average).reduce((a, b) => a + b) /
    reviews.length;

List<(IconData, String)> _powerAndSecurity(Listing listing) => [
  if (listing.has24hrElectricity) (LucideIcons.plugZap, '24hr electricity'),
  if (listing.hasGenerator) (LucideIcons.zap, 'Generator'),
  if (listing.hasInverter) (LucideIcons.batteryCharging, 'Inverter'),
  if (listing.isGatedEstate) (LucideIcons.lockKeyhole, 'Gated estate'),
  if (listing.hasSecurityGuard) (LucideIcons.shieldCheck, 'Security guard'),
  if (listing.hasCctv) (LucideIcons.video, 'CCTV'),
];

IconData _amenityIcon(String amenity) => switch (amenity) {
  'wifi' => LucideIcons.wifi,
  'parking' => LucideIcons.parkingCircle,
  'ac' => LucideIcons.snowflake,
  'fan' => LucideIcons.fan,
  'pool' => LucideIcons.waves,
  'kitchen' => LucideIcons.cookingPot,
  'gym' => LucideIcons.dumbbell,
  'workspace' => LucideIcons.laptop,
  'washing_machine' => LucideIcons.washingMachine,
  'garden' => LucideIcons.trees,
  'bbq' => LucideIcons.flame,
  'beach_access' => LucideIcons.umbrella,
  _ => LucideIcons.circleCheck,
};

String _amenityLabel(String amenity) => switch (amenity) {
  'wifi' => 'WiFi',
  'parking' => 'Parking',
  'ac' => 'Air conditioning',
  'fan' => 'Ceiling fan',
  'pool' => 'Swimming pool',
  'kitchen' => 'Kitchen',
  'gym' => 'Gym',
  'workspace' => 'Workspace',
  'washing_machine' => 'Washing machine',
  'garden' => 'Garden',
  'bbq' => 'BBQ area',
  'beach_access' => 'Beach access',
  _ => amenity.replaceAll('_', ' '),
};
