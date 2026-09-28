import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:staynaija_shared/core/theme/bold_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:staynaija_shared/core/api/dio_client.dart';
import 'package:staynaija_shared/core/theme/app_theme.dart';
import 'package:staynaija_shared/core/widgets/app_image.dart';
import 'package:staynaija_shared/core/widgets/soft_card.dart';
import 'package:staynaija_shared/bookings/booking_repository.dart';
import 'package:staynaija_shared/models/booking.dart';
import 'package:staynaija_shared/models/listing.dart';
import 'package:staynaija_shared/models/stay_type.dart';
import 'package:staynaija/features/discovery/discovery_provider.dart';

class BookingFlowScreen extends ConsumerStatefulWidget {
  const BookingFlowScreen({super.key, required this.listingId});

  final String listingId;

  @override
  ConsumerState<BookingFlowScreen> createState() => _BookingFlowScreenState();
}

class _BookingFlowScreenState extends ConsumerState<BookingFlowScreen> {
  DateTime? _checkIn;
  DateTime? _checkOut;
  int _numGuests = 1;
  PriceBreakdown? _breakdown;
  bool _isLoadingPrice = false;
  bool _isSubmitting = false;
  String? _error;

  // In the listing's own pricing-period units (weeks/months) - only used for
  // Long/Extended stay listings, where a guest thinks "3 months", not two
  // calendar taps 90 days apart. Defaulted to the listing's minimum once it
  // loads - see _minUnits below.
  int _durationUnits = 1;
  bool _durationInitialized = false;

  final _bookingRepository = BookingRepository();
  final _dateFormat = DateFormat('EEE, d MMM');

  int _minUnits(Listing listing) {
    final units = (listing.minimumNights / listing.pricingUnit.nightsPerUnit).ceil();
    return units < 1 ? 1 : units;
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
      initialDateRange: _checkIn != null && _checkOut != null ? DateTimeRange(start: _checkIn!, end: _checkOut!) : null,
    );
    if (range == null) return;
    setState(() {
      _checkIn = range.start;
      _checkOut = range.end;
      _breakdown = null;
      _error = null;
    });
    await _loadPriceBreakdown();
  }

  /// The weekly/monthly-priced equivalent of [_pickDateRange]: one date plus
  /// a duration stepper, rather than asking a guest to tap out the exact
  /// far-off end date on a calendar for what is functionally a lease.
  Future<void> _pickMoveInDate(Listing listing) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _checkIn ?? now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 365)),
    );
    if (picked == null) return;
    setState(() {
      _checkIn = picked;
      _checkOut = picked.add(Duration(days: _durationUnits * listing.pricingUnit.nightsPerUnit));
      _breakdown = null;
      _error = null;
    });
    await _loadPriceBreakdown();
  }

  void _changeDuration(int units, Listing listing) {
    setState(() {
      _durationUnits = units;
      if (_checkIn != null) {
        _checkOut = _checkIn!.add(Duration(days: units * listing.pricingUnit.nightsPerUnit));
        _breakdown = null;
      }
    });
    if (_checkIn != null) _loadPriceBreakdown();
  }

  Future<void> _loadPriceBreakdown() async {
    if (_checkIn == null || _checkOut == null) return;
    setState(() {
      _isLoadingPrice = true;
      _error = null;
    });
    try {
      final breakdown = await _bookingRepository.getPriceBreakdown(
        listingId: widget.listingId,
        checkIn: _checkIn!,
        checkOut: _checkOut!,
      );
      setState(() => _breakdown = breakdown);
    } catch (e) {
      setState(() {
        _breakdown = null;
        _error = apiErrorMessage(e);
      });
    } finally {
      if (mounted) setState(() => _isLoadingPrice = false);
    }
  }

  Future<void> _confirm() async {
    if (_checkIn == null || _checkOut == null) return;
    setState(() {
      _isSubmitting = true;
      _error = null;
    });
    try {
      final booking = await _bookingRepository.createBooking(
        listingId: widget.listingId,
        checkIn: _checkIn!,
        checkOut: _checkOut!,
        numGuests: _numGuests,
      );
      if (!mounted) return;
      if (booking.status == BookingStatus.awaitingPayment) {
        context.pushReplacement('/checkout/${booking.id}');
      } else {
        context.pushReplacement('/booking-requested/${booking.id}');
      }
    } catch (e) {
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final listingAsync = ref.watch(listingRepositoryProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Request to book')),
      body: FutureBuilder<Listing>(
        future: listingAsync.getById(widget.listingId),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final listing = snapshot.data!;
          final unit = listing.pricingUnit;
          final isNightly = unit == PricingUnit.nightly;
          if (!_durationInitialized) {
            _durationUnits = _minUnits(listing);
            _durationInitialized = true;
          }

          return Column(
            children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                  children: [
                    _ListingSummaryCard(listing: listing),
                    const SizedBox(height: 22),
                    const _SectionLabel('Your stay'),
                    SoftCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          _DetailRow(
                            icon: LucideIcons.calendar,
                            label: isNightly
                                ? (_checkIn == null
                                    ? 'Select check-in / check-out'
                                    : '${_dateFormat.format(_checkIn!)}  →  ${_dateFormat.format(_checkOut!)}')
                                : (_checkIn == null ? 'Select move-in date' : 'Move in ${_dateFormat.format(_checkIn!)}'),
                            sublabel: isNightly
                                ? (listing.minimumNights > 1 ? '${listing.minimumNights}-night minimum' : null)
                                : (_checkOut != null ? 'Move out ${_dateFormat.format(_checkOut!)}' : null),
                            onTap: isNightly ? _pickDateRange : () => _pickMoveInDate(listing),
                          ),
                          const Divider(height: 1, indent: 70),
                          if (!isNightly) ...[
                            _DurationRow(
                              unit: unit,
                              units: _durationUnits,
                              minUnits: _minUnits(listing),
                              onChanged: (value) => _changeDuration(value, listing),
                            ),
                            const Divider(height: 1, indent: 70),
                          ],
                          _GuestsRow(
                            numGuests: _numGuests,
                            maxGuests: listing.maxGuests,
                            onChanged: (value) => setState(() => _numGuests = value),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 22),
                    if (_isLoadingPrice)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 30),
                        child: Center(child: CircularProgressIndicator()),
                      ),
                    if (_breakdown != null) ...[
                      const _SectionLabel('Price details'),
                      _PriceBreakdownCard(breakdown: _breakdown!),
                    ],
                    if (_error != null) ...[
                      const SizedBox(height: 14),
                      _ErrorBanner(message: _error!),
                    ],
                  ],
                ),
              ),
              _BottomBar(
                total: _breakdown?.totalPrice,
                isEnabled: _breakdown != null && !_isSubmitting,
                isSubmitting: _isSubmitting,
                label: listing.instantBook ? 'Reserve and pay' : 'Send request',
                onPressed: _confirm,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);

  final String label;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8, top: 2, left: 4),
        child: Text(
          label.toUpperCase(),
          style: const TextStyle(fontSize: 11, letterSpacing: 1.1, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
        ),
      );
}

