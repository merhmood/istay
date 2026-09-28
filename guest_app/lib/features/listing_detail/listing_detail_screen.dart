import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:heroicons/heroicons.dart';
import 'package:staynaija_shared/core/theme/bold_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:staynaija_shared/core/api/dio_client.dart';
import 'package:staynaija_shared/core/theme/app_theme.dart';
import 'package:staynaija_shared/core/widgets/app_image.dart';
import 'package:staynaija_shared/core/widgets/app_refresh.dart';
import 'package:staynaija_shared/auth/auth_provider.dart';
import 'package:staynaija/features/discovery/discovery_provider.dart';
import 'package:staynaija/core/widgets/sign_in_prompt.dart';
import 'package:staynaija/features/discovery/favorites_provider.dart';
import 'package:staynaija/features/discovery/services/external_maps.dart';
import 'package:staynaija_shared/core/map/brand_tile_layer.dart';
import 'package:staynaija_shared/core/widgets/map_markers.dart';
import 'package:staynaija_shared/messaging/message_repository.dart';
import 'package:staynaija_shared/reviews/review_repository.dart';
import 'package:staynaija_shared/models/listing.dart';
import 'package:staynaija_shared/models/review.dart';
import 'package:staynaija_shared/models/stay_type.dart';

final _listingProvider = FutureProvider.family((ref, String id) => ref.watch(listingRepositoryProvider).getById(id));
final _reviewsProvider = FutureProvider.family((ref, String listingId) => ReviewRepository().listForListing(listingId));

class ListingDetailScreen extends ConsumerStatefulWidget {
  const ListingDetailScreen({super.key, required this.listingId});

  final String listingId;

  @override
  ConsumerState<ListingDetailScreen> createState() => _ListingDetailScreenState();
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
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not load listing.\n${apiErrorMessage(error)}', textAlign: TextAlign.center),
          ),
        ),
        data: (listing) => AppRefresh(
          onRefresh: () async {
            ref.invalidate(_listingProvider(listingId));
            ref.invalidate(_reviewsProvider(listingId));
            // Wait for the refetch, otherwise the indicator disappears before
            // the new data has landed.
            await ref.read(_listingProvider(listingId).future);
          },
          // Clears the floating back/save buttons over the photo header.
          displacement: 80,
          child: _ListingDetailBody(listing: listing),
        ),
      ),
      bottomNavigationBar: listingAsync.maybeWhen(
        data: (_) => ListingReserveBar(listingId: listingId),
        orElse: () => null,
      ),
    );
  }
}

