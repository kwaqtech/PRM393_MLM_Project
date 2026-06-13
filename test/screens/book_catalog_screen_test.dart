import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:provider/provider.dart';

import 'package:mini_library_management/models/book_model.dart';
import 'package:mini_library_management/providers/auth_provider.dart';
import 'package:mini_library_management/providers/book_provider.dart';
import 'package:mini_library_management/screens/home/book_catalog_screen.dart';

import 'book_catalog_screen_test.mocks.dart';

@GenerateMocks([AuthProvider, BookProvider])
void main() {
  late MockAuthProvider mockAuthProvider;
  late MockBookProvider mockBookProvider;

  setUp(() {
    mockAuthProvider = MockAuthProvider();
    mockBookProvider = MockBookProvider();

    when(mockAuthProvider.isAdmin).thenReturn(false);
    when(mockBookProvider.searchQuery).thenReturn('');
    when(mockBookProvider.selectedCategory).thenReturn(null);
  });

  Widget createTestWidget() {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: mockAuthProvider),
        ChangeNotifierProvider<BookProvider>.value(value: mockBookProvider),
      ],
      child: const MaterialApp(
        home: BookCatalogScreen(),
      ),
    );
  }

  testWidgets('Shows loading indicator when isLoading is true', (tester) async {
    when(mockBookProvider.isLoading).thenReturn(true);
    when(mockBookProvider.books).thenReturn([]);
    when(mockBookProvider.allBooks).thenReturn([]);
    when(mockBookProvider.errorMessage).thenReturn(null);

    await tester.pumpWidget(createTestWidget());

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('Shows error message when errorMessage is not null', (tester) async {
    when(mockBookProvider.isLoading).thenReturn(false);
    when(mockBookProvider.books).thenReturn([]);
    when(mockBookProvider.allBooks).thenReturn([]);
    when(mockBookProvider.errorMessage).thenReturn('Failed to load books');

    await tester.pumpWidget(createTestWidget());

    expect(find.text('Failed to load books'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('Shows empty state when books list is empty', (tester) async {
    when(mockBookProvider.isLoading).thenReturn(false);
    when(mockBookProvider.books).thenReturn([]);
    when(mockBookProvider.allBooks).thenReturn([]);
    when(mockBookProvider.errorMessage).thenReturn(null);

    await tester.pumpWidget(createTestWidget());

    expect(find.text('No books yet'), findsOneWidget);
  });

  testWidgets('Shows list of books when data is available', (tester) async {
    final books = [
      BookModel(
        id: '1',
        title: 'Flutter For Beginners',
        author: 'John Doe',
        description: 'Learn Flutter',
        category: 'Tech',
        isbn: '12345',
        totalCopies: 5,
        availableCopies: 5,
        createdAt: DateTime.now(),
      ),
      BookModel(
        id: '2',
        title: 'Advanced Dart',
        author: 'Jane Smith',
        description: 'Learn Dart',
        category: 'Tech',
        isbn: '67890',
        totalCopies: 3,
        availableCopies: 1,
        createdAt: DateTime.now(),
      ),
    ];

    when(mockBookProvider.isLoading).thenReturn(false);
    when(mockBookProvider.books).thenReturn(books);
    when(mockBookProvider.allBooks).thenReturn(books);
    when(mockBookProvider.errorMessage).thenReturn(null);

    // Ensure image network calls don't crash the test
    // NetworkImage isn't used if we just mock NetworkImage or provide a test environment
    // Actually, network image will throw in test environment. We can use mock_network_images or just let it fail gracefully if caught, but it's better to just ensure it doesn't crash the whole test.
    // CachedNetworkImage throws if not mocked, but we will see.

    await tester.pumpWidget(createTestWidget());
    
    // Pump and settle to let images fail loading if they do
    await tester.pumpAndSettle();

    expect(find.text('Flutter For Beginners'), findsOneWidget);
    expect(find.text('Advanced Dart'), findsOneWidget);
  });
}