class _ListingSummaryCard extends StatelessWidget {
  const _ListingSummaryCard({required this.listing});

  final Listing listing;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppImage(
            url: listing.photos.isNotEmpty ? listing.photos.first.url : null,
            width: 68,
            height: 68,
            borderRadius: BorderRadius.circular(14),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  listing.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14.5, height: 1.25),
                ),
                const SizedBox(height: 5),
                Row(
                  children: [
                    Icon(LucideIcons.mapPin, size: 12, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        listing.neighborhoodLandmark.isNotEmpty ? '${listing.neighborhoodLandmark}, ${listing.city}' : listing.city,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(6)),
                  child: Text(
                    stayTypeLabel(listing.propertyType),
                    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
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

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), shape: BoxShape.circle),
      child: Icon(icon, size: 18, color: AppColors.primary),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.icon, required this.label, this.sublabel, required this.onTap});

  final IconData icon;
  final String label;
  final String? sublabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            _IconBadge(icon: icon),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                  if (sublabel != null) ...[
                    const SizedBox(height: 2),
                    Text(sublabel!, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ],
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _GuestsRow extends StatelessWidget {
  const _GuestsRow({required this.numGuests, required this.maxGuests, required this.onChanged});

  final int numGuests;
  final int maxGuests;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const _IconBadge(icon: LucideIcons.users),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$numGuests guest${numGuests > 1 ? 's' : ''}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                Text('Up to $maxGuests', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          _Stepper(
            value: numGuests,
            onDecrement: numGuests > 1 ? () => onChanged(numGuests - 1) : null,
            onIncrement: numGuests < maxGuests ? () => onChanged(numGuests + 1) : null,
          ),
        ],
      ),
    );
  }
}

