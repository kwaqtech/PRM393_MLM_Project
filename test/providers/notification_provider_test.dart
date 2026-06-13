import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:mini_library_management/models/notification_model.dart';
import 'package:mini_library_management/providers/notification_provider.dart';
import 'package:mini_library_management/services/firestore_service.dart';

import 'notification_provider_test.mocks.dart';

@GenerateMocks([FirestoreService])
void main() {
  late NotificationProvider provider;
  late MockFirestoreService mockFirestoreService;

  setUp(() {
    mockFirestoreService = MockFirestoreService();
    provider = NotificationProvider(firestoreService: mockFirestoreService);
  });

  group('NotificationProvider Tests', () {
    test('Initial state is correct', () {
      expect(provider.notifications, isEmpty);
      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
      expect(provider.unreadCount, 0);
    });

    test('listenToNotifications updates state on valid data stream', () async {
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

      when(mockFirestoreService.notificationsStream('user1'))
          .thenAnswer((_) => Stream.value(notifications));

      provider.listenToNotifications('user1');
      await Future.delayed(Duration.zero); // allow stream to emit

      expect(provider.isLoading, isFalse);
      expect(provider.error, isNull);
      expect(provider.notifications.length, 1);
      expect(provider.unreadCount, 1);
    });

    test('listenToNotifications handles stream error', () async {
      when(mockFirestoreService.notificationsStream('user1'))
          .thenAnswer((_) => Stream.error(Exception('Stream error')));

      provider.listenToNotifications('user1');
      await Future.delayed(Duration.zero);

      expect(provider.isLoading, isFalse);
      expect(provider.error, contains('Exception: Stream error'));
      expect(provider.notifications, isEmpty);
    });

    test('markAsRead updates via service', () async {
      when(mockFirestoreService.markNotificationAsRead('notif1'))
          .thenAnswer((_) async => {});

      await provider.markAsRead('notif1');

      expect(provider.error, isNull);
      verify(mockFirestoreService.markNotificationAsRead('notif1')).called(1);
    });

    test('markAllAsRead updates all unread notifications', () async {
      final notifications = [
        NotificationModel(
          id: '1',
          userId: 'user1',
          title: 'Test',
          message: 'Test message',
          createdAt: DateTime.now(),
          isRead: false,
        ),
        NotificationModel(
          id: '2',
          userId: 'user1',
          title: 'Test',
          message: 'Test message',
          createdAt: DateTime.now(),
          isRead: true, // already read, shouldn't be called
        ),
      ];

      when(mockFirestoreService.notificationsStream('user1'))
          .thenAnswer((_) => Stream.value(notifications));

      provider.listenToNotifications('user1');
      await Future.delayed(Duration.zero);

      when(mockFirestoreService.markNotificationsAsReadBatch(['1']))
          .thenAnswer((_) async {});

      await provider.markAllAsRead();

      verify(mockFirestoreService.markNotificationsAsReadBatch(['1'])).called(1);
      verifyNever(mockFirestoreService.markNotificationAsRead('1'));
      verifyNever(mockFirestoreService.markNotificationAsRead('2'));
    });
  });
}
