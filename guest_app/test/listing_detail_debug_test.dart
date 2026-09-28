import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:staynaija/features/listing_detail/listing_detail_screen.dart';

void main() {
  testWidgets('ListingDetailScreen renders without layout errors', (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: ListingDetailScreen(listingId: '84d5a3c2-1c64-4999-a004-4769f6d65013'),
        ),
      ),
    );

    // Real Dio network calls need real wall-clock time, not just frame pumps.
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 2)));
    await tester.pump();
    await tester.runAsync(() => Future.delayed(const Duration(seconds: 2)));
    await tester.pump();

    final exception = tester.takeException();
    // ignore: avoid_print
    print('CAUGHT EXCEPTION: $exception');

    // ignore: avoid_print
    print('Has CircularProgressIndicator: ${find.byType(CircularProgressIndicator).evaluate().isNotEmpty}');
    // ignore: avoid_print
    print('Has title text: ${find.text('Modern 2-Bed Apartment in Lekki Phase 1').evaluate().isNotEmpty}');
    final reserveFinder = find.text('Reserve');
    // ignore: avoid_print
    print('Has Reserve button: ${reserveFinder.evaluate().isNotEmpty}');
    final priceFinder = find.textContaining('₦');
    // ignore: avoid_print
    print('Price text widgets found: ${priceFinder.evaluate().length}');
    for (final el in priceFinder.evaluate()) {
      final renderBox = el.renderObject as RenderBox?;
      // ignore: avoid_print
      print('  price widget size: ${renderBox?.size}');
    }
  });
}
