import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/controllers/page_state_service.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/data/models/property_model.dart';
import 'package:ghar360/core/data/models/unified_filter_model.dart';
import 'package:ghar360/features/likes/presentation/controllers/likes_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/mocks.dart';

class MockPageStateService extends GetxServiceMock implements PageStateService {}

void main() {
  late MockPageStateService mockPageStateService;
  late Rx<PageStateModel> likesState;
  late Rx<PageType> currentPageType;

  setUpAll(() {
    registerFallbackValue(PageType.likes);
  });

  setUp(() {
    GetxTestBinding.init();

    mockPageStateService = MockPageStateService();
    likesState = PageStateModel.initial(PageType.likes).obs;
    currentPageType = PageType.likes.obs;

    // Stub reactive fields
    when(() => mockPageStateService.likesState).thenReturn(likesState);
    when(() => mockPageStateService.currentPageType).thenReturn(currentPageType);
    when(() => mockPageStateService.currentLikesSegment).thenReturn('liked');

    // Stub methods
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
    when(() => mockPageStateService.updatePageSearch(any(), any())).thenReturn(null);
    when(() => mockPageStateService.updateLikesSegment(any())).thenReturn(null);
    when(() => mockPageStateService.loadMorePageData(any())).thenAnswer((_) async {});
    when(() => mockPageStateService.useCurrentLocationForPage(any())).thenAnswer((_) async {});
    when(() => mockPageStateService.removePropertyFromLikes(any())).thenReturn(null);

    GetxTestBinding.bind().register<PageStateService>(mockPageStateService);
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  LikesController createController() {
    final c = LikesController();
    c.onInit();
    return c;
  }

  List<PropertyModel> seedProperties(int count) {
    return List.generate(count, (i) => testPropertyModel(id: 200 + i));
  }

  group('LikesController', () {
    test('initial state has liked segment selected and empty properties', () {
      final controller = createController();

      expect(controller.currentSegment.value, LikesSegment.liked);
      expect(controller.likedProperties, isEmpty);
      expect(controller.passedProperties, isEmpty);
      expect(controller.searchQuery.value, '');
    });

    test('switchToSegment updates segment and calls updateLikesSegment', () {
      final controller = createController();

      controller.switchToSegment(LikesSegment.passed);

      expect(controller.currentSegment.value, LikesSegment.passed);
      verify(() => mockPageStateService.updateLikesSegment('passed')).called(1);
    });

    test('switchToSegment same segment is a no-op', () {
      final controller = createController();
      // Default segment is 'liked'
      controller.switchToSegment(LikesSegment.liked);

      // updateLikesSegment should NOT be called since segment didn't change
      verifyNever(() => mockPageStateService.updateLikesSegment(any()));
    });

    test('addToFavourites calls recordSwipe with isLiked true', () async {
      final controller = createController();

      await controller.addToFavourites(42);

      verify(() => mockPageStateService.recordSwipe(propertyId: 42, isLiked: true)).called(1);
      verify(() => mockPageStateService.loadPageData(PageType.likes, forceRefresh: true)).called(1);
    });

    test('removeFromFavourites calls recordSwipe with isLiked false', () async {
      final controller = createController();

      await controller.removeFromFavourites(42);

      verify(() => mockPageStateService.recordSwipe(propertyId: 42, isLiked: false)).called(1);
      verify(() => mockPageStateService.loadPageData(PageType.likes, forceRefresh: true)).called(1);
    });

    test('currentProperties returns properties from page state', () {
      final props = seedProperties(3);
      likesState.value = PageStateModel(
        pageType: PageType.likes,
        filters: const UnifiedFilterModel(),
        properties: props,
        additionalData: const {'currentSegment': 'liked'},
      );

      final controller = createController();
      expect(controller.currentProperties.length, 3);
    });

    test('retryCurrentSegment calls loadPageData', () {
      final controller = createController();

      controller.retryCurrentSegment();

      verify(() => mockPageStateService.loadPageData(PageType.likes, forceRefresh: true)).called(1);
    });

    test('clearSearch resets query and calls updatePageSearch', () {
      final controller = createController();
      controller.searchQuery.value = 'test query';

      controller.clearSearch();

      expect(controller.searchQuery.value, '');
      verify(() => mockPageStateService.updatePageSearch(PageType.likes, '')).called(1);
    });
  });
}
