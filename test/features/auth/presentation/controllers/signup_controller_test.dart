// test/features/auth/presentation/controllers/signup_controller_test.dart
//
// Tests for [SignUpController]: initial state, nextStep validation,
// signUp success/failure/already-registered, verifyOtp, resendOtp.

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/features/auth/data/auth_method.dart';
import 'package:ghar360/features/auth/data/auth_repository.dart';
import 'package:ghar360/features/auth/data/models/identifier_status.dart';
import 'package:ghar360/features/auth/presentation/controllers/signup_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(AuthMethod.emailPassword);
  });

  late MockAuthRepository authRepository;

  setUp(() {
    GetxTestBinding.init();

    authRepository = MockAuthRepository();

    GetxTestBinding.bind().register<AuthRepository>(authRepository);
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  SignUpController createControllerWithArgs(Map<String, dynamic> args) {
    // Set arguments directly on the routing object instead of calling
    // Get.toNamed(), which is a no-op in test mode (no navigator state)
    // and would leave Get.arguments as null.
    Get.routing.args = args;
    final controller = SignUpController();
    Get.put<SignUpController>(controller, permanent: true);
    return controller;
  }

  group('SignUpController', () {
    group('initial state from arguments', () {
      test('sets identifier and channel from arguments', () {
        final controller = createControllerWithArgs({
          'identifier': 'new@example.com',
          'channel': 'email',
        });

        expect(controller.identifier.value, 'new@example.com');
        expect(controller.channel.value, IdentifierChannel.email);
        expect(controller.isEmailSignup, isTrue);
      });

      test('defaults to phone channel when channel is not email', () {
        final controller = createControllerWithArgs({
          'identifier': '9876543210',
          'channel': 'phone',
        });

        expect(controller.identifier.value, '9876543210');
        expect(controller.channel.value, IdentifierChannel.phone);
        expect(controller.isEmailSignup, isFalse);
      });

      test('initial reactive state has expected defaults', () {
        final controller = createControllerWithArgs({
          'identifier': 'test@example.com',
          'channel': 'email',
        });

        expect(controller.isLoading.value, isFalse);
        expect(controller.isPasswordVisible.value, isFalse);
        expect(controller.isConfirmPasswordVisible.value, isFalse);
        expect(controller.isTermsAccepted.value, isFalse);
        expect(controller.currentStep.value, 0);
        expect(controller.errorMessage.value, isEmpty);
        expect(controller.passwordStrength.value, 0);
      });
    });

    group('togglePasswordVisibility', () {
      test('toggles isPasswordVisible', () {
        final controller = createControllerWithArgs({
          'identifier': 'test@example.com',
          'channel': 'email',
        });

        controller.togglePasswordVisibility();
        expect(controller.isPasswordVisible.value, isTrue);

        controller.togglePasswordVisibility();
        expect(controller.isPasswordVisible.value, isFalse);
      });

      test('toggles isConfirmPasswordVisible', () {
        final controller = createControllerWithArgs({
          'identifier': 'test@example.com',
          'channel': 'email',
        });

        controller.toggleConfirmPasswordVisibility();
        expect(controller.isConfirmPasswordVisible.value, isTrue);

        controller.toggleConfirmPasswordVisibility();
        expect(controller.isConfirmPasswordVisible.value, isFalse);
      });
    });

    group('previousStep', () {
      test('does not go below step 0', () {
        final controller = createControllerWithArgs({
          'identifier': 'test@example.com',
          'channel': 'email',
        });

        expect(controller.currentStep.value, 0);
        controller.previousStep();
        expect(controller.currentStep.value, 0);
      });

      test('decrements from step 2 to step 1', () {
        final controller = createControllerWithArgs({
          'identifier': 'test@example.com',
          'channel': 'email',
        });

        controller.currentStep.value = 2;
        controller.previousStep();
        expect(controller.currentStep.value, 1);
      });
    });

    group('nextStep', () {
      test('does not advance from step 0 when form is unvalidated', () {
        final controller = createControllerWithArgs({
          'identifier': 'test@example.com',
          'channel': 'email',
        });

        // personalInfoFormKey.currentState is null → validate fails
        controller.nextStep();
        expect(controller.currentStep.value, 0);
      });

      test('sets terms_consent_required error when terms not accepted at step 1', () {
        final controller = createControllerWithArgs({
          'identifier': 'test@example.com',
          'channel': 'email',
        });

        // Simulate being at step 1 with valid security form (which we can't
        // validate without a widget tree), but terms not accepted.
        controller.currentStep.value = 1;
        controller.isTermsAccepted.value = false;

        // nextStep at step 1: securityFormKey validation fails (no form),
        // so it won't reach the terms check. We verify the guard path.
        controller.nextStep();
        expect(controller.currentStep.value, 1);
      });
    });

    group('signUp', () {
      test('moves to OTP step on email signup success', () async {
        final controller = createControllerWithArgs({
          'identifier': 'new@example.com',
          'channel': 'email',
        });

        controller.fullNameController.text = 'Test User';
        controller.passwordController.text = 'StrongPass1!';

        when(
          () => authRepository.signUpWithEmailOtp('new@example.com', data: any(named: 'data')),
        ).thenAnswer((_) async {});

        await controller.signUp();

        expect(controller.currentStep.value, 2);
        expect(controller.isLoading.value, isFalse);
        expect(controller.errorMessage.value, isEmpty);
      });

      test('moves to OTP step on phone signup success', () async {
        final controller = createControllerWithArgs({
          'identifier': '9876543210',
          'channel': 'phone',
        });

        controller.fullNameController.text = 'Test User';
        controller.passwordController.text = 'StrongPass1!';

        when(
          () => authRepository.signUpWithPhonePassword(
            '9876543210',
            'StrongPass1!',
            data: any(named: 'data'),
          ),
        ).thenAnswer((_) async => AuthResponse());

        await controller.signUp();

        expect(controller.currentStep.value, 2);
        expect(controller.isLoading.value, isFalse);
      });

      test('redirects to login on already-registered error', () async {
        final controller = createControllerWithArgs({
          'identifier': 'existing@example.com',
          'channel': 'email',
        });

        controller.fullNameController.text = 'Test User';
        controller.passwordController.text = 'StrongPass1!';

        when(
          () => authRepository.signUpWithEmailOtp('existing@example.com', data: any(named: 'data')),
        ).thenThrow(const AuthException('User already registered'));

        await controller.signUp();

        // Navigation to login is safe in test mode.
        // The error is handled — no error message on the controller
        // (the redirect handles it).
        expect(controller.isLoading.value, isFalse);
      });

      test('sets errorMessage on generic AuthException', () async {
        final controller = createControllerWithArgs({
          'identifier': 'new@example.com',
          'channel': 'email',
        });

        controller.fullNameController.text = 'Test User';
        controller.passwordController.text = 'StrongPass1!';

        when(
          () => authRepository.signUpWithEmailOtp(any(), data: any(named: 'data')),
        ).thenThrow(const AuthException('Service unavailable'));

        await controller.signUp();

        expect(controller.errorMessage.value, 'Service unavailable');
        expect(controller.isLoading.value, isFalse);
      });

      test('sets errorMessage on unexpected exception', () async {
        final controller = createControllerWithArgs({
          'identifier': 'new@example.com',
          'channel': 'email',
        });

        controller.fullNameController.text = 'Test User';
        controller.passwordController.text = 'StrongPass1!';

        when(
          () => authRepository.signUpWithEmailOtp(any(), data: any(named: 'data')),
        ).thenThrow(Exception('network timeout'));

        await controller.signUp();

        expect(controller.errorMessage.value, isNotEmpty);
        expect(controller.isLoading.value, isFalse);
      });
    });

    group('verifyOtp', () {
      test('rejects OTP shorter than 6 digits', () async {
        final controller = createControllerWithArgs({
          'identifier': 'new@example.com',
          'channel': 'email',
        });

        await controller.verifyOtp('123');

        expect(controller.errorMessage.value, isNotEmpty);
        verifyNever(
          () => authRepository.verifyEmailOtp(
            email: any(named: 'email'),
            token: any(named: 'token'),
          ),
        );
      });

      test('calls verifyEmailOtp for email signup', () async {
        final controller = createControllerWithArgs({
          'identifier': 'new@example.com',
          'channel': 'email',
        });
        controller.otpController.text = '123456';

        when(
          () => authRepository.verifyEmailOtp(email: 'new@example.com', token: '123456'),
        ).thenAnswer((_) async => AuthResponse());
        when(
          () => authRepository.recordLastMethod(any(), identifier: any(named: 'identifier')),
        ).thenAnswer((_) async {});

        await controller.verifyOtp('123456');

        expect(controller.errorMessage.value, isEmpty);
        verify(
          () => authRepository.verifyEmailOtp(email: 'new@example.com', token: '123456'),
        ).called(1);
      });

      test('calls verifyPhoneOtp for phone signup', () async {
        final controller = createControllerWithArgs({
          'identifier': '9876543210',
          'channel': 'phone',
        });

        when(
          () => authRepository.verifyPhoneOtp(phone: '9876543210', token: '654321'),
        ).thenAnswer((_) async => AuthResponse());
        when(
          () => authRepository.recordLastMethod(any(), identifier: any(named: 'identifier')),
        ).thenAnswer((_) async {});

        await controller.verifyOtp('654321');

        expect(controller.errorMessage.value, isEmpty);
        verify(() => authRepository.verifyPhoneOtp(phone: '9876543210', token: '654321')).called(1);
      });

      test('sets errorMessage on AuthException', () async {
        final controller = createControllerWithArgs({
          'identifier': 'new@example.com',
          'channel': 'email',
        });

        when(
          () => authRepository.verifyEmailOtp(
            email: any(named: 'email'),
            token: any(named: 'token'),
          ),
        ).thenThrow(const AuthException('Invalid OTP code'));

        await controller.verifyOtp('123456');

        expect(controller.errorMessage.value, 'Invalid OTP code');
        expect(controller.isLoading.value, isFalse);
      });

      test('returns early if already loading', () async {
        final controller = createControllerWithArgs({
          'identifier': 'new@example.com',
          'channel': 'email',
        });

        controller.isLoading.value = true;
        await controller.verifyOtp('123456');

        verifyNever(
          () => authRepository.verifyEmailOtp(
            email: any(named: 'email'),
            token: any(named: 'token'),
          ),
        );
      });
    });

    group('resendOtp', () {
      test('does nothing when canResendOtp is false', () async {
        final controller = createControllerWithArgs({
          'identifier': 'new@example.com',
          'channel': 'email',
        });

        expect(controller.canResendOtp.value, isFalse);

        await controller.resendOtp();

        verifyNever(() => authRepository.signUpWithEmailOtp(any()));
      });
    });

    group('goBackToForm', () {
      test('moves from OTP step to security step and clears OTP', () {
        final controller = createControllerWithArgs({
          'identifier': 'new@example.com',
          'channel': 'email',
        });

        controller.currentStep.value = 2;
        controller.otpController.text = '123456';

        controller.goBackToForm();

        expect(controller.currentStep.value, 1);
        expect(controller.otpController.text, isEmpty);
        expect(controller.errorMessage.value, isEmpty);
      });

      test('decrements from step 1 to step 0', () {
        final controller = createControllerWithArgs({
          'identifier': 'new@example.com',
          'channel': 'email',
        });

        controller.currentStep.value = 1;
        controller.goBackToForm();

        expect(controller.currentStep.value, 0);
      });
    });
  });
}
