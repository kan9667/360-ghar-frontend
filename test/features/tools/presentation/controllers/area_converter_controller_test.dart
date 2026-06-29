// test/features/tools/presentation/controllers/area_converter_controller_test.dart
//
// Unit tests for [AreaConverterController]. Covers:
// - Initial state (selectedUnit, empty conversions)
// - convert() with sqFt input
// - convert() with all unit types
// - Zero and negative input clearing conversions
// - clear() resets everything

import 'package:flutter_test/flutter_test.dart';

import 'package:ghar360/features/tools/presentation/controllers/area_converter_controller.dart';
import '../../../../helpers/getx_test_binding.dart';

void main() {
  setUp(() {
    GetxTestBinding.init();
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  AreaConverterController createController() {
    final c = AreaConverterController();
    c.onInit();
    return c;
  }

  group('AreaConverterController', () {
    // ── Initial state ────────────────────────────────────────────────────

    test('initial state has sqFt selected and empty conversions', () {
      final controller = createController();

      expect(controller.selectedUnit.value, AreaUnit.sqFt);
      expect(controller.conversions, isEmpty);
      expect(controller.inputController.text, isEmpty);
    });

    // ── convert() with sqFt input ────────────────────────────────────────

    test('convert() with sqFt input populates all unit conversions', () {
      final controller = createController();
      controller.inputController.text = '1000';
      controller.convert();

      // 1000 sqft → 1000 sqft (identity)
      expect(controller.conversions[AreaUnit.sqFt], closeTo(1000, 0.1));
      // 1000 sqft / 10.7639 ≈ 92.9 sqm
      expect(controller.conversions[AreaUnit.sqM], closeTo(92.9, 0.1));
      // 1000 sqft / 9 ≈ 111.11 sq yards
      expect(controller.conversions[AreaUnit.sqYards], closeTo(111.11, 0.1));
      // 1000 sqft / 9 ≈ 111.11 gaj
      expect(controller.conversions[AreaUnit.gaj], closeTo(111.11, 0.1));
      // 1000 sqft / 43560 ≈ 0.02296 acres
      expect(controller.conversions[AreaUnit.acres], closeTo(0.02296, 0.0001));
      // 1000 sqft / 27000 ≈ 0.03704 bigha
      expect(controller.conversions[AreaUnit.bigha], closeTo(0.03704, 0.0001));
    });

    // ── convert() with acres input ───────────────────────────────────────

    test('convert() with acres input converts correctly to all units', () {
      final controller = createController();
      controller.selectedUnit.value = AreaUnit.acres;
      controller.inputController.text = '1';
      controller.convert();

      // 1 acre = 43560 sqft
      expect(controller.conversions[AreaUnit.sqFt], closeTo(43560, 0.1));
      // 1 acre = 43560 / 10.7639 ≈ 4046.86 sqm
      expect(controller.conversions[AreaUnit.sqM], closeTo(4046.86, 0.1));
      // 1 acre = 43560 / 9 ≈ 4840 sq yards
      expect(controller.conversions[AreaUnit.sqYards], closeTo(4840, 0.1));
      // 1 acre = 1 acre
      expect(controller.conversions[AreaUnit.acres], closeTo(1, 0.0001));
    });

    // ── Zero input clears conversions ────────────────────────────────────

    test('convert() with zero input clears conversions', () {
      final controller = createController();
      controller.inputController.text = '0';
      controller.convert();

      expect(controller.conversions, isEmpty);
    });

    // ── Negative input clears conversions ────────────────────────────────

    test('convert() with negative input clears conversions', () {
      final controller = createController();
      controller.inputController.text = '-50';
      controller.convert();

      expect(controller.conversions, isEmpty);
    });

    // ── onUnitChanged triggers re-conversion ─────────────────────────────

    test('onUnitChanged updates selectedUnit and recalculates', () {
      final controller = createController();
      controller.inputController.text = '100';
      controller.convert();

      final sqYardsBefore = controller.conversions[AreaUnit.sqYards];
      controller.onUnitChanged(AreaUnit.sqYards);

      expect(controller.selectedUnit.value, AreaUnit.sqYards);
      // With 100 sq yards as input: 100 * 9 = 900 sqft
      expect(controller.conversions[AreaUnit.sqFt], closeTo(900, 0.1));
      // Original 100 sqFt input gives different result than 100 sq yards
      expect(controller.conversions[AreaUnit.sqYards], isNot(closeTo(sqYardsBefore!, 0.1)));
    });

    // ── clear() resets everything ────────────────────────────────────────

    test('clear() resets all state', () {
      final controller = createController();
      controller.inputController.text = '500';
      controller.selectedUnit.value = AreaUnit.sqM;
      controller.convert();

      expect(controller.conversions, isNotEmpty);

      controller.clear();

      expect(controller.inputController.text, isEmpty);
      expect(controller.conversions, isEmpty);
    });
  });
}
