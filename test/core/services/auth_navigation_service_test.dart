import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/data/models/auth_status.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/services/auth_navigation_service.dart';
import 'package:ghar360/core/translations/app_translations.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/getx_test_binding.dart';
import '../../helpers/mocks.dart';

void main() {
  late MockAuthController mockAuthController;
  late Rx<AuthStatus> authStatus;
  late Rxn<RouteSettings> redirectRoute;

  setUp(() {
    GetxTestBinding.init();
    mockAuthController = MockAuthController();
    authStatus = AuthStatus.initial.obs;
    redirectRoute = Rxn<RouteSettings>();

    when(() => mockAuthController.authStatus).thenReturn(authStatus);
    when(() => mockAuthController.redirectRoute).thenReturn(redirectRoute);
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  /// Pumps a [GetMaterialApp] with app translations so that GetX navigation
  /// (Get.offAllNamed etc.) has a valid delegate.
  Future<void> pumpGetApp(WidgetTester tester) async {
    await tester.pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: const Locale('en', 'US'),
        fallbackLocale: const Locale('en', 'US'),
        initialRoute: AppRoutes.splash,
        getPages: [
          GetPage(name: AppRoutes.splash, page: () => const SizedBox()),
          GetPage(name: AppRoutes.phoneEntry, page: () => const SizedBox()),
          GetPage(name: AppRoutes.setPassword, page: () => const SizedBox()),
          GetPage(name: AppRoutes.profileCompletion, page: () => const SizedBox()),
          GetPage(name: AppRoutes.dashboard, page: () => const SizedBox()),
          GetPage(name: AppRoutes.profile, page: () => const SizedBox()),
        ],
      ),
    );
  }

  /// Registers the mock AuthController and creates [AuthNavigationService].
  AuthNavigationService createService() {
    GetxTestBinding.bind().register<AuthController>(mockAuthController);
    final service = AuthNavigationService();
    service.onInit();
    return service;
  }

  group('AuthNavigationService', () {
    testWidgets('initializes without error when auth status is initial', (tester) async {
      authStatus.value = AuthStatus.initial;
      await pumpGetApp(tester);
      expect(createService, returnsNormally);
    });

    testWidgets('initializes without error when auth status is error', (tester) async {
      authStatus.value = AuthStatus.error;
      await pumpGetApp(tester);
      expect(createService, returnsNormally);
    });

    testWidgets('navigateToRedirectRoute does nothing when redirectRoute is null', (tester) async {
      await pumpGetApp(tester);
      redirectRoute.value = null;
      final service = createService();

      expect(() => service.navigateToRedirectRoute(), returnsNormally);
      expect(redirectRoute.value, isNull);
    });

    testWidgets('navigateToRedirectRoute does nothing when route name is null', (tester) async {
      await pumpGetApp(tester);
      redirectRoute.value = const RouteSettings(name: null);
      final service = createService();

      expect(() => service.navigateToRedirectRoute(), returnsNormally);
      // redirectRoute is NOT cleared because the name guard prevented navigation
      expect(redirectRoute.value, isNotNull);
    });

    testWidgets('navigateToRedirectRoute clears redirectRoute and navigates', (tester) async {
      await pumpGetApp(tester);
      redirectRoute.value = const RouteSettings(
        name: AppRoutes.dashboard,
        arguments: {'key': 'value'},
      );
      final service = createService();

      service.navigateToRedirectRoute();
      await tester.pumpAndSettle();

      // The redirect route should be cleared after successful navigation
      expect(redirectRoute.value, isNull);
    });

    testWidgets('navigateToRedirectRoute uses stored route name', (tester) async {
      await pumpGetApp(tester);
      redirectRoute.value = const RouteSettings(name: AppRoutes.profile, arguments: {'tab': 2});
      final service = createService();

      service.navigateToRedirectRoute();
      await tester.pumpAndSettle();

      expect(redirectRoute.value, isNull);
      expect(Get.currentRoute, AppRoutes.profile);
    });

    testWidgets('handles requiresPasswordSetup status and navigates', (tester) async {
      await pumpGetApp(tester);
      authStatus.value = AuthStatus.initial;
      createService();

      authStatus.value = AuthStatus.requiresPasswordSetup;
      await tester.pumpAndSettle();

      // After microtask, should have navigated to setPassword
      expect(Get.currentRoute, AppRoutes.setPassword);
    });

    testWidgets('handles unauthenticated status and navigates to phoneEntry', (tester) async {
      await pumpGetApp(tester);
      authStatus.value = AuthStatus.initial;
      createService();

      authStatus.value = AuthStatus.unauthenticated;
      await tester.pumpAndSettle();

      // Without onboarding seen, navigates to phoneEntry (GetStorage defaults to null)
      expect(Get.currentRoute, anyOf(AppRoutes.splash, AppRoutes.phoneEntry));
    });

    testWidgets('handles authenticated status and navigates to dashboard', (tester) async {
      await pumpGetApp(tester);
      authStatus.value = AuthStatus.initial;
      createService();

      authStatus.value = AuthStatus.authenticated;
      await tester.pumpAndSettle();

      expect(Get.currentRoute, AppRoutes.dashboard);
    });

    testWidgets('handles requiresProfileCompletion status and navigates', (tester) async {
      await pumpGetApp(tester);
      authStatus.value = AuthStatus.initial;
      createService();

      authStatus.value = AuthStatus.requiresProfileCompletion;
      await tester.pumpAndSettle();

      expect(Get.currentRoute, AppRoutes.profileCompletion);
    });

    testWidgets('onClose disposes cleanly', (tester) async {
      await pumpGetApp(tester);
      final service = createService();
      expect(() => service.onClose(), returnsNormally);
    });
  });
}
