import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/data/models/auth_status.dart';
import 'package:ghar360/core/middlewares/auth_middleware.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/getx_test_binding.dart';
import '../../helpers/mocks.dart';

void main() {
  late MockAuthController mockAuthController;
  late Rx<AuthStatus> authStatus;

  setUp(() {
    GetxTestBinding.init();
    mockAuthController = MockAuthController();
    authStatus = AuthStatus.initial.obs;
    when(() => mockAuthController.authStatus).thenReturn(authStatus);
    when(() => mockAuthController.redirectRoute).thenReturn(Rxn<RouteSettings>());
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  group('AuthMiddleware', () {
    test('redirects to phoneEntry when AuthController is not registered', () {
      // Do NOT register AuthController
      final middleware = AuthMiddleware();
      final result = middleware.redirect('/dashboard');

      expect(result, isNotNull);
      expect(result!.name, AppRoutes.phoneEntry);
    });

    test('returns null when authenticated', () {
      authStatus.value = AuthStatus.authenticated;
      GetxTestBinding.bind().register<AuthController>(mockAuthController);

      final middleware = AuthMiddleware();
      final result = middleware.redirect('/dashboard');

      expect(result, isNull);
    });

    test('redirects to setPassword when requiresPasswordSetup', () {
      authStatus.value = AuthStatus.requiresPasswordSetup;
      GetxTestBinding.bind().register<AuthController>(mockAuthController);

      final middleware = AuthMiddleware();
      final result = middleware.redirect('/dashboard');

      expect(result, isNotNull);
      expect(result!.name, AppRoutes.setPassword);
    });

    test('returns null when already on setPassword route and requiresPasswordSetup', () {
      authStatus.value = AuthStatus.requiresPasswordSetup;
      GetxTestBinding.bind().register<AuthController>(mockAuthController);

      final middleware = AuthMiddleware();
      final result = middleware.redirect(AppRoutes.setPassword);

      expect(result, isNull);
    });

    test('redirects to profileCompletion when requiresProfileCompletion', () {
      authStatus.value = AuthStatus.requiresProfileCompletion;
      GetxTestBinding.bind().register<AuthController>(mockAuthController);

      final middleware = AuthMiddleware();
      final result = middleware.redirect('/dashboard');

      expect(result, isNotNull);
      expect(result!.name, AppRoutes.profileCompletion);
    });

    test('returns null when already on profileCompletion route', () {
      authStatus.value = AuthStatus.requiresProfileCompletion;
      GetxTestBinding.bind().register<AuthController>(mockAuthController);

      final middleware = AuthMiddleware();
      final result = middleware.redirect(AppRoutes.profileCompletion);

      expect(result, isNull);
    });

    test('redirects unauthenticated user to phoneEntry', () {
      authStatus.value = AuthStatus.unauthenticated;
      GetxTestBinding.bind().register<AuthController>(mockAuthController);

      final middleware = AuthMiddleware();
      final result = middleware.redirect('/dashboard');

      expect(result, isNotNull);
      expect(result!.name, AppRoutes.phoneEntry);
    });

    test('stores attempted route in redirectRoute when unauthenticated', () {
      authStatus.value = AuthStatus.unauthenticated;
      final redirectRoute = Rxn<RouteSettings>();
      when(() => mockAuthController.redirectRoute).thenReturn(redirectRoute);
      GetxTestBinding.bind().register<AuthController>(mockAuthController);

      AuthMiddleware().redirect('/dashboard');

      expect(redirectRoute.value, isNotNull);
      expect(redirectRoute.value!.name, '/dashboard');
    });

    test('does not store redirect route when navigating to phoneEntry', () {
      authStatus.value = AuthStatus.unauthenticated;
      final redirectRoute = Rxn<RouteSettings>();
      when(() => mockAuthController.redirectRoute).thenReturn(redirectRoute);
      GetxTestBinding.bind().register<AuthController>(mockAuthController);

      AuthMiddleware().redirect(AppRoutes.phoneEntry);

      expect(redirectRoute.value, isNull);
    });

    test('has priority 1', () {
      expect(AuthMiddleware().priority, 1);
    });
  });
}
