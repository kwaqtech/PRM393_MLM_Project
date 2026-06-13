import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../models/book_model.dart';
import '../utils/theme.dart';

/// A card widget displaying a book's cover, title, author, and availability.
/// Used in the book catalog grid.
class BookCard extends StatelessWidget {
  final BookModel book;
  final VoidCallback onTap;

  const BookCard({super.key, required this.book, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cover Image ──
            Expanded(flex: 3, child: _buildCover()),

            // ── Info Section ──
            Expanded(
              flex: 2,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Title
                    Text(
                      book.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),

                    // Author
                    Text(
                      book.author,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const Spacer(),

                    // Availability
                    Row(
                      children: [
                        Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: book.isAvailable
                                ? AppTheme.successColor
                                : AppTheme.errorColor,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            book.isAvailable
                                ? '${book.availableCopies} available'
                                : 'Unavailable',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                              color: book.isAvailable
                                  ? AppTheme.successColor
                                  : AppTheme.errorColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCover() {
    if (book.coverUrl.isEmpty) {
      return Container(
        width: double.infinity,
        color: AppTheme.primaryColor.withAlpha(20),
        child: const Icon(
          Icons.menu_book,
          size: 48,
          color: AppTheme.primaryColor,
        ),
      );
    }

    return CachedNetworkImage(
      imageUrl: book.coverUrl,
      width: double.infinity,
      fit: BoxFit.cover,
      placeholder: (_, _) => Container(
        color: AppTheme.primaryColor.withAlpha(20),
        child: const Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      ),
      errorWidget: (_, _, _) => Container(
        color: AppTheme.primaryColor.withAlpha(20),
        child: const Icon(
          Icons.broken_image,
          size: 40,
          color: AppTheme.textHint,
        ),
      ),
    );
  }
}