class _ListingDetailBody extends ConsumerWidget {
  const _ListingDetailBody({required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reviewsAsync = ref.watch(_reviewsProvider(listing.id));
    final stayNote = stayTypeGuestNote(listing.propertyType);

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(child: _PhotoHeader(listing: listing)),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TitleBlock(listing: listing, reviewsAsync: reviewsAsync),
                const SizedBox(height: 18),
                _FactsRow(listing: listing),
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
                if (_powerAndSecurity(listing).isNotEmpty || listing.amenities.isNotEmpty || listing.breakfastIncluded)
                  _Section(
                    title: 'What this place offers',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_powerAndSecurity(listing).isNotEmpty) ...[
                          const _SubHeading('Power & security'),
                          _FeatureList(features: _powerAndSecurity(listing), highlight: true),
                        ],
                        if (listing.amenities.isNotEmpty || listing.breakfastIncluded) ...[
                          if (_powerAndSecurity(listing).isNotEmpty) const SizedBox(height: 22),
                          const _SubHeading('Amenities'),
                          _FeatureList(
                            features: [
                              // Called out ahead of the generic amenities: it
                              // is the one detail actually named in three of
                              // the ten stay-type descriptions, and it changes
                              // what a guest expects to pay for separately.
                              if (listing.breakfastIncluded) (LucideIcons.coffee, 'Breakfast included'),
                              for (final a in listing.amenities) (_amenityIcon(a), _amenityLabel(a)),
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
                if (listing.houseRules != null)
                  _Section(
                    title: 'House rules',
                    child: Text(
                      listing.houseRules!,
                      style: const TextStyle(height: 1.6, color: AppColors.textSecondary, fontSize: 14),
                    ),
                  ),
                reviewsAsync.when(
                  loading: () => const _Section(
                    title: 'Reviews',
                    isLast: true,
                    child: Padding(padding: EdgeInsets.symmetric(vertical: 12), child: LinearProgressIndicator()),
                  ),
                  error: (e, _) => _Section(
                    title: 'Reviews',
                    isLast: true,
                    child: Text(
                      'Could not load reviews (${apiErrorMessage(e)})',
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
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
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Full-bleed photo carousel with the page dots, counter and the back/save
/// controls floating over it.
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
    final isFavorite = ref.watch(favoritesProvider.select((ids) => ids.contains(widget.listing.id)));
    final topPadding = MediaQuery.paddingOf(context).top;

    return SizedBox(
      height: 320,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (photos.isEmpty)
            Container(color: Colors.grey.shade200, child: Icon(LucideIcons.house, size: 64, color: Colors.grey.shade400))
          else
            PageView.builder(
              controller: _controller,
              itemCount: photos.length,
              onPageChanged: (index) => setState(() => _page = index),
              itemBuilder: (context, index) => AppImage(url: photos[index].url),
            ),
          // Scrim so the white back/save buttons stay legible over bright photos.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topPadding + 80,
            child: const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x55000000), Colors.transparent],
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
                _CircleButton(icon: LucideIcons.arrowLeft, onTap: () => context.pop()),
                _CircleButton(
                  child: HeroIcon(
                    HeroIcons.heart,
                    style: isFavorite ? HeroIconStyle.solid : HeroIconStyle.outline,
                    color: isFavorite ? AppColors.error : AppColors.textPrimary,
                    size: 20,
                  ),
                  onTap: () {
                    if (isSignedOut(ref)) {
                      promptSignIn(
                        context,
                        title: 'Save this place',
                        message: 'Sign in to keep a wishlist of stays you like across your devices.',
                      );
                      return;
                    }
                    ref.read(favoritesProvider.notifier).toggle(widget.listing.id);
                  },
                ),
              ],
            ),
          ),
          if (photos.length > 1) ...[
            Positioned(
              bottom: 14,
              right: 14,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(20)),
                child: Text(
                  '${_page + 1}/${photos.length}',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
                ),
              ),
            ),
            Positioned(
              bottom: 16,
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
      ),
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
          child: Center(child: child ?? Icon(icon, size: 20, color: AppColors.textPrimary)),
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
        // Type and instant-book read as plain overline text rather than pills -
        // the whole screen avoids boxed chrome.
        Row(
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
              const Text('  ·  ', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
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
        const SizedBox(height: 10),
        Text(
          listing.title,
          style: const TextStyle(fontSize: 23, fontWeight: FontWeight.w700, height: 1.25),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Icon(LucideIcons.mapPin, size: 15, color: AppColors.textSecondary),
            const SizedBox(width: 5),
            Expanded(
              child: Text(
                '${listing.city} · ${listing.neighborhoodLandmark}',
                style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Icon(LucideIcons.star, size: 15, color: AppColors.accent),
            const SizedBox(width: 5),
            Text(
              average != null ? average.toStringAsFixed(1) : 'New',
              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
            ),
            const SizedBox(width: 5),
            Text(
              average != null
                  ? '· ${reviews.length} review${reviews.length == 1 ? '' : 's'}'
                  : '· no reviews yet',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ],
        ),
      ],
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
      (LucideIcons.bedDouble, '${listing.bedrooms} ${listing.bedrooms == 1 ? 'bedroom' : 'bedrooms'}'),
      (LucideIcons.bath, '${listing.bathrooms} ${listing.bathrooms == 1 ? 'bathroom' : 'bathrooms'}'),
      (LucideIcons.users, 'Up to ${listing.maxGuests}'),
      // Worth surfacing before a guest gets to the date picker rather than
      // after: a Long stay listing's 30-night floor is a hard rejection, not
      // a preference, and finding that out only once you try to book is the
      // kind of thing that reads as the app being broken.
      if (listing.minimumNights > 1)
        (LucideIcons.calendarDays, '${listing.minimumNights}-night minimum'),
    ];

    return Wrap(
      spacing: 18,
      runSpacing: 10,
      children: [
        for (final fact in facts)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(fact.$1, size: 17, color: AppColors.primary),
              const SizedBox(width: 7),
              Text(fact.$2, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w500)),
            ],
          ),
      ],
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
      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.info, size: 16, color: AppColors.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(note, style: const TextStyle(color: AppColors.textPrimary, fontSize: 13, height: 1.45))),
        ],
      ),
    );
  }
}

