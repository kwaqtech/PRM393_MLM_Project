import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:mini_library_management/models/book_model.dart';
import 'package:mini_library_management/models/borrow_model.dart';
import 'package:mini_library_management/models/user_model.dart';
import 'package:mini_library_management/providers/borrow_provider.dart';
import 'package:mini_library_management/services/firestore_service.dart';
import 'package:mini_library_management/utils/constants.dart';

import 'borrow_provider_test.mocks.dart';

@GenerateMocks([FirestoreService])
void main() {
  late BorrowProvider provider;
  late MockFirestoreService mockFirestoreService;

  setUp(() {
    provideDummy<BorrowModel>(BorrowModel(
      id: '',
      userId: '',
      bookId: '',
      status: '',
      borrowDate: DateTime.now(),
      dueDate: DateTime.now(),
      createdAt: DateTime.now(),
      bookTitle: '',
      userName: '',
    ));
    mockFirestoreService = MockFirestoreService();
    provider = BorrowProvider(firestoreService: mockFirestoreService);
  });

  group('BorrowProvider Tests', () {
    test('Initial state is correct', () {
      expect(provider.borrows, isEmpty);
      expect(provider.isLoading, isFalse);
      expect(provider.errorMessage, isNull);
      expect(provider.statusFilter, 'all');
    });

    test('requestBorrow fails if user has reached max limit', () async {
      // Create a user with active borrows at the limit
      final user = UserModel(
        id: 'user1',
        email: 'test@test.com',
        fullName: 'Test User',
        role: AppConstants.roleStudent,
        createdAt: DateTime.now(),
      );

      final book = BookModel(
        id: 'book1',
        title: 'Book 1',
        author: 'Author',
        description: '',
        category: 'Tech',
        isbn: '1234567890',
        totalCopies: 5,
        availableCopies: 5,
        createdAt: DateTime.now(),
      );

      // Simulate state by streaming in data to provider first
      final borrows = List.generate(
        AppConstants.maxBooksPerStudent,
        (i) => BorrowModel(
          id: 'borrow$i',
          userId: 'user1',
          bookId: 'some_other_book$i',
          status: AppConstants.statusApproved,
          borrowDate: DateTime.now(),
          dueDate: DateTime.now().add(const Duration(days: 7)),
          createdAt: DateTime.now(),
          bookTitle: 'Some Book $i',
          userName: 'Test User',
        ),
      );

      when(mockFirestoreService.userBorrowsStream('user1'))
          .thenAnswer((_) => Stream.value(borrows));

      provider.startListening(userId: 'user1', isAdmin: false);
      
      // Allow stream to emit
      await Future.delayed(Duration.zero);

      // Try to request a new borrow
      final success = await provider.requestBorrow(book: book, user: user);

      expect(success, isFalse);
      expect(provider.errorMessage, contains('can only borrow up to'));
    });

    test('requestBorrow fails if user already has this book active', () async {
      final user = UserModel(
        id: 'user1',
        email: 'test@test.com',
        fullName: 'Test User',
        role: AppConstants.roleStudent,
        createdAt: DateTime.now(),
      );

      final book = BookModel(
        id: 'book1',
        title: 'Book 1',
        author: 'Author',
        description: '',
        category: 'Tech',
        isbn: '1234567890',
        totalCopies: 5,
        availableCopies: 5,
        createdAt: DateTime.now(),
      );

      final borrows = [
        BorrowModel(
          id: 'borrow1',
          userId: 'user1',
          bookId: 'book1', // Same book ID
          status: AppConstants.statusPending,
          borrowDate: DateTime.now(),
          dueDate: DateTime.now().add(const Duration(days: 7)),
          createdAt: DateTime.now(),
          bookTitle: 'Book 1',
          userName: 'Test User',
        )
      ];

      when(mockFirestoreService.userBorrowsStream('user1'))
          .thenAnswer((_) => Stream.value(borrows));

      provider.startListening(userId: 'user1', isAdmin: false);
      
      await Future.delayed(Duration.zero);

      final success = await provider.requestBorrow(book: book, user: user);

      expect(success, isFalse);
      expect(provider.errorMessage, contains('already have an active borrow'));
    });

    test('requestBorrow succeeds for valid request', () async {
      final user = UserModel(
        id: 'user1',
        email: 'test@test.com',
        fullName: 'Test User',
        role: AppConstants.roleStudent,
        createdAt: DateTime.now(),
      );

      final book = BookModel(
        id: 'book1',
        title: 'Book 1',
        author: 'Author',
        description: '',
        category: 'Tech',
        isbn: '1234567890',
        totalCopies: 5,
        availableCopies: 5,
        createdAt: DateTime.now(),
      );

      when(mockFirestoreService.userBorrowsStream('user1'))
          .thenAnswer((_) => Stream.value([]));
      
      when(mockFirestoreService.createBorrow(any))
          .thenAnswer((_) async => 'mock_id');

      provider.startListening(userId: 'user1', isAdmin: false);
      await Future.delayed(Duration.zero);

      final success = await provider.requestBorrow(book: book, user: user);

      expect(success, isTrue);
      expect(provider.errorMessage, isNull);
      verify(mockFirestoreService.createBorrow(any)).called(1);
    });
  });
}
