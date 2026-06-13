import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:mini_library_management/models/message_model.dart';
import 'package:mini_library_management/providers/chat_provider.dart';
import 'package:mini_library_management/services/firestore_service.dart';

import 'chat_provider_test.mocks.dart';

@GenerateMocks([FirestoreService])
void main() {
  late ChatProvider provider;
  late MockFirestoreService mockFirestoreService;

  setUp(() {
    mockFirestoreService = MockFirestoreService();
    provider = ChatProvider(firestoreService: mockFirestoreService);
  });

  group('ChatProvider Tests', () {
    test('Initial state is correct', () {
      expect(provider.chatRooms, isEmpty);
      expect(provider.messages, isEmpty);
      expect(provider.activeChatRoomId, isNull);
      expect(provider.isLoadingRooms, isFalse);
      expect(provider.isLoadingMessages, isFalse);
      expect(provider.isSending, isFalse);
      expect(provider.error, isNull);
    });

    test('listenToChatRooms updates state', () async {
      final rooms = [
        ChatRoomModel(
          id: 'room1',
          participants: ['user1', 'admin1'],
          lastMessage: 'Hello',
          lastMessageAt: DateTime.now(),
        ),
      ];

      when(
        mockFirestoreService.chatRoomsStream('user1'),
      ).thenAnswer((_) => Stream.value(rooms));

      provider.listenToChatRooms('user1');
      await Future.delayed(Duration.zero);

      expect(provider.isLoadingRooms, isFalse);
      expect(provider.error, isNull);
      expect(provider.chatRooms.length, 1);
    });

    test('openChatRoom updates active messages', () async {
      final messages = [
        MessageModel(
          id: 'msg1',
          senderId: 'user1',
          text: 'Hello',
          sentAt: DateTime.now(),
        ),
      ];

      when(
        mockFirestoreService.messagesStream('room1'),
      ).thenAnswer((_) => Stream.value(messages));

      provider.openChatRoom('room1');

      expect(provider.activeChatRoomId, 'room1');
      expect(provider.isLoadingMessages, isTrue);

      await Future.delayed(Duration.zero);

      expect(provider.isLoadingMessages, isFalse);
      expect(provider.messages.length, 1);
      expect(provider.error, isNull);
    });

    test('sendMessage successfully', () async {
      when(
        mockFirestoreService.sendMessage(
          chatRoomId: 'room1',
          message: anyNamed('message'),
        ),
      ).thenAnswer((_) async => {});

      final result = await provider.sendMessage(
        chatRoomId: 'room1',
        senderId: 'user1',
        text: 'Test message',
      );

      expect(result, isTrue);
      expect(provider.isSending, isFalse);
      expect(provider.error, isNull);
      verify(
        mockFirestoreService.sendMessage(
          chatRoomId: 'room1',
          message: anyNamed('message'),
        ),
      ).called(1);
    });

    test('sendMessage fails for empty text', () async {
      final result = await provider.sendMessage(
        chatRoomId: 'room1',
        senderId: 'user1',
        text: '   ',
      );

      expect(result, isFalse);
      verifyNever(
        mockFirestoreService.sendMessage(
          chatRoomId: 'room1',
          message: anyNamed('message'),
        ),
      );
    });
  });
}
