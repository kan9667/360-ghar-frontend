// test/features/profile/data/support_repository_test.dart
//
// Unit tests for [SupportRepository.submitBugReport].
// Registers a [MockApiClient] in the GetX container so the real
// [SupportRepository] can resolve it during construction.

import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/data/models/bug_report_model.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/network/api_paths.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/profile/data/support_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/getx_test_binding.dart';
import '../../../helpers/mocks.dart';

void main() {
  late MockApiClient apiClient;
  late SupportRepository repository;

  setUp(() {
    GetxTestBinding.init();
    apiClient = MockApiClient();
    GetxTestBinding.bind().register<ApiClient>(apiClient);
    repository = SupportRepository();
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  BugReportRequest sampleRequest() => const BugReportRequest(
    source: 'app',
    bugType: BugType.uiBug,
    severity: BugSeverity.medium,
    title: 'Crash on detail page',
    description: 'Tapping the gallery crashes the app.',
  );

  Map<String, dynamic> sampleResponseJson() => {
    'id': 42,
    'source': 'app',
    'bug_type': 'ui_bug',
    'severity': 'medium',
    'status': 'open',
    'title': 'Crash on detail page',
    'description': 'Tapping the gallery crashes the app.',
  };

  group('submitBugReport', () {
    test('returns BugReportResponse on success', () async {
      when(() => apiClient.post(ApiPaths.bugs, body: any(named: 'body'))).thenAnswer(
        (_) async => ApiResponse(statusCode: 201, body: sampleResponseJson(), headers: {}),
      );

      final response = await repository.submitBugReport(sampleRequest());

      expect(response.id, 42);
      expect(response.title, 'Crash on detail page');
      expect(response.bugType, BugType.uiBug);
      verify(() => apiClient.post(ApiPaths.bugs, body: any(named: 'body'))).called(1);
    });

    test('unwraps data envelope before parsing', () async {
      when(() => apiClient.post(ApiPaths.bugs, body: any(named: 'body'))).thenAnswer(
        (_) async =>
            ApiResponse(statusCode: 201, body: {'data': sampleResponseJson()}, headers: {}),
      );

      final response = await repository.submitBugReport(sampleRequest());
      expect(response.id, 42);
    });

    test('throws ServerException when response payload is empty', () async {
      when(() => apiClient.post(ApiPaths.bugs, body: any(named: 'body'))).thenAnswer(
        (_) async => ApiResponse(statusCode: 200, body: <String, dynamic>{}, headers: {}),
      );

      // The FormatException from ResponseParser is caught and wrapped in
      // ServerException by the catch-all handler in submitBugReport.
      expect(() => repository.submitBugReport(sampleRequest()), throwsA(isA<ServerException>()));
    });

    test('rethrows AppException from API client', () async {
      when(
        () => apiClient.post(ApiPaths.bugs, body: any(named: 'body')),
      ).thenThrow(ServerException('Server down', statusCode: 503));

      expect(() => repository.submitBugReport(sampleRequest()), throwsA(isA<ServerException>()));
    });

    test('wraps unexpected errors in ServerException', () async {
      when(
        () => apiClient.post(ApiPaths.bugs, body: any(named: 'body')),
      ).thenThrow(Exception('unexpected'));

      expect(() => repository.submitBugReport(sampleRequest()), throwsA(isA<ServerException>()));
    });
  });
}
