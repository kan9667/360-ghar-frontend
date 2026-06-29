// test/features/tools/presentation/controllers/carpet_area_controller_test.dart
//
// Unit tests for [CarpetAreaController]. Covers:
// - calculate() with default 25% loading
// - calculate() with different loading percentages
// - Zero area triggers validation error
// - onLoadingChanged recalculates when already calculated
// - clear() resets all state

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/features/tools/presentation/controllers/carpet_area_controller.dart';
import '../../../../helpers/getx_test_binding.dart';

void main() {
  setUp(() {
    GetxTestBinding.init();
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  CarpetAreaController createController() {
    final c = CarpetAreaController();
    c.onInit();
    return c;
  }

  group('CarpetAreaController', () {
    // ── Default loading (25%) ────────────────────────────────────────────

    test('calculate() with default 25% loading computes correct areas', () {
      final controller = createController();
      controller.superBuiltUpController.text = '1500'; // 1500 sqft super built-up

      controller.calculate();

      expect(controller.hasCalculated.value, isTrue);
      expect(controller.validationError.value, isEmpty);

      // Loading 25%: builtUp = 1500 / 1.25 = 1200
      expect(controller.builtUpArea.value, closeTo(1200, 0.1));
      // Carpet = 1200 * (1 - 0.12) = 1200 * 0.88 = 1056
      expect(controller.carpetArea.value, closeTo(1056, 0.1));
      // Usable percentage = 1056 / 1500 * 100 = 70.4%
      expect(controller.usablePercentage.value, closeTo(70.4, 0.1));
    });

    // ── Different loading percentages ────────────────────────────────────

    test('calculate() with 40% loading yields smaller carpet area', () {
      final controller = createController();
      controller.superBuiltUpController.text = '1000';
      controller.loadingPercentage.value = 40;

      controller.calculate();

      // builtUp = 1000 / 1.4 ≈ 714.29
      expect(controller.builtUpArea.value, closeTo(714.29, 0.1));
      // carpet = 714.29 * 0.88 ≈ 628.57
      expect(controller.carpetArea.value, closeTo(628.57, 0.1));
    });

    test('calculate() with 0% loading yields maximum carpet area', () {
      final controller = createController();
      controller.superBuiltUpController.text = '1000';
      controller.loadingPercentage.value = 0;

      controller.calculate();

      // builtUp = 1000 / 1 = 1000
      expect(controller.builtUpArea.value, closeTo(1000, 0.1));
      // carpet = 1000 * 0.88 = 880
      expect(controller.carpetArea.value, closeTo(880, 0.1));
    });

    // ── Zero area ────────────────────────────────────────────────────────

    test('calculate() with zero area shows validation error', () {
      final controller = createController();
      controller.superBuiltUpController.text = '0';

      controller.calculate();

      expect(controller.hasCalculated.value, isFalse);
      expect(controller.validationError.value, isNotEmpty);
    });

    // ── onLoadingChanged recalculates ────────────────────────────────────

    test('onLoadingChanged recalculates when hasCalculated is true', () {
      final controller = createController();
      controller.superBuiltUpController.text = '1000';
      controller.calculate();

      final carpetBefore = controller.carpetArea.value;

      // Change loading to 50%
      controller.onLoadingChanged(50);

      expect(controller.loadingPercentage.value, 50);
      // Higher loading → smaller carpet
      expect(controller.carpetArea.value, lessThan(carpetBefore));
    });

    // ── clear() resets all state ─────────────────────────────────────────

    test('clear() resets all state to defaults', () {
      final controller = createController();
      controller.superBuiltUpController.text = '1500';
      controller.loadingPercentage.value = 35;
      controller.calculate();

      controller.clear();

      expect(controller.superBuiltUpController.text, isEmpty);
      expect(controller.loadingPercentage.value, 25.0);
      expect(controller.hasCalculated.value, isFalse);
      expect(controller.validationError.value, isEmpty);
      expect(controller.carpetArea.value, 0);
      expect(controller.builtUpArea.value, 0);
      expect(controller.usablePercentage.value, 0);
    });
  });
}
