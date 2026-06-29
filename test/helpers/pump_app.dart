// test/helpers/pump_app.dart
//
// Helper to pump a widget wrapped in the standard app shell for widget tests.
// Provides GetMaterialApp with translations, theme, and locale configured.

import 'package:flutter/material.dart';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:ghar360/core/translations/app_translations.dart';

/// Extension on [WidgetTester] to provide a convenient [pumpApp] method
/// that wraps the widget under test in a [GetMaterialApp] with all
/// required app-level configuration.
extension PumpApp on WidgetTester {
  /// Pumps [widget] inside a fully-configured [GetMaterialApp].
  ///
  /// [initialRoute] defaults to '/'.
  /// [bindings] can be used to register GetX dependencies before pump.
  Future<void> pumpApp(
    Widget widget, {
    String? initialRoute,
    ThemeData? theme,
    Locale? locale,
  }) async {
    await pumpWidget(
      GetMaterialApp(
        translations: AppTranslations(),
        locale: locale ?? const Locale('en', 'US'),
        fallbackLocale: const Locale('en', 'US'),
        theme: theme ?? ThemeData.light(),
        initialRoute: initialRoute,
        home: widget,
      ),
    );
  }

  /// Pumps the widget and waits for all animations and async work to settle.
  Future<void> pumpAndSettleApp(
    Widget widget, {
    String? initialRoute,
    ThemeData? theme,
    Locale? locale,
  }) async {
    await pumpApp(widget, initialRoute: initialRoute, theme: theme, locale: locale);
    await pumpAndSettle();
  }
}
