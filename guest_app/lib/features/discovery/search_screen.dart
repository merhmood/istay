import 'package:flutter/material.dart';
import 'package:staynaija_shared/core/theme/bold_icons.dart';

import 'package:staynaija_shared/core/theme/app_theme.dart';
import 'package:staynaija/features/discovery/services/recent_searches_service.dart';

/// Full-screen search entry: just the input, the guest's previous searches and
/// nearby places. Pops with the chosen city name (or null if dismissed).
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.nearbyPlaceNames = const []});

  final List<String> nearbyPlaceNames;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _controller = TextEditingController();
  final _recentSearchesService = RecentSearchesService();
  List<String> _recentSearches = [];

  @override
  void initState() {
    super.initState();
    _loadRecentSearches();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadRecentSearches() async {
    final recent = await _recentSearchesService.get();
    if (mounted) setState(() => _recentSearches = recent);
  }

  void _submit(String city) {
    final trimmed = city.trim();
    if (trimmed.isEmpty) return;
    Navigator.of(context).pop(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: Icon(LucideIcons.chevronLeft),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: TextField(
          controller: _controller,
          autofocus: true,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: 'Search city, state, or stay type',
            prefixIcon: Icon(LucideIcons.search, size: 20),
            filled: true,
            fillColor: AppColors.background,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.symmetric(vertical: 8),
          ),
          onSubmitted: _submit,
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: TextButton(onPressed: () => _submit(_controller.text), child: const Text('Search')),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          if (_recentSearches.isNotEmpty) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('Recent searches', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                TextButton(
                  onPressed: () async {
                    await _recentSearchesService.clear();
                    _loadRecentSearches();
                  },
                  child: const Text('Clear'),
                ),
              ],
            ),
            for (final city in _recentSearches)
              _SearchRow(
                icon: LucideIcons.clock,
                label: city,
                onTap: () => _submit(city),
                onRemove: () async {
                  await _recentSearchesService.remove(city);
                  _loadRecentSearches();
                },
              ),
            const SizedBox(height: 20),
          ],
          if (widget.nearbyPlaceNames.isNotEmpty) ...[
            const Text('Near you', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            for (final place in widget.nearbyPlaceNames)
              _SearchRow(icon: LucideIcons.mapPin, label: place, onTap: () => _submit(place)),
          ],
          if (_recentSearches.isEmpty && widget.nearbyPlaceNames.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 40),
              child: Center(
                child: Text('Type a city, state, or stay type to find stays', style: TextStyle(color: AppColors.textSecondary)),
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchRow extends StatelessWidget {
  const _SearchRow({required this.icon, required this.label, required this.onTap, this.onRemove});

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, size: 20, color: AppColors.textSecondary),
      title: Text(label),
      trailing: onRemove == null
          ? null
          : IconButton(
              icon: Icon(LucideIcons.x, size: 16, color: AppColors.textSecondary),
              onPressed: onRemove,
            ),
      onTap: onTap,
    );
  }
}
