// test/features/auth/presentation/controllers/login_controller_test.dart
//
// Tests for [LoginController]: signIn, verifyOtp, resendOtp,
// togglePasswordVisibility, and initial state from arguments.
//
// Controllers that read Get.arguments in onInit are constructed directly
// (bypassing Get.put → onInit) and their observable state is set manually.

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/features/auth/data/auth_method.dart';
import 'package:ghar360/features/auth/data/auth_repository.dart';
import 'package:ghar360/features/auth/data/models/identifier_status.dart';
import 'package:ghar360/features/auth/presentation/controllers/login_controller.dart';
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
  late MockAuthController authController;

  setUp(() {
    GetxTestBinding.init();

    authRepository = MockAuthRepository();
    authController = MockAuthController();

    // Stub recordLastMethod which may be called in verifyOtp paths.
    when(
      () => authRepository.recordLastMethod(any(), identifier: any(named: 'identifier')),
    ).thenAnswer((_) async {});

    GetxTestBinding.bind()
      ..register<AuthRepository>(authRepository)
      ..register<AuthController>(authController);
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  /// Creates a LoginController with the given state set manually.
  /// Bypasses Get.put (which triggers onInit that reads Get.arguments).
  LoginController createController({
    String identifier = '',
    IdentifierChannel channel = IdentifierChannel.email,
    LoginStep step = LoginStep.password,
  }) {
    // Construct directly — onInit is NOT called.
    final controller = LoginController();
    // Register in GetX so any downstream Get.find works.
    Get.put<LoginController>(controller, permanent: true);
    // Manually set the state that onInit would normally derive from arguments.
    controller.identifier.value = identifier;
    controller.channel.value = channel;
    controller.step.value = step;
    return controller;
  }

  group('LoginController', () {
    group('initial state', () {
      test('default observable values are correct', () {
        final controller = createController(
          identifier: 'user@example.com',
          channel: IdentifierChannel.email,
          step: LoginStep.password,
        );

        expect(controller.step.value, LoginStep.password);
        expect(controller.identifier.value, 'user@example.com');
        expect(controller.channel.value, IdentifierChannel.email);
        expect(controller.isEmail, isTrue);
        expect(controller.isLoading.value, isFalse);
        expect(controller.isPasswordVisible.value, isFalse);
        expect(controller.errorMessage.value, isEmpty);
      });

      test('isEmail is false for phone channel', () {
        final controller = createController(
          identifier: '9876543210',
          channel: IdentifierChannel.phone,
        );
        expect(controller.isEmail, isFalse);
      });
    });

    group('togglePasswordVisibility', () {
      test('toggles from false to true', () {
        final controller = createController();
        controller.togglePasswordVisibility();
        expect(controller.isPasswordVisible.value, isTrue);
      });

      test('toggles back to false', () {
        final controller = createController();
        controller.togglePasswordVisibility();
        controller.togglePasswordVisibility();
        expect(controller.isPasswordVisible.value, isFalse);
      });
    });

    group('signIn', () {
      test('does nothing when form validation is unavailable', () async {
        final controller = createController(
          identifier: 'user@example.com',
          channel: IdentifierChannel.email,
        );

        // No Form widget → passwordFormKey.currentState is null → validate fails
        await controller.signIn();

        expect(controller.isLoading.value, isFalse);
        verifyNever(() => authRepository.signInWithEmailPassword(any(), any()));
      });
    });

    group('verifyOtp', () {
      test('rejects OTP shorter than 6 digits', () async {
        final controller = createController(
          identifier: 'user@example.com',
          channel: IdentifierChannel.email,
          step: LoginStep.otp,
        );

        await controller.verifyOtp('123');

        expect(controller.errorMessage.value, isNotEmpty);
        verifyNever(
          () => authRepository.verifyEmailOtp(
            email: any(named: 'email'),
            token: any(named: 'token'),
          ),
        );
      });

      test('rejects empty OTP', () async {
        final controller = createController(
          identifier: 'user@example.com',
          channel: IdentifierChannel.email,
          step: LoginStep.otp,
        );

        await controller.verifyOtp('');

        expect(controller.errorMessage.value, isNotEmpty);
      });

      test('calls verifyEmailOtp for email channel', () async {
        final controller = createController(
          identifier: 'user@example.com',
          channel: IdentifierChannel.email,
          step: LoginStep.otp,
        );

        when(
          () => authRepository.verifyEmailOtp(email: 'user@example.com', token: '123456'),
        ).thenAnswer((_) async => AuthResponse());

        await controller.verifyOtp('123456');

        expect(controller.errorMessage.value, isEmpty);
        expect(controller.isLoading.value, isFalse);
        verify(
          () => authRepository.verifyEmailOtp(email: 'user@example.com', token: '123456'),
        ).called(1);
      });

      test('calls verifyPhoneOtp for phone channel', () async {
        final controller = createController(
          identifier: '9876543210',
          channel: IdentifierChannel.phone,
          step: LoginStep.otp,
        );

        when(
          () => authRepository.verifyPhoneOtp(phone: '9876543210', token: '654321'),
        ).thenAnswer((_) async => AuthResponse());

        await controller.verifyOtp('654321');

        expect(controller.errorMessage.value, isEmpty);
        verify(() => authRepository.verifyPhoneOtp(phone: '9876543210', token: '654321')).called(1);
      });

      test('sets errorMessage on AuthException', () async {
        final controller = createController(
          identifier: 'user@example.com',
          channel: IdentifierChannel.email,
          step: LoginStep.otp,
        );

        when(
          () => authRepository.verifyEmailOtp(
            email: any(named: 'email'),
            token: any(named: 'token'),
          ),
        ).thenThrow(const AuthException('Invalid OTP'));

        await controller.verifyOtp('123456');

        expect(controller.errorMessage.value, 'Invalid OTP');
        expect(controller.isLoading.value, isFalse);
      });

      test('clears requiresPasswordSetup on auth failure', () async {
        final controller = createController(
          identifier: 'user@example.com',
          channel: IdentifierChannel.email,
          step: LoginStep.otp,
        );

        when(
          () => authRepository.verifyEmailOtp(
            email: any(named: 'email'),
            token: any(named: 'token'),
          ),
        ).thenThrow(const AuthException('Invalid OTP'));

        await controller.verifyOtp('123456');

        verify(() => authController.clearRequiresPasswordSetup()).called(1);
      });

      test('returns early if already loading', () async {
        final controller = createController(
          identifier: 'user@example.com',
          channel: IdentifierChannel.email,
          step: LoginStep.otp,
        );

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
        final controller = createController(
          identifier: 'user@example.com',
          channel: IdentifierChannel.email,
          step: LoginStep.otp,
        );

        expect(controller.canResendOtp.value, isFalse);

        await controller.resendOtp();

        verifyNever(() => authRepository.sendEmailOtp(any()));
      });
    });
  });
}
