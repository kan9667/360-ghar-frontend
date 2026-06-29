// test/features/likes/presentation/views/likes_view_test.dart

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/core/controllers/page_state_service.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/features/likes/presentation/controllers/likes_controller.dart';
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
// Tests — controller-level tests that verify LikesController state
// without rendering the full view (which requires complex Obx stubs).
// ---------------------------------------------------------------------------

void main() {
  late _MockPageStateService pageStateService;

  setUp(() {
    GetxTestBinding.init();
    pageStateService = _MockPageStateService();
    GetxTestBinding.bind().register<PageStateService>(pageStateService);
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  group('LikesController state', () {
    test('initial segment is liked', () {
      final controller = LikesController();
      Get.put<LikesController>(controller);

      expect(controller.currentSegment.value, LikesSegment.liked);
    });

    test('switchToSegment changes to passed', () {
      final controller = LikesController();
      Get.put<LikesController>(controller);

      controller.switchToSegment(LikesSegment.passed);

      expect(controller.currentSegment.value, LikesSegment.passed);
    });

    test('switchToSegment no-op for same segment', () {
      final controller = LikesController();
      Get.put<LikesController>(controller);

      // Already on liked.
      controller.switchToSegment(LikesSegment.liked);

      expect(controller.currentSegment.value, LikesSegment.liked);
    });

    test('currentProperties returns page state properties', () {
      pageStateService.likesState.value = const PageStateModel(
        pageType: PageType.likes,
        filters: UnifiedFilterModel(),
        properties: [],
      );

      final controller = LikesController();
      Get.put<LikesController>(controller);

      expect(controller.currentProperties, isEmpty);
    });

    test('page state has liked segment data', () {
      pageStateService.likesState.value = const PageStateModel(
        pageType: PageType.likes,
        filters: UnifiedFilterModel(),
        properties: [],
        additionalData: {'currentSegment': 'liked'},
      );

      expect(
        pageStateService.likesState.value.getAdditionalData<String>('currentSegment'),
        'liked',
      );
    });

    test('page state has passed segment data', () {
      pageStateService.likesState.value = const PageStateModel(
        pageType: PageType.likes,
        filters: UnifiedFilterModel(),
        properties: [],
        additionalData: {'currentSegment': 'passed'},
      );

      expect(
        pageStateService.likesState.value.getAdditionalData<String>('currentSegment'),
        'passed',
      );
    });
  });
}
