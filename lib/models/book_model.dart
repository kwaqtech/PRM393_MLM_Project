import 'package:cloud_firestore/cloud_firestore.dart';

/// Data model for a library book.
class BookModel {
  final String id;
  final String title;
  final String author;
  final String isbn;
  final String category;
  final String description;
  final String coverUrl;
  final int totalCopies;
  final int availableCopies;
  final DateTime createdAt;

  BookModel({
    required this.id,
    required this.title,
    required this.author,
    required this.isbn,
    required this.category,
    required this.description,
    this.coverUrl = '',
    required this.totalCopies,
    required this.availableCopies,
    required this.createdAt,
  });

  /// Whether there are copies available to borrow.
  bool get isAvailable => availableCopies > 0;

  /// Availability display string, e.g. "3 of 5 available".
  String get availabilityText => '$availableCopies of $totalCopies available';

  /// Create a [BookModel] from a Firestore document snapshot.
  factory BookModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BookModel(
      id: doc.id,
      title: data['title'] ?? '',
      author: data['author'] ?? '',
      isbn: data['isbn'] ?? '',
      category: data['category'] ?? 'Other',
      description: data['description'] ?? '',
      coverUrl: data['coverUrl'] ?? '',
      totalCopies: data['totalCopies'] ?? 0,
      availableCopies: data['availableCopies'] ?? 0,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  /// Convert this model to a Firestore-compatible map.
  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'author': author,
      'isbn': isbn,
      'category': category,
      'description': description,
      'coverUrl': coverUrl,
      'totalCopies': totalCopies,
      'availableCopies': availableCopies,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

  /// Create a copy of this model with updated fields.
  BookModel copyWith({
    String? id,
    String? title,
    String? author,
    String? isbn,
    String? category,
    String? description,
    String? coverUrl,
    int? totalCopies,
    int? availableCopies,
    DateTime? createdAt,
  }) {
    return BookModel(
      id: id ?? this.id,
      title: title ?? this.title,
      author: author ?? this.author,
      isbn: isbn ?? this.isbn,
      category: category ?? this.category,
      description: description ?? this.description,
      coverUrl: coverUrl ?? this.coverUrl,
      totalCopies: totalCopies ?? this.totalCopies,
      availableCopies: availableCopies ?? this.availableCopies,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() => 'BookModel(id: $id, title: $title, author: $author)';
}
