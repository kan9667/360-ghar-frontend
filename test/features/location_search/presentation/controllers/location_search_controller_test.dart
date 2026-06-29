// test/features/location_search/presentation/controllers/location_search_controller_test.dart
//
// Unit tests for [LocationSearchController]. Covers:
// - Initial state
// - onSearchChanged updates searchQuery
// - selectPlace success and error flows
// - useCurrentLocation success and error flows
// - concurrent guard (isLoading prevents re-entry)
//
// NOTE: selectPlace and useCurrentLocation call Get.back() internally, which
// requires a navigator. We register a GlobalKey<NavigatorState> via Get.key
// in setUp to satisfy this requirement in the unit test environment.

import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/controllers/location_controller.dart';
import 'package:ghar360/core/controllers/page_state_service.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/services/google_places_service.dart';
import 'package:ghar360/features/location_search/presentation/controllers/location_search_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/mocks.dart';

void main() {
  late MockLocationController mockLocationController;
  late MockPageStateService mockPageStateService;

  setUp(() {
    GetxTestBinding.init();
    mockLocationController = MockLocationController();
    mockPageStateService = MockPageStateService();

    // Register fallback values for mocktail verification
    registerFallbackValue(const LocationData(name: '', latitude: 0, longitude: 0));

    GetxTestBinding.bind()
      ..register<LocationController>(mockLocationController)
      ..register<PageStateService>(mockPageStateService);
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  LocationSearchController createController() {
    final c = LocationSearchController();
    c.onInit();
    return c;
  }

  /// Helper to build a [PlaceSuggestion] for tests.
  PlaceSuggestion testSuggestion({
    String placeId = 'place-123',
    String mainText = 'Connaught Place',
    String secondaryText = 'New Delhi, Delhi',
  }) {
    return PlaceSuggestion(
      placeId: placeId,
      description: '$mainText, $secondaryText',
      mainText: mainText,
      secondaryText: secondaryText,
    );
  }

  group('LocationSearchController', () {
    // ── Initial state ────────────────────────────────────────────────────

    test('initial state has empty search, not loading, no error', () {
      final controller = createController();

      expect(controller.searchQuery.value, isEmpty);
      expect(controller.isLoading.value, isFalse);
      expect(controller.searchError.value, isEmpty);
      expect(controller.searchController.text, isEmpty);
    });

    // ── onSearchChanged ──────────────────────────────────────────────────

    test('onSearchChanged updates searchQuery', () {
      final controller = createController();

      controller.onSearchChanged('Mumbai');

      expect(controller.searchQuery.value, 'Mumbai');
    });

    // ── selectPlace success ──────────────────────────────────────────────

    test('selectPlace success updates location via pageStateService', () async {
      final controller = createController();
      final suggestion = testSuggestion();
      final locationData = const LocationData(
        name: 'Connaught Place',
        latitude: 28.6315,
        longitude: 77.2167,
      );

      when(
        () => mockLocationController.getPlaceDetails('place-123', preferredName: 'Connaught Place'),
      ).thenAnswer((_) async => locationData);
      when(
        () => mockPageStateService.updateLocation(locationData, source: 'search'),
      ).thenAnswer((_) async {});

      await controller.selectPlace(suggestion);

      expect(controller.isLoading.value, isFalse);
      verify(
        () => mockLocationController.getPlaceDetails('place-123', preferredName: 'Connaught Place'),
      ).called(1);
      verify(() => mockPageStateService.updateLocation(locationData, source: 'search')).called(1);
    });

    // ── selectPlace error (null location data) ───────────────────────────

    test('selectPlace with null location data does not update location', () async {
      final controller = createController();
      final suggestion = testSuggestion();

      when(
        () => mockLocationController.getPlaceDetails('place-123', preferredName: 'Connaught Place'),
      ).thenAnswer((_) async => null);

      await controller.selectPlace(suggestion);

      expect(controller.isLoading.value, isFalse);
      verifyNever(() => mockPageStateService.updateLocation(any(), source: any(named: 'source')));
    });

    // ── selectPlace exception ────────────────────────────────────────────

    test('selectPlace exception resets isLoading and does not crash', () async {
      final controller = createController();
      final suggestion = testSuggestion();

      when(
        () => mockLocationController.getPlaceDetails('place-123', preferredName: 'Connaught Place'),
      ).thenThrow(Exception('network error'));

      await controller.selectPlace(suggestion);

      expect(controller.isLoading.value, isFalse);
    });

    // ── useCurrentLocation success ───────────────────────────────────────

    test('useCurrentLocation success fetches address and updates location', () async {
      final controller = createController();

      when(() => mockLocationController.hasLocation).thenReturn(true);
      when(() => mockLocationController.currentLatitude).thenReturn(28.6139);
      when(() => mockLocationController.currentLongitude).thenReturn(77.2090);
      when(
        () => mockLocationController.getAddressFromCoordinates(28.6139, 77.2090),
      ).thenAnswer((_) async => 'New Delhi, Delhi');
      when(
        () => mockPageStateService.updateLocation(any(), source: 'search'),
      ).thenAnswer((_) async {});

      await controller.useCurrentLocation();

      expect(controller.isLoading.value, isFalse);
      verify(() => mockLocationController.getAddressFromCoordinates(28.6139, 77.2090)).called(1);
      verify(() => mockPageStateService.updateLocation(any(), source: 'search')).called(1);
    });

    // ── useCurrentLocation error (no location available) ─────────────────

    test('useCurrentLocation with no location fetches GPS first', () async {
      final controller = createController();

      when(() => mockLocationController.hasLocation).thenReturn(false);
      when(
        () => mockLocationController.getCurrentLocation(forceRefresh: true),
      ).thenAnswer((_) async {});

      await controller.useCurrentLocation();

      expect(controller.isLoading.value, isFalse);
      verify(() => mockLocationController.getCurrentLocation(forceRefresh: true)).called(1);
      verifyNever(() => mockPageStateService.updateLocation(any(), source: any(named: 'source')));
    });

    // ── Concurrent guard ─────────────────────────────────────────────────

    test('selectPlace is guarded by isLoading (skips when already loading)', () async {
      final controller = createController();
      controller.isLoading.value = true;

      final suggestion = testSuggestion();
      await controller.selectPlace(suggestion);

      // Should not call getPlaceDetails because isLoading was true
      verifyNever(
        () => mockLocationController.getPlaceDetails(
          any(),
          preferredName: any(named: 'preferredName'),
        ),
      );
    });

    test('useCurrentLocation is guarded by isLoading (skips when already loading)', () async {
      final controller = createController();
      controller.isLoading.value = true;

      await controller.useCurrentLocation();

      verifyNever(
        () => mockLocationController.getCurrentLocation(forceRefresh: any(named: 'forceRefresh')),
      );
    });
  });
}
