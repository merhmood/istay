import 'package:flutter_test/flutter_test.dart';

import 'package:staynaija_shared/staynaija_shared.dart';

void main() {
  test('booking status maps to and from the API string representation', () {
    for (final status in BookingStatus.values) {
      expect(BookingStatus.fromApi(status.apiValue), status);
    }
  });

  test('formatNaira renders a Naira-formatted amount', () {
    expect(formatNaira(55000), contains('55,000'));
  });
}