class _DurationRow extends StatelessWidget {
  const _DurationRow({required this.unit, required this.units, required this.minUnits, required this.onChanged});

  final PricingUnit unit;
  final int units;
  final int minUnits;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          const _IconBadge(icon: LucideIcons.hourglass),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$units ${unit.label}${units > 1 ? 's' : ''}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14)),
                const SizedBox(height: 2),
                const Text('Length of stay', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          _Stepper(
            value: units,
            onDecrement: units > minUnits ? () => onChanged(units - 1) : null,
            onIncrement: () => onChanged(units + 1),
          ),
        ],
      ),
    );
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.value, required this.onDecrement, required this.onIncrement});

  final int value;
  final VoidCallback? onDecrement;
  final VoidCallback? onIncrement;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepperButton(icon: LucideIcons.minus, onTap: onDecrement),
        SizedBox(width: 30, child: Text('$value', textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15))),
        _StepperButton(icon: LucideIcons.plus, onTap: onIncrement),
      ],
    );
  }
}

class _StepperButton extends StatelessWidget {
  const _StepperButton({required this.icon, required this.onTap});

  final IconData icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: enabled ? AppColors.primary.withValues(alpha: 0.35) : Colors.grey.shade200),
        ),
        child: Icon(icon, size: 14, color: enabled ? AppColors.primary : Colors.grey.shade400),
      ),
    );
  }
}

class _PriceBreakdownCard extends StatelessWidget {
  const _PriceBreakdownCard({required this.breakdown});

  final PriceBreakdown breakdown;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _row('${formatNaira(breakdown.nightlyRate)} x ${breakdown.nights} night${breakdown.nights == 1 ? '' : 's'}', breakdown.subtotal),
          if (breakdown.discountAmount > 0) _row('Discount', -breakdown.discountAmount, accent: true),
          if (breakdown.cleaningFee > 0) _row('Cleaning fee', breakdown.cleaningFee),
          const Padding(padding: EdgeInsets.symmetric(vertical: 8), child: Divider(height: 1)),
          _row('Total', breakdown.totalPrice, bold: true),
        ],
      ),
    );
  }

  Widget _row(String label, double amount, {bool bold = false, bool accent = false}) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: TextStyle(
                fontWeight: bold ? FontWeight.w700 : FontWeight.w500,
                fontSize: bold ? 15 : 13.5,
                color: bold ? AppColors.textPrimary : AppColors.textSecondary,
              ),
            ),
            Text(
              '${amount < 0 ? '-' : ''}${formatNaira(amount.abs())}',
              style: TextStyle(
                fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                fontSize: bold ? 16 : 13.5,
                color: bold ? AppColors.textPrimary : (accent ? AppColors.primary : AppColors.textPrimary),
              ),
            ),
          ],
        ),
      );
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AppColors.error.withValues(alpha: 0.08), borderRadius: BorderRadius.circular(14)),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.triangleAlert, size: 16, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: const TextStyle(color: AppColors.error, fontSize: 12.5, height: 1.4))),
        ],
      ),
    );
  }
}

/// Sticky rather than the last item in the scroll view - the total and the
/// action that spends it should never require scrolling to find, and this is
/// the one screen in the app where that specifically matters.
class _BottomBar extends StatelessWidget {
  const _BottomBar({
    required this.total,
    required this.isEnabled,
    required this.isSubmitting,
    required this.label,
    required this.onPressed,
  });

  final double? total;
  final bool isEnabled;
  final bool isSubmitting;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 16, offset: const Offset(0, -4))],
        ),
        child: Row(
          children: [
            Expanded(
              child: total != null
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(formatNaira(total!), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                        const Text('Total', style: TextStyle(color: AppColors.textSecondary, fontSize: 11.5)),
                      ],
                    )
                  : const Text('Pick your dates to see the price', style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5)),
            ),
            const SizedBox(width: 16),
            // The app-wide ElevatedButton theme sets minimumSize to
            // Size.fromHeight(50) = Size(double.infinity, 50) for full-width
            // buttons; a Row measures a non-flex child with unbounded width, so
            // without this override the button would be asked to render at
            // infinite width. See listing_detail_screen.dart for the same fix.
            ElevatedButton(
              style: ElevatedButton.styleFrom(minimumSize: const Size(0, 50), padding: const EdgeInsets.symmetric(horizontal: 22)),
              onPressed: isEnabled ? onPressed : null,
              child: isSubmitting
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}
