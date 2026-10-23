import 'dart:io';

import 'package:flutter/material.dart';
import 'package:staynaija_shared/core/theme/bold_icons.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';

import 'package:staynaija_shared/core/api/dio_client.dart';
import 'package:staynaija_shared/core/theme/app_theme.dart';
import 'package:staynaija_shared/core/widgets/app_image.dart';
import 'package:staynaija_shared/core/widgets/soft_card.dart';
import 'package:staynaija_shared/listings/listing_repository.dart';
import 'package:staynaija_shared/models/listing.dart';
import 'package:staynaija_shared/models/stay_type.dart';
import 'package:staynaija_host/features/host/location_picker_screen.dart';

const _standardAmenities = ['wifi', 'parking', 'ac', 'pool', 'kitchen'];

/// One glyph per stay type, purely a scanning aid on the picker sheet - the
/// taxonomy itself lives in `stay_type.dart` and knows nothing about icons.
const Map<String, IconData> _stayTypeIcons = {
  'hotel_stay': LucideIcons.building2,
  'shortlet_apartment': LucideIcons.building,
  'long_stay': LucideIcons.calendarDays,
  'extended_stay': LucideIcons.clock,
  'hostel_stay': LucideIcons.users,
  'resort_stay': LucideIcons.palmtree,
  'guesthouse_bnb': LucideIcons.doorOpen,
  'vacation_rental': LucideIcons.house,
  'homestay': LucideIcons.heartHandshake,
  'lodge_stay': LucideIcons.tent,
};

IconData _stayTypeIcon(String slug) => _stayTypeIcons[slug] ?? LucideIcons.house;

class CreateEditListingScreen extends StatefulWidget {
  const CreateEditListingScreen({super.key, this.existing});

  final Listing? existing;

  @override
  State<CreateEditListingScreen> createState() => _CreateEditListingScreenState();
}

class _CreateEditListingScreenState extends State<CreateEditListingScreen> {
  final _formKey = GlobalKey<FormState>();
  final _repository = ListingRepository();

  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late final TextEditingController _houseRulesController;
  late final TextEditingController _cityController;
  late final TextEditingController _landmarkController;
  late final TextEditingController _priceController;
  late final TextEditingController _cleaningFeeController;
  late final TextEditingController _weeklyDiscountController;
  late final TextEditingController _monthlyDiscountController;

  LatLng? _location;
  String _propertyType = stayTypes.first.slug;
  int _bedrooms = 1;
  int _bathrooms = 1;
  int _maxGuests = 2;
  int _minimumNights = 1;
  bool _breakfastIncluded = false;
  final Set<String> _selectedAmenities = {};
  bool _hasGenerator = false;
  bool _hasInverter = false;
  bool _has24hrElectricity = false;
  bool _isGatedEstate = false;
  bool _hasSecurityGuard = false;
  bool _hasCctv = false;
  bool _instantBook = false;

  StayType get _selectedStayType => stayTypes.firstWhere((t) => t.slug == _propertyType, orElse: () => stayTypes.first);

