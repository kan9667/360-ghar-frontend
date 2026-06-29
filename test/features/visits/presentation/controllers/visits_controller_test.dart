import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/controllers/auth_controller.dart';
import 'package:ghar360/core/data/models/auth_status.dart';
import 'package:ghar360/core/data/models/visit_model.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/visits/data/datasources/visits_remote_datasource.dart';
import 'package:ghar360/features/visits/presentation/controllers/visits_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/mocks.dart';

void main() {
  late MockAuthController mockAuthController;
  late MockVisitsRemoteDatasource mockVisitsDatasource;
  late Rx<AuthStatus> authStatus;

  setUp(() {
    GetxTestBinding.init();

    mockAuthController = MockAuthController();
    mockVisitsDatasource = MockVisitsRemoteDatasource();
    authStatus = AuthStatus.unauthenticated.obs;

    // Stub AuthController reactive fields
    when(() => mockAuthController.authStatus).thenReturn(authStatus);
    when(() => mockAuthController.isAuthenticated).thenReturn(false);

    GetxTestBinding.bind()
      ..register<AuthController>(mockAuthController)
      ..register<VisitsRemoteDatasource>(mockVisitsDatasource);
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  VisitsController createController() {
    final c = VisitsController();
    c.onInit();
    return c;
  }

  VisitModel makeVisit({
    int id = 1,
    required DateTime scheduledDate,
    VisitStatus status = VisitStatus.scheduled,
  }) {
    return VisitModel(
      id: id,
      propertyId: 100,
      userId: 1,
      scheduledDate: scheduledDate,
      status: status,
      createdAt: DateTime(2024, 1, 1),
    );
  }

  group('VisitsController', () {
    test('initial state has empty lists and loading flags false', () {
      final controller = createController();

      expect(controller.visits, isEmpty);
      expect(controller.upcomingVisitsList, isEmpty);
      expect(controller.pastVisitsList, isEmpty);
      expect(controller.isLoading.value, isFalse);
      expect(controller.error.value, isNull);
    });

    test('loadVisits fetches and splits into upcoming and past', () async {
      // Switch to authenticated
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      authStatus.value = AuthStatus.authenticated;

      final now = DateTime.now();
      final upcoming = makeVisit(id: 1, scheduledDate: now.add(const Duration(days: 3)));
      final past = makeVisit(
        id: 2,
        scheduledDate: now.subtract(const Duration(days: 2)),
        status: VisitStatus.completed,
      );

      when(
        () => mockVisitsDatasource.fetchVisitsSummary(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => VisitsPayload(visits: [upcoming, past], hasMore: false));

      final controller = createController();
      await controller.loadVisits();

      expect(controller.upcomingVisitsList.length, 1);
      expect(controller.upcomingVisitsList.first.id, 1);
      expect(controller.pastVisitsList.length, 1);
      expect(controller.pastVisitsList.first.id, 2);
      expect(controller.isLoading.value, isFalse);
    });

    test('loadVisits sets authentication error when not authenticated', () async {
      final controller = createController();
      await controller.loadVisits();

      expect(controller.error.value, isA<AuthenticationException>());
    });

    test('bookVisit returns false when not authenticated', () async {
      final controller = createController();
      final result = await controller.bookVisit(
        testPropertyModel(),
        DateTime.now().add(const Duration(days: 1)),
      );

      expect(result, isFalse);
    });

    test('bookVisit returns true on success when authenticated', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      authStatus.value = AuthStatus.authenticated;

      final visitDate = DateTime.now().add(const Duration(days: 5));
      final scheduledVisit = makeVisit(id: 10, scheduledDate: visitDate);

      when(
        () => mockVisitsDatasource.scheduleVisit(
          propertyId: any(named: 'propertyId'),
          scheduledDate: any(named: 'scheduledDate'),
          specialRequirements: any(named: 'specialRequirements'),
        ),
      ).thenAnswer((_) async => scheduledVisit);

      // Stub the refresh after booking
      when(
        () => mockVisitsDatasource.fetchVisitsSummary(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => VisitsPayload(visits: [scheduledVisit], hasMore: false));

      final controller = createController();
      final result = await controller.bookVisit(testPropertyModel(id: 100), visitDate);

      expect(result, isTrue);
    });

    test('cancelVisit returns false when not authenticated', () async {
      final controller = createController();
      final result = await controller.cancelVisit(1, reason: 'changed mind');

      expect(result, isFalse);
    });

    test('rescheduleVisit returns false when not authenticated', () async {
      final controller = createController();
      final result = await controller.rescheduleVisit(
        1,
        DateTime.now().add(const Duration(days: 10)),
      );

      expect(result, isFalse);
    });

    test('formatVisitDate returns today for current date', () {
      final controller = createController();
      final result = controller.formatVisitDate(DateTime.now());

      expect(result, isNotEmpty);
      // The actual string depends on translations; verify it's a non-empty key
      expect(result, isA<String>());
    });

    test('formatVisitDate returns different values for today vs future', () {
      final controller = createController();
      final todayResult = controller.formatVisitDate(DateTime.now());
      final futureResult = controller.formatVisitDate(DateTime.now().add(const Duration(days: 5)));

      // They should produce different output
      expect(todayResult, isNot(equals(futureResult)));
    });

    test('_clearAllData clears all lists when auth status changes to unauthenticated', () async {
      when(() => mockAuthController.isAuthenticated).thenReturn(true);
      authStatus.value = AuthStatus.authenticated;

      // Pre-populate lists by loading visits
      final now = DateTime.now();
      final upcoming = makeVisit(id: 1, scheduledDate: now.add(const Duration(days: 3)));
      when(
        () => mockVisitsDatasource.fetchVisitsSummary(
          cursor: any(named: 'cursor'),
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) async => VisitsPayload(visits: [upcoming], hasMore: false));

      final controller = createController();
      await Future<void>.value(); // Let _initializeController run
      expect(controller.visits, isNotEmpty);

      // Simulate logout
      when(() => mockAuthController.isAuthenticated).thenReturn(false);
      authStatus.value = AuthStatus.unauthenticated;
      await Future<void>.value();

      expect(controller.visits, isEmpty);
      expect(controller.upcomingVisitsList, isEmpty);
      expect(controller.pastVisitsList, isEmpty);
      expect(controller.relationshipManager.value, isNull);
      expect(controller.hasLoadedVisits.value, isFalse);
    });
  });
}
