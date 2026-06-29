// test/features/profile/data/static_page_repository_test.dart
//
// Unit tests for [StaticPageRepository.fetchPublicPage].
// Registers a [MockApiClient] in the GetX container so the real
// [StaticPageRepository] can resolve it during construction.

import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/network/api_paths.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/profile/data/static_page_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/getx_test_binding.dart';
import '../../../helpers/mocks.dart';

void main() {
  late MockApiClient apiClient;
  late StaticPageRepository repository;

  setUp(() {
    GetxTestBinding.init();
    apiClient = MockApiClient();
    GetxTestBinding.bind().register<ApiClient>(apiClient);
    repository = StaticPageRepository();
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  group('fetchPublicPage', () {
    test('returns StaticPageModel on success', () async {
      when(
        () => apiClient.get(
          ApiPaths.staticPagePublic('about-us'),
          useCache: any(named: 'useCache'),
          requireAuth: any(named: 'requireAuth'),
          notifyUnauthorized: any(named: 'notifyUnauthorized'),
        ),
      ).thenAnswer(
        (_) async => ApiResponse(
          statusCode: 200,
          body: {'title': 'About Us', 'content': '<p>Welcome</p>'},
          headers: {},
        ),
      );

      final page = await repository.fetchPublicPage('about-us');

      expect(page.title, 'About Us');
      expect(page.content, '<p>Welcome</p>');
    });

    test('unwraps data envelope before parsing', () async {
      when(
        () => apiClient.get(
          ApiPaths.staticPagePublic('terms'),
          useCache: any(named: 'useCache'),
          requireAuth: any(named: 'requireAuth'),
          notifyUnauthorized: any(named: 'notifyUnauthorized'),
        ),
      ).thenAnswer(
        (_) async => ApiResponse(
          statusCode: 200,
          body: {
            'data': {'title': 'Terms', 'content': 'Terms text'},
          },
          headers: {},
        ),
      );

      final page = await repository.fetchPublicPage('terms');
      expect(page.title, 'Terms');
    });

    test('uses fallbackTitle when response has no title field', () async {
      when(
        () => apiClient.get(
          ApiPaths.staticPagePublic('privacy'),
          useCache: any(named: 'useCache'),
          requireAuth: any(named: 'requireAuth'),
          notifyUnauthorized: any(named: 'notifyUnauthorized'),
        ),
      ).thenAnswer(
        (_) async => ApiResponse(statusCode: 200, body: {'content': 'Privacy text'}, headers: {}),
      );

      final page = await repository.fetchPublicPage('privacy');
      expect(page.title, 'privacy'); // fallbackTitle
      expect(page.content, 'Privacy text');
    });

    test('throws NotFoundException on 404', () async {
      when(
        () => apiClient.get(
          ApiPaths.staticPagePublic('missing'),
          useCache: any(named: 'useCache'),
          requireAuth: any(named: 'requireAuth'),
          notifyUnauthorized: any(named: 'notifyUnauthorized'),
        ),
      ).thenThrow(NotFoundException('Not found'));

      expect(() => repository.fetchPublicPage('missing'), throwsA(isA<NotFoundException>()));
    });

    test('rethrows ServerException on server error', () async {
      when(
        () => apiClient.get(
          ApiPaths.staticPagePublic('about-us'),
          useCache: any(named: 'useCache'),
          requireAuth: any(named: 'requireAuth'),
          notifyUnauthorized: any(named: 'notifyUnauthorized'),
        ),
      ).thenThrow(ServerException('Internal error', statusCode: 500));

      expect(() => repository.fetchPublicPage('about-us'), throwsA(isA<ServerException>()));
    });
  });
}
