import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:get_storage/get_storage.dart';
import 'package:ghar360/core/controllers/localization_controller.dart';
import 'package:ghar360/core/controllers/theme_controller.dart';
import 'package:ghar360/features/profile/data/profile_repository.dart';
import 'package:ghar360/features/profile/presentation/controllers/preferences_controller.dart';
import 'package:mocktail/mocktail.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/mocks.dart';

// ---------------------------------------------------------------------------
// Fake path_provider so GetStorage can initialise in tests
// ---------------------------------------------------------------------------

class _FakePathProviderPlatform extends PathProviderPlatform {
  _FakePathProviderPlatform(this._path);
  final String _path;

  @override
  Future<String?> getApplicationDocumentsPath() async => _path;
}

// ---------------------------------------------------------------------------
// Inline mocks for controllers not covered by the shared mocks file
// ---------------------------------------------------------------------------

class MockThemeController extends GetxServiceMock implements ThemeController {
  final Rx<AppThemeMode> _mode = AppThemeMode.system.obs;

  @override
  AppThemeMode get currentThemeMode => _mode.value;

  @override
  void setThemeMode(AppThemeMode mode) {
    _mode.value = mode;
  }
}

class MockLocalizationController extends GetxServiceMock implements LocalizationController {
  @override
  void changeLanguage(String languageCode, String countryCode) {}

  @override
  String getCurrentLanguageName() => 'English';
}

void main() {
  late MockThemeController mockThemeController;
  late MockLocalizationController mockLocalizationController;
  late MockProfileRepository mockProfileRepository;
  late Directory tempDir;

  setUp(() async {
    // Create a temp directory for GetStorage
    tempDir = await Directory.systemTemp.createTemp('get_storage_test_');
    PathProviderPlatform.instance = _FakePathProviderPlatform(tempDir.path);

    GetxTestBinding.init();
    await GetStorage.init();

    mockThemeController = MockThemeController();
    mockLocalizationController = MockLocalizationController();
    mockProfileRepository = MockProfileRepository();

    GetxTestBinding.bind()
      ..register<ThemeController>(mockThemeController)
      ..register<LocalizationController>(mockLocalizationController)
      ..register<ProfileRepository>(mockProfileRepository);
  });

  tearDown(() async {
    GetxTestBinding.reset();
    // Clean up temp directory
    try {
      await tempDir.delete(recursive: true);
    } catch (_) {}
  });

  PreferencesController createController() {
    final c = PreferencesController();
    c.onInit();
    return c;
  }

  group('PreferencesController', () {
    test('defaults notification toggles to true when storage is empty', () {
      final controller = createController();

      expect(controller.pushNotifications.value, isTrue);
      expect(controller.emailNotifications.value, isTrue);
      expect(controller.similarProperties.value, isTrue);
    });

    test('themeMode defaults to ThemeController.currentThemeMode on init', () {
      final controller = createController();

      expect(controller.themeMode.value, AppThemeMode.system);
    });

    test('updateTheme delegates to ThemeController and persists immediately', () {
      final controller = createController();

      controller.updateTheme(AppThemeMode.dark);

      // Controller's own observable is updated
      expect(controller.themeMode.value, AppThemeMode.dark);
      // ThemeController mock received the change (state-based check)
      expect(mockThemeController.currentThemeMode, AppThemeMode.dark);
    });

    test('updateThemeFromBoolean maps true to dark and false to light', () {
      final controller = createController();

      controller.updateThemeFromBoolean(true);
      expect(controller.themeMode.value, AppThemeMode.dark);
      expect(mockThemeController.currentThemeMode, AppThemeMode.dark);

      controller.updateThemeFromBoolean(false);
      expect(controller.themeMode.value, AppThemeMode.light);
      expect(mockThemeController.currentThemeMode, AppThemeMode.light);
    });

    test('savePreferences syncs notification toggles to backend', () async {
      final controller = createController();

      controller.pushNotifications.value = false;
      controller.emailNotifications.value = true;
      controller.similarProperties.value = false;

      when(
        () => mockProfileRepository.updateUserPreferences(any()),
      ).thenAnswer((_) async => testUserModel());

      // savePreferences() is declared `void` (not Future<void>), so we
      // cannot await it directly. The async body runs as a microtask.
      controller.savePreferences();
      // Flush the microtask queue so the async body completes.
      await Future(() {});

      verify(
        () => mockProfileRepository.updateUserPreferences({
          'push_notifications': false,
          'email_notifications': true,
          'similar_properties': false,
        }),
      ).called(1);
    });

    test('savePreferences calls ThemeController.setThemeMode with current theme', () async {
      final controller = createController();
      controller.themeMode.value = AppThemeMode.light;

      when(
        () => mockProfileRepository.updateUserPreferences(any()),
      ).thenAnswer((_) async => testUserModel());

      controller.savePreferences();
      await Future(() {});

      // ThemeController mock received the light mode via savePreferences
      expect(mockThemeController.currentThemeMode, AppThemeMode.light);
    });

    test('currentThemeNameKey returns correct key for each mode', () {
      final controller = createController();

      controller.themeMode.value = AppThemeMode.light;
      expect(controller.currentThemeNameKey, 'light_mode');

      controller.themeMode.value = AppThemeMode.dark;
      expect(controller.currentThemeNameKey, 'dark_mode');

      controller.themeMode.value = AppThemeMode.system;
      expect(controller.currentThemeNameKey, 'system_mode');
    });

    test('convenience getters reflect the current values', () {
      final controller = createController();

      controller.pushNotifications.value = false;
      expect(controller.isPushNotificationsEnabled, isFalse);

      controller.emailNotifications.value = true;
      expect(controller.isEmailNotificationsEnabled, isTrue);

      controller.similarProperties.value = false;
      expect(controller.isSimilarPropertiesEnabled, isFalse);

      controller.themeMode.value = AppThemeMode.dark;
      expect(controller.currentThemeMode, AppThemeMode.dark);
    });
  });
}
