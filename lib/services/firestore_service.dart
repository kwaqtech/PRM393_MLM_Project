import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/book_model.dart';
import '../models/borrow_model.dart';
import '../models/message_model.dart';
import '../models/notification_model.dart';
import '../models/user_model.dart';
import '../utils/constants.dart';

/// Wrapper around Cloud Firestore for all data operations.
/// Provides typed CRUD methods and real-time streams for each collection.
class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // ─────────────────────────────────────────────
  // BOOKS
  // ─────────────────────────────────────────────

  /// Stream of all books, ordered by creation date (newest first).
  Stream<List<BookModel>> booksStream() {
    return _db
        .collection(AppConstants.booksCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => BookModel.fromFirestore(doc)).toList(),
        );
  }

  /// Fetch a single book by ID.
  Future<BookModel?> getBook(String bookId) async {
    final doc = await _db
        .collection(AppConstants.booksCollection)
        .doc(bookId)
        .get();
    if (!doc.exists) return null;
    return BookModel.fromFirestore(doc);
  }

  /// Add a new book. Returns the generated document ID.
  Future<String> addBook(BookModel book) async {
    final docRef = await _db
        .collection(AppConstants.booksCollection)
        .add(book.toFirestore());
    return docRef.id;
  }

  /// Update an existing book.
  Future<void> updateBook(BookModel book) async {
    await _db
        .collection(AppConstants.booksCollection)
        .doc(book.id)
        .update(book.toFirestore());
  }

  /// Delete a book by ID.
  Future<void> deleteBook(String bookId) async {
    await _db.collection(AppConstants.booksCollection).doc(bookId).delete();
  }

  // ─────────────────────────────────────────────
  // BORROWS
  // ─────────────────────────────────────────────

  /// Stream of borrows for a specific user.
  Stream<List<BorrowModel>> userBorrowsStream(String userId) {
    return _db
        .collection(AppConstants.borrowsCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => BorrowModel.fromFirestore(doc))
              .toList(),
        );
  }

  /// Stream of ALL borrows (for admin view).
  Stream<List<BorrowModel>> allBorrowsStream() {
    return _db
        .collection(AppConstants.borrowsCollection)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => BorrowModel.fromFirestore(doc))
              .toList(),
        );
  }

  /// Create a new borrow request.
  /// Uses a **transaction** to atomically read [availableCopies] and
  /// decrement it, preventing it from going negative under concurrent requests.
  Future<String> createBorrow(BorrowModel borrow) async {
    final borrowRef = _db.collection(AppConstants.borrowsCollection).doc();
    final bookRef = _db
        .collection(AppConstants.booksCollection)
        .doc(borrow.bookId);

    await _db.runTransaction((txn) async {
      final bookSnap = await txn.get(bookRef);
      if (!bookSnap.exists) {
        throw Exception('Book not found: ${borrow.bookId}');
      }
      final available = (bookSnap.data() as Map<String, dynamic>)['availableCopies'] ?? 0;
      if (available <= 0) {
        throw Exception('No available copies for this book.');
      }

      txn.set(borrowRef, borrow.toFirestore());
      txn.update(bookRef, {'availableCopies': FieldValue.increment(-1)});
    });

    return borrowRef.id;
  }

  /// Update a borrow's status (approve, reject, return).
  /// If marking as returned OR rejecting (restoreCopy:true), increments
  /// [availableCopies] on the book.
  Future<void> updateBorrowStatus({
    required String borrowId,
    required String newStatus,
    required String bookId,
    DateTime? returnDate,
    bool restoreCopy = false,
  }) async {
    final batch = _db.batch();

    final borrowRef = _db
        .collection(AppConstants.borrowsCollection)
        .doc(borrowId);
    final updates = <String, dynamic>{'status': newStatus};
    if (returnDate != null) {
      updates['returnDate'] = Timestamp.fromDate(returnDate);
    }
    batch.update(borrowRef, updates);

    // Restore available copies when book is returned or request is rejected
    if (newStatus == AppConstants.statusReturned || restoreCopy) {
      final bookRef = _db.collection(AppConstants.booksCollection).doc(bookId);
      batch.update(bookRef, {'availableCopies': FieldValue.increment(1)});
    }

    await batch.commit();
  }

  // ─────────────────────────────────────────────
  // NOTIFICATIONS
  // ─────────────────────────────────────────────

  /// Stream of notifications for a specific user, newest first.
  Stream<List<NotificationModel>> notificationsStream(String userId) {
    return _db
        .collection(AppConstants.notificationsCollection)
        .where('userId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => NotificationModel.fromFirestore(doc))
              .toList(),
        );
  }

  /// Create a notification.
  Future<void> addNotification(NotificationModel notification) async {
    await _db
        .collection(AppConstants.notificationsCollection)
        .add(notification.toFirestore());
  }

  /// Mark a notification as read.
  Future<void> markNotificationAsRead(String notificationId) async {
    await _db
        .collection(AppConstants.notificationsCollection)
        .doc(notificationId)
        .update({'isRead': true});
  }

  /// Mark multiple notifications as read using a batch.
  Future<void> markNotificationsAsReadBatch(List<String> notificationIds) async {
    if (notificationIds.isEmpty) return;
    final batch = _db.batch();
    for (final id in notificationIds) {
      final docRef = _db.collection(AppConstants.notificationsCollection).doc(id);
      batch.update(docRef, {'isRead': true});
    }
    await batch.commit();
  }

  // ─────────────────────────────────────────────
  // CHAT
  // ─────────────────────────────────────────────

  /// Find or create a chat room between two participants.
  Future<ChatRoomModel> getOrCreateChatRoom(
    String userId1,
    String userId2,
  ) async {
    // Sort IDs to ensure consistent lookup
    final participants = [userId1, userId2]..sort();

    // Try to find an existing chat room with these participants
    final query = await _db
        .collection(AppConstants.chatRoomsCollection)
        .where('participants', isEqualTo: participants)
        .limit(1)
        .get();

    if (query.docs.isNotEmpty) {
      return ChatRoomModel.fromFirestore(query.docs.first);
    }

    // Create a new chat room
    final room = ChatRoomModel(
      id: '',
      participants: participants,
      lastMessageAt: DateTime.now(),
    );
    final docRef = await _db
        .collection(AppConstants.chatRoomsCollection)
        .add(room.toFirestore());

    return ChatRoomModel(id: docRef.id, participants: participants);
  }

  /// Stream of chat rooms for a user.
  Stream<List<ChatRoomModel>> chatRoomsStream(String userId) {
    return _db
        .collection(AppConstants.chatRoomsCollection)
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => ChatRoomModel.fromFirestore(doc))
              .toList(),
        );
  }

  /// Stream of messages in a chat room, ordered by time.
  Stream<List<MessageModel>> messagesStream(String chatRoomId) {
    return _db
        .collection(AppConstants.chatRoomsCollection)
        .doc(chatRoomId)
        .collection(AppConstants.chatMessagesSubcollection)
        .orderBy('sentAt', descending: false)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => MessageModel.fromFirestore(doc))
              .toList(),
        );
  }

  /// Send a message in a chat room.
  /// Also updates the chat room's [lastMessage] and [lastMessageAt].
  Future<void> sendMessage({
    required String chatRoomId,
    required MessageModel message,
  }) async {
    final batch = _db.batch();

    // Add the message to the subcollection
    final messageRef = _db
        .collection(AppConstants.chatRoomsCollection)
        .doc(chatRoomId)
        .collection(AppConstants.chatMessagesSubcollection)
        .doc();
    batch.set(messageRef, message.toFirestore());

    // Update the chat room with last message info
    final roomRef = _db
        .collection(AppConstants.chatRoomsCollection)
        .doc(chatRoomId);
    batch.update(roomRef, {
      'lastMessage': message.text,
      'lastMessageAt': Timestamp.fromDate(message.sentAt),
    });

    await batch.commit();
  }

  // ─────────────────────────────────────────────
  // USERS
  // ─────────────────────────────────────────────

  /// Fetch a single user by ID.
  Future<UserModel?> getUser(String userId) async {
    final doc = await _db
        .collection(AppConstants.usersCollection)
        .doc(userId)
        .get();
    if (!doc.exists) return null;
    return UserModel.fromFirestore(doc);
  }

  /// Stream of all admin users (for the student to find someone to chat with).
  Stream<List<UserModel>> adminUsersStream() {
    return _db
        .collection(AppConstants.usersCollection)
        .where('role', isEqualTo: AppConstants.roleAdmin)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList(),
        );
  }
}
