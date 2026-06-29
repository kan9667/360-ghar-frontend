// test/features/splash/presentation/views/splash_view_test.dart

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/features/splash/presentation/controllers/splash_controller.dart';
import 'package:ghar360/features/splash/presentation/views/splash_view.dart';
import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/mocks.dart';
import '../../../../helpers/pump_app.dart';

// ---------------------------------------------------------------------------
// Test controller stub — avoids GetStorage and AnimationController by
// providing pre-built animations without touching the real lifecycle.
// Uses GetxServiceMock to avoid the parent SplashController constructor
// which creates GetStorage (pending timer) and GetTickerProviderStateMixin.
// ---------------------------------------------------------------------------

class _TestSplashController extends GetxServiceMock implements SplashController {
  bool skippedToHome = false;
  bool nextStepCalled = false;
  bool previousStepCalled = false;

  @override
  PageController? pageController = PageController();

  @override
  Animation<double>? fadeAnimation = const AlwaysStoppedAnimation<double>(1.0);

  @override
  Animation<Offset>? slideAnimation = const AlwaysStoppedAnimation<Offset>(Offset.zero);

  @override
  Animation<double>? scaleAnimation = const AlwaysStoppedAnimation<double>(1.0);

  @override
  Animation<double>? rotationAnimation = const AlwaysStoppedAnimation<double>(1.0);

  @override
  final RxInt currentStep = 0.obs;

  @override
  void skipToHome() {
    skippedToHome = true;
  }

  @override
  void nextStep() {
    nextStepCalled = true;
    if (currentStep.value < 2) {
      currentStep.value++;
    }
  }

  @override
  void previousStep() {
    previousStepCalled = true;
    if (currentStep.value > 0) {
      currentStep.value--;
    }
  }

  @override
  void onClose() {
    pageController?.dispose();
  }
}

/// A controller whose animations are null, triggering the loading spinner.
class _NullAnimationsSplashController extends GetxServiceMock implements SplashController {
  @override
  final RxInt currentStep = 0.obs;
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

  group('SplashView', () {
    testWidgets('shows CircularProgressIndicator when animations are null', (tester) async {
      final controller = _NullAnimationsSplashController();
      Get.put<SplashController>(controller);

      await tester.pumpApp(const SplashView());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('renders first onboarding slide when animations are ready', (tester) async {
      final controller = _TestSplashController();
      Get.put<SplashController>(controller);

      await tester.pumpApp(const SplashView());
      await tester.pump(const Duration(seconds: 1));

      // The scaffold with the splash key should be present.
      expect(find.byKey(const ValueKey('qa.splash.screen')), findsOneWidget);

      // The PageView (which hosts slides) is rendered.
      expect(find.byType(PageView), findsOneWidget);

      // The bottom dock with line indicators should be visible.
      expect(find.byKey(const ValueKey('qa.splash.skip')), findsOneWidget);
    });

    testWidgets('skip button is visible and triggers skipToHome', (tester) async {
      final controller = _TestSplashController();
      Get.put<SplashController>(controller);

      await tester.pumpApp(const SplashView());
      await tester.pump(const Duration(seconds: 1));

      final skipButton = find.byKey(const ValueKey('qa.splash.skip'));
      expect(skipButton, findsOneWidget);

      await tester.tap(skipButton);
      await tester.pump();

      expect(controller.skippedToHome, isTrue);
    });

    testWidgets('next button advances currentStep on first slide', (tester) async {
      final controller = _TestSplashController();
      Get.put<SplashController>(controller);

      await tester.pumpApp(const SplashView());
      await tester.pump(const Duration(seconds: 1));

      // On the first slide, currentStep should be 0.
      expect(controller.currentStep.value, 0);

      // The next button should be visible (first slide shows Next, not Get Started).
      final nextButton = find.byKey(const ValueKey('qa.splash.next'));
      expect(nextButton, findsOneWidget);

      await tester.tap(nextButton);
      await tester.pump();

      expect(controller.nextStepCalled, isTrue);
      expect(controller.currentStep.value, 1);
    });

    testWidgets('back button appears after advancing past first slide', (tester) async {
      final controller = _TestSplashController();
      Get.put<SplashController>(controller);

      await tester.pumpApp(const SplashView());
      await tester.pump(const Duration(seconds: 1));

      // On the first slide, the back button should NOT be visible.
      expect(find.bySemanticsLabel('qa.splash.back'), findsNothing);

      // Advance to slide 2.
      controller.currentStep.value = 1;
      await tester.pump();

      // Now the back button should appear (use semantics label to avoid
      // key duplication between the wrapper and inner button).
      expect(find.bySemanticsLabel('qa.splash.back'), findsOneWidget);
    });
  });
}