/// Sections are separated by whitespace alone - no rules or outlines anywhere
/// on this screen.
class _Section extends StatelessWidget {
  const _Section({required this.title, required this.child, this.isLast = false});

  final String title;
  final Widget child;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 17.5, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
        const SizedBox(height: 14),
        child,
        if (!isLast) const SizedBox(height: 34),
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
    const style = TextStyle(height: 1.6, color: AppColors.textSecondary, fontSize: 14);

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
              overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
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
        final columnWidth = ((constraints.maxWidth - gutter) / 2).floorToDouble() - 0.5;
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
                      color: highlight ? AppColors.primary : AppColors.textSecondary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        feature.$2,
                        maxLines: 2,
                        style: TextStyle(
                          fontSize: 13.5,
                          height: 1.3,
                          fontWeight: highlight ? FontWeight.w500 : FontWeight.w400,
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
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.none),
              ),
              children: [
                const BrandTileLayer(userAgentPackageName: 'com.staynaija.mobile'),
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
              child: Icon(LucideIcons.mapPin, size: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    const TextSpan(
                      text: 'Near: ',
                      style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.textPrimary),
                    ),
                    TextSpan(text: listing.neighborhoodLandmark),
                  ],
                ),
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary, height: 1.5),
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
    ref.read(listingRepositoryProvider).recordInteraction(listing.id, InteractionKind.directions);
    return open();
  }

  static String _address(Listing listing) =>
      ExternalMaps.formatAddress(landmark: listing.neighborhoodLandmark, city: listing.city);
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
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not open $label.')),
          );
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
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
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
        style: TextStyle(color: AppColors.textSecondary, fontSize: 13.5, height: 1.5),
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
                    color: i < reviews[index].average.round() ? AppColors.accent : Colors.grey.shade300,
                  ),
                ),
              const SizedBox(width: 6),
              Text(
                reviews[index].average.toStringAsFixed(1),
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
              ),
            ],
          ),
          if (reviews[index].comment != null) ...[
            const SizedBox(height: 8),
            Text(reviews[index].comment!, style: const TextStyle(fontSize: 13.5, height: 1.6)),
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
            boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 12, offset: Offset(0, -2))],
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
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 18),
                            ),
                            Text(' / ${listing.displayUnitLabel}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                          ],
                        ),
                        // Only meaningful on a nightly rate - see the host
                        // form's note on why these are cleared for anything
                        // priced weekly or monthly.
                        if (listing.pricingUnit == PricingUnit.nightly && listing.weeklyDiscountPercent > 0)
                          Text(
                            '${listing.weeklyDiscountPercent.toStringAsFixed(0)}% off weekly stays',
                            style: const TextStyle(color: AppColors.primary, fontSize: 11, fontWeight: FontWeight.w600),
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
                            message: 'Sign in so the host can reply to you and you can keep the conversation.',
                          );
                          return;
                        }
                        final conversation = await MessageRepository().startConversation(listing.id);
                        if (context.mounted) context.push('/chat/${conversation.id}');
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
                            message: 'We need an account to hold your booking, take payment securely and share '
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
    reviews.map((review) => review.average).reduce((a, b) => a + b) / reviews.length;

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
