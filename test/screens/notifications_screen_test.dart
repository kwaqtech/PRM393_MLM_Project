import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';
import 'package:mini_library_management/models/notification_model.dart';
import 'package:mini_library_management/providers/notification_provider.dart';
import 'package:mini_library_management/screens/notifications/notifications_screen.dart';

import 'notifications_screen_test.mocks.dart';

@GenerateMocks([NotificationProvider])
void main() {
  late MockNotificationProvider mockNotificationProvider;

  setUp(() {
    mockNotificationProvider = MockNotificationProvider();
    when(mockNotificationProvider.isLoading).thenReturn(false);
    when(mockNotificationProvider.error).thenReturn(null);
    when(mockNotificationProvider.notifications).thenReturn([]);
    when(mockNotificationProvider.unreadCount).thenReturn(0);
  });

  Widget createWidgetUnderTest() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<NotificationProvider>.value(
          value: mockNotificationProvider,
        ),
      ],
      child: const MaterialApp(
        home: NotificationsScreen(),
      ),
    );
  }

  group('NotificationsScreen Tests', () {
    testWidgets('displays loading indicator when loading', (WidgetTester tester) async {
      when(mockNotificationProvider.isLoading).thenReturn(true);

      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('displays empty state when no notifications', (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.text('No Notifications'), findsOneWidget);
    });

    testWidgets('displays notifications list', (WidgetTester tester) async {
      final notifications = [
        NotificationModel(
          id: '1',
          userId: 'user1',
          title: 'Test Notification',
          message: 'This is a test notification',
          createdAt: DateTime.now(),
          isRead: false,
        ),
      ];

      when(mockNotificationProvider.notifications).thenReturn(notifications);

      await tester.pumpWidget(createWidgetUnderTest());

      expect(find.text('Test Notification'), findsOneWidget);
      expect(find.text('This is a test notification'), findsOneWidget);
    });

    testWidgets('mark all as read button is clickable', (WidgetTester tester) async {
      final notifications = [
        NotificationModel(
          id: '1',
          userId: 'user1',
          title: 'Test',
          message: 'Test message',
          createdAt: DateTime.now(),
          isRead: false,
        ),
      ];
      when(mockNotificationProvider.notifications).thenReturn(notifications);
      when(mockNotificationProvider.unreadCount).thenReturn(1);

      await tester.pumpWidget(createWidgetUnderTest());

      final markAllButton = find.byIcon(Icons.done_all);
      expect(markAllButton, findsOneWidget);

      await tester.tap(markAllButton);
      await tester.pump();

      verify(mockNotificationProvider.markAllAsRead()).called(1);
    });
  });
}
