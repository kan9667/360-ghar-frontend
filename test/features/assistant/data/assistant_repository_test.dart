import 'package:flutter_test/flutter_test.dart';
import 'package:ghar360/core/network/api_client.dart';
import 'package:ghar360/core/network/sse_client.dart';
import 'package:ghar360/features/assistant/data/assistant_repository.dart';
import 'package:ghar360/features/assistant/data/models/chat_message_model.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/getx_test_binding.dart';
import '../../../helpers/mocks.dart';

void main() {
  late MockApiClient mockApiClient;
  late MockSseClient mockSseClient;
  late AssistantRepository repository;

  setUp(() {
    GetxTestBinding.init();
    mockApiClient = MockApiClient();
    mockSseClient = MockSseClient();
    GetxTestBinding.bind()
      ..register<ApiClient>(mockApiClient)
      ..register<SseClient>(mockSseClient);
    repository = AssistantRepository();
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  /// Convenience helper: builds an [ApiResponse] with the given body.
  ApiResponse mockResponse(dynamic body) {
    return ApiResponse(statusCode: 200, body: body, headers: {});
  }

  group('AssistantRepository', () {
    // ── getConversations propagates errors (not swallowed) ────────────────

    test('getConversations propagates exceptions from ApiClient', () async {
      when(
        () => mockApiClient.get('/agent/conversations', queryParams: any(named: 'queryParams')),
      ).thenThrow(Exception('Server error'));

      expect(() => repository.getConversations(), throwsA(isA<Exception>()));
    });

    // ── getConversations with cursor envelope ─────────────────────────────

    test('getConversations parses cursor envelope correctly', () async {
      when(
        () => mockApiClient.get('/agent/conversations', queryParams: any(named: 'queryParams')),
      ).thenAnswer(
        (_) async => mockResponse({
          'items': [
            {
              'id': 1,
              'title': 'First',
              'created_at': '2024-01-01T00:00:00Z',
              'updated_at': '2024-01-02T00:00:00Z',
              'message_count': 5,
            },
            {
              'id': 2,
              'title': 'Second',
              'created_at': '2024-01-03T00:00:00Z',
              'updated_at': '2024-01-04T00:00:00Z',
              'message_count': 10,
            },
          ],
          'has_more': true,
          'next_cursor': 'cursor_abc',
        }),
      );

      final page = await repository.getConversations();

      expect(page.items.length, 2);
      expect(page.items[0].title, 'First');
      expect(page.items[1].title, 'Second');
      expect(page.hasMore, isTrue);
      expect(page.nextCursor, 'cursor_abc');
    });

    // ── getConversationMessages ───────────────────────────────────────────

    test('getConversationMessages returns parsed messages on success', () async {
      when(() => mockApiClient.get('/agent/conversations/7/messages?limit=100')).thenAnswer(
        (_) async => mockResponse([
          {'id': 'msg1', 'role': 'user', 'content': 'Hello', 'created_at': '2024-01-01T00:00:00Z'},
          {
            'id': 'msg2',
            'role': 'assistant',
            'content': 'Hi there!',
            'created_at': '2024-01-01T00:00:01Z',
          },
        ]),
      );

      final messages = await repository.getConversationMessages(7);

      expect(messages.length, 2);
      expect(messages[0].role, ChatRole.user);
      expect(messages[0].content, 'Hello');
      expect(messages[1].role, ChatRole.assistant);
      expect(messages[1].content, 'Hi there!');
    });

    // ── getConversationMessages returns [] on error ───────────────────────

    test('getConversationMessages returns empty list on error', () async {
      when(() => mockApiClient.get(any())).thenThrow(Exception('Network error'));

      final messages = await repository.getConversationMessages(99);

      expect(messages, isEmpty);
    });

    // ── deleteConversation returns true on success ───────────────────────

    test('deleteConversation returns true on success', () async {
      when(
        () => mockApiClient.delete('/agent/conversations/15'),
      ).thenAnswer((_) async => mockResponse(null));

      final result = await repository.deleteConversation(15);

      expect(result, isTrue);
      verify(() => mockApiClient.delete('/agent/conversations/15')).called(1);
    });

    // ── deleteConversation returns false on error ─────────────────────────

    test('deleteConversation returns false on error', () async {
      when(
        () => mockApiClient.delete('/agent/conversations/15'),
      ).thenThrow(Exception('Delete failed'));

      final result = await repository.deleteConversation(15);

      expect(result, isFalse);
    });

    // ── widgetHtmlCache caches successes ──────────────────────────────────

    test('getWidgetHtml caches successful response', () async {
      when(
        () => mockApiClient.get('/agent/widgets/map_widget'),
      ).thenAnswer((_) async => mockResponse('<div>Map</div>'));

      // First call — should hit the API.
      final result1 = await repository.getWidgetHtml('map_widget');
      expect(result1, '<div>Map</div>');

      // Second call — should return cached value without another API call.
      final result2 = await repository.getWidgetHtml('map_widget');
      expect(result2, '<div>Map</div>');

      // Only one network call should have been made.
      verify(() => mockApiClient.get('/agent/widgets/map_widget')).called(1);
    });

    // ── widgetHtmlCache does NOT cache failures ───────────────────────────

    test('getWidgetHtml does not cache failures, allows retry', () async {
      when(
        () => mockApiClient.get('/agent/widgets/failing_widget'),
      ).thenThrow(Exception('Server error'));

      // First call — fails.
      final result1 = await repository.getWidgetHtml('failing_widget');
      expect(result1, isNull);

      // Set up a successful response for the retry.
      when(
        () => mockApiClient.get('/agent/widgets/failing_widget'),
      ).thenAnswer((_) async => mockResponse('<div>Recovered</div>'));

      // Second call — should retry (not return cached null).
      final result2 = await repository.getWidgetHtml('failing_widget');
      expect(result2, '<div>Recovered</div>');

      // Two network calls should have been made (failure + retry).
      verify(() => mockApiClient.get('/agent/widgets/failing_widget')).called(2);
    });

    // ── getConversations with bare list response (legacy format) ──────────

    test('getConversations handles bare list response (legacy format)', () async {
      when(
        () => mockApiClient.get('/agent/conversations', queryParams: any(named: 'queryParams')),
      ).thenAnswer(
        (_) async => mockResponse([
          {
            'id': 1,
            'title': 'Legacy conversation',
            'created_at': '2024-01-01T00:00:00Z',
            'updated_at': '2024-01-01T00:00:00Z',
            'message_count': 1,
          },
        ]),
      );

      final page = await repository.getConversations();

      expect(page.items.length, 1);
      expect(page.items[0].title, 'Legacy conversation');
      // Bare list → treated as terminal page (no more, no cursor).
      expect(page.hasMore, isFalse);
      expect(page.nextCursor, isNull);
    });
  });
}
