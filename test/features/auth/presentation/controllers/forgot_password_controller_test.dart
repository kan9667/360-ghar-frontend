// test/features/auth/presentation/controllers/forgot_password_controller_test.dart
//
// Tests for [ForgotPasswordController]: sendResetOtp, verifyResetOtp,
// updatePassword, step navigation, and validateIdentifier.

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/features/auth/data/auth_repository.dart';
import 'package:ghar360/features/auth/presentation/controllers/forgot_password_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockAuthRepository authRepository;

  setUp(() {
    GetxTestBinding.init();

    authRepository = MockAuthRepository();

    GetxTestBinding.bind().register<AuthRepository>(authRepository);
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  ForgotPasswordController createController() {
    final controller = ForgotPasswordController();
    Get.put<ForgotPasswordController>(controller, permanent: true);
    return controller;
  }

  group('ForgotPasswordController', () {
    group('initial state', () {
      test('has expected default values', () {
        final controller = createController();

        expect(controller.isLoading.value, isFalse);
        expect(controller.isPasswordVisible.value, isFalse);
        expect(controller.isConfirmPasswordVisible.value, isFalse);
        expect(controller.currentStep.value, 0);
        expect(controller.errorMessage.value, isEmpty);
        expect(controller.looksLikeEmail.value, isFalse);
      });

      test('isEmail reflects looksLikeEmail', () {
        final controller = createController();
        expect(controller.isEmail, isFalse);

        controller.looksLikeEmail.value = true;
        expect(controller.isEmail, isTrue);
      });
    });

    group('validateIdentifier', () {
      late ForgotPasswordController controller;

      setUp(() {
        controller = createController();
      });

      test('returns null for valid email', () {
        expect(controller.validateIdentifier('user@example.com'), isNull);
      });

      test('returns null for valid phone number', () {
        expect(controller.validateIdentifier('9876543210'), isNull);
      });

      test('returns error for empty string', () {
        expect(controller.validateIdentifier(''), isNotNull);
      });

      test('returns error for null', () {
        expect(controller.validateIdentifier(null), isNotNull);
      });

      test('returns error for invalid identifier', () {
        expect(controller.validateIdentifier('abc'), isNotNull);
      });
    });

    group('togglePasswordVisibility', () {
      test('toggles isPasswordVisible', () {
        final controller = createController();
        controller.togglePasswordVisibility();
        expect(controller.isPasswordVisible.value, isTrue);
        controller.togglePasswordVisibility();
        expect(controller.isPasswordVisible.value, isFalse);
      });

      test('toggles isConfirmPasswordVisible', () {
        final controller = createController();
        controller.toggleConfirmPasswordVisibility();
        expect(controller.isConfirmPasswordVisible.value, isTrue);
        controller.toggleConfirmPasswordVisibility();
        expect(controller.isConfirmPasswordVisible.value, isFalse);
      });
    });

    group('sendResetOtp', () {
      test('does nothing when form validation is unavailable', () async {
        final controller = createController();
        controller.identifierController.text = 'user@example.com';

        // No form attached → formKey.currentState is null → validate fails
        await controller.sendResetOtp();

        expect(controller.currentStep.value, 0);
        expect(controller.isLoading.value, isFalse);
      });
    });

    group('verifyResetOtp', () {
      test('rejects OTP shorter than 6 digits', () async {
        final controller = createController();
        controller.identifierController.text = 'user@example.com';
        controller.otpController.text = '123';

        await controller.verifyResetOtp();

        expect(controller.errorMessage.value, isNotEmpty);
        expect(controller.currentStep.value, 0);
      });

      test('rejects empty OTP', () async {
        final controller = createController();
        controller.identifierController.text = 'user@example.com';
        controller.otpController.text = '';

        await controller.verifyResetOtp();

        expect(controller.errorMessage.value, isNotEmpty);
      });

      test('calls verifyEmailOtp for email identifier and moves to step 2', () async {
        final controller = createController();
        controller.identifierController.text = 'user@example.com';
        controller.looksLikeEmail.value = true;
        controller.otpController.text = '123456';

        when(
          () => authRepository.verifyEmailOtp(email: 'user@example.com', token: '123456'),
        ).thenAnswer((_) async => AuthResponse());

        await controller.verifyResetOtp();

        expect(controller.currentStep.value, 2);
        expect(controller.errorMessage.value, isEmpty);
        expect(controller.isLoading.value, isFalse);
        verify(
          () => authRepository.verifyEmailOtp(email: 'user@example.com', token: '123456'),
        ).called(1);
      });

      test('calls verifyPhoneOtp for phone identifier', () async {
        final controller = createController();
        controller.identifierController.text = '9876543210';
        controller.looksLikeEmail.value = false;
        controller.otpController.text = '654321';

        // IdentifierUtils.normalize('9876543210') produces '+919876543210'
        when(
          () => authRepository.verifyPhoneOtp(phone: '+919876543210', token: '654321'),
        ).thenAnswer((_) async => AuthResponse());

        await controller.verifyResetOtp();

        expect(controller.currentStep.value, 2);
        verify(
          () => authRepository.verifyPhoneOtp(phone: '+919876543210', token: '654321'),
        ).called(1);
      });

      test('sets errorMessage on AuthException', () async {
        final controller = createController();
        controller.identifierController.text = 'user@example.com';
        controller.looksLikeEmail.value = true;
        controller.otpController.text = '123456';

        when(
          () => authRepository.verifyEmailOtp(
            email: any(named: 'email'),
            token: any(named: 'token'),
          ),
        ).thenThrow(const AuthException('OTP expired'));

        await controller.verifyResetOtp();

        expect(controller.errorMessage.value, 'OTP expired');
        expect(controller.isLoading.value, isFalse);
        expect(controller.currentStep.value, 0);
      });

      test('sets errorMessage on unexpected exception', () async {
        final controller = createController();
        controller.identifierController.text = 'user@example.com';
        controller.looksLikeEmail.value = true;
        controller.otpController.text = '123456';

        when(
          () => authRepository.verifyEmailOtp(
            email: any(named: 'email'),
            token: any(named: 'token'),
          ),
        ).thenThrow(Exception('network error'));

        await controller.verifyResetOtp();

        expect(controller.errorMessage.value, isNotEmpty);
        expect(controller.isLoading.value, isFalse);
      });
    });

    group('updatePassword', () {
      test('rejects empty password', () async {
        final controller = createController();
        controller.newPasswordController.text = '';
        controller.confirmPasswordController.text = '';

        await controller.updatePassword();

        expect(controller.errorMessage.value, isNotEmpty);
      });

      test('rejects password shorter than 6 characters', () async {
        final controller = createController();
        controller.newPasswordController.text = 'abc';
        controller.confirmPasswordController.text = 'abc';

        await controller.updatePassword();

        expect(controller.errorMessage.value, isNotEmpty);
      });

      test('rejects mismatched passwords', () async {
        final controller = createController();
        controller.newPasswordController.text = 'StrongPass1!';
        controller.confirmPasswordController.text = 'DifferentPass1!';

        await controller.updatePassword();

        expect(controller.errorMessage.value, isNotEmpty);
      });

      test('calls updateUserPassword on success and navigates to login', () async {
        final controller = createController();
        controller.identifierController.text = 'user@example.com';
        controller.looksLikeEmail.value = true;
        controller.newPasswordController.text = 'NewStrongPass1!';
        controller.confirmPasswordController.text = 'NewStrongPass1!';

        when(
          () => authRepository.updateUserPassword('NewStrongPass1!'),
        ).thenAnswer((_) async => FakeUser());

        await controller.updatePassword();

        expect(controller.errorMessage.value, isEmpty);
        expect(controller.isLoading.value, isFalse);
        verify(() => authRepository.updateUserPassword('NewStrongPass1!')).called(1);
      });

      test('sets errorMessage on failure', () async {
        final controller = createController();
        controller.identifierController.text = 'user@example.com';
        controller.looksLikeEmail.value = true;
        controller.newPasswordController.text = 'NewPass1!';
        controller.confirmPasswordController.text = 'NewPass1!';

        when(
          () => authRepository.updateUserPassword('NewPass1!'),
        ).thenThrow(const AuthException('Password update failed'));

        await controller.updatePassword();

        expect(controller.errorMessage.value, isNotEmpty);
        expect(controller.isLoading.value, isFalse);
      });
    });

    group('goBackToStep', () {
      test('navigates from step 2 back to step 1 and clears password fields', () {
        final controller = createController();
        controller.currentStep.value = 2;
        controller.newPasswordController.text = 'pass';
        controller.confirmPasswordController.text = 'pass';

        controller.goBackToStep(1);

        expect(controller.currentStep.value, 1);
        expect(controller.newPasswordController.text, isEmpty);
        expect(controller.confirmPasswordController.text, isEmpty);
        expect(controller.errorMessage.value, isEmpty);
      });

      test('navigates from step 1 back to step 0 and clears OTP', () {
        final controller = createController();
        controller.currentStep.value = 1;
        controller.otpController.text = '123456';

        controller.goBackToStep(0);

        expect(controller.currentStep.value, 0);
        expect(controller.otpController.text, isEmpty);
        expect(controller.errorMessage.value, isEmpty);
      });

      test('does not navigate to current or future step', () {
        final controller = createController();
        controller.currentStep.value = 1;

        controller.goBackToStep(1); // same step
        expect(controller.currentStep.value, 1);

        controller.goBackToStep(2); // future step
        expect(controller.currentStep.value, 1);
      });
    });

    group('resendOtp', () {
      test('does nothing when canResendOtp is false', () async {
        final controller = createController();
        controller.identifierController.text = 'user@example.com';

        expect(controller.canResendOtp.value, isFalse);

        await controller.resendOtp();

        verifyNever(() => authRepository.sendEmailOtp(any()));
        verifyNever(() => authRepository.sendPhoneOtp(any()));
      });
    });
  });
}

/// Minimal fake User for Supabase AuthResponse.
class FakeUser extends Fake implements User {
  @override
  String get id => 'fake-id';

  @override
  String? get email => 'user@example.com';
}
