import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/controllers/page_state_service.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/discover/presentation/controllers/discover_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/mocks.dart';

class MockPageStateService extends GetxServiceMock implements PageStateService {}

void main() {
  late MockPageStateService mockPageStateService;
  late Rx<PageStateModel> discoverState;
  late Rx<PageType> currentPageType;

  setUpAll(() {
    registerFallbackValue(PageType.discover);
    registerFallbackValue(const UnifiedFilterModel());
    registerFallbackValue(testPropertyModel());
  });

  setUp(() {
    GetxTestBinding.init();

    mockPageStateService = MockPageStateService();
    discoverState = PageStateModel.initial(PageType.discover).obs;
    currentPageType = PageType.discover.obs;

    // Stub reactive fields so controller workers can register listeners
    when(() => mockPageStateService.discoverState).thenReturn(discoverState);
    when(() => mockPageStateService.currentPageType).thenReturn(currentPageType);

    // Stub methods that the controller or its helpers may call
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
    ).thenReturn(PageStateModel.initial(PageType.discover));
    when(() => mockPageStateService.updatePageFilters(any(), any())).thenReturn(null);
    when(() => mockPageStateService.useCurrentLocation()).thenAnswer((_) async {});
    when(() => mockPageStateService.useCurrentLocationForPage(any())).thenAnswer((_) async {});
    when(() => mockPageStateService.loadMoreData(any())).thenAnswer((_) async {});
    when(
      () => mockPageStateService.undoSwipe(
        propertyId: any(named: 'propertyId'),
        originalIsLiked: any(named: 'originalIsLiked'),
      ),
    ).thenAnswer((_) async {});
    when(() => mockPageStateService.reinsertPropertyToDiscover(any())).thenReturn(null);

    GetxTestBinding.bind().register<PageStateService>(mockPageStateService);
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  DiscoverController createController() {
    final c = DiscoverController();
    c.onInit();
    return c;
  }

  List<PropertyModel> seedProperties(int count) {
    return List.generate(count, (i) => testPropertyModel(id: 100 + i));
  }

  void seedDeck(List<PropertyModel> properties) {
    discoverState.value = PageStateModel(
      pageType: PageType.discover,
      filters: const UnifiedFilterModel(),
      properties: properties,
    );
  }

  group('DiscoverController', () {
    test('initial state is DiscoverState.initial with empty deck and zero stats', () {
      final controller = createController();

      expect(controller.state.value, DiscoverState.initial);
      expect(controller.deck, isEmpty);
      expect(controller.totalSwipesInSession.value, 0);
      expect(controller.likesInSession.value, 0);
      expect(controller.passesInSession.value, 0);
      expect(controller.currentIndex.value, 0);
    });

    test('nextProperties returns empty list when deck is empty', () {
      final controller = createController();
      expect(controller.nextProperties, isEmpty);
    });

    test('nextProperties returns up to 3 properties after current index', () {
      final props = seedProperties(5);
      seedDeck(props);

      final controller = createController();
      final next = controller.nextProperties;

      expect(next.length, 3);
      expect(next[0].id, 101);
      expect(next[1].id, 102);
      expect(next[2].id, 103);
    });

    test('nextProperties returns remaining items when fewer than 3 left', () {
      final props = seedProperties(3);
      seedDeck(props);

      final controller = createController();
      final next = controller.nextProperties;

      // currentIndex is 0, so nextProperties skips the first, returns 2
      expect(next.length, 2);
      expect(next[0].id, 101);
      expect(next[1].id, 102);
    });

    test('progressPercentage returns 0 for empty deck', () {
      final controller = createController();
      expect(controller.progressPercentage, 0.0);
    });

    test('progressPercentage returns correct ratio when deck has items', () {
      final props = seedProperties(4);
      seedDeck(props);

      final controller = createController();
      controller.currentIndex.value = 1;

      expect(controller.progressPercentage, 0.25);
    });

    test('swipeRight increments like stats', () async {
      final props = seedProperties(5);
      seedDeck(props);

      final controller = createController();
      await controller.swipeRight(props[0]);

      expect(controller.totalSwipesInSession.value, 1);
      expect(controller.likesInSession.value, 1);
      expect(controller.passesInSession.value, 0);
    });

    test('swipeLeft increments pass stats', () async {
      final props = seedProperties(5);
      seedDeck(props);

      final controller = createController();
      await controller.swipeLeft(props[0]);

      expect(controller.totalSwipesInSession.value, 1);
      expect(controller.likesInSession.value, 0);
      expect(controller.passesInSession.value, 1);
    });

    test('retryLoading clears error and calls loadPageData', () {
      final controller = createController();
      controller.error.value = ServerException('test error');
      controller.state.value = DiscoverState.error;

      controller.retryLoading();

      expect(controller.error.value, isNull);
      verify(
        () => mockPageStateService.loadPageData(PageType.discover, forceRefresh: true),
      ).called(1);
    });
  });
}
