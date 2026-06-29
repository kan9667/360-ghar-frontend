// test/features/tools/presentation/controllers/emi_calculator_controller_test.dart
//
// Unit tests for [EmiCalculatorController]. Covers:
// - calculate() with valid inputs
// - Validation error for zero/negative principal, rate, tenure
// - toggleTenureUnit flips between years and months
// - clear() resets all state
// - Edge case: very long tenure

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/features/tools/presentation/controllers/emi_calculator_controller.dart';
import '../../../../helpers/getx_test_binding.dart';

void main() {
  setUp(() {
    GetxTestBinding.init();
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  EmiCalculatorController createController() {
    final c = EmiCalculatorController();
    c.onInit();
    return c;
  }

  group('EmiCalculatorController', () {
    // ── Valid inputs ─────────────────────────────────────────────────────

    test('calculate() with valid inputs sets EMI, totalPayment, totalInterest', () {
      final controller = createController();
      controller.principalController.text = '1000000'; // 10L
      controller.rateController.text = '8.5';
      controller.tenureController.text = '20'; // 20 years

      controller.calculate();

      expect(controller.hasCalculated.value, isTrue);
      expect(controller.validationError.value, isEmpty);
      // EMI for 10L @ 8.5% for 20 years ≈ ₹8678.23
      expect(controller.monthlyEmi.value, closeTo(8678.23, 1));
      // Total payment = EMI * 240 months
      expect(controller.totalPayment.value, closeTo(8678.23 * 240, 100));
      // Total interest = total payment - principal
      expect(controller.totalInterest.value, closeTo(controller.totalPayment.value - 1000000, 100));
    });

    // ── Validation errors ────────────────────────────────────────────────

    test('calculate() with zero principal shows validation error', () {
      final controller = createController();
      controller.principalController.text = '0';
      controller.rateController.text = '8.5';
      controller.tenureController.text = '20';

      controller.calculate();

      expect(controller.hasCalculated.value, isFalse);
      expect(controller.validationError.value, isNotEmpty);
    });

    test('calculate() with negative rate shows validation error', () {
      final controller = createController();
      controller.principalController.text = '1000000';
      controller.rateController.text = '-5';
      controller.tenureController.text = '20';

      controller.calculate();

      expect(controller.hasCalculated.value, isFalse);
      expect(controller.validationError.value, isNotEmpty);
    });

    // ── toggleTenureUnit ─────────────────────────────────────────────────

    test('toggleTenureUnit flips between years and months', () {
      final controller = createController();

      expect(controller.tenureInYears.value, isTrue);

      controller.toggleTenureUnit();
      expect(controller.tenureInYears.value, isFalse);

      controller.toggleTenureUnit();
      expect(controller.tenureInYears.value, isTrue);
    });

    test('toggleTenureUnit recalculates EMI when already calculated', () {
      final controller = createController();
      controller.principalController.text = '1000000';
      controller.rateController.text = '8.5';
      controller.tenureController.text = '20'; // 20 years
      controller.calculate();

      final emiYears = controller.monthlyEmi.value;

      // Switch to months: 20 months is much shorter than 20 years
      controller.toggleTenureUnit();
      expect(controller.tenureInYears.value, isFalse);
      expect(controller.monthlyEmi.value, greaterThan(emiYears));
    });

    // ── clear() resets all state ─────────────────────────────────────────

    test('clear() resets all state to defaults', () {
      final controller = createController();
      controller.principalController.text = '1000000';
      controller.rateController.text = '8.5';
      controller.tenureController.text = '20';
      controller.calculate();

      controller.clear();

      expect(controller.principalController.text, isEmpty);
      expect(controller.rateController.text, isEmpty);
      expect(controller.tenureController.text, isEmpty);
      expect(controller.tenureInYears.value, isTrue);
      expect(controller.hasCalculated.value, isFalse);
      expect(controller.validationError.value, isEmpty);
      expect(controller.monthlyEmi.value, 0);
      expect(controller.totalInterest.value, 0);
      expect(controller.totalPayment.value, 0);
    });
  });
}