  List<File> _newPhotos = [];
  bool _isSaving = false;
  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final l = widget.existing;
    _titleController = TextEditingController(text: l?.title ?? '');
    _descriptionController = TextEditingController(text: l?.description ?? '');
    _houseRulesController = TextEditingController(text: l?.houseRules ?? '');
    _cityController = TextEditingController(text: l?.city ?? '');
    _landmarkController = TextEditingController(text: l?.neighborhoodLandmark ?? '');
    _cleaningFeeController = TextEditingController(text: l?.cleaningFee.toStringAsFixed(0) ?? '0');
    _weeklyDiscountController = TextEditingController(text: l?.weeklyDiscountPercent.toStringAsFixed(0) ?? '0');
    _monthlyDiscountController = TextEditingController(text: l?.monthlyDiscountPercent.toStringAsFixed(0) ?? '0');
    if (l != null) {
      _location = LatLng(l.latitude, l.longitude);
      // A listing saved before this taxonomy existed (or edited outside the
      // app) can hold a legacy word like "apartment" - normalised to a real
      // slug here so the picker below always has a matching item.
      _propertyType = stayTypes.any((t) => t.slug == l.propertyType)
          ? l.propertyType
          : normalizeStayTypeSlug(l.propertyType);
      _bedrooms = l.bedrooms;
      _bathrooms = l.bathrooms;
      _maxGuests = l.maxGuests;
      _minimumNights = l.minimumNights;
      _breakfastIncluded = l.breakfastIncluded;
      _selectedAmenities.addAll(l.amenities);
      _hasGenerator = l.hasGenerator;
      _hasInverter = l.hasInverter;
      _has24hrElectricity = l.has24hrElectricity;
      _isGatedEstate = l.isGatedEstate;
      _hasSecurityGuard = l.hasSecurityGuard;
      _hasCctv = l.hasCctv;
      _instantBook = l.instantBook;
      // The stored rate is always the true nightly-equivalent figure; shown
      // here converted into whatever unit this stay type is actually priced
      // in, so a Long stay host sees "450000" for their monthly rent rather
      // than a nightly-equivalent "15000" that means nothing to them.
      _priceController = TextEditingController(text: l.displayRate.toStringAsFixed(0));
    } else {
      _minimumNights = _selectedStayType.defaultMinimumNights;
      _priceController = TextEditingController();
    }
  }

  Future<void> _pickLocation() async {
    final result = await Navigator.of(context).push<LatLng>(
      MaterialPageRoute(builder: (_) => LocationPickerScreen(initial: _location)),
    );
    if (result != null) setState(() => _location = result);
  }

  Future<void> _pickPhotos() async {
    final picked = await ImagePicker().pickMultiImage(imageQuality: 85);
    if (picked.isNotEmpty) {
      setState(() => _newPhotos = [..._newPhotos, ...picked.map((x) => File(x.path))]);
    }
  }

  /// Opens the full stay-type picker. A dropdown menu collapses each item to
  /// one line, which cut every description with "…" - some mid-word - and
  /// none of the ten choices could be told apart on that alone. A full-width
  /// sheet gives each one the room its description actually needs.
  Future<void> _pickStayType() async {
    final oldUnit = _selectedStayType.pricingUnit;
    final selected = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => _StayTypeSheet(selected: _propertyType),
    );
    if (selected == null || selected == _propertyType) return;

    setState(() {
      _propertyType = selected;
      final newUnit = _selectedStayType.pricingUnit;

      // Re-express whatever price is already typed in the new unit, so
      // switching from Shortlet to Long stay turns "50000" into "1500000"
      // instead of silently reinterpreting the same digits as a monthly rent.
      final entered = double.tryParse(_priceController.text);
      if (entered != null && oldUnit != newUnit) {
        final nightlyEquivalent = entered / oldUnit.nightsPerUnit;
        _priceController.text = (nightlyEquivalent * newUnit.nightsPerUnit).toStringAsFixed(0);
      }

      // Only for a brand-new listing: the minimum-nights field hasn't been
      // touched by the host yet, so it is still fair to move it to match the
      // newly-chosen type's suggested floor. An existing listing's value is
      // the host's own deliberate data and is left alone.
      if (!_isEditing) _minimumNights = _selectedStayType.defaultMinimumNights;
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_location == null) {
      setState(() => _error = 'Please drop a pin for the property location');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final listing = Listing(
        id: widget.existing?.id ?? '',
        hostId: widget.existing?.hostId ?? '',
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim(),
        city: _cityController.text.trim(),
        neighborhoodLandmark: _landmarkController.text.trim(),
        latitude: _location!.latitude,
        longitude: _location!.longitude,
        propertyType: _propertyType,
        bedrooms: _bedrooms,
        bathrooms: _bathrooms,
        maxGuests: _maxGuests,
        // The host enters the rate in their stay type's natural unit (a
        // month's rent for Long stay, a week for Extended stay); converted
        // back to the true per-night figure the API and every price
        // calculation actually operate on.
        nightlyRate: double.parse(_priceController.text) / _selectedStayType.pricingUnit.nightsPerUnit,
        // Meaningless once the base rate isn't nightly - booking a Long stay
        // listing is always 28+ nights by its own minimum, so a "monthly
        // discount" on top of an already-monthly rate would just always fire.
        weeklyDiscountPercent:
            _selectedStayType.pricingUnit == PricingUnit.nightly ? double.tryParse(_weeklyDiscountController.text) ?? 0 : 0,
        monthlyDiscountPercent:
            _selectedStayType.pricingUnit == PricingUnit.nightly ? double.tryParse(_monthlyDiscountController.text) ?? 0 : 0,
        cleaningFee: double.tryParse(_cleaningFeeController.text) ?? 0,
        minimumNights: _minimumNights,
        breakfastIncluded: _breakfastIncluded,
        amenities: _selectedAmenities.toList(),
        houseRules: _houseRulesController.text.trim().isEmpty ? null : _houseRulesController.text.trim(),
        hasGenerator: _hasGenerator,
        hasInverter: _hasInverter,
        has24hrElectricity: _has24hrElectricity,
        isGatedEstate: _isGatedEstate,
        hasSecurityGuard: _hasSecurityGuard,
        hasCctv: _hasCctv,
        instantBook: _instantBook,
        isPublished: widget.existing?.isPublished ?? true,
        photos: const [],
      );

      final Listing saved;
      if (_isEditing) {
        saved = await _repository.update(widget.existing!.id, listing.toCreateJson());
      } else {
        saved = await _repository.create(listing);
      }

      for (final photo in _newPhotos) {
        await _repository.uploadPhoto(saved.id, photo);
      }

      if (mounted) context.pop();
    } catch (e) {
      setState(() => _error = apiErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _houseRulesController.dispose();
    _cityController.dispose();
    _landmarkController.dispose();
    _priceController.dispose();
    _cleaningFeeController.dispose();
    _weeklyDiscountController.dispose();
    _monthlyDiscountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedType = stayTypes.firstWhere(
      (t) => t.slug == _propertyType,
      orElse: () => stayTypes.first,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(_isEditing ? 'Edit listing' : 'New listing'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Section(
                icon: LucideIcons.fileText,
                title: 'The basics',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Title'),
                    TextFormField(
                      controller: _titleController,
                      decoration: _fieldDecoration(hint: 'e.g. Quiet Studio in Jabi', icon: LucideIcons.type),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    _fieldLabel('Description'),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      decoration: _fieldDecoration(hint: 'What makes this place worth booking?'),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    _fieldLabel('House rules (optional)'),
                    TextFormField(
                      controller: _houseRulesController,
                      maxLines: 3,
                      decoration: _fieldDecoration(hint: 'e.g. No smoking, no parties, quiet hours after 10pm'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _Section(
                icon: LucideIcons.mapPin,
                title: 'Location',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('City'),
                    TextFormField(
                      controller: _cityController,
                      decoration: _fieldDecoration(hint: 'Lagos, Abuja, Port Harcourt…', icon: LucideIcons.building2),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    _fieldLabel('Landmark description'),
                    TextFormField(
                      controller: _landmarkController,
                      decoration: _fieldDecoration(hint: 'e.g. Behind Shoprite Lekki', icon: LucideIcons.landmark),
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                    ),
                    const SizedBox(height: 14),
                    // This is what a Bolt driver actually gets sent to, so it is
                    // called out as its own step rather than buried as a field.
                    _PinStatusTile(isSet: _location != null, onTap: _pickLocation),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _Section(
                icon: LucideIcons.layoutGrid,
                title: 'Stay type & capacity',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('Stay type'),
                    _StayTypeField(type: selectedType, onTap: _pickStayType),
                    const SizedBox(height: 18),
                    Row(children: [
                      Expanded(
                        child: _CounterField(
                          label: 'Bedrooms',
                          value: _bedrooms,
                          onChanged: (v) => setState(() => _bedrooms = v),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _CounterField(
                          label: 'Bathrooms',
                          value: _bathrooms,
                          onChanged: (v) => setState(() => _bathrooms = v),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _CounterField(
                          label: 'Guests',
                          value: _maxGuests,
                          onChanged: (v) => setState(() => _maxGuests = v),
                        ),
                      ),
                    ]),
                    const SizedBox(height: 14),
                    _fieldLabel('Minimum stay'),
                    _MinimumNightsField(
                      nights: _minimumNights,
                      onChanged: (v) => setState(() => _minimumNights = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _Section(
                icon: LucideIcons.banknote,
                title: 'Pricing',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _fieldLabel('${_capitalize(selectedType.pricingUnit.label)} rate (₦)'),
                    TextFormField(
                      controller: _priceController,
                      keyboardType: TextInputType.number,
                      decoration: _fieldDecoration(hint: '0', icon: LucideIcons.banknote),
                      validator: (v) => (double.tryParse(v ?? '') == null) ? 'Enter a valid amount' : null,
                    ),
                    // A discount for staying 7+ or 28+ nights only makes sense
                    // when the base rate is nightly - a Long stay listing's
                    // minimum is already 30 nights, so a "monthly discount" on
                    // top of an already-monthly rate would always silently
                    // apply. Hidden rather than shown-and-ignored.
                    if (selectedType.pricingUnit == PricingUnit.nightly) ...[
                      const SizedBox(height: 14),
                      Row(children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _fieldLabel('Weekly discount %'),
                              TextFormField(
                                controller: _weeklyDiscountController,
                                keyboardType: TextInputType.number,
                                decoration: _fieldDecoration(hint: '0'),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _fieldLabel('Monthly discount %'),
                              TextFormField(
                                controller: _monthlyDiscountController,
                                keyboardType: TextInputType.number,
                                decoration: _fieldDecoration(hint: '0'),
                              ),
                            ],
                          ),
                        ),
                      ]),
                    ],
                    const SizedBox(height: 14),
                    _fieldLabel('Cleaning fee (₦)'),
                    TextFormField(
                      controller: _cleaningFeeController,
                      keyboardType: TextInputType.number,
                      decoration: _fieldDecoration(hint: '0'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _Section(
                icon: LucideIcons.sparkles,
                title: 'Amenities & essentials',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _standardAmenities.map((a) {
                        final selected = _selectedAmenities.contains(a);
                        return FilterChip(
                          label: Text(a.toUpperCase()),
                          selected: selected,
                          onSelected: (v) => setState(() => v ? _selectedAmenities.add(a) : _selectedAmenities.remove(a)),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 4),
                    // Its own toggle rather than folded into the amenities
                    // chips above: "often including breakfast" is the actual
                    // wording of three of the ten stay-type descriptions, and
                    // it changes what a guest expects to pay for separately -
                    // a different kind of fact than "has wifi".
                    _switchTile('Breakfast included', _breakfastIncluded, (v) => setState(() => _breakfastIncluded = v)),
                    const SizedBox(height: 18),
                    const Divider(height: 1),
                    const SizedBox(height: 14),
                    _sectionLabel('Power'),
                    _switchTile('Generator', _hasGenerator, (v) => setState(() => _hasGenerator = v)),
                    _switchTile('Inverter', _hasInverter, (v) => setState(() => _hasInverter = v)),
                    _switchTile(
                        '24hr electricity', _has24hrElectricity, (v) => setState(() => _has24hrElectricity = v)),
                    const SizedBox(height: 4),
                    _sectionLabel('Security'),
                    _switchTile('Gated estate', _isGatedEstate, (v) => setState(() => _isGatedEstate = v)),
                    _switchTile('Security guard', _hasSecurityGuard, (v) => setState(() => _hasSecurityGuard = v)),
                    _switchTile('CCTV', _hasCctv, (v) => setState(() => _hasCctv = v)),
                    const SizedBox(height: 4),
                    _switchTile(
                      'Instant book (skip host approval)',
                      _instantBook,
                      (v) => setState(() => _instantBook = v),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              _Section(
                icon: LucideIcons.images,
                title: 'Photos',
                child: _PhotosGrid(
                  existing: widget.existing?.photos ?? const [],
                  newPhotos: _newPhotos,
                  onAdd: _pickPhotos,
                  onRemoveNew: (index) => setState(() => _newPhotos = [..._newPhotos]..removeAt(index)),
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 16),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13)),
                ),
              ],
              const SizedBox(height: 22),
              SizedBox(
                height: 50,
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _submit,
                  child: _isSaving
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : Text(_isEditing ? 'Save changes' : 'Create listing'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fieldLabel(String text) => Padding(
        padding: const EdgeInsets.only(left: 2, bottom: 6),
        child: Text(text, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
      );

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary, letterSpacing: 0.4),
        ),
      );

  InputDecoration _fieldDecoration({String? hint, IconData? icon}) => InputDecoration(
        hintText: hint,
        fillColor: AppColors.background,
        prefixIcon: icon == null ? null : Icon(icon, size: 18, color: AppColors.textSecondary),
      );

  Widget _switchTile(String label, bool value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(label, style: const TextStyle(fontSize: 14)),
      value: value,
      onChanged: onChanged,
    );
  }
}

String _capitalize(String text) => text.isEmpty ? text : '${text[0].toUpperCase()}${text.substring(1)}';

/// Shortest stay this listing accepts, as a stepper rather than a bare number
/// field - a host can misread "minimum nights: 1" as an average and type "30"
/// meaning "usually a month," when what the field actually does is reject any
/// shorter booking outright. A stepper with a live "nights"/"night" caption
/// makes the floor unambiguous.
class _MinimumNightsField extends StatelessWidget {
  const _MinimumNightsField({required this.nights, required this.onChanged});

  final int nights;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
      child: Row(
        children: [
          IconButton(
            padding: EdgeInsets.zero,
            onPressed: nights > 1 ? () => onChanged(nights - 1) : null,
            icon: Icon(LucideIcons.minus, size: 15),
            color: nights > 1 ? AppColors.primary : AppColors.textSecondary.withValues(alpha: 0.35),
          ),
          const SizedBox(width: 8),
          Text(
            '$nights ${nights == 1 ? 'night' : 'nights'}',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 8),
          IconButton(
            padding: EdgeInsets.zero,
            onPressed: () => onChanged(nights + 1),
            icon: Icon(LucideIcons.plus, size: 15),
            color: AppColors.primary,
          ),
          const Spacer(),
        ],
      ),
    );
  }
}

/// A section of the form: an icon-and-title header above a card, matching the
/// grouped-card language used across the rest of the host app rather than one
/// long undifferentiated list of fields.
class _Section extends StatelessWidget {
  const _Section({required this.icon, required this.title, required this.child});

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 10),
          child: Row(
            children: [
              Icon(icon, size: 16, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(title, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
        SoftCard(padding: const EdgeInsets.all(16), child: child),
      ],
    );
  }
}

/// The location-picker launcher, styled to communicate what it actually
/// controls: the exact point a ride app hands a driver, not a cosmetic map
/// preview - so an unset pin reads as a warning, not a neutral empty state.
class _PinStatusTile extends StatelessWidget {
  const _PinStatusTile({required this.isSet, required this.onTap});

  final bool isSet;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = isSet ? AppColors.primary : Colors.orange.shade800;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isSet ? AppColors.primary.withValues(alpha: 0.06) : Colors.orange.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(isSet ? LucideIcons.mapPinCheck : LucideIcons.mapPinned, size: 18, color: color),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isSet ? 'Pin placed - tap to adjust' : 'Drop a pin on the exact entrance',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, color: color),
              ),
            ),
            Icon(LucideIcons.chevronRight, size: 16, color: color),
          ],
        ),
      ),
    );
  }
}

/// The stay-type "field" - looks like the text fields around it, but opens
/// [_StayTypeSheet] instead of a keyboard.
class _StayTypeField extends StatelessWidget {
  // Matches the 12px radius every other field on this screen uses via the
  // shared theme's input decoration - kept as a literal here since that
  // radius isn't exposed as a public constant.
  static const _radius = BorderRadius.all(Radius.circular(12));

  const _StayTypeField({required this.type, required this.onTap});

  final StayType type;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: _radius,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(color: AppColors.background, borderRadius: _radius),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(_stayTypeIcon(type.slug), size: 16, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(type.label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600)),
            ),
            Icon(LucideIcons.chevronDown, size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

/// Full-width stay-type picker.
///
/// A `DropdownButtonFormField` collapses each item to one line, which for
/// this taxonomy cut every description with an ellipsis - "Hotel/apartment
/// designed for longer periods, usually wit…" - and several of the ten
/// choices became indistinguishable once truncated that way. A sheet gives
/// each row the width and line count its description actually needs.
class _StayTypeSheet extends StatelessWidget {
  const _StayTypeSheet({required this.selected});

  final String selected;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.82),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 10),
            Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.25),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 6),
              child: Row(
                children: [
                  Text('Stay type', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                itemCount: stayTypes.length,
                separatorBuilder: (_, _) => const SizedBox(height: 2),
                itemBuilder: (context, index) {
                  final type = stayTypes[index];
                  final isSelected = type.slug == selected;
                  return InkWell(
                    onTap: () => Navigator.of(context).pop(type.slug),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                      decoration: BoxDecoration(
                        color: isSelected ? AppColors.primary.withValues(alpha: 0.07) : null,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            margin: const EdgeInsets.only(top: 2),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(11),
                            ),
                            child: Icon(_stayTypeIcon(type.slug), size: 18, color: AppColors.primary),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(type.label, style: const TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 2),
                                Text(
                                  type.description,
                                  style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                          if (isSelected) ...[
                            const SizedBox(width: 8),
                            Icon(LucideIcons.circleCheck, size: 20, color: AppColors.primary),
                          ],
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bedrooms/bathrooms/guests, restyled as a small pill stepper instead of two
/// bare `IconButton`s flanking a number - reads as one control rather than
/// three loose elements.
class _CounterField extends StatelessWidget {
  const _CounterField({required this.label, required this.value, required this.onChanged});

  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 2, bottom: 6),
          child: Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(12)),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _stepButton(LucideIcons.minus, value > 1 ? () => onChanged(value - 1) : null),
              Text('$value', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              _stepButton(LucideIcons.plus, () => onChanged(value + 1)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _stepButton(IconData icon, VoidCallback? onTap) {
    return SizedBox(
      width: 32,
      height: 42,
      child: IconButton(
        padding: EdgeInsets.zero,
        onPressed: onTap,
        icon: Icon(icon, size: 15),
        color: onTap == null ? AppColors.textSecondary.withValues(alpha: 0.35) : AppColors.primary,
      ),
    );
  }
}

/// Existing photos (read-only - already uploaded) followed by newly picked
/// ones (removable before save), then an "add" tile. Replaces a single button
/// whose label was the only feedback a host got that anything was selected.
class _PhotosGrid extends StatelessWidget {
  const _PhotosGrid({
    required this.existing,
    required this.newPhotos,
    required this.onAdd,
    required this.onRemoveNew,
  });

  final List<ListingPhoto> existing;
  final List<File> newPhotos;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemoveNew;

  static const _tileSize = 84.0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (existing.isNotEmpty) ...[
          const Text(
            'Already on the listing',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: _tileSize,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: existing.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) => ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AppImage(url: existing[i].url, width: _tileSize, height: _tileSize),
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < newPhotos.length; i++) _newPhotoTile(newPhotos[i], () => onRemoveNew(i)),
            _addTile(),
          ],
        ),
        if (newPhotos.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            '${newPhotos.length} new photo${newPhotos.length == 1 ? '' : 's'} will be added on save',
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ],
      ],
    );
  }

  Widget _newPhotoTile(File file, VoidCallback onRemove) {
    return SizedBox(
      width: _tileSize,
      height: _tileSize,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(file, width: _tileSize, height: _tileSize, fit: BoxFit.cover),
          ),
          Positioned(
            top: -6,
            right: -6,
            child: InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(11),
              child: Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(
                  color: Colors.black87,
                  shape: BoxShape.circle,
                ),
                child: const Icon(LucideIcons.x, size: 13, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _addTile() {
    return InkWell(
      onTap: onAdd,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: _tileSize,
        height: _tileSize,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withValues(alpha: 0.25), style: BorderStyle.solid),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(LucideIcons.imagePlus, size: 20, color: AppColors.primary),
            const SizedBox(height: 4),
            Text('Add', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
          ],
        ),
      ),
    );
  }
}
