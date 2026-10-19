import 'package:flutter_test/flutter_test.dart';
import 'package:waya_fx_bot/core/utils.dart';

void main() {
  test('money formatting', () {
    expect(money(1234.5), '\$1,234.50');
    expect(money(-3, sign: true), '-\$3.00');
    expect(money(2, sign: true), '+\$2.00');
  });
}
