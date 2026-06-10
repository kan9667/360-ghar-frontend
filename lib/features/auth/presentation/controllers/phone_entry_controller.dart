// lib/features/auth/presentation/controllers/phone_entry_controller.dart

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/firebase/analytics_service.dart';
import 'package:ghar360/core/routes/app_routes.dart';
import 'package:ghar360/core/utils/debug_logger.dart';
import 'package:ghar360/core/utils/error_handler.dart';
import 'package:ghar360/features/auth/data/auth_method.dart';
import 'package:ghar360/features/auth/data/auth_repository.dart';
import 'package:ghar360/features/auth/data/identifier_utils.dart';
import 'package:smart_auth/smart_auth.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

enum IdentifierEntryState { idle, checking, error, success }

/// Unified auth entry: a Google button + a single identifier field that
/// auto-detects email vs phone, calls the `identifier-status` state-machine,
/// then routes to the password / OTP-first / signup branch.
class PhoneEntryController extends GetxController {
  final AuthRepository _authRepository = Get.find();
  final formKey = GlobalKey<FormState>();

  final identifierController = TextEditingController();
  final identifierFocusNode = FocusNode();

  final Rx<IdentifierEntryState> state = IdentifierEntryState.idle.obs;
  final RxBool isLoading = false.obs;
  final RxBool isGoogleLoading = false.obs;
  final RxBool isAppleLoading = false.obs;
  final RxString errorMessage = ''.obs;
  final RxBool isIdentifierFocused = false.obs;
  final RxInt validationShakeTrigger = 0.obs;

  /// True when the current text looks like an email (drives keyboard + hints).
  final RxBool looksLikeEmail = false.obs;

  /// Last-used method hint surfaced on the entry screen.
  final Rxn<AuthMethod> lastMethod = Rxn<AuthMethod>();
  final RxString lastIdentifierHint = ''.obs;

  /// Google is always offered: the Supabase Google provider is enabled, so we
  /// use the native ID-token flow when client IDs are present, otherwise the
  /// Supabase OAuth redirect flow.
  bool get isGoogleAvailable => true;

  /// Apple sign-in is shown on iOS only (App Store compliance).
  bool get isAppleAvailable => _authRepository.isAppleSignInSupported;

  String? validateIdentifier(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) {
      return 'identifier_required'.tr;
    }
    if (IdentifierUtils.isEmail(raw) || IdentifierUtils.isPhone(raw)) {
      return null;
    }
    return 'identifier_invalid'.tr;
  }

  @override
  void onInit() {
    super.onInit();
    identifierFocusNode.addListener(() {
      isIdentifierFocused.value = identifierFocusNode.hasFocus;
    });
    identifierController.addListener(() {
      looksLikeEmail.value = IdentifierUtils.looksLikeEmail(identifierController.text);
    });

    // Pre-select / highlight the last-used method.
    final store = _authRepository.lastAuthMethodStore;
    lastMethod.value = store.lastMethod;
    lastIdentifierHint.value = store.lastIdentifierHint ?? '';
  }

  /// Android-only: show the device phone-number hint picker and prefill.
  Future<void> requestPhoneNumberHint() async {
    if (kIsWeb || !Platform.isAndroid) return;
    try {
      final res = await SmartAuth.instance.requestPhoneNumberHint();
      if (res.hasData && res.data != null && res.data!.isNotEmpty) {
        identifierController.text = res.data!;
        looksLikeEmail.value = IdentifierUtils.looksLikeEmail(res.data!);
      }
    } catch (e) {
      DebugLogger.debug('Phone number hint unavailable: $e');
    }
  }

  Future<void> signInWithGoogle() async {
    if (isGoogleLoading.value) return;
    isGoogleLoading.value = true;
    errorMessage.value = '';
    try {
      AnalyticsService.authPhoneEntered();
      await _authRepository.signInWithGoogle();
      // Success: the AuthController onAuthStateChange listener drives routing.
      DebugLogger.success('Google sign-in flow completed');
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('cancel')) {
        // User dismissed the picker; stay silent.
        DebugLogger.auth('Google sign-in cancelled by user');
      } else {
        errorMessage.value = e.message;
        ErrorHandler.handleAuthError(e);
        DebugLogger.error('Google sign-in failed', e);
      }
    } catch (e) {
      errorMessage.value = 'google_signin_error'.tr;
      ErrorHandler.handleNetworkError(e);
      DebugLogger.error('Unexpected Google sign-in error', e);
    } finally {
      isGoogleLoading.value = false;
    }
  }

  Future<void> signInWithApple() async {
    if (isAppleLoading.value) return;
    isAppleLoading.value = true;
    errorMessage.value = '';
    try {
      AnalyticsService.authPhoneEntered();
      await _authRepository.signInWithApple();
      // Success: the AuthController onAuthStateChange listener drives routing.
      DebugLogger.success('Apple sign-in flow completed');
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      if (msg.contains('cancel')) {
        // User dismissed the sheet; stay silent.
        DebugLogger.auth('Apple sign-in cancelled by user');
      } else {
        errorMessage.value = e.message;
        ErrorHandler.handleAuthError(e);
        DebugLogger.error('Apple sign-in failed', e);
      }
    } catch (e) {
      errorMessage.value = 'apple_signin_error'.tr;
      ErrorHandler.handleNetworkError(e);
      DebugLogger.error('Unexpected Apple sign-in error', e);
    } finally {
      isAppleLoading.value = false;
    }
  }

  Future<void> checkAndNavigate() async {
    final isValid = formKey.currentState?.validate() ?? false;
    if (!isValid) {
      validationShakeTrigger.value++;
      return;
    }

    state.value = IdentifierEntryState.checking;
    isLoading.value = true;
    errorMessage.value = '';

    try {
      final raw = identifierController.text.trim();
      final normalized = IdentifierUtils.normalize(raw);

      final status = await _authRepository.checkIdentifierStatus(normalized);
      state.value = IdentifierEntryState.success;
      AnalyticsService.authPhoneEntered();

      final args = <String, dynamic>{
        'identifier': normalized,
        'channel': status.channel.name,
        'next_step': status.nextStep.name,
        'exists': status.exists,
        'has_password': status.hasPassword,
        'verified': status.verified,
      };

      if (status.isNewUser) {
        DebugLogger.auth('New user → signup');
        Get.toNamed(AppRoutes.signup, arguments: args);
      } else if (status.isPasswordStep) {
        DebugLogger.auth('Existing verified user with password → login');
        Get.toNamed(AppRoutes.login, arguments: args);
      } else {
        // Existing but unverified / passwordless → OTP-first login.
        DebugLogger.auth('Existing user, OTP-first → login');
        Get.toNamed(AppRoutes.login, arguments: args);
      }
    } catch (e) {
      DebugLogger.error('Error checking identifier status', e);
      state.value = IdentifierEntryState.error;
      errorMessage.value = 'network_error'.tr;
      ErrorHandler.handleNetworkError(e);
    } finally {
      isLoading.value = false;
    }
  }

  @override
  void onClose() {
    identifierController.dispose();
    identifierFocusNode.dispose();
    super.onClose();
  }
}
