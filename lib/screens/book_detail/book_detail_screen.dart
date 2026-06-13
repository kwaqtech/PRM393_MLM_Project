import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/book_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/book_provider.dart';
import '../../providers/borrow_provider.dart';
import '../../utils/constants.dart';
import '../../utils/theme.dart';
import '../home/add_edit_book_screen.dart';

/// Book detail screen — cover image, full info, availability, and actions.
class BookDetailScreen extends StatelessWidget {
  final BookModel book;
  const BookDetailScreen({super.key, required this.book});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Details'),
        actions: [
          if (auth.isAdmin) ...[
            IconButton(
              icon: const Icon(Icons.edit),
              tooltip: 'Edit',
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AddEditBookScreen(book: book),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Delete',
              onPressed: () => _confirmDelete(context),
            ),
          ],
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Cover Image ──
            _buildCoverImage(),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Title & Author ──
                  Text(
                    book.title,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'by ${book.author}',
                    style: const TextStyle(
                      fontSize: 16,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // ── Availability Badge ──
                  _buildAvailabilityBadge(),
                  const SizedBox(height: 20),

                  // ── Info Cards ──
                  _buildInfoRow(
                    Icons.category_outlined,
                    'Category',
                    book.category,
                  ),
                  _buildInfoRow(Icons.qr_code, 'ISBN', book.isbn),
                  _buildInfoRow(
                    Icons.inventory_2_outlined,
                    'Total Copies',
                    '${book.totalCopies}',
                  ),
                  const SizedBox(height: 20),

                  // ── Description ──
                  const Text(
                    'Description',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    book.description.isNotEmpty
                        ? book.description
                        : 'No description available.',
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppTheme.textSecondary,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 80), // Space for FAB
                ],
              ),
            ),
          ],
        ),
      ),

      // ── Borrow Button (Students only) ──
      floatingActionButton: !auth.isAdmin && book.isAvailable
          ? FloatingActionButton.extended(
              onPressed: () => _handleBorrow(context, auth),
              icon: const Icon(Icons.bookmark_add),
              label: const Text('Borrow This Book'),
            )
          : null,
    );
  }

  Widget _buildCoverImage() {
    if (book.coverUrl.isEmpty) {
      return Container(
        width: double.infinity,
        height: 250,
        color: AppTheme.primaryColor.withAlpha(20),
        child: const Icon(
          Icons.menu_book,
          size: 80,
          color: AppTheme.primaryColor,
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      height: 250,
      child: CachedNetworkImage(
        imageUrl: book.coverUrl,
        fit: BoxFit.cover,
        placeholder: (_, _) => Container(
          color: AppTheme.primaryColor.withAlpha(20),
          child: const Center(child: CircularProgressIndicator()),
        ),
        errorWidget: (_, _, _) => Container(
          color: AppTheme.primaryColor.withAlpha(20),
          child: const Icon(
            Icons.broken_image,
            size: 64,
            color: AppTheme.textHint,
          ),
        ),
      ),
    );
  }

  Widget _buildAvailabilityBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: book.isAvailable
            ? AppTheme.successColor.withAlpha(25)
            : AppTheme.errorColor.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: book.isAvailable ? AppTheme.successColor : AppTheme.errorColor,
          width: 0.5,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            book.isAvailable
                ? Icons.check_circle_outline
                : Icons.cancel_outlined,
            size: 18,
            color: book.isAvailable
                ? AppTheme.successColor
                : AppTheme.errorColor,
          ),
          const SizedBox(width: 8),
          Text(
            book.isAvailable ? book.availabilityText : 'Not Available',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: book.isAvailable
                  ? AppTheme.successColor
                  : AppTheme.errorColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.textSecondary),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: const TextStyle(color: AppTheme.textSecondary, fontSize: 14),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontWeight: FontWeight.w500, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  void _handleBorrow(BuildContext context, AuthProvider auth) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Borrow Book'),
        content: Text(
          'Request to borrow "${book.title}" for ${AppConstants.defaultBorrowDays} days?',
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final provider = context.read<BorrowProvider>();
              final user = auth.currentUser;
              if (user == null) return;

              final success = await provider.requestBorrow(
                book: book,
                user: user,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      success
                          ? 'Borrow request submitted!'
                          : provider.errorMessage ?? 'Request failed',
                    ),
                    backgroundColor: success ? null : AppTheme.errorColor,
                  ),
                );
              }
            },
            child: const Text('Confirm'),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Book'),
        content: Text('Are you sure you want to delete "${book.title}"?'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await context.read<BookProvider>().deleteBook(
                book,
              );
              if (context.mounted) {
                if (success) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('Book deleted')));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Failed to delete book'),
                      backgroundColor: AppTheme.errorColor,
                    ),
                  );
                }
              }
            },
            child: const Text(
              'Delete',
              style: TextStyle(color: AppTheme.errorColor),
            ),
          ),
        ],
      ),
    );
  }
}
