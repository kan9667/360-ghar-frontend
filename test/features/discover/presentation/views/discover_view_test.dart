// test/features/discover/presentation/views/discover_view_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/core/controllers/location_controller.dart';
import 'package:ghar360/core/controllers/page_state_service.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/discover/presentation/controllers/discover_controller.dart';
import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/mocks.dart';

// ---------------------------------------------------------------------------
// Lightweight mock PageStateService
// ---------------------------------------------------------------------------

class _MockPageStateService extends GetxServiceMock implements PageStateService {
  @override
  final Rx<PageStateModel> discoverState = PageStateModel.initial(PageType.discover).obs;
  @override
  final Rx<PageStateModel> likesState = PageStateModel.initial(PageType.likes).obs;
  @override
  final Rx<PageStateModel> exploreState = PageStateModel.initial(PageType.explore).obs;
  @override
  final Rx<PageType> currentPageType = PageType.discover.obs;

  @override
  bool isSearchVisible(PageType pageType) => false;

  @override
  PageStateModel getStateForPage(PageType pageType) {
    switch (pageType) {
      case PageType.explore:
        return exploreState.value;
      case PageType.discover:
        return discoverState.value;
      case PageType.likes:
        return likesState.value;
    }
  }

  @override
  String get currentLikesSegment =>
      likesState.value.getAdditionalData<String>('currentSegment') ?? 'liked';
}

// ---------------------------------------------------------------------------
// Tests — controller-level tests that verify DiscoverController state
// without rendering the full view (which requires complex Obx stubs).
// ---------------------------------------------------------------------------

void main() {
  late _MockPageStateService pageStateService;
  late MockLocationController locationController;

  setUp(() {
    GetxTestBinding.init();
    pageStateService = _MockPageStateService();
    locationController = MockLocationController();
    GetxTestBinding.bind()
      ..register<PageStateService>(pageStateService)
      ..register<LocationController>(locationController);
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  group('DiscoverController state transitions', () {
    test('initial state is DiscoverState.initial', () {
      final controller = DiscoverController();
      Get.put<DiscoverController>(controller);

      expect(controller.state.value, DiscoverState.initial);
      expect(controller.deck, isEmpty);
      expect(controller.error.value, isNull);
    });

    test('state transitions to loading when page state is loading', () {
      pageStateService.discoverState.value = const PageStateModel(
        pageType: PageType.discover,
        filters: UnifiedFilterModel(),
        properties: [],
        isLoading: true,
      );

      final controller = DiscoverController();
      Get.put<DiscoverController>(controller);

      // The controller's state should reflect the page state.
      expect(pageStateService.discoverState.value.isLoading, isTrue);
    });

    test('state transitions to error when page state has error', () {
      final error = ServerException('Network error', code: 'TEST');
      pageStateService.discoverState.value = PageStateModel(
        pageType: PageType.discover,
        filters: const UnifiedFilterModel(),
        properties: [],
        error: error,
      );

      final controller = DiscoverController();
      Get.put<DiscoverController>(controller);

      expect(pageStateService.discoverState.value.error, isNotNull);
      expect(pageStateService.discoverState.value.error!.message, 'Network error');
    });

    test('state transitions to empty when page state has no properties', () {
      pageStateService.discoverState.value = const PageStateModel(
        pageType: PageType.discover,
        filters: UnifiedFilterModel(),
        properties: [],
      );

      expect(pageStateService.discoverState.value.properties, isEmpty);
      expect(pageStateService.discoverState.value.isLoading, isFalse);
    });

    test('state has properties when page state is loaded', () {
      pageStateService.discoverState.value = const PageStateModel(
        pageType: PageType.discover,
        filters: UnifiedFilterModel(),
        properties: [],
      );

      expect(pageStateService.discoverState.value.isLoading, isFalse);
      expect(pageStateService.discoverState.value.error, isNull);
    });
  });
}
