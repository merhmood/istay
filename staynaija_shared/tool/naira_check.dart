import 'package:intl/intl.dart';

void main() {
  final format = NumberFormat.currency(locale: 'en_NG', symbol: '₦', decimalDigits: 0);
  final result = format.format(55000);
  print('RESULT: [$result]');
  print('LENGTH: ${result.length}');
  for (final ch in result.runes) {
    print(String.fromCharCode(ch) + ' -> U+' + ch.toRadixString(16));
  }
}
