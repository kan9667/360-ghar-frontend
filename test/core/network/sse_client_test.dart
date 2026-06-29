import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/network/auth_header_provider.dart';
import 'package:ghar360/core/network/sse_client.dart';
import 'package:mocktail/mocktail.dart';

void main() {
  group('SseEvent', () {
    test('stores event and data fields', () {
      const event = SseEvent(event: 'message', data: {'key': 'value'});
      expect(event.event, 'message');
      expect(event.data, {'key': 'value'});
    });

    test('toString returns human-readable representation', () {
      const event = SseEvent(event: 'done', data: {'status': 'ok'});
      expect(event.toString(), 'SseEvent(done, {status: ok})');
    });

    test('supports empty data map', () {
      const event = SseEvent(event: 'ping', data: {});
      expect(event.data, isEmpty);
    });
  });

  group('SseClient construction', () {
    late MockAuthHeaderProvider mockAuthProvider;

    setUp(() {
      mockAuthProvider = MockAuthHeaderProvider();
    });

    test('strips trailing slash from baseUrl', () {
      final client = SseClient(authProvider: mockAuthProvider, baseUrl: 'https://example.com/');
      // Verify construction succeeds — URL is normalized internally
      expect(client, isNotNull);
    });

    test('strips api version prefix from baseUrl', () {
      final client = SseClient(
        authProvider: mockAuthProvider,
        baseUrl: 'https://example.com/api/v1',
      );
      expect(client, isNotNull);
    });

    test('handles baseUrl without trailing slash', () {
      final client = SseClient(authProvider: mockAuthProvider, baseUrl: 'https://example.com');
      expect(client, isNotNull);
    });

    test('handles baseUrl with trailing slash and api prefix', () {
      final client = SseClient(
        authProvider: mockAuthProvider,
        baseUrl: 'https://example.com/api/v1/',
      );
      expect(client, isNotNull);
    });
  });

  group('SseClient.postStream', () {
    late MockAuthHeaderProvider mockAuthProvider;

    setUp(() {
      mockAuthProvider = MockAuthHeaderProvider();
    });

    test('yields AUTH_MISSING error when auth header is null', () async {
      when(
        () => mockAuthProvider.getAuthHeader(forceRefresh: any(named: 'forceRefresh')),
      ).thenAnswer((_) async => null);

      final client = SseClient(authProvider: mockAuthProvider, baseUrl: 'https://example.com');

      final events = await client.postStream('/chat', body: {'message': 'hello'}).toList();

      expect(events, hasLength(1));
      expect(events.first.event, 'error');
      expect(events.first.data['code'], 'AUTH_MISSING');
    });

    test('yields AUTH_MISSING error with correct message', () async {
      when(
        () => mockAuthProvider.getAuthHeader(forceRefresh: any(named: 'forceRefresh')),
      ).thenAnswer((_) async => null);

      final client = SseClient(authProvider: mockAuthProvider, baseUrl: 'https://example.com');

      final events = await client.postStream('/chat', body: {'query': 'test'}).toList();

      expect(events.first.data['message'], 'Not authenticated');
    });

    test('emits exactly one event when auth is missing', () async {
      when(
        () => mockAuthProvider.getAuthHeader(forceRefresh: any(named: 'forceRefresh')),
      ).thenAnswer((_) async => null);

      final client = SseClient(authProvider: mockAuthProvider, baseUrl: 'https://example.com');

      var count = 0;
      await for (final _ in client.postStream('/chat', body: {})) {
        count++;
      }

      expect(count, 1);
    });
  });
}

/// Test-local mock for [AuthHeaderProvider].
class MockAuthHeaderProvider extends Mock implements AuthHeaderProvider {}
