import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/data/models/user_model.dart';
import 'package:ghar360/features/profile/presentation/controllers/profile_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/mocks.dart';
import '../../../../helpers/test_data.dart';

void main() {
  late MockAuthController mockAuthController;

  setUp(() {
    GetxTestBinding.init();
    mockAuthController = MockAuthController();
    GetxTestBinding.bind().register<AuthController>(mockAuthController);
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  ProfileController createController() {
    final c = ProfileController();
    c.onInit();
    return c;
  }

  group('ProfileController', () {
    test('isProfileLoading starts as false', () {
      // Stub currentUser on the mock AuthController
      when(() => mockAuthController.currentUser).thenReturn(Rxn<UserModel>());

      final controller = createController();

      expect(controller.isProfileLoading.value, isFalse);
      expect(controller.isLoading, isFalse);
    });

    test('currentUser is null when AuthController has no user', () {
      when(() => mockAuthController.currentUser).thenReturn(Rxn<UserModel>());

      final controller = createController();

      expect(controller.currentUser.value, isNull);
    });

    test('currentUser reflects the AuthController currentUser', () {
      final user = testUserModelFull(fullName: 'Jane Doe');
      final rxUser = Rxn<UserModel>(user);
      when(() => mockAuthController.currentUser).thenReturn(rxUser);

      final controller = createController();

      expect(controller.currentUser.value, isNotNull);
      expect(controller.currentUser.value!.fullName, 'Jane Doe');
    });

    test('currentUser is reactive — changes propagate from AuthController', () {
      final rxUser = Rxn<UserModel>();
      when(() => mockAuthController.currentUser).thenReturn(rxUser);

      final controller = createController();
      expect(controller.currentUser.value, isNull);

      // Simulate AuthController setting a user
      final user = testUserModelFull(fullName: 'John Smith');
      rxUser.value = user;

      expect(controller.currentUser.value, isNotNull);
      expect(controller.currentUser.value!.fullName, 'John Smith');
    });

    test('signOut delegates to AuthController.signOut', () async {
      when(() => mockAuthController.currentUser).thenReturn(Rxn<UserModel>());
      when(() => mockAuthController.signOut()).thenAnswer((_) async {});

      final controller = createController();
      await controller.signOut();

      verify(() => mockAuthController.signOut()).called(1);
    });

    test('signOut sets isProfileLoading true during execution and resets after', () async {
      when(() => mockAuthController.currentUser).thenReturn(Rxn<UserModel>());

      // Use a Completer to control when signOut finishes
      final completer = Completer<void>();
      when(() => mockAuthController.signOut()).thenAnswer((_) => completer.future);

      final controller = createController();

      // Start sign-out (will block on completer)
      final future = controller.signOut();

      // While in-flight, isProfileLoading should be true
      expect(controller.isProfileLoading.value, isTrue);
      expect(controller.isLoading, isTrue);

      // Complete the signOut
      completer.complete();
      await future;

      // After completion, isProfileLoading should be false
      expect(controller.isProfileLoading.value, isFalse);
      expect(controller.isLoading, isFalse);
    });

    test('signOut resets isProfileLoading even when signOut throws', () async {
      when(() => mockAuthController.currentUser).thenReturn(Rxn<UserModel>());
      when(() => mockAuthController.signOut()).thenThrow(Exception('Network error'));

      final controller = createController();

      // signOut should propagate the exception
      expect(() => controller.signOut(), throwsException);

      // But isProfileLoading should still be reset to false
      expect(controller.isProfileLoading.value, isFalse);
    });

    test('isLoading getter tracks isProfileLoading value', () {
      when(() => mockAuthController.currentUser).thenReturn(Rxn<UserModel>());

      final controller = createController();

      expect(controller.isLoading, isFalse);
      controller.isProfileLoading.value = true;
      expect(controller.isLoading, isTrue);
      controller.isProfileLoading.value = false;
      expect(controller.isLoading, isFalse);
    });
  });
}
