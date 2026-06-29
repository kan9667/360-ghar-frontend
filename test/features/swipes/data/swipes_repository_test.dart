// test/features/swipes/data/swipes_repository_test.dart
//
// Unit tests for [SwipesRepository]. Covers:
// - recordSwipe success
// - recordSwipe network failure enqueues to offline queue
// - recordSwipe queue failure rethrows

import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/controllers/offline_queue_service.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/utils/app_exceptions.dart';
import 'package:ghar360/features/swipes/data/swipes_repository.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/getx_test_binding.dart';
import '../../../helpers/mocks.dart';

class MockOfflineQueueService extends GetxServiceMock implements OfflineQueueService {}

void main() {
  late MockApiClient mockApiClient;
  late MockOfflineQueueService mockOfflineQueue;
  late SwipesRepository repository;

  setUp(() {
    GetxTestBinding.init();
    mockApiClient = MockApiClient();
    mockOfflineQueue = MockOfflineQueueService();

    GetxTestBinding.bind()
      ..register<ApiClient>(mockApiClient)
      ..register<OfflineQueueService>(mockOfflineQueue);

    repository = SwipesRepository();
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  group('SwipesRepository', () {
    // ── recordSwipe success ────────────────────────────────────────────

    test('recordSwipe completes successfully on valid API response', () async {
      when(
        () => mockApiClient.post('/swipes', body: any(named: 'body')),
      ).thenAnswer((_) async => ApiResponse(statusCode: 200, body: {}, headers: {}));

      await repository.recordSwipe(propertyId: 100, isLiked: true);

      verify(
        () => mockApiClient.post('/swipes', body: {'property_id': 100, 'is_liked': true}),
      ).called(1);
    });

    test('recordSwipe with isLiked=false sends correct payload', () async {
      when(
        () => mockApiClient.post('/swipes', body: any(named: 'body')),
      ).thenAnswer((_) async => ApiResponse(statusCode: 200, body: {}, headers: {}));

      await repository.recordSwipe(propertyId: 200, isLiked: false);

      verify(
        () => mockApiClient.post('/swipes', body: {'property_id': 200, 'is_liked': false}),
      ).called(1);
    });

    // ── recordSwipe network failure enqueues to offline queue ──────────

    test('recordSwipe enqueues to offline queue on NetworkException', () async {
      when(
        () => mockApiClient.post('/swipes', body: any(named: 'body')),
      ).thenThrow(NetworkException('No internet connection'));

      when(
        () => mockOfflineQueue.enqueueSwipe(
          propertyId: any(named: 'propertyId'),
          isLiked: any(named: 'isLiked'),
        ),
      ).thenAnswer((_) async {});

      // Should not throw — swallows network error after enqueueing
      await repository.recordSwipe(propertyId: 100, isLiked: true);

      verify(() => mockOfflineQueue.enqueueSwipe(propertyId: 100, isLiked: true)).called(1);
    });

    test('recordSwipe enqueues dislike on NetworkException', () async {
      when(
        () => mockApiClient.post('/swipes', body: any(named: 'body')),
      ).thenThrow(NetworkException('Connection refused'));

      when(
        () => mockOfflineQueue.enqueueSwipe(
          propertyId: any(named: 'propertyId'),
          isLiked: any(named: 'isLiked'),
        ),
      ).thenAnswer((_) async {});

      await repository.recordSwipe(propertyId: 50, isLiked: false);

      verify(() => mockOfflineQueue.enqueueSwipe(propertyId: 50, isLiked: false)).called(1);
    });

    // ── recordSwipe queue failure rethrows ─────────────────────────────

    test('recordSwipe rethrows when offline queue enqueue fails', () async {
      when(
        () => mockApiClient.post('/swipes', body: any(named: 'body')),
      ).thenThrow(NetworkException('Offline'));

      when(
        () => mockOfflineQueue.enqueueSwipe(
          propertyId: any(named: 'propertyId'),
          isLiked: any(named: 'isLiked'),
        ),
      ).thenThrow(Exception('Queue storage full'));

      expect(
        () => repository.recordSwipe(propertyId: 100, isLiked: true),
        throwsA(isA<Exception>()),
      );
    });

    // ── recordSwipe rethrows non-network AppExceptions ─────────────────

    test('recordSwipe rethrows non-network AppExceptions directly', () async {
      when(
        () => mockApiClient.post('/swipes', body: any(named: 'body')),
      ).thenThrow(AuthenticationException('Unauthorized'));

      expect(
        () => repository.recordSwipe(propertyId: 100, isLiked: true),
        throwsA(isA<AuthenticationException>()),
      );

      // Offline queue should NOT be called for non-network errors
      verifyNever(
        () => mockOfflineQueue.enqueueSwipe(
          propertyId: any(named: 'propertyId'),
          isLiked: any(named: 'isLiked'),
        ),
      );
    });
  });
}
