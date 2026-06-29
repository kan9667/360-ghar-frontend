import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/controllers/location_controller.dart';
import 'package:ghar360/core/controllers/page_state_service.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/explore/presentation/controllers/explore_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/mocks.dart';

class MockPageStateService extends GetxServiceMock implements PageStateService {}

void main() {
  late MockPageStateService mockPageStateService;
  late MockLocationController mockLocationController;
  late Rx<PageStateModel> exploreState;
  late Rx<PageType> currentPageType;
  late Rxn<Position> currentPosition;

  setUpAll(() {
    registerFallbackValue(PageType.explore);
    registerFallbackValue(const UnifiedFilterModel());
    registerFallbackValue(const LocationData(name: '', latitude: 0, longitude: 0));
  });

  setUp(() {
    GetxTestBinding.init();

    mockPageStateService = MockPageStateService();
    mockLocationController = MockLocationController();

    exploreState = PageStateModel.initial(PageType.explore).obs;
    currentPageType = PageType.explore.obs;
    currentPosition = Rxn<Position>();

    // Stub PageStateService reactive fields
    when(() => mockPageStateService.exploreState).thenReturn(exploreState);
    when(() => mockPageStateService.currentPageType).thenReturn(currentPageType);

    // Stub PageStateService methods
    when(
      () => mockPageStateService.loadPageData(
        any(),
        forceRefresh: any(named: 'forceRefresh'),
        backgroundRefresh: any(named: 'backgroundRefresh'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockPageStateService.recordSwipe(
        propertyId: any(named: 'propertyId'),
        isLiked: any(named: 'isLiked'),
      ),
    ).thenAnswer((_) async {});
    when(
      () => mockPageStateService.getCurrentPageState(),
    ).thenReturn(PageStateModel.initial(PageType.explore));
    when(() => mockPageStateService.updatePageFilters(any(), any())).thenReturn(null);
    when(() => mockPageStateService.updatePageSearch(any(), any())).thenReturn(null);
    when(
      () => mockPageStateService.updateLocationForPage(any(), any(), source: any(named: 'source')),
    ).thenAnswer((_) async {});
    when(() => mockPageStateService.loadMoreData(any())).thenAnswer((_) async {});

    // Stub LocationController reactive fields
    when(() => mockLocationController.currentPosition).thenReturn(currentPosition);
    when(() => mockLocationController.hasLocation).thenReturn(false);

    // Stub LocationController methods
    when(
      () => mockLocationController.getCurrentLocation(forceRefresh: any(named: 'forceRefresh')),
    ).thenAnswer((_) async {});
    when(() => mockLocationController.getIpLocation()).thenAnswer((_) async => null);
    when(() => mockLocationController.getInitialLocation()).thenAnswer(
      (_) async => const LocationData(name: 'Test', latitude: 28.6139, longitude: 77.2090),
    );

    GetxTestBinding.bind()
      ..register<PageStateService>(mockPageStateService)
      ..register<LocationController>(mockLocationController);
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  ExploreController createController() {
    final c = ExploreController();
    c.onInit();
    return c;
  }

  List<PropertyModel> seedProperties(int count) {
    return List.generate(count, (i) => testPropertyModel(id: 200 + i));
  }

  group('ExploreController', () {
    test('initial state is ExploreState.initial with empty properties', () {
      final controller = createController();

      expect(controller.state.value, ExploreState.initial);
      expect(controller.properties, isEmpty);
      expect(controller.selectedProperty.value, isNull);
      expect(controller.isMapReady.value, isFalse);
    });

    test('activatePage syncs properties from page state when data present', () {
      final props = seedProperties(3);
      exploreState.value = PageStateModel(
        pageType: PageType.explore,
        filters: const UnifiedFilterModel(),
        properties: props,
        selectedLocation: const LocationData(name: 'Test', latitude: 28.61, longitude: 77.21),
        lastFetched: DateTime.now(),
      );

      final controller = createController();
      controller.activatePage();

      expect(controller.properties.length, 3);
      expect(controller.state.value, ExploreState.loaded);
    });

    test('toggleLike sets optimistic override for unliked property', () async {
      final props = seedProperties(3);
      exploreState.value = PageStateModel(
        pageType: PageType.explore,
        filters: const UnifiedFilterModel(),
        properties: props,
        selectedLocation: const LocationData(name: 'Test', latitude: 28.61, longitude: 77.21),
        lastFetched: DateTime.now(),
      );

      final controller = createController();
      controller.activatePage();

      final property = props[0];
      expect(controller.isPropertyLiked(property), isFalse);

      await controller.toggleLike(property);

      expect(controller.likedOverrides[property.id], isTrue);
      expect(controller.isPropertyLiked(property), isTrue);
    });

    test('toggleLike reverts override on failure', () async {
      final props = seedProperties(3);
      exploreState.value = PageStateModel(
        pageType: PageType.explore,
        filters: const UnifiedFilterModel(),
        properties: props,
        selectedLocation: const LocationData(name: 'Test', latitude: 28.61, longitude: 77.21),
        lastFetched: DateTime.now(),
      );

      when(
        () => mockPageStateService.recordSwipe(
          propertyId: any(named: 'propertyId'),
          isLiked: any(named: 'isLiked'),
        ),
      ).thenThrow(ServerException('network error'));

      final controller = createController();
      controller.activatePage();

      final property = props[0];
      await controller.toggleLike(property);

      // Should revert to original (not liked)
      expect(controller.likedOverrides[property.id], isFalse);
    });

    test('selectProperty sets selected property and auto-expands list', () {
      final controller = createController();
      controller.isListCollapsed.value = true;

      final prop = testPropertyModel(id: 300);
      controller.selectProperty(prop);

      expect(controller.selectedProperty.value?.id, 300);
      expect(controller.isListCollapsed.value, isFalse);
    });

    test('clearSelection clears the selected property', () {
      final controller = createController();
      final prop = testPropertyModel(id: 301);
      controller.selectedProperty.value = prop;

      controller.clearSelection();

      expect(controller.selectedProperty.value, isNull);
    });

    test('retryLoading clears error and sets loading state', () {
      final controller = createController();
      controller.error.value = ServerException('test error');
      controller.state.value = ExploreState.error;

      controller.retryLoading();

      expect(controller.error.value, isNull);
      expect(controller.state.value, ExploreState.loading);
      verify(
        () => mockPageStateService.loadPageData(PageType.explore, forceRefresh: true),
      ).called(1);
    });

    test('helper getters reflect state correctly', () {
      final controller = createController();

      expect(controller.isLoading, isFalse);
      expect(controller.isEmpty, isFalse);
      expect(controller.hasError, isFalse);
      expect(controller.isLoaded, isFalse);
      expect(controller.hasProperties, isFalse);
      expect(controller.hasSelection, isFalse);

      controller.state.value = ExploreState.loaded;
      expect(controller.isLoaded, isTrue);

      controller.state.value = ExploreState.empty;
      expect(controller.isEmpty, isTrue);
    });
  });
}
