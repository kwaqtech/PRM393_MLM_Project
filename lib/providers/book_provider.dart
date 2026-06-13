import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../models/book_model.dart';
import '../services/firestore_service.dart';
import '../services/storage_service.dart';
import '../utils/error_handler.dart';
import '../utils/logger.dart';

/// Manages book catalog state — listing, search, filter, and CRUD.
class BookProvider extends ChangeNotifier {
  final FirestoreService _firestoreService = FirestoreService();
  final StorageService _storageService = StorageService();

  List<BookModel> _books = [];
  List<BookModel> _filteredBooks = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _searchQuery = '';
  String? _selectedCategory;
  StreamSubscription? _booksSubscription;

  // ─── Getters ────────────────────────────────────

  List<BookModel> get books => _filteredBooks;
  List<BookModel> get allBooks => _books;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get searchQuery => _searchQuery;
  String? get selectedCategory => _selectedCategory;

  // ─── Lifecycle ──────────────────────────────────

  /// Start listening to the books collection.
  void startListening() {
    _isLoading = true;
    notifyListeners();

    _booksSubscription?.cancel();
    _booksSubscription = _firestoreService.booksStream().listen(
      (books) {
        _books = books;
        _applyFilters();
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (e, st) {
        AppLogger.error('Failed to load books stream', e, st);
        _errorMessage = ErrorHandler.getErrorMessage(e);
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _booksSubscription?.cancel();
    super.dispose();
  }

  // ─── Search & Filter ────────────────────────────

  /// Update the search query and re-filter.
  void setSearchQuery(String query) {
    _searchQuery = query;
    _applyFilters();
    notifyListeners();
  }

  /// Set the category filter. Pass `null` to clear.
  void setCategory(String? category) {
    _selectedCategory = category;
    _applyFilters();
    notifyListeners();
  }

  /// Clear all filters.
  void clearFilters() {
    _searchQuery = '';
    _selectedCategory = null;
    _applyFilters();
    notifyListeners();
  }

  void _applyFilters() {
    var result = List<BookModel>.from(_books);

    // Search by title or author
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      result = result
          .where(
            (b) =>
                b.title.toLowerCase().contains(q) ||
                b.author.toLowerCase().contains(q) ||
                b.isbn.toLowerCase().contains(q),
          )
          .toList();
    }

    // Filter by category
    if (_selectedCategory != null) {
      result = result.where((b) => b.category == _selectedCategory).toList();
    }

    _filteredBooks = result;
  }

  // ─── CRUD Operations (Admin) ────────────────────

  /// Add a new book. Optionally upload a cover image.
  Future<bool> addBook({
    required String title,
    required String author,
    required String isbn,
    required String category,
    required String description,
    required int totalCopies,
    File? coverImage,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      String coverUrl = '';
      if (coverImage != null) {
        coverUrl = await _storageService.uploadBookCover(coverImage);
      }

      final book = BookModel(
        id: '',
        title: title.trim(),
        author: author.trim(),
        isbn: isbn.trim(),
        category: category,
        description: description.trim(),
        coverUrl: coverUrl,
        totalCopies: totalCopies,
        availableCopies: totalCopies,
        createdAt: DateTime.now(),
      );

      await _firestoreService.addBook(book);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e, st) {
      AppLogger.error('Failed to add book', e, st);
      _errorMessage = ErrorHandler.getErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Update an existing book. Optionally upload a new cover.
  Future<bool> updateBook({
    required BookModel existing,
    required String title,
    required String author,
    required String isbn,
    required String category,
    required String description,
    required int totalCopies,
    File? coverImage,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      String coverUrl = existing.coverUrl;
      if (coverImage != null) {
        // Upload new cover
        coverUrl = await _storageService.uploadBookCover(coverImage);
        // Delete old cover if it existed
        if (existing.coverUrl.isNotEmpty) {
          await _storageService.deleteImage(existing.coverUrl);
        }
      }

      // Calculate new available copies
      final copiesDiff = totalCopies - existing.totalCopies;
      final newAvailable = existing.availableCopies + copiesDiff;

      final updated = existing.copyWith(
        title: title.trim(),
        author: author.trim(),
        isbn: isbn.trim(),
        category: category,
        description: description.trim(),
        coverUrl: coverUrl,
        totalCopies: totalCopies,
        availableCopies: newAvailable.clamp(0, totalCopies),
      );

      await _firestoreService.updateBook(updated);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e, st) {
      AppLogger.error('Failed to update book', e, st);
      _errorMessage = ErrorHandler.getErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Delete a book and its cover image.
  Future<bool> deleteBook(BookModel book) async {
    try {
      if (book.coverUrl.isNotEmpty) {
        await _storageService.deleteImage(book.coverUrl);
      }
      await _firestoreService.deleteBook(book.id);
      return true;
    } catch (e, st) {
      AppLogger.error('Failed to delete book', e, st);
      _errorMessage = ErrorHandler.getErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  /// Get available categories with book counts.
  Map<String, int> get categoryCounts {
    final counts = <String, int>{};
    for (final book in _books) {
      counts[book.category] = (counts[book.category] ?? 0) + 1;
    }
    return counts;
  }
}
