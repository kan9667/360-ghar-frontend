import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/features/properties/data/properties_repository.dart';
import 'package:ghar360/features/property_details/presentation/controllers/property_details_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/mocks.dart';

void main() {
  late MockPropertiesRepository mockPropertiesRepository;

  setUp(() {
    GetxTestBinding.init();
    mockPropertiesRepository = MockPropertiesRepository();
    GetxTestBinding.bind().register<PropertiesRepository>(mockPropertiesRepository);
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  /// Set Get.arguments by manipulating the routing state directly.
  /// In GetX 4.x, `Get.arguments` delegates to `Get.routing.args`.
  void setArguments(dynamic args) {
    // Routing is mutable — update its args field.
    Get.routing.update((r) => r.args = args);
  }

  /// Helper: set arguments then construct and initialise the controller.
  PropertyDetailsController createControllerWithArgs(dynamic args) {
    setArguments(args);
    final c = PropertyDetailsController();
    c.onInit();
    return c;
  }

  /// Helper: create controller with no arguments set (args = null).
  PropertyDetailsController createController() {
    setArguments(null);
    final c = PropertyDetailsController();
    c.onInit();
    return c;
  }

  group('PropertyDetailsController', () {
    test('resolves property directly from Get.arguments when PropertyModel', () async {
      final prop = testPropertyModel(id: 42);

      final controller = createControllerWithArgs(prop);
      await Future<void>.value();

      expect(controller.property.value, isNotNull);
      expect(controller.property.value!.id, 42);
      expect(controller.isLoading.value, isFalse);
      expect(controller.errorKey.value, isNull);
    });

    test('resolves property from Get.arguments["property"] embedded PropertyModel', () async {
      final prop = testPropertyModel(id: 77);

      final controller = createControllerWithArgs({'property': prop});
      await Future<void>.value();

      expect(controller.property.value, isNotNull);
      expect(controller.property.value!.id, 77);
      expect(controller.isLoading.value, isFalse);
    });

    test('fetches property by string id from Get.arguments', () async {
      when(
        () => mockPropertiesRepository.getPropertyDetail(101),
      ).thenAnswer((_) async => testPropertyModel(id: 101));

      final controller = createControllerWithArgs('101');
      await Future<void>.value();

      expect(controller.property.value, isNotNull);
      expect(controller.property.value!.id, 101);
      expect(controller.isLoading.value, isFalse);
      expect(controller.errorKey.value, isNull);
    });

    test('fetches property by id from Get.arguments map with "id" key', () async {
      when(
        () => mockPropertiesRepository.getPropertyDetail(401),
      ).thenAnswer((_) async => testPropertyModel(id: 401));

      final controller = createControllerWithArgs({'id': '401'});
      await Future<void>.value();

      expect(controller.property.value, isNotNull);
      expect(controller.property.value!.id, 401);
      verify(() => mockPropertiesRepository.getPropertyDetail(401)).called(1);
    });

    test('fetches property by id from Get.arguments map with "property_id" key', () async {
      when(
        () => mockPropertiesRepository.getPropertyDetail(402),
      ).thenAnswer((_) async => testPropertyModel(id: 402));

      final controller = createControllerWithArgs({'property_id': '402'});
      await Future<void>.value();

      expect(controller.property.value, isNotNull);
      expect(controller.property.value!.id, 402);
    });

    test('sets error when Get.arguments is null and no URL parameters', () async {
      final controller = createController();
      await Future<void>.value();

      expect(controller.isLoading.value, isFalse);
      expect(controller.errorKey.value, 'property_not_found');
      expect(controller.property.value, isNull);
    });

    test('sets error for non-numeric string id', () async {
      final controller = createControllerWithArgs({'id': 'abc'});
      await Future<void>.value();

      expect(controller.isLoading.value, isFalse);
      expect(controller.errorKey.value, 'invalid_property_id');
      expect(controller.property.value, isNull);
    });

    test('sets error when repository throws an exception', () async {
      when(
        () => mockPropertiesRepository.getPropertyDetail(500),
      ).thenThrow(Exception('Network timeout'));

      final controller = createControllerWithArgs('500');
      await Future<void>.value();

      expect(controller.isLoading.value, isFalse);
      expect(controller.errorKey.value, 'property_load_failed');
      expect(controller.errorDetail.value, isNotNull);
      expect(controller.property.value, isNull);
    });

    test('retry reloads property after an error', () async {
      when(
        () => mockPropertiesRepository.getPropertyDetail(300),
      ).thenThrow(Exception('Server down'));

      final controller = createControllerWithArgs('300');
      await Future<void>.value();

      // First load fails.
      expect(controller.errorKey.value, 'property_load_failed');

      // Set up success for retry.
      when(
        () => mockPropertiesRepository.getPropertyDetail(300),
      ).thenAnswer((_) async => testPropertyModel(id: 300));

      controller.retry();
      await Future<void>.value();

      expect(controller.property.value, isNotNull);
      expect(controller.property.value!.id, 300);
      expect(controller.isLoading.value, isFalse);
      expect(controller.errorKey.value, isNull);
    });

    test('errorMessage returns mapped message for property_load_failed', () async {
      when(
        () => mockPropertiesRepository.getPropertyDetail(600),
      ).thenThrow(Exception('Internal error'));

      final controller = createControllerWithArgs('600');
      await Future<void>.value();

      expect(controller.errorKey.value, 'property_load_failed');
      expect(controller.errorMessage, isNotNull);
    });

    test('errorMessage returns null when no error is set', () async {
      final controller = createControllerWithArgs(testPropertyModel(id: 1));
      await Future<void>.value();

      expect(controller.errorMessage, isNull);
    });

    test('resolves int argument as direct property id', () async {
      when(
        () => mockPropertiesRepository.getPropertyDetail(250),
      ).thenAnswer((_) async => testPropertyModel(id: 250));

      final controller = createControllerWithArgs(250);
      await Future<void>.value();

      expect(controller.property.value, isNotNull);
      expect(controller.property.value!.id, 250);
      verify(() => mockPropertiesRepository.getPropertyDetail(250)).called(1);
    });
  });
}
