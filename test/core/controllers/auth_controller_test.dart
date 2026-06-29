// test/core/controllers/auth_controller_test.dart
//
// Unit tests for [AuthController]. Covers:
// - Initial reactive state
// - Auth state transitions driven by the Supabase auth stream
// - signOut clears state
// - markRequiresPasswordSetup / clearRequiresPasswordSetup flags
// - updateUserProfile transitions auth status
// - _handleUnauthorizedFromApi sets unauthenticated

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/data/models/auth_status.dart';
import 'package:ghar360/core/data/models/user_model.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/auth/data/auth_repository.dart';
import 'package:ghar360/features/notifications/data/datasources/notifications_remote_datasource.dart';
import 'package:ghar360/features/profile/data/profile_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../helpers/getx_test_binding.dart';
import '../../helpers/mocks.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// A fake [User] for Supabase auth state changes.
class FakeUser extends Fake implements User {
  @override
  String get id => 'fake-uid-123';

  @override
  String get email => 'fake@example.com';
}

/// A fake [Session] for the auth repository.
class FakeSession extends Fake implements Session {
  @override
  String get accessToken => 'fake-access-token';

  @override
  int get expiresAt => DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
}

void main() {
  // Fake fallbacks for types used in mocktail verification
  setUpAll(() {
    Get.testMode = true;
    registerFallbackValue(const Duration(seconds: 10));
    registerFallbackValue(FakeUser());
    registerFallbackValue(
      UnauthorizedEvent(
        error: AuthenticationException('fallback'),
        method: 'GET',
        endpoint: '/test',
        statusCode: 401,
        isSessionCritical: true,
      ),
    );
  });

  late MockAuthRepository authRepo;
  late MockProfileRepository profileRepo;
  late MockNotificationsRemoteDatasource notificationsDs;
  late StreamController<User?> authStreamController;

  setUp(() {
    GetxTestBinding.init();
    authRepo = MockAuthRepository();
    profileRepo = MockProfileRepository();
    notificationsDs = MockNotificationsRemoteDatasource();
    authStreamController = StreamController<User?>();

    // Common stubs required by AuthController.onInit
    when(() => authRepo.onAuthStateChange).thenAnswer((_) => authStreamController.stream);
    when(() => authRepo.currentUser).thenReturn(null);
    when(() => authRepo.currentSession).thenReturn(null);

    GetxTestBinding.bind()
      ..register<AuthRepository>(authRepo)
      ..register<ProfileRepository>(profileRepo)
      ..register<NotificationsRemoteDatasource>(notificationsDs);
  });

  tearDown(() {
    authStreamController.close();
    GetxTestBinding.reset();
  });

  // Helper to construct and register the controller under test.
  AuthController createController() {
    final c = AuthController();
    Get.put<AuthController>(c);
    return c;
  }

  // -------------------------------------------------------------------------
  // Initial state
  // -------------------------------------------------------------------------
  group('initial state', () {
    test('authStatus starts as initial before onInit', () {
      final c = AuthController();
      // Verify raw default values before any GetX lifecycle runs.
      expect(c.authStatus.value, AuthStatus.initial);
      expect(c.currentUser.value, isNull);
      expect(c.isLoading.value, isFalse);
      expect(c.isDeleting.value, isFalse);
      expect(c.isAuthResolving.value, isFalse);
      expect(c.authErrorMessage.value, isNull);
      expect(c.requiresPasswordSetup, isFalse);
    });

    test('onInit sets unauthenticated when no Supabase user exists', () async {
      // authRepo.currentUser returns null (default stub)
      final c = createController();
      // Allow microtasks from onInit to flush
      await Future.delayed(Duration.zero);

      expect(c.authStatus.value, AuthStatus.unauthenticated);
      expect(c.currentUser.value, isNull);
    });
  });

  // -------------------------------------------------------------------------
  // Auth state transitions
  // -------------------------------------------------------------------------
  group('auth state transitions', () {
    test('unauthenticated → authenticated when stream emits a user', () async {
      final user = FakeUser();
      final session = FakeSession();

      // Stub token and profile loading
      when(
        () => authRepo.waitForAccessToken(
          timeout: any(named: 'timeout'),
          minTtlSeconds: any(named: 'minTtlSeconds'),
        ),
      ).thenAnswer((_) async => 'valid-token');
      when(() => profileRepo.getCurrentUserProfile()).thenAnswer(
        (_) async => UserModel(
          id: 1,
          supabaseUserId: 'fake-uid-123',
          email: 'fake@example.com',
          fullName: 'Test User',
          dateOfBirth: '1990-01-01',
          isActive: true,
          isVerified: false,
          createdAt: DateTime(2024, 1, 1),
        ),
      );

      final c = createController();
      await Future.delayed(Duration.zero);
      expect(c.authStatus.value, AuthStatus.unauthenticated);

      // Emit sign-in event via the stream
      when(() => authRepo.currentUser).thenReturn(user);
      when(() => authRepo.currentSession).thenReturn(session);
      authStreamController.add(user);

      // Wait for the debounce timer (300ms) + profile load
      await Future.delayed(const Duration(milliseconds: 500));
      // Allow async profile load to finish
      await Future.delayed(const Duration(seconds: 1));

      expect(c.authStatus.value, AuthStatus.authenticated);
      expect(c.currentUser.value, isNotNull);
      expect(c.currentUser.value!.fullName, 'Test User');
    });

    test('authenticated → unauthenticated when stream emits null', () async {
      final user = FakeUser();
      final session = FakeSession();

      // Setup for initial sign-in
      when(
        () => authRepo.waitForAccessToken(
          timeout: any(named: 'timeout'),
          minTtlSeconds: any(named: 'minTtlSeconds'),
        ),
      ).thenAnswer((_) async => 'valid-token');
      when(() => profileRepo.getCurrentUserProfile()).thenAnswer(
        (_) async => UserModel(
          id: 1,
          supabaseUserId: 'fake-uid-123',
          email: 'fake@example.com',
          fullName: 'Test User',
          dateOfBirth: '1990-01-01',
          isActive: true,
          isVerified: false,
          createdAt: DateTime(2024, 1, 1),
        ),
      );

      final c = createController();
      await Future.delayed(Duration.zero);

      // Sign in
      when(() => authRepo.currentUser).thenReturn(user);
      when(() => authRepo.currentSession).thenReturn(session);
      authStreamController.add(user);
      await Future.delayed(const Duration(milliseconds: 500));
      await Future.delayed(const Duration(seconds: 1));
      expect(c.authStatus.value, AuthStatus.authenticated);

      // Sign out via stream
      when(() => authRepo.currentUser).thenReturn(null);
      when(() => authRepo.currentSession).thenReturn(null);
      authStreamController.add(null);
      await Future.delayed(const Duration(milliseconds: 400));

      expect(c.authStatus.value, AuthStatus.unauthenticated);
      expect(c.currentUser.value, isNull);
      expect(c.isAuthResolving.value, isFalse);
    });

    test('emits requiresProfileCompletion for user with incomplete profile', () async {
      final user = FakeUser();
      final session = FakeSession();

      when(
        () => authRepo.waitForAccessToken(
          timeout: any(named: 'timeout'),
          minTtlSeconds: any(named: 'minTtlSeconds'),
        ),
      ).thenAnswer((_) async => 'valid-token');
      // Incomplete profile: no fullName or dateOfBirth
      when(() => profileRepo.getCurrentUserProfile()).thenAnswer(
        (_) async => UserModel(
          id: 1,
          supabaseUserId: 'fake-uid-123',
          email: 'test@example.com',
          isActive: true,
          isVerified: false,
          createdAt: DateTime(2024, 1, 1),
        ),
      );

      final c = createController();
      await Future.delayed(Duration.zero);

      when(() => authRepo.currentUser).thenReturn(user);
      when(() => authRepo.currentSession).thenReturn(session);
      authStreamController.add(user);
      await Future.delayed(const Duration(milliseconds: 500));
      await Future.delayed(const Duration(seconds: 1));

      expect(c.authStatus.value, AuthStatus.requiresProfileCompletion);
    });

    test('sets error status when profile load fails', () async {
      final user = FakeUser();
      final session = FakeSession();

      when(
        () => authRepo.waitForAccessToken(
          timeout: any(named: 'timeout'),
          minTtlSeconds: any(named: 'minTtlSeconds'),
        ),
      ).thenAnswer((_) async => 'valid-token');
      when(() => profileRepo.getCurrentUserProfile()).thenThrow(Exception('Network failure'));

      final c = createController();
      await Future.delayed(Duration.zero);

      when(() => authRepo.currentUser).thenReturn(user);
      when(() => authRepo.currentSession).thenReturn(session);
      authStreamController.add(user);
      await Future.delayed(const Duration(milliseconds: 500));
      await Future.delayed(const Duration(seconds: 2));

      expect(c.authStatus.value, AuthStatus.error);
      expect(c.authErrorMessage.value, isNotNull);
    });
  });

  // -------------------------------------------------------------------------
  // signOut
  // -------------------------------------------------------------------------
  group('signOut', () {
    test('signOut calls repository and sets loading', () async {
      when(() => authRepo.signOut()).thenAnswer((_) async {});
      when(() => notificationsDs.unregisterDeviceToken(any())).thenAnswer((_) async => true);

      final c = createController();
      await Future.delayed(Duration.zero);

      await c.signOut();

      verify(() => authRepo.signOut()).called(1);
      expect(c.isLoading.value, isFalse);
    });

    test('signOut error is handled gracefully', () async {
      when(() => authRepo.signOut()).thenThrow(Exception('signout failed'));

      final c = createController();
      await Future.delayed(Duration.zero);

      // Should not throw
      await c.signOut();
      expect(c.isLoading.value, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // markRequiresPasswordSetup / clearRequiresPasswordSetup
  // -------------------------------------------------------------------------
  group('password setup flags', () {
    test('markRequiresPasswordSetup sets the flag', () {
      final c = AuthController();
      expect(c.requiresPasswordSetup, isFalse);

      c.markRequiresPasswordSetup();
      expect(c.requiresPasswordSetup, isTrue);
    });

    test('clearRequiresPasswordSetup clears the flag', () {
      final c = AuthController();
      c.markRequiresPasswordSetup();
      expect(c.requiresPasswordSetup, isTrue);

      c.clearRequiresPasswordSetup();
      expect(c.requiresPasswordSetup, isFalse);
    });

    test('requiresPasswordSetup leads to requiresPasswordSetup auth status', () async {
      final user = FakeUser();
      final session = FakeSession();

      when(
        () => authRepo.waitForAccessToken(
          timeout: any(named: 'timeout'),
          minTtlSeconds: any(named: 'minTtlSeconds'),
        ),
      ).thenAnswer((_) async => 'valid-token');
      when(() => profileRepo.getCurrentUserProfile()).thenAnswer(
        (_) async => UserModel(
          id: 1,
          supabaseUserId: 'fake-uid-123',
          email: 'test@example.com',
          fullName: 'Test User',
          dateOfBirth: '1990-01-01',
          isActive: true,
          isVerified: false,
          createdAt: DateTime(2024, 1, 1),
        ),
      );

      final c = createController();
      await Future.delayed(Duration.zero);

      // Mark password setup requirement before sign-in completes
      c.markRequiresPasswordSetup();

      when(() => authRepo.currentUser).thenReturn(user);
      when(() => authRepo.currentSession).thenReturn(session);
      authStreamController.add(user);
      await Future.delayed(const Duration(milliseconds: 500));
      await Future.delayed(const Duration(seconds: 1));

      expect(c.authStatus.value, AuthStatus.requiresPasswordSetup);
    });
  });

  // -------------------------------------------------------------------------
  // updateUserProfile
  // -------------------------------------------------------------------------
  group('updateUserProfile', () {
    test('transitions to authenticated when profile becomes complete', () async {
      when(() => profileRepo.updateUserProfile(any())).thenAnswer(
        (_) async => UserModel(
          id: 1,
          supabaseUserId: 'fake-uid-123',
          email: 'test@example.com',
          fullName: 'Updated Name',
          dateOfBirth: '1990-05-15',
          isActive: true,
          isVerified: false,
          createdAt: DateTime(2024, 1, 1),
        ),
      );

      final c = createController();
      await Future.delayed(Duration.zero);
      // Set to requiresProfileCompletion (simulating incomplete profile)
      c.authStatus.value = AuthStatus.requiresProfileCompletion;

      final result = await c.updateUserProfile({'full_name': 'Updated Name'});

      expect(result, isTrue);
      expect(c.authStatus.value, AuthStatus.authenticated);
      expect(c.currentUser.value!.fullName, 'Updated Name');
      expect(c.isLoading.value, isFalse);
    });

    test('returns false on update failure', () async {
      when(() => profileRepo.updateUserProfile(any())).thenThrow(Exception('update failed'));

      final c = createController();
      await Future.delayed(Duration.zero);
      c.authStatus.value = AuthStatus.requiresProfileCompletion;

      final result = await c.updateUserProfile({'full_name': 'Bad'});

      expect(result, isFalse);
      expect(c.isLoading.value, isFalse);
    });
  });

  // -------------------------------------------------------------------------
  // _handleUnauthorizedFromApi
  // -------------------------------------------------------------------------
  group('_handleUnauthorizedFromApi', () {
    test('sets unauthenticated on critical unauthorized event', () async {
      // First sign in to be in authenticated state
      final user = FakeUser();
      final session = FakeSession();

      when(
        () => authRepo.waitForAccessToken(
          timeout: any(named: 'timeout'),
          minTtlSeconds: any(named: 'minTtlSeconds'),
        ),
      ).thenAnswer((_) async => 'valid-token');
      when(() => profileRepo.getCurrentUserProfile()).thenAnswer(
        (_) async => UserModel(
          id: 1,
          supabaseUserId: 'fake-uid-123',
          email: 'test@example.com',
          fullName: 'Test User',
          dateOfBirth: '1990-01-01',
          isActive: true,
          isVerified: false,
          createdAt: DateTime(2024, 1, 1),
        ),
      );
      // signOut mock: simulate real Supabase behaviour by emitting null on the
      // auth stream (Supabase emits a signed-out event when session is cleared).
      when(() => authRepo.signOut()).thenAnswer((_) async {
        when(() => authRepo.currentUser).thenReturn(null);
        when(() => authRepo.currentSession).thenReturn(null);
        authStreamController.add(null);
      });

      final c = createController();
      await Future.delayed(Duration.zero);

      // Sign in
      when(() => authRepo.currentUser).thenReturn(user);
      when(() => authRepo.currentSession).thenReturn(session);
      authStreamController.add(user);
      await Future.delayed(const Duration(milliseconds: 500));
      await Future.delayed(const Duration(seconds: 1));
      expect(c.authStatus.value, AuthStatus.authenticated);

      // Simulate the unauthorized handler being registered and triggered.
      // AuthController.onInit sets ApiClient.onUnauthorized.
      final handler = ApiClient.onUnauthorized;
      expect(handler, isNotNull, reason: 'onInit should have registered the handler');

      // Fire the handler with a critical unauthorized event
      await handler!(
        UnauthorizedEvent(
          error: AuthenticationException('UNAUTHORIZED', code: 'UNAUTHORIZED'),
          method: 'GET',
          endpoint: '/api/v1/profile',
          statusCode: 401,
          isSessionCritical: true,
        ),
      );

      // signOut was called → stream emitted null → debounce 300ms → unauthenticated
      await Future.delayed(const Duration(milliseconds: 500));
      expect(c.authStatus.value, AuthStatus.unauthenticated);
    });

    test('ignores non-critical unauthorized event', () async {
      final user = FakeUser();
      final session = FakeSession();

      when(
        () => authRepo.waitForAccessToken(
          timeout: any(named: 'timeout'),
          minTtlSeconds: any(named: 'minTtlSeconds'),
        ),
      ).thenAnswer((_) async => 'valid-token');
      when(() => profileRepo.getCurrentUserProfile()).thenAnswer(
        (_) async => UserModel(
          id: 1,
          supabaseUserId: 'fake-uid-123',
          email: 'test@example.com',
          fullName: 'Test User',
          dateOfBirth: '1990-01-01',
          isActive: true,
          isVerified: false,
          createdAt: DateTime(2024, 1, 1),
        ),
      );

      final c = createController();
      await Future.delayed(Duration.zero);

      when(() => authRepo.currentUser).thenReturn(user);
      when(() => authRepo.currentSession).thenReturn(session);
      authStreamController.add(user);
      await Future.delayed(const Duration(milliseconds: 500));
      await Future.delayed(const Duration(seconds: 1));
      expect(c.authStatus.value, AuthStatus.authenticated);

      // Fire with non-critical event
      final handler = ApiClient.onUnauthorized;
      await handler!(
        UnauthorizedEvent(
          error: AuthenticationException('UNAUTHORIZED', code: 'UNAUTHORIZED'),
          method: 'GET',
          endpoint: '/api/v1/some-resource',
          statusCode: 401,
          isSessionCritical: false,
        ),
      );

      // Should remain authenticated
      expect(c.authStatus.value, AuthStatus.authenticated);
    });

    test('ignores non-UNAUTHORIZED error code', () async {
      final c = createController();
      await Future.delayed(Duration.zero);

      final handler = ApiClient.onUnauthorized;
      await handler!(
        UnauthorizedEvent(
          error: AuthenticationException('FORBIDDEN', code: 'FORBIDDEN'),
          method: 'GET',
          endpoint: '/api/v1/admin',
          statusCode: 403,
          isSessionCritical: true,
        ),
      );

      // Should remain unauthenticated (initial state after no user)
      expect(c.authStatus.value, AuthStatus.unauthenticated);
    });
  });

  // -------------------------------------------------------------------------
  // Convenience getters
  // -------------------------------------------------------------------------
  group('convenience getters', () {
    test('isAuthenticated returns true only when status is authenticated', () async {
      final c = createController();
      await Future.delayed(Duration.zero);

      expect(c.isAuthenticated, isFalse);

      c.authStatus.value = AuthStatus.authenticated;
      expect(c.isAuthenticated, isTrue);

      c.authStatus.value = AuthStatus.requiresProfileCompletion;
      expect(c.isAuthenticated, isFalse);
    });

    test('userEmail returns null when no user', () async {
      final c = createController();
      await Future.delayed(Duration.zero);

      expect(c.userEmail, isNull);
    });
  });
}
