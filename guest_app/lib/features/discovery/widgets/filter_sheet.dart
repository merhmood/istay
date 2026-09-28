import 'package:flutter/material.dart';

import 'package:staynaija_shared/listings/listing_repository.dart';
import 'package:staynaija_shared/models/stay_type.dart';

class FilterSheet extends StatefulWidget {
  const FilterSheet({super.key, required this.initialFilters});

  final ListingFilters initialFilters;

  @override
  State<FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<FilterSheet> {
  late ListingFilters _filters;
  late TextEditingController _minPriceController;
  late TextEditingController _maxPriceController;

  /// `_filters.minPrice`/`maxPrice` are always the true nightly-equivalent
  /// rate underneath (see [ListingFilters.toQuery]) - this is just which unit
  /// the two text fields above are currently *displayed* in. Null (no stay
  /// type picked) means "night", the unit every stay type can be compared in.
  PricingUnit? get _priceUnit => _filters.propertyType == null ? null : pricingUnitFor(_filters.propertyType!);

  @override
  void initState() {
    super.initState();
    _filters = widget.initialFilters;
    _minPriceController = TextEditingController(text: _displayPrice(_filters.minPrice));
    _maxPriceController = TextEditingController(text: _displayPrice(_filters.maxPrice));
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    super.dispose();
  }

  String _displayPrice(double? nightlyEquivalent) {
    if (nightlyEquivalent == null) return '';
    final nightsPerUnit = _priceUnit?.nightsPerUnit ?? 1;
    return (nightlyEquivalent * nightsPerUnit).round().toString();
  }

  /// Re-expresses whatever is currently typed in the two price fields in the
  /// new unit, so picking "Long stay" turns an entered "50000" (meant as a
  /// nightly figure) into its monthly equivalent instead of silently keeping
  /// the same number under a now-wrong label.
  void _convertPriceFields(PricingUnit? from, PricingUnit? to) {
    final fromNights = from?.nightsPerUnit ?? 1;
    final toNights = to?.nightsPerUnit ?? 1;
    if (fromNights == toNights) return;
    final min = double.tryParse(_minPriceController.text);
    if (min != null) _minPriceController.text = (min / fromNights * toNights).round().toString();
    final max = double.tryParse(_maxPriceController.text);
    if (max != null) _maxPriceController.text = (max / fromNights * toNights).round().toString();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: ListView(
            controller: scrollController,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Filters', style: Theme.of(context).textTheme.titleLarge),
                  TextButton(
                    onPressed: () => setState(() {
                      _filters = const ListingFilters();
                      _minPriceController.clear();
                      _maxPriceController.clear();
                    }),
                    child: const Text('Reset'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // No unit named until a stay type is picked: the filter compares
              // listings on their true nightly-equivalent rate under the hood
              // so mixed stay types stay comparable, and with results still
              // mixed there's no single honest unit to label this with. Once
              // a specific stay type is chosen, every result shares its unit,
              // so the fields switch to show and accept figures in it
              // directly - a Long stay host thinks in months, not nights.
              Text(
                _priceUnit == null ? 'Price range (₦)' : 'Price range (₦ / ${_priceUnit!.label})',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _minPriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Min'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _maxPriceController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Max'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Text('Stay type', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: stayTypes.map((type) {
                  final selected = _filters.propertyType == type.slug;
                  return FilterChip(
                    label: Text(type.label),
                    selected: selected,
                    // A single stay is one type, so this behaves as a
                    // single-select: picking a chip replaces any previous
                    // choice, and picking the already-selected one clears it
                    // back to "any type" rather than leaving nothing tappable
                    // to undo the filter.
                    onSelected: (value) => setState(() {
                      final oldUnit = _priceUnit;
                      _filters = value
                          ? _filters.copyWith(propertyType: type.slug)
                          : _filters.copyWith(clearPropertyType: true);
                      _convertPriceFields(oldUnit, _priceUnit);
                    }),
                  );
                }).toList(),
              ),
              const SizedBox(height: 20),
              Text('Power', style: Theme.of(context).textTheme.titleSmall),
              _switchTile('Generator', _filters.hasGenerator, (v) => setState(() => _filters = _filters.copyWith(hasGenerator: v))),
              _switchTile('Inverter', _filters.hasInverter, (v) => setState(() => _filters = _filters.copyWith(hasInverter: v))),
              _switchTile(
                  '24hr electricity', _filters.has24hrElectricity, (v) => setState(() => _filters = _filters.copyWith(has24hrElectricity: v))),
              const SizedBox(height: 12),
              Text('Security', style: Theme.of(context).textTheme.titleSmall),
              _switchTile('Gated estate', _filters.isGatedEstate, (v) => setState(() => _filters = _filters.copyWith(isGatedEstate: v))),
              _switchTile(
                  'Security guard', _filters.hasSecurityGuard, (v) => setState(() => _filters = _filters.copyWith(hasSecurityGuard: v))),
              _switchTile('CCTV', _filters.hasCctv, (v) => setState(() => _filters = _filters.copyWith(hasCctv: v))),
              const SizedBox(height: 12),
              Text('Amenities', style: Theme.of(context).textTheme.titleSmall),
              Wrap(
                spacing: 8,
                children: ['wifi', 'parking', 'ac', 'pool', 'kitchen'].map((amenity) {
                  final selected = _filters.amenities.contains(amenity);
                  return FilterChip(
                    label: Text(amenity.toUpperCase()),
                    selected: selected,
                    onSelected: (value) {
                      final updated = [..._filters.amenities];
                      value ? updated.add(amenity) : updated.remove(amenity);
                      setState(() => _filters = _filters.copyWith(amenities: updated));
                    },
                  );
                }).toList(),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () {
                  // Text fields hold figures in _priceUnit; filters store the
                  // true nightly-equivalent, so convert back on the way out.
                  final nightsPerUnit = _priceUnit?.nightsPerUnit ?? 1;
                  final minPrice = double.tryParse(_minPriceController.text);
                  final maxPrice = double.tryParse(_maxPriceController.text);
                  Navigator.of(context).pop(_filters.copyWith(
                    minPrice: minPrice == null ? null : minPrice / nightsPerUnit,
                    maxPrice: maxPrice == null ? null : maxPrice / nightsPerUnit,
                  ));
                },
                child: const Text('Show results'),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _switchTile(String label, bool? value, ValueChanged<bool> onChanged) {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(label),
      value: value ?? false,
      onChanged: onChanged,
    );
  }
}
