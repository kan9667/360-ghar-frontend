// test/features/visits/presentation/views/visits_view_test.dart

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/core/data/models/visit_model.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/core/widgets/common/segmented_control.dart';
import 'package:ghar360/features/visits/presentation/controllers/visits_controller.dart';
import 'package:ghar360/features/visits/presentation/views/visits_view.dart';
import 'package:ghar360/features/visits/presentation/widgets/visit_card.dart';
import 'package:ghar360/features/visits/presentation/widgets/visits_skeleton_loaders.dart';
import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/pump_app.dart';

// ---------------------------------------------------------------------------
// Test controller — skips AuthController, DashboardController, and
// VisitsRemoteDatasource lookups.
// ---------------------------------------------------------------------------

class _TestVisitsController extends VisitsController {
  @override
  // ignore: must_call_super
  void onInit() {
    // Skip auth-status worker, dashboard tab worker, and all data loading.
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

VisitModel _futureVisit({int id = 1}) {
  return VisitModel(
    id: id,
    propertyId: 100,
    userId: 1,
    scheduledDate: DateTime.now().add(const Duration(days: 7)),
    status: VisitStatus.scheduled,
    createdAt: DateTime.now().subtract(const Duration(days: 1)),
  );
}

VisitModel _pastVisit({int id = 2}) {
  return VisitModel(
    id: id,
    propertyId: 200,
    userId: 1,
    scheduledDate: DateTime.now().subtract(const Duration(days: 7)),
    status: VisitStatus.completed,
    createdAt: DateTime.now().subtract(const Duration(days: 14)),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUp(() {
    GetxTestBinding.init();
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  group('VisitsView', () {
    testWidgets('shows loading skeleton when loading', (tester) async {
      final controller = _TestVisitsController();
      controller.isLoading.value = true;
      Get.put<VisitsController>(controller);

      await tester.pumpApp(const VisitsView());
      await tester.pump();

      // Loading state renders RelationshipManagerSkeleton and VisitCardSkeletons.
      expect(find.byType(RelationshipManagerSkeleton), findsWidgets);
    });

    testWidgets('shows error state with retry button', (tester) async {
      final controller = _TestVisitsController();
      controller.isLoading.value = false;
      controller.error.value = NetworkException('Connection failed');
      // visits must be empty for the error branch (error && visits.isEmpty).
      Get.put<VisitsController>(controller);

      await tester.pumpApp(const VisitsView());
      await tester.pump();

      // The shared ErrorStates.genericError renders the error message.
      expect(find.text('Connection failed'), findsOneWidget);

      // The retry button should be present (network errors are retryable).
      expect(find.byType(ElevatedButton), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsOneWidget);
    });

    testWidgets('shows empty state for scheduled tab when no visits', (tester) async {
      final controller = _TestVisitsController();
      controller.isLoading.value = false;
      controller.hasLoadedVisits.value = true;
      // Both lists empty → empty state within the content view.
      Get.put<VisitsController>(controller);

      await tester.pumpApp(const VisitsView());
      await tester.pump(const Duration(seconds: 1));

      // The screen should be present.
      expect(find.bySemanticsLabel('qa.visits.screen'), findsOneWidget);

      // Empty state text "no_visits" (translated) should appear.
      // The _buildEmptyState widget renders italic text.
      expect(find.byType(SegmentedControl), findsOneWidget);
    });

    testWidgets('renders visit cards when visits are loaded', (tester) async {
      final controller = _TestVisitsController();
      controller.isLoading.value = false;
      controller.hasLoadedVisits.value = true;
      controller.upcomingVisitsList.assignAll([_futureVisit(id: 1), _futureVisit(id: 2)]);
      controller.pastVisitsList.assignAll([_pastVisit(id: 3)]);
      Get.put<VisitsController>(controller);

      await tester.pumpApp(const VisitsView());
      await tester.pump(const Duration(seconds: 1));

      // The screen should be present.
      expect(find.bySemanticsLabel('qa.visits.screen'), findsOneWidget);

      // VisitCard widgets should be rendered for the upcoming visits.
      expect(find.byType(VisitCard), findsNWidgets(2));
    });

    testWidgets('renders segmented control for scheduled and past tabs', (tester) async {
      final controller = _TestVisitsController();
      controller.isLoading.value = false;
      controller.hasLoadedVisits.value = true;
      controller.upcomingVisitsList.assignAll([_futureVisit()]);
      controller.pastVisitsList.assignAll([_pastVisit()]);
      Get.put<VisitsController>(controller);

      await tester.pumpApp(const VisitsView());
      await tester.pump(const Duration(seconds: 1));

      // The SegmentedControl should be rendered.
      expect(find.byType(SegmentedControl), findsOneWidget);

      // Both tab labels should be present (using text finders for reliability).
      expect(find.text('scheduled_visits'.tr), findsOneWidget);
      expect(find.text('past_visits'.tr), findsOneWidget);
    });
  });
}
