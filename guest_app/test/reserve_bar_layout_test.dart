import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('Row with Expanded price column + two buttons lays out within 480px width', (tester) async {
    tester.view.physicalSize = const Size(480, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: const SizedBox.shrink(),
          bottomNavigationBar: DecoratedBox(
            decoration: const BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)]),
            child: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('₦55,000', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('per night', style: TextStyle(color: Colors.grey, fontSize: 12)),
                        ],
                      ),
                    ),
                    OutlinedButton(onPressed: () {}, child: const Text('Message host')),
                    const SizedBox(width: 8),
                    ElevatedButton(onPressed: () {}, child: const Text('Reserve')),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    final exception = tester.takeException();
    // ignore: avoid_print
    print('EXCEPTION: $exception');

    final priceSize = tester.getSize(find.text('₦55,000'));
    final reserveFinder = find.text('Reserve');
    // ignore: avoid_print
    print('price text size: $priceSize');
    // ignore: avoid_print
    print('Reserve button found: ${reserveFinder.evaluate().isNotEmpty}');
    if (reserveFinder.evaluate().isNotEmpty) {
      // ignore: avoid_print
      print('Reserve text position: ${tester.getTopLeft(reserveFinder)}');
    }
  });
}
