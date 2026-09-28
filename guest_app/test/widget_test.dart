import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:staynaija/main.dart';

void main() {
  testWidgets('App boots to the login screen when logged out', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: StayNaijaApp()));
    await tester.pump();

    expect(find.text('StayNaija'), findsWidgets);
  });
}
