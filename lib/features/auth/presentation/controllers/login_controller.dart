// lib/features/auth/presentation/controllers/login_controller.dart

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/firebase/analytics_service.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/utils/app_toast.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/core/utils/error_handler.dart';
import 'package:ghar360/features/auth/data/auth_method.dart';
import 'package:ghar360/features/auth/data/auth_repository.dart';
import 'package:ghar360/features/auth/data/identifier_utils.dart';
import 'package:ghar360/features/auth/data/models/identifier_status.dart';
import 'package:ghar360/features/auth/presentation/controllers/otp_resend_timer.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Steps the login screen can show.
enum LoginStep { password, otp }

/// Login flow driven by the identifier-status state-machine.
///
/// - `next_step == password` → [LoginStep.password] → signInWith{Email|Phone}Password.
/// - `next_step == otp` (existing user) → [LoginStep.otp] → send OTP → verify.
class LoginController extends GetxController with OtpResendTimer {
  final AuthRepository _authRepository = Get.find();
  final AuthController _authController = Get.find();
  final passwordFormKey = GlobalKey<FormState>();

  final passwordController = TextEditingController();
  final otpController = TextEditingController();

  final isLoading = false.obs;
  final isPasswordVisible = false.obs;
  final RxString errorMessage = ''.obs;

  final Rx<LoginStep> step = LoginStep.password.obs;
  final RxString identifier = ''.obs;
  final Rx<IdentifierChannel> channel = IdentifierChannel.phone.obs;

  /// Whether the account already has a password. For the OTP-first branch this
  /// comes from `/auth/identifier-status` (`has_password`); an unknown
  /// identifier is treated as no-password. Drives the mandatory set-password
  /// step after OTP verification (requirement 6).
  bool _hasPassword = true;

  // OTP resend countdown (canResendOtp / otpCountdown) provided by OtpResendTimer.

  bool get isEmail => channel.value == IdentifierChannel.email;

  /// Masked identifier for display.
  String get maskedIdentifier => IdentifierUtils.mask(identifier.value);

  @override
  void onInit() {
    super.onInit();
    passwordController.addListener(() {
      if (errorMessage.value.isNotEmpty) {
        errorMessage.value = '';
      }
    });
    final args = Get.arguments;
    if (args is Map && args['identifier'] != null) {
      identifier.value = args['identifier'] as String;
      channel.value = (args['channel'] == 'email')
          ? IdentifierChannel.email
          : IdentifierChannel.phone;
      // Unknown identifier (exists == false) is treated as no-password.
      final exists = args['exists'] == true;
      _hasPassword = exists && (args['has_password'] == true);
      final nextStep = args['next_step'] as String?;
      if (nextStep == 'otp') {
        step.value = LoginStep.otp;
        // Kick off OTP send immediately for the OTP-first branch.
        Future.microtask(_sendOtp);
      } else {
        step.value = LoginStep.password;
      }
    } else {
      DebugLogger.warning('LoginView accessed without identifier; redirecting to entry');
      Future.microtask(() => Get.offNamed(AppRoutes.phoneEntry));
    }
  }

  void togglePasswordVisibility() {
    isPasswordVisible.value = !isPasswordVisible.value;
  }

  // --- PASSWORD LOGIN ---

  Future<void> signIn() async {
    if (!(passwordFormKey.currentState?.validate() ?? false)) return;

    isLoading.value = true;
    errorMessage.value = '';

    try {
      final id = identifier.value;
      final password = passwordController.text;

      if (isEmail) {
        await _authRepository.signInWithEmailPassword(id, password);
        await _authRepository.recordLastMethod(AuthMethod.emailPassword, identifier: id);
      } else {
        await _authRepository.signInWithPhonePassword(id, password);
        await _authRepository.recordLastMethod(AuthMethod.phonePassword, identifier: id);
      }

      // Success! The AuthController listener handles navigation.
      DebugLogger.success('Sign in successful');
    } on AuthException catch (e) {
      if (e.message.toLowerCase().contains('invalid login credentials')) {
        errorMessage.value = 'invalid_credentials'.tr;
      } else {
        errorMessage.value = e.message;
      }
      ErrorHandler.handleAuthError(e);
      DebugLogger.error('Sign in failed', e);
    } catch (e) {
      errorMessage.value = 'login_error'.tr;
      ErrorHandler.handleNetworkError(e);
      DebugLogger.error('Unexpected login error', e);
    } finally {
      isLoading.value = false;
    }
  }

  // --- OTP-FIRST LOGIN ---

  Future<void> _sendOtp() async {
    try {
      isLoading.value = true;
      errorMessage.value = '';
      final id = identifier.value;
      if (isEmail) {
        await _authRepository.sendEmailOtp(id);
      } else {
        await _authRepository.sendPhoneOtp(id);
      }
      startOtpCountdown();
      AppToast.success('otp_sent'.tr, 'otp_sent_message'.tr);
    } on AuthException catch (e) {
      errorMessage.value = e.message;
      ErrorHandler.handleAuthError(e);
    } catch (e) {
      errorMessage.value = 'otp_send_error'.tr;
      ErrorHandler.handleNetworkError(e);
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> resendOtp() async {
    if (!canResendOtp.value) return;
    await _sendOtp();
  }

  Future<void> verifyOtp([String? code]) async {
    final token = (code ?? otpController.text).trim();
    if (token.length != 6) {
      errorMessage.value = 'invalid_otp'.tr;
      return;
    }
    if (isLoading.value) return;

    isLoading.value = true;
    errorMessage.value = '';

    // If the account has no password yet, force a mandatory set-password step
    // after this OTP succeeds. Must be set BEFORE verify triggers the auth
    // state change so the status decision routes to set-password.
    if (!_hasPassword) {
      _authController.markRequiresPasswordSetup();
    }

    try {
      final id = identifier.value;
      if (isEmail) {
        await _authRepository.verifyEmailOtp(email: id, token: token);
        await _authRepository.recordLastMethod(AuthMethod.emailOtp, identifier: id);
      } else {
        await _authRepository.verifyPhoneOtp(phone: id, token: token);
        await _authRepository.recordLastMethod(AuthMethod.phoneOtp, identifier: id);
      }
      AnalyticsService.authOtpVerified();
      // Success! The AuthController listener handles navigation (to the
      // set-password screen if a password is still required).
      DebugLogger.success('OTP verification successful');
    } on AuthException catch (e) {
      // Verify failed → no session was created, so clear the pending
      // set-password gate to avoid a stale requirement on the next attempt.
      _authController.clearRequiresPasswordSetup();
      errorMessage.value = e.message;
      ErrorHandler.handleAuthError(e);
      DebugLogger.error('OTP verification failed', e);
    } catch (e) {
      _authController.clearRequiresPasswordSetup();
      errorMessage.value = 'otp_verification_error'.tr;
      ErrorHandler.handleNetworkError(e);
      DebugLogger.error('Unexpected OTP verification error', e);
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    disposeOtpTimer();
    passwordController.dispose();
    otpController.dispose();
    super.onClose();
  }
}
