import 'dart:async';

import 'package:flutter/material.dart';

import '../models/book_model.dart';
import '../models/borrow_model.dart';
import '../models/notification_model.dart';
import '../models/user_model.dart';
import '../services/firestore_service.dart';
import '../utils/constants.dart';
import '../utils/error_handler.dart';
import '../utils/logger.dart';

/// Manages borrow state — requests, history, approvals, and returns.
class BorrowProvider extends ChangeNotifier {
  final FirestoreService _firestoreService;

  BorrowProvider({FirestoreService? firestoreService})
      : _firestoreService = firestoreService ?? FirestoreService();
  List<BorrowModel> _borrows = [];
  bool _isLoading = false;
  String? _errorMessage;
  String _statusFilter =
      'all'; // 'all', 'pending', 'approved', 'returned', 'overdue'
  StreamSubscription? _borrowSubscription;

  // ─── Getters ────────────────────────────────────

  List<BorrowModel> get borrows => _filteredBorrows;
  List<BorrowModel> get allBorrows => _borrows;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  String get statusFilter => _statusFilter;

  List<BorrowModel> get _filteredBorrows {
    if (_statusFilter == 'all') return _borrows;
    if (_statusFilter == 'overdue') {
      return _borrows.where((b) => b.isOverdue).toList();
    }
    return _borrows.where((b) => b.status == _statusFilter).toList();
  }

  /// Count of pending borrows (useful for badges).
  int get pendingCount =>
      _borrows.where((b) => b.status == AppConstants.statusPending).length;

  /// Count of overdue borrows.
  int get overdueCount => _borrows.where((b) => b.isOverdue).length;

  // ─── Lifecycle ──────────────────────────────────

  /// Start listening to borrows — student sees own, admin sees all.
  void startListening({required String userId, required bool isAdmin}) {
    _isLoading = true;
    notifyListeners();

    _borrowSubscription?.cancel();

    final stream = isAdmin
        ? _firestoreService.allBorrowsStream()
        : _firestoreService.userBorrowsStream(userId);

    _borrowSubscription = stream.listen(
      (borrows) {
        _borrows = borrows;
        _isLoading = false;
        _errorMessage = null;
        notifyListeners();
      },
      onError: (e, st) {
        AppLogger.error('Failed to load borrows stream', e, st);
        _errorMessage = ErrorHandler.getErrorMessage(e);
        _isLoading = false;
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _borrowSubscription?.cancel();
    super.dispose();
  }

  // ─── Filter ─────────────────────────────────────

  void setStatusFilter(String filter) {
    _statusFilter = filter;
    notifyListeners();
  }

  // ─── Borrow Request (Student) ───────────────────

  /// Create a new borrow request for the given book.
  Future<bool> requestBorrow({
    required BookModel book,
    required UserModel user,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      // Check if user already has an active/pending borrow for this book
      final existingBorrow = _borrows.where(
        (b) =>
            b.bookId == book.id &&
            b.userId == user.id &&
            (b.isPending || b.isActive),
      );
      if (existingBorrow.isNotEmpty) {
        _errorMessage = 'You already have an active borrow for this book.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      // Check max borrow limit
      final activeBorrows = _borrows.where(
        (b) => b.userId == user.id && (b.isPending || b.isActive),
      );
      if (activeBorrows.length >= AppConstants.maxBooksPerStudent) {
        _errorMessage =
            'You can only borrow up to ${AppConstants.maxBooksPerStudent} books at a time.';
        _isLoading = false;
        notifyListeners();
        return false;
      }

      final now = DateTime.now();
      final borrow = BorrowModel(
        id: '',
        userId: user.id,
        bookId: book.id,
        status: AppConstants.statusPending,
        borrowDate: now,
        dueDate: now.add(const Duration(days: AppConstants.defaultBorrowDays)),
        createdAt: now,
        bookTitle: book.title,
        bookCoverUrl: book.coverUrl,
        userName: user.fullName,
      );

      await _firestoreService.createBorrow(borrow);
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e, st) {
      AppLogger.error('Failed to submit borrow request', e, st);
      _errorMessage = ErrorHandler.getErrorMessage(e);
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  // ─── Admin Actions ──────────────────────────────

  /// Approve a pending borrow request.
  Future<bool> approveBorrow(BorrowModel borrow) async {
    try {
      await _firestoreService.updateBorrowStatus(
        borrowId: borrow.id,
        newStatus: AppConstants.statusApproved,
        bookId: borrow.bookId,
      );

      // Notify student
      await _firestoreService.addNotification(
        NotificationModel(
          id: '',
          userId: borrow.userId,
          title: 'Borrow Approved',
          message: 'Your request to borrow "${borrow.bookTitle}" has been approved.',
          createdAt: DateTime.now(),
        ),
      );

      return true;
    } catch (e, st) {
      AppLogger.error('Failed to approve borrow', e, st);
      _errorMessage = ErrorHandler.getErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  /// Reject a pending borrow request (restores available copies).
  Future<bool> rejectBorrow(BorrowModel borrow) async {
    try {
      await _firestoreService.updateBorrowStatus(
        borrowId: borrow.id,
        newStatus: AppConstants.statusRejected,
        bookId: borrow.bookId,
        restoreCopy: true, // pending request had decremented copies
      );

      // Notify student
      await _firestoreService.addNotification(
        NotificationModel(
          id: '',
          userId: borrow.userId,
          title: 'Borrow Rejected',
          message: 'Your request to borrow "${borrow.bookTitle}" has been rejected.',
          createdAt: DateTime.now(),
        ),
      );

      return true;
    } catch (e, st) {
      AppLogger.error('Failed to reject borrow', e, st);
      _errorMessage = ErrorHandler.getErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  /// Mark a borrow as returned.
  Future<bool> markReturned(BorrowModel borrow) async {
    try {
      await _firestoreService.updateBorrowStatus(
        borrowId: borrow.id,
        newStatus: AppConstants.statusReturned,
        bookId: borrow.bookId,
        returnDate: DateTime.now(),
      );

      // Notify student
      await _firestoreService.addNotification(
        NotificationModel(
          id: '',
          userId: borrow.userId,
          title: 'Book Returned',
          message: 'You have successfully returned "${borrow.bookTitle}".',
          createdAt: DateTime.now(),
        ),
      );

      return true;
    } catch (e, st) {
      AppLogger.error('Failed to mark as returned', e, st);
      _errorMessage = ErrorHandler.getErrorMessage(e);
      notifyListeners();
      return false;
    }
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }
}
