import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/middlewares/auth_middleware.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/getx_test_binding.dart';
import '../../helpers/mocks.dart';

void main() {
  late MockAuthController mockAuthController;

  setUp(() {
    GetxTestBinding.init();
    mockAuthController = MockAuthController();
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  group('GuestMiddleware', () {
    test('allows access when AuthController is not registered', () {
      final middleware = GuestMiddleware();
      final result = middleware.redirect('/login');
      expect(result, isNull);
    });

    test('redirects to dashboard when user is authenticated', () {
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      GetxTestBinding.bind().register<AuthController>(mockAuthController);

      final middleware = GuestMiddleware();
      final result = middleware.redirect('/login');

      expect(result, isNotNull);
      expect(result!.name, AppRoutes.dashboard);
    });

    test('allows access when user is not authenticated', () {
      when(() => mockAuthController.isAuthenticated).thenReturn(false);
      GetxTestBinding.bind().register<AuthController>(mockAuthController);

      final middleware = GuestMiddleware();
      final result = middleware.redirect('/login');

      expect(result, isNull);
    });

    test('redirects authenticated user away from phone-entry route', () {
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      GetxTestBinding.bind().register<AuthController>(mockAuthController);

      final middleware = GuestMiddleware();
      final result = middleware.redirect(AppRoutes.phoneEntry);

      expect(result, isNotNull);
      expect(result!.name, AppRoutes.dashboard);
    });

    test('allows unauthenticated user to access phone-entry route', () {
      when(() => mockAuthController.isAuthenticated).thenReturn(false);
      GetxTestBinding.bind().register<AuthController>(mockAuthController);

      final middleware = GuestMiddleware();
      final result = middleware.redirect(AppRoutes.phoneEntry);

      expect(result, isNull);
    });

    test('has higher priority than AuthMiddleware', () {
      final guestMiddleware = GuestMiddleware();
      final authMiddleware = AuthMiddleware();

      expect(guestMiddleware.priority, greaterThan(authMiddleware.priority!));
    });
  });
}
