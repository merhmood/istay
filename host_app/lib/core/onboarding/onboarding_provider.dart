import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _hasSeenOnboardingKey = 'host_has_seen_onboarding';

/// Read once in `main()` before `runApp` and passed in as this provider's
/// override, the same way the guest app's recent-searches flag is read
/// eagerly rather than through a FutureProvider - the router's redirect logic
/// needs a synchronous answer on first frame, and a screen flashing onboarding
/// then immediately un-flashing it once a FutureProvider resolves would look
/// like a bug.
Future<bool> loadHasSeenOnboarding() async {
  final prefs = await SharedPreferences.getInstance();
  return prefs.getBool(_hasSeenOnboardingKey) ?? false;
}

Future<void> markOnboardingSeen() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool(_hasSeenOnboardingKey, true);
}

final hasSeenOnboardingProvider = StateProvider<bool>((ref) => false);
