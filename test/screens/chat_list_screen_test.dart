import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:mini_library_management/models/message_model.dart';
import 'package:mini_library_management/models/user_model.dart';
import 'package:mini_library_management/providers/auth_provider.dart';
import 'package:mini_library_management/providers/chat_provider.dart';
import 'package:mini_library_management/screens/chat/chat_list_screen.dart';
import 'package:mini_library_management/services/firestore_service.dart';

import 'chat_list_screen_test.mocks.dart';

@GenerateMocks([ChatProvider, AuthProvider, FirestoreService])
void main() {
  late MockChatProvider mockChatProvider;
  late MockAuthProvider mockAuthProvider;

  late MockFirestoreService mockFirestoreService;

  setUp(() {
    mockChatProvider = MockChatProvider();
    mockAuthProvider = MockAuthProvider();
    mockFirestoreService = MockFirestoreService();

    when(mockChatProvider.isLoadingRooms).thenReturn(false);
    when(mockChatProvider.error).thenReturn(null);
    when(mockChatProvider.chatRooms).thenReturn([]);

    final user = UserModel(
      id: 'admin1',
      email: 'admin@test.com',
      fullName: 'Admin User',
      role: 'librarian',
      createdAt: DateTime.now(),
    );
    when(mockAuthProvider.currentUser).thenReturn(user);
    when(mockAuthProvider.isAdmin).thenReturn(true);

    // Mock the other user in the room
    when(mockFirestoreService.getUser('user1')).thenAnswer(
      (_) async => UserModel(
        id: 'user1',
        email: 'user@test.com',
        fullName: 'User',
        role: 'student',
        createdAt: DateTime.now(),
      ),
    );
    when(mockFirestoreService.adminUsersStream()).thenAnswer((_) => Stream.value([]));
  });

  Widget createWidgetUnderTest() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ChatProvider>.value(
          value: mockChatProvider,
        ),
        ChangeNotifierProvider<AuthProvider>.value(
          value: mockAuthProvider,
        ),
      ],
      child: MaterialApp(
        home: ChatListScreen(firestoreService: mockFirestoreService),
      ),
    );
  }

  group('ChatListScreen Tests', () {
    testWidgets('displays empty state when no chat rooms', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('No Conversations'), findsOneWidget);
    });

    testWidgets('displays chat rooms list', (WidgetTester tester) async {
      final rooms = [
        ChatRoomModel(
          id: 'room1',
          participants: ['user1', 'admin1'],
          lastMessage: 'Last message text',
          lastMessageAt: DateTime.now(),
        ),
      ];

      when(mockChatProvider.chatRooms).thenReturn(rooms);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // We expect the name of the *other* participant to show up.
      expect(find.text('User'), findsOneWidget);
      expect(find.text('Last message text'), findsOneWidget);
    });

    testWidgets('hides fab for librarian', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('shows fab for student', (WidgetTester tester) async {
      final user = UserModel(
        id: 'student1',
        email: 'student@test.com',
        fullName: 'Student User',
        role: 'student',
        createdAt: DateTime.now(),
      );
      when(mockAuthProvider.currentUser).thenReturn(user);
      when(mockAuthProvider.isAdmin).thenReturn(false);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });
  });
}
