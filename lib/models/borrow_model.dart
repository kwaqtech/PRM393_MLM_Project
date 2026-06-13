import 'package:cloud_firestore/cloud_firestore.dart';

import '../utils/constants.dart';

/// Data model for a book borrow record.
class BorrowModel {
  final String id;
  final String userId;
  final String bookId;
  final String status; // 'pending', 'approved', 'returned', 'overdue'
  final DateTime borrowDate;
  final DateTime dueDate;
  final DateTime? returnDate;
  final DateTime createdAt;

  // Denormalized fields for display (avoids extra Firestore reads)
  final String? bookTitle;
  final String? bookCoverUrl;
  final String? userName;

  BorrowModel({
    required this.id,
    required this.userId,
    required this.bookId,
    required this.status,
    required this.borrowDate,
    required this.dueDate,
    this.returnDate,
    required this.createdAt,
    this.bookTitle,
    this.bookCoverUrl,
    this.userName,
  });

  /// Whether the borrow is currently overdue.
  bool get isOverdue =>
      status == AppConstants.statusApproved &&
      DateTime.now().isAfter(dueDate) &&
      returnDate == null;

  /// Whether the borrow is still pending approval.
  bool get isPending => status == AppConstants.statusPending;

  /// Whether the borrow has been approved and is active.
  bool get isActive =>
      status == AppConstants.statusApproved && returnDate == null;

  /// Number of days remaining until due date (negative if overdue).
  int get daysRemaining => dueDate.difference(DateTime.now()).inDays;

  /// Create a [BorrowModel] from a Firestore document snapshot.
  factory BorrowModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BorrowModel(
      id: doc.id,
      userId: data['userId'] ?? '',
      bookId: data['bookId'] ?? '',
      status: data['status'] ?? AppConstants.statusPending,
      borrowDate:
          (data['borrowDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      dueDate:
          (data['dueDate'] as Timestamp?)?.toDate() ??
          DateTime.now().add(
            const Duration(days: AppConstants.defaultBorrowDays),
          ),
      returnDate: (data['returnDate'] as Timestamp?)?.toDate(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      bookTitle: data['bookTitle'],
      bookCoverUrl: data['bookCoverUrl'],
      userName: data['userName'],
    );
  }

  /// Convert this model to a Firestore-compatible map.
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'bookId': bookId,
      'status': status,
      'borrowDate': Timestamp.fromDate(borrowDate),
      'dueDate': Timestamp.fromDate(dueDate),
      'returnDate': returnDate != null ? Timestamp.fromDate(returnDate!) : null,
      'createdAt': Timestamp.fromDate(createdAt),
      'bookTitle': bookTitle,
      'bookCoverUrl': bookCoverUrl,
      'userName': userName,
    };
  }

  /// Create a copy of this model with updated fields.
  /// To explicitly clear [returnDate], pass `returnDate: null` —
  /// use the [clearReturnDate] flag since Dart's `??` cannot distinguish
  /// "not supplied" from "supplied null".
  BorrowModel copyWith({
    String? id,
    String? userId,
    String? bookId,
    String? status,
    DateTime? borrowDate,
    DateTime? dueDate,
    Object? returnDate = _sentinel,
    DateTime? createdAt,
    String? bookTitle,
    String? bookCoverUrl,
    String? userName,
  }) {
    return BorrowModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      bookId: bookId ?? this.bookId,
      status: status ?? this.status,
      borrowDate: borrowDate ?? this.borrowDate,
      dueDate: dueDate ?? this.dueDate,
      returnDate: returnDate == _sentinel
          ? this.returnDate
          : returnDate as DateTime?,
      createdAt: createdAt ?? this.createdAt,
      bookTitle: bookTitle ?? this.bookTitle,
      bookCoverUrl: bookCoverUrl ?? this.bookCoverUrl,
      userName: userName ?? this.userName,
    );
  }

  static const Object _sentinel = Object();

  @override
  String toString() => 'BorrowModel(id: $id, bookId: $bookId, status: $status)';
}
