import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/book_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/book_provider.dart';
import '../../utils/constants.dart';
import '../../utils/theme.dart';
import '../../widgets/book_card.dart';
import '../book_detail/book_detail_screen.dart';
import 'add_edit_book_screen.dart';

/// Book catalog screen — grid of books with search and category filter.
class BookCatalogScreen extends StatefulWidget {
  const BookCatalogScreen({super.key});

  @override
  State<BookCatalogScreen> createState() => _BookCatalogScreenState();
}

class _BookCatalogScreenState extends State<BookCatalogScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Start listening to Firestore when this screen loads
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BookProvider>().startListening();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bookProvider = context.watch<BookProvider>();
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Book Catalog'),
        actions: [
          if (authProvider.isAdmin)
            IconButton(
              icon: const Icon(Icons.add),
              tooltip: 'Add Book',
              onPressed: () => _navigateToAddBook(context),
            ),
        ],
      ),
      body: Column(
        children: [
          // ── Search Bar ──
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              controller: _searchController,
              onChanged: (q) => bookProvider.setSearchQuery(q),
              decoration: InputDecoration(
                hintText: 'Search by title, author, or ISBN...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: bookProvider.searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          bookProvider.setSearchQuery('');
                        },
                      )
                    : null,
              ),
            ),
          ),

          // ── Category Chips ──
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _CategoryChip(
                  label: 'All',
                  isSelected: bookProvider.selectedCategory == null,
                  onTap: () => bookProvider.setCategory(null),
                ),
                ...AppConstants.bookCategories.map(
                  (cat) => _CategoryChip(
                    label: cat,
                    isSelected: bookProvider.selectedCategory == cat,
                    onTap: () => bookProvider.setCategory(cat),
                  ),
                ),
              ],
            ),
          ),

          // ── Book Grid ──
          Expanded(child: _buildBookGrid(bookProvider)),
        ],
      ),
    );
  }

  Widget _buildBookGrid(BookProvider provider) {
    if (provider.isLoading && provider.allBooks.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.errorMessage != null && provider.allBooks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 48,
              color: AppTheme.errorColor,
            ),
            const SizedBox(height: 12),
            Text(
              provider.errorMessage!,
              style: const TextStyle(color: AppTheme.textSecondary),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: provider.startListening,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (provider.books.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.menu_book,
              size: 64,
              color: AppTheme.primaryColor.withAlpha(100),
            ),
            const SizedBox(height: 16),
            Text(
              provider.searchQuery.isNotEmpty ||
                      provider.selectedCategory != null
                  ? 'No books match your filters'
                  : 'No books yet',
              style: const TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
            ),
            if (provider.searchQuery.isNotEmpty ||
                provider.selectedCategory != null) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  _searchController.clear();
                  provider.clearFilters();
                },
                child: const Text('Clear Filters'),
              ),
            ],
          ],
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: provider.books.length,
      itemBuilder: (context, index) {
        final book = provider.books[index];
        return BookCard(
          book: book,
          onTap: () => _navigateToDetail(context, book),
        );
      },
    );
  }

  void _navigateToDetail(BuildContext context, BookModel book) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => BookDetailScreen(book: book)),
    );
  }

  void _navigateToAddBook(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const AddEditBookScreen()),
    );
  }
}

/// Small filter chip for category selection.
class _CategoryChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _CategoryChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (_) => onTap(),
        selectedColor: AppTheme.primaryColor.withAlpha(38),
        checkmarkColor: AppTheme.primaryColor,
        labelStyle: TextStyle(
          color: isSelected ? AppTheme.primaryColor : AppTheme.textSecondary,
          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
        ),
      ),
    );
  }
}
