import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:ghar360/core/network/sse_client.dart';
import 'package:ghar360/features/assistant/data/assistant_repository.dart';
import 'package:ghar360/features/assistant/data/models/chat_message_model.dart';
import 'package:ghar360/features/assistant/data/models/conversation_model.dart';
import 'package:ghar360/features/assistant/presentation/controllers/assistant_controller.dart';
import 'package:mocktail/mocktail.dart';

import '../../../../helpers/getx_test_binding.dart';
import '../../../../helpers/mocks.dart';

void main() {
  late MockAssistantRepository mockRepository;
  late MockSseClient mockSseClient;

  setUp(() {
    GetxTestBinding.init();
    mockRepository = MockAssistantRepository();
    mockSseClient = MockSseClient();
    GetxTestBinding.bind()
      ..register<AssistantRepository>(mockRepository)
      ..register<SseClient>(mockSseClient);
  });

  tearDown(() {
    GetxTestBinding.reset();
  });

  AssistantController createController() {
    final c = AssistantController();
    c.onInit();
    return c;
  }

  /// Creates a [ConversationModel] with sensible defaults for tests.
  ConversationModel testConversation({required int id, String? title, int messageCount = 0}) {
    return ConversationModel(
      id: id,
      title: title ?? 'Conversation $id',
      createdAt: DateTime(2024, 1, id),
      updatedAt: DateTime(2024, 1, id),
      messageCount: messageCount,
    );
  }

  group('AssistantController', () {
    // ── sendMessage ─────────────────────────────────────────────────────

    test('sendMessage adds user message and assistant placeholder, sets streaming', () {
      final streamController = StreamController<SseEvent>();
      when(
        () => mockRepository.streamChat(message: 'hello', conversationId: null),
      ).thenAnswer((_) => streamController.stream);

      final controller = createController();
      controller.sendMessage('hello');

      expect(controller.messages.length, 2);
      expect(controller.messages[0].role, ChatRole.user);
      expect(controller.messages[0].content, 'hello');
      expect(controller.messages[1].role, ChatRole.assistant);
      expect(controller.messages[1].isStreaming, isTrue);
      expect(controller.isStreaming.value, isTrue);

      streamController.close();
    });

    // ── selectConversation (success) ─────────────────────────────────────

    test('selectConversation loads messages on success', () async {
      final msgs = [
        ChatMessageModel(
          id: '1',
          role: ChatRole.user,
          content: 'Hi',
          timestamp: DateTime(2024, 1, 1),
        ),
        ChatMessageModel(
          id: '2',
          role: ChatRole.assistant,
          content: 'Hello!',
          timestamp: DateTime(2024, 1, 2),
        ),
      ];
      when(() => mockRepository.getConversationMessages(5)).thenAnswer((_) async => msgs);

      final controller = createController();
      await controller.selectConversation(5);

      expect(controller.conversationId.value, 5);
      expect(controller.messages.length, 2);
      expect(controller.messages[0].content, 'Hi');
      expect(controller.messages[1].content, 'Hello!');
    });

    // ── selectConversation (error) ───────────────────────────────────────

    test('selectConversation handles error gracefully', () async {
      when(() => mockRepository.getConversationMessages(99)).thenThrow(Exception('Network error'));

      final controller = createController();
      await controller.selectConversation(99);

      // conversationId is set even on error.
      expect(controller.conversationId.value, 99);
      // Messages are cleared then error returns [] from repository.
      expect(controller.messages, isEmpty);
    });

    // ── loadConversations (success) ──────────────────────────────────────

    test('loadConversations populates list on success', () async {
      final page = ConversationsPage(
        items: [
          testConversation(id: 1, title: 'First'),
          testConversation(id: 2, title: 'Second'),
        ],
        hasMore: true,
        nextCursor: 'cursor_abc',
      );
      when(() => mockRepository.getConversations()).thenAnswer((_) async => page);

      final controller = createController();
      await controller.loadConversations();

      expect(controller.conversations.length, 2);
      expect(controller.conversations[0].title, 'First');
      expect(controller.conversations[1].title, 'Second');
      expect(controller.conversationsNextCursor.value, 'cursor_abc');
      expect(controller.conversationsHasMore.value, isTrue);
      expect(controller.isLoadingConversations.value, isFalse);
      expect(controller.conversationsError.value, isFalse);
    });

    // ── loadConversations (error) ────────────────────────────────────────

    test('loadConversations sets error flag on failure', () async {
      when(() => mockRepository.getConversations()).thenThrow(Exception('Server down'));

      final controller = createController();
      await controller.loadConversations();

      expect(controller.conversations, isEmpty);
      expect(controller.conversationsError.value, isTrue);
      expect(controller.isLoadingConversations.value, isFalse);
    });

    // ── deleteConversation (success) ─────────────────────────────────────

    test('deleteConversation removes item from list on success', () async {
      when(() => mockRepository.deleteConversation(3)).thenAnswer((_) async => true);

      final controller = createController();
      controller.conversations.assignAll([
        testConversation(id: 1),
        testConversation(id: 3),
        testConversation(id: 5),
      ]);

      await controller.deleteConversation(3);

      expect(controller.conversations.length, 2);
      expect(controller.conversations.any((c) => c.id == 3), isFalse);
      expect(controller.isDeleting.value, isFalse);
    });

    // ── deleteConversation (failure) ─────────────────────────────────────

    test('deleteConversation keeps list intact on failure', () async {
      when(() => mockRepository.deleteConversation(3)).thenAnswer((_) async => false);

      final controller = createController();
      controller.conversations.assignAll([testConversation(id: 1), testConversation(id: 3)]);

      await controller.deleteConversation(3);

      // List should remain unchanged when delete returns false.
      expect(controller.conversations.length, 2);
      expect(controller.isDeleting.value, isFalse);
    });

    // ── deleteConversation sets isDeleting correctly ─────────────────────

    test('deleteConversation toggles isDeleting during operation', () async {
      final completer = Completer<bool>();
      when(() => mockRepository.deleteConversation(7)).thenAnswer((_) => completer.future);

      final controller = createController();
      controller.conversations.assignAll([testConversation(id: 7)]);

      // Fire and forget — don't await yet.
      final future = controller.deleteConversation(7);

      // isDeleting should be true while the future is pending.
      expect(controller.isDeleting.value, isTrue);

      completer.complete(true);
      await future;

      // isDeleting should be false after completion.
      expect(controller.isDeleting.value, isFalse);
    });

    // ── conversation_id parsed as int from SSE event ─────────────────────

    test('conversation_info event with int conversation_id sets value', () async {
      final streamController = StreamController<SseEvent>();
      when(
        () => mockRepository.streamChat(message: 'test', conversationId: null),
      ).thenAnswer((_) => streamController.stream);

      final controller = createController();
      controller.sendMessage('test');

      streamController.add(
        const SseEvent(event: 'conversation_info', data: {'conversation_id': 42}),
      );
      // Allow microtask to flush so the stream listener processes the event.
      await Future<void>.value();
      expect(controller.conversationId.value, 42);

      await streamController.close();
    });

    // ── conversation_id parsed as string from SSE event ──────────────────

    test('conversation_info event with string conversation_id parses to int', () async {
      final streamController = StreamController<SseEvent>();
      when(
        () => mockRepository.streamChat(message: 'test', conversationId: null),
      ).thenAnswer((_) => streamController.stream);

      final controller = createController();
      controller.sendMessage('test');

      streamController.add(
        const SseEvent(event: 'conversation_info', data: {'conversation_id': '99'}),
      );
      await Future<void>.value();
      expect(controller.conversationId.value, 99);

      await streamController.close();
    });

    // ── cancelStream ─────────────────────────────────────────────────────

    test('cancelStream stops streaming and clears state', () {
      final streamController = StreamController<SseEvent>();
      when(
        () => mockRepository.streamChat(message: 'hi', conversationId: null),
      ).thenAnswer((_) => streamController.stream);

      final controller = createController();
      controller.sendMessage('hi');
      expect(controller.isStreaming.value, isTrue);

      controller.cancelStream();

      expect(controller.isStreaming.value, isFalse);
      expect(controller.activeToolCall.value, isNull);
    });

    // ── deleteConversation success resets active conversation ─────────────

    test('deleteConversation resets active conversation when deleting current one', () async {
      when(() => mockRepository.deleteConversation(10)).thenAnswer((_) async => true);

      final controller = createController();
      controller.conversations.assignAll([testConversation(id: 10), testConversation(id: 20)]);
      // Simulate that conversation 10 is currently active.
      controller.conversationId.value = 10;
      controller.messages.add(
        ChatMessageModel(
          id: 'msg1',
          role: ChatRole.user,
          content: 'hello',
          timestamp: DateTime.now(),
        ),
      );

      await controller.deleteConversation(10);

      expect(controller.conversations.length, 1);
      expect(controller.conversationId.value, isNull);
      expect(controller.messages, isEmpty);
    });
  });
}
