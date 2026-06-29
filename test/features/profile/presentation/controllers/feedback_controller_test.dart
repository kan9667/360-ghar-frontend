import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/data/models/bug_report_model.dart';
import 'package:ghar360/features/profile/data/support_repository.dart';
import 'package:ghar360/features/profile/presentation/controllers/feedback_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/mocks.dart';

// ---------------------------------------------------------------------------
// Inline mock for SupportRepository (not in shared mocks file)
// ---------------------------------------------------------------------------

class MockSupportRepository extends GetxServiceMock implements SupportRepository {}

// ---------------------------------------------------------------------------
// Fallback value for BugReportRequest (required by mocktail's `any()` matcher)
// ---------------------------------------------------------------------------

class _FakeBugReportRequest extends Fake implements BugReportRequest {}

void main() {
  late MockSupportRepository mockSupportRepository;

  setUpAll(() {
    registerFallbackValue(_FakeBugReportRequest());
  });

  setUp(() {
    GetxTestBinding.init();
    mockSupportRepository = MockSupportRepository();
    GetxTestBinding.bind().register<SupportRepository>(mockSupportRepository);
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  FeedbackController createController() {
    final c = FeedbackController(supportRepository: mockSupportRepository);
    c.onInit();
    return c;
  }

  group('FeedbackController', () {
    test('initial state has default bug type and severity', () {
      final controller = createController();

      expect(controller.selectedBugType.value, BugType.uiBug);
      expect(controller.selectedSeverity.value, BugSeverity.medium);
      expect(controller.isSubmitting.value, isFalse);
    });

    test('setBugType updates selectedBugType', () {
      final controller = createController();

      controller.setBugType(BugType.performanceIssue);
      expect(controller.selectedBugType.value, BugType.performanceIssue);
    });

    test('setBugType ignores null', () {
      final controller = createController();

      controller.setBugType(null);
      expect(controller.selectedBugType.value, BugType.uiBug);
    });

    test('setSeverity updates selectedSeverity', () {
      final controller = createController();

      controller.setSeverity(BugSeverity.critical);
      expect(controller.selectedSeverity.value, BugSeverity.critical);
    });

    test('setSeverity ignores null', () {
      final controller = createController();

      controller.setSeverity(null);
      expect(controller.selectedSeverity.value, BugSeverity.medium);
    });

    test('submitFeedback skips when already submitting', () async {
      final controller = createController();
      controller.isSubmitting.value = true;

      await controller.submitFeedback();

      verifyNever(() => mockSupportRepository.submitBugReport(any()));
    });

    test('submitFeedback returns early when formKey.currentState is null', () async {
      final controller = createController();
      controller.titleController.text = 'App crashes on launch';
      controller.descriptionController.text = 'Steps to reproduce';

      await controller.submitFeedback();

      // formKey.currentState is null → validation early return, repository untouched
      verifyNever(() => mockSupportRepository.submitBugReport(any()));
      expect(controller.isSubmitting.value, isFalse);
    });

    test('formKey is initialized and text controllers are empty by default', () {
      final controller = createController();

      expect(controller.formKey, isNotNull);
      expect(controller.titleController.text, '');
      expect(controller.descriptionController.text, '');
      expect(controller.stepsController.text, '');
      expect(controller.expectedController.text, '');
      expect(controller.actualController.text, '');
      expect(controller.tagsController.text, '');
    });
  });
}
