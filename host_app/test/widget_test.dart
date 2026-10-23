import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:staynaija_host/main.dart';

void main() {
  testWidgets('Host app boots to the login screen when logged out', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: StayNaijaHostApp()));
    await tester.pump();

    expect(find.text('iStay Host'), findsWidgets);
  });
}
