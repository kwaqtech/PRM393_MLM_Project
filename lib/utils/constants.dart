/// Application-wide constants for the Mini Library Management app.
class AppConstants {
  AppConstants._();

  // App info
  static const String appName = 'Mini Library';
  static const String appVersion = '1.0.0';

  // Firestore collection names
  static const String usersCollection = 'users';
  static const String booksCollection = 'books';
  static const String borrowsCollection = 'borrows';
  static const String notificationsCollection = 'notifications';
  static const String chatRoomsCollection = 'chatRooms';
  static const String chatMessagesSubcollection = 'messages';

  // User roles
  static const String roleStudent = 'student';
  static const String roleAdmin = 'admin';

  // Borrow status
  static const String statusPending = 'pending';
  static const String statusApproved = 'approved';
  static const String statusReturned = 'returned';
  static const String statusOverdue = 'overdue';
  static const String statusRejected = 'rejected';

  // Borrow settings
  static const int defaultBorrowDays = 14;
  static const int maxBooksPerStudent = 5;

  // Book categories
  static const List<String> bookCategories = [
    'Fiction',
    'Non-Fiction',
    'Science',
    'Technology',
    'History',
    'Mathematics',
    'Literature',
    'Art',
    'Business',
    'Education',
    'Other',
  ];

  // Map — TODO: Replace with your school library coordinates
  static const double libraryLatitude = 10.8411; // Example: FPT University HCM
  static const double libraryLongitude = 106.8098;
  static const String libraryName = 'FPT University Library';
}
