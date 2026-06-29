import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/core/utils/formatters.dart';

void main() {
  group('Formatters.normalizeIndianPhone', () {
    test('returns number with +91 prefix unchanged', () {
      expect(Formatters.normalizeIndianPhone('+919876543210'), '+919876543210');
    });

    test('adds +91 prefix to 10-digit number', () {
      expect(Formatters.normalizeIndianPhone('9876543210'), '+919876543210');
    });

    test('adds +91 to 10-digit number starting with 0', () {
      expect(Formatters.normalizeIndianPhone('0123456789'), '+910123456789');
    });

    test('returns empty string unchanged', () {
      expect(Formatters.normalizeIndianPhone(''), '');
    });

    test('returns number shorter than 10 digits unchanged', () {
      expect(Formatters.normalizeIndianPhone('12345'), '12345');
    });

    test('returns number longer than 10 digits (no +91) unchanged', () {
      expect(Formatters.normalizeIndianPhone('12345678901'), '12345678901');
    });

    test('returns number with different country code unchanged', () {
      expect(Formatters.normalizeIndianPhone('+14155552671'), '+14155552671');
    });

    test('returns exactly 10-digit number with leading zeros with +91 prefix', () {
      expect(Formatters.normalizeIndianPhone('0000000000'), '+910000000000');
    });
  });
}
