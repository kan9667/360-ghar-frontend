// test/features/dashboard/presentation/controllers/dashboard_controller_test.dart
//
// Unit tests for [DashboardController]. Covers:
// - Initial state (currentIndex=2, visitedTabs={2})
// - changeTab updates index and adds to visitedTabs
// - syncTabWithRoute mapping
// - loadDashboardData concurrent guard (isLoading check)
// - _clearAllData clears storage keys and reactive state

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/controllers/page_state_service.dart';
import 'package:ghar360/core/data/models/auth_status.dart';
import 'package:ghar360/core/data/models/page_state_model.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/features/dashboard/presentation/controllers/dashboard_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/mocks.dart';

void main() {
  // Mock path_provider platform channel so GetStorage can initialise in tests.
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('plugins.flutter.io/path_provider');

  setUpAll(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(
      channel,
      (MethodCall methodCall) async {
        if (methodCall.method == 'getApplicationDocumentsDirectory') {
          return '.';
        }
        return null;
      },
    );
    registerFallbackValue(PageType.discover);
  });

  late MockAuthController mockAuthController;
  late MockPageStateService mockPageStateService;
  late Rx<AuthStatus> authStatus;
  late Rx<PageType> currentPageType;

  setUp(() async {
    GetxTestBinding.init();
    await GetStorage.init();
    GetStorage().erase();

    mockAuthController = MockAuthController();
    mockPageStateService = MockPageStateService();

    // Auth setup — start authenticated by default
    authStatus = AuthStatus.authenticated.obs;
    when(() => mockAuthController.authStatus).thenReturn(authStatus);
    when(() => mockAuthController.isAuthenticated).thenReturn(true);

    // PageStateService setup
    currentPageType = PageType.discover.obs;
    when(() => mockPageStateService.currentPageType).thenReturn(currentPageType);
    when(() => mockPageStateService.setCurrentPage(any())).thenReturn(null);
    when(
      () => mockPageStateService.discoverState,
    ).thenReturn(PageStateModel.initial(PageType.discover).obs);

    GetxTestBinding.bind()
      ..register<AuthController>(mockAuthController)
      ..register<PageStateService>(mockPageStateService);
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  DashboardController createController() {
    final c = DashboardController();
    c.onInit();
    return c;
  }

  group('DashboardController', () {
    // ── Initial state ──────────────────────────────────────────────────

    test('initial state has currentIndex=2 and visitedTabs={2}', () {
      final controller = createController();

      expect(controller.currentIndex.value, 2);
      expect(controller.visitedTabs, {2});
    });

    test('initial reactive collections are empty', () {
      // Start unauthenticated so onInit does not trigger loadDashboardData,
      // which would set isLoading to true asynchronously.
      when(() => mockAuthController.isAuthenticated).thenReturn(false);
      final controller = createController();

      expect(controller.dashboardData, isEmpty);
      expect(controller.recentActivity, isEmpty);
      expect(controller.userStats, isEmpty);
      expect(controller.isLoading.value, false);
      expect(controller.isRefreshing.value, false);
      expect(controller.error.value, isNull);
    });

    // ── changeTab ──────────────────────────────────────────────────────

    test('changeTab updates currentIndex and adds to visitedTabs', () {
      final controller = createController();

      controller.changeTab(1);

      expect(controller.currentIndex.value, 1);
      expect(controller.visitedTabs, contains(1));
      expect(controller.visitedTabs, contains(2)); // initial tab preserved
    });

    test('changeTab with same index is a no-op', () {
      final controller = createController();

      // Default index is 2
      controller.changeTab(2);

      // No redundant update — visitedTabs unchanged (only {2} from init)
      expect(controller.currentIndex.value, 2);
    });

    test('changeTab calls setCurrentPage for mapped page types', () {
      final controller = createController();

      controller.changeTab(1); // Explore
      verify(() => mockPageStateService.setCurrentPage(PageType.explore)).called(1);

      controller.changeTab(3); // Likes
      verify(() => mockPageStateService.setCurrentPage(PageType.likes)).called(1);
    });

    test('changeTab does not call setCurrentPage for unmapped indices (Profile, Visits)', () {
      final controller = createController();

      controller.changeTab(0); // Profile — no PageType
      controller.changeTab(4); // Visits — no PageType

      verifyNever(() => mockPageStateService.setCurrentPage(any()));
    });

    // ── syncTabWithRoute ───────────────────────────────────────────────

    test('syncTabWithRoute maps known routes to correct tab indices', () {
      final controller = createController();

      controller.syncTabWithRoute(AppRoutes.profile);
      expect(controller.currentIndex.value, 0);
      expect(controller.visitedTabs, contains(0));

      controller.syncTabWithRoute(AppRoutes.explore);
      expect(controller.currentIndex.value, 1);
      expect(controller.visitedTabs, contains(1));

      controller.syncTabWithRoute(AppRoutes.discover);
      expect(controller.currentIndex.value, 2);

      controller.syncTabWithRoute(AppRoutes.likes);
      expect(controller.currentIndex.value, 3);
      expect(controller.visitedTabs, contains(3));

      controller.syncTabWithRoute(AppRoutes.visits);
      expect(controller.currentIndex.value, 4);
      expect(controller.visitedTabs, contains(4));

      controller.syncTabWithRoute(AppRoutes.assistant);
      expect(controller.currentIndex.value, 5);
      expect(controller.visitedTabs, contains(5));
    });

    test('syncTabWithRoute does not change tab for dashboard or unknown routes', () {
      final controller = createController();

      controller.syncTabWithRoute(AppRoutes.dashboard);
      expect(controller.currentIndex.value, 2); // unchanged

      controller.syncTabWithRoute('/');
      expect(controller.currentIndex.value, 2); // unchanged

      controller.syncTabWithRoute('/some-unknown-route');
      expect(controller.currentIndex.value, 2); // unchanged
    });

    // ── loadDashboardData concurrent guard ─────────────────────────────

    test('loadDashboardData returns early when already loading (concurrent guard)', () async {
      // Start unauthenticated so onInit does not trigger loadDashboardData.
      when(() => mockAuthController.isAuthenticated).thenReturn(false);
      final controller = DashboardController();
      controller.onInit();

      // Now make authenticated so the isAuthenticated guard passes,
      // but set isLoading to simulate a concurrent load in progress.
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      controller.isLoading.value = true;

      // Call loadDashboardData — should return immediately due to isLoading guard
      await controller.loadDashboardData();

      // isLoading should still be true (never entered the try block)
      expect(controller.isLoading.value, true);
    });

    test('loadDashboardData returns early when not authenticated', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(false);

      final controller = createController();
      controller.isLoading.value = false;

      await controller.loadDashboardData();

      // Should not have set isLoading to true (returned before try block)
      expect(controller.isLoading.value, false);
    });

    // ── _clearAllData (tested indirectly via auth state change) ────────

    test('logout clears all dashboard data and storage keys', () async {
      final controller = createController();

      // Seed some data into storage
      final storage = GetStorage();
      await storage.write(kDashPropertiesViewedKey, 10);
      await storage.write(kDashPropertiesLikedKey, 5);
      await storage.write(kDashSearchesMadeKey, 3);
      await storage.write(kDashRecentActivityKey, [
        {'type': 'view', 'title': 'test'},
      ]);

      // Seed reactive data
      controller.userStats.value = {'properties_viewed': 10};
      controller.recentActivity.value = [
        {'type': 'view', 'title': 'test'},
      ];
      controller.dashboardData.value = {'total_views': 100};

      // Trigger logout — the ever worker should call _clearAllData
      when(() => mockAuthController.isAuthenticated).thenReturn(false);
      authStatus.value = AuthStatus.unauthenticated;

      // Wait for the worker to fire
      await Future<void>.delayed(Duration.zero);

      // Verify reactive state is cleared
      expect(controller.dashboardData, isEmpty);
      expect(controller.recentActivity, isEmpty);
      expect(controller.userStats, isEmpty);
      expect(controller.error.value, isNull);

      // Verify storage keys are removed
      expect(storage.read(kDashPropertiesViewedKey), isNull);
      expect(storage.read(kDashPropertiesLikedKey), isNull);
      expect(storage.read(kDashSearchesMadeKey), isNull);
      expect(storage.read(kDashRecentActivityKey), isNull);
    });

    // ── refreshDashboard ───────────────────────────────────────────────

    test('refreshDashboard is a no-op when not authenticated', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(false);

      final controller = createController();

      await controller.refreshDashboard();

      expect(controller.isRefreshing.value, false);
    });

    test('refreshDashboard is a no-op when already refreshing', () async {
      final controller = createController();
      controller.isRefreshing.value = true;

      await controller.refreshDashboard();

      expect(controller.isRefreshing.value, true);
    });

    // ── userStats getters ──────────────────────────────────────────────

    test('stat getters return defaults when userStats is empty', () {
      final controller = createController();

      expect(controller.propertiesViewed, 0);
      expect(controller.propertiesLiked, 0);
      expect(controller.visitsScheduled, 0);
      expect(controller.searchesMade, 0);
      expect(controller.timeSpentMinutes, 0);
      expect(controller.favoriteLocation, 'N/A');
    });
  });
}
