import 'package:shared_preferences/shared_preferences.dart';

/// Stores the guest's recent city searches on-device (per-device, not synced -
/// same approach most apps take for search history).
class RecentSearchesService {
  static const _key = 'recent_city_searches';
  static const _maxEntries = 5;

  Future<List<String>> get() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_key) ?? [];
  }

  Future<void> record(String city) async {
    final trimmed = city.trim();
    if (trimmed.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_key) ?? [];
    final updated = [trimmed, ...current.where((c) => c.toLowerCase() != trimmed.toLowerCase())];
    await prefs.setStringList(_key, updated.take(_maxEntries).toList());
  }

  Future<void> remove(String city) async {
    final prefs = await SharedPreferences.getInstance();
    final current = prefs.getStringList(_key) ?? [];
    await prefs.setStringList(_key, current.where((c) => c.toLowerCase() != city.toLowerCase()).toList());
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key);
  }
}
