import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/borrow_model.dart';
import '../../providers/auth_provider.dart';
import '../../providers/borrow_provider.dart';
import '../../utils/constants.dart';
import '../../utils/theme.dart';

/// Borrow history screen — students see their borrows, admins manage all.
class BorrowHistoryScreen extends StatefulWidget {
  const BorrowHistoryScreen({super.key});

  @override
  State<BorrowHistoryScreen> createState() => _BorrowHistoryScreenState();
}

class _BorrowHistoryScreenState extends State<BorrowHistoryScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.userId != null) {
        context.read<BorrowProvider>().startListening(
          userId: auth.userId!,
          isAdmin: auth.isAdmin,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final borrowProvider = context.watch<BorrowProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text(auth.isAdmin ? 'Manage Borrows' : 'My Borrows'),
      ),
      body: Column(
        children: [
          // ── Status Filter Chips ──
          _buildFilterChips(borrowProvider),

          // ── Borrow List ──
          Expanded(child: _buildBorrowList(borrowProvider, auth.isAdmin)),
        ],
      ),
    );
  }

  Widget _buildFilterChips(BorrowProvider provider) {
    final filters = [
      {'key': 'all', 'label': 'All'},
      {'key': AppConstants.statusPending, 'label': 'Pending'},
      {'key': AppConstants.statusApproved, 'label': 'Active'},
      {'key': 'overdue', 'label': 'Overdue'},
      {'key': AppConstants.statusReturned, 'label': 'Returned'},
    ];

    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: filters.map((f) {
          final isSelected = provider.statusFilter == f['key'];
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: FilterChip(
              label: Text(f['label']!),
              selected: isSelected,
              onSelected: (_) => provider.setStatusFilter(f['key']!),
              selectedColor: AppTheme.primaryColor.withAlpha(38),
              checkmarkColor: AppTheme.primaryColor,
              labelStyle: TextStyle(
                color: isSelected
                    ? AppTheme.primaryColor
                    : AppTheme.textSecondary,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildBorrowList(BorrowProvider provider, bool isAdmin) {
    if (provider.isLoading && provider.allBorrows.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (provider.borrows.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bookmark_border,
              size: 64,
              color: AppTheme.primaryColor.withAlpha(100),
            ),
            const SizedBox(height: 16),
            Text(
              provider.statusFilter == 'all'
                  ? 'No borrow records yet'
                  : 'No ${provider.statusFilter} borrows',
              style: const TextStyle(
                fontSize: 16,
                color: AppTheme.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      itemCount: provider.borrows.length,
      itemBuilder: (context, index) {
        final borrow = provider.borrows[index];
        return _BorrowCard(borrow: borrow, isAdmin: isAdmin);
      },
    );
  }
}

/// A single borrow record card with status badge and admin actions.
class _BorrowCard extends StatelessWidget {
  final BorrowModel borrow;
  final bool isAdmin;

  const _BorrowCard({required this.borrow, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('MMM dd, yyyy');
    final effectiveStatus = borrow.isOverdue ? 'overdue' : borrow.status;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header: Book title + Status badge ──
            Row(
              children: [
                Expanded(
                  child: Text(
                    borrow.bookTitle ?? 'Unknown Book',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _StatusBadge(status: effectiveStatus),
              ],
            ),

            // ── Borrower name (admin only) ──
            if (isAdmin && borrow.userName != null) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(
                    Icons.person_outline,
                    size: 16,
                    color: AppTheme.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    borrow.userName!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 10),

            // ── Dates ──
            Row(
              children: [
                _buildDateInfo(
                  Icons.calendar_today,
                  'Borrowed',
                  dateFormat.format(borrow.borrowDate),
                ),
                const SizedBox(width: 20),
                _buildDateInfo(
                  Icons.event,
                  borrow.returnDate != null ? 'Returned' : 'Due',
                  dateFormat.format(borrow.returnDate ?? borrow.dueDate),
                ),
              ],
            ),

            // ── Days remaining (for active borrows) ──
            if (borrow.isActive) ...[
              const SizedBox(height: 8),
              Text(
                borrow.isOverdue
                    ? '${-borrow.daysRemaining} days overdue'
                    : '${borrow.daysRemaining} days remaining',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: borrow.isOverdue
                      ? AppTheme.errorColor
                      : AppTheme.successColor,
                ),
              ),
            ],

            // ── Admin Actions ──
            if (isAdmin && (borrow.isPending || borrow.isActive)) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 8),
              _buildAdminActions(context),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDateInfo(IconData icon, String label, String date) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.textHint),
        const SizedBox(width: 4),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 12, color: AppTheme.textHint),
        ),
        Text(
          date,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildAdminActions(BuildContext context) {
    final provider = context.read<BorrowProvider>();

    if (borrow.isPending) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          OutlinedButton.icon(
            onPressed: () => _handleAction(
              context,
              () => provider.rejectBorrow(borrow),
              'Borrow rejected',
            ),
            icon: const Icon(Icons.close, size: 18),
            label: const Text('Reject'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.errorColor,
              side: const BorderSide(color: AppTheme.errorColor),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton.icon(
            onPressed: () => _handleAction(
              context,
              () => provider.approveBorrow(borrow),
              'Borrow approved',
            ),
            icon: const Icon(Icons.check, size: 18),
            label: const Text('Approve'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.successColor,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          ),
        ],
      );
    }

    // Active borrow — mark as returned
    return Align(
      alignment: Alignment.centerRight,
      child: ElevatedButton.icon(
        onPressed: () => _handleAction(
          context,
          () => provider.markReturned(borrow),
          'Marked as returned',
        ),
        icon: const Icon(Icons.assignment_return, size: 18),
        label: const Text('Mark Returned'),
        style: ElevatedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        ),
      ),
    );
  }

  Future<void> _handleAction(
    BuildContext context,
    Future<bool> Function() action,
    String successMsg,
  ) async {
    final success = await action();
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(success ? successMsg : 'Action failed'),
          backgroundColor: success ? null : AppTheme.errorColor,
        ),
      );
    }
  }
}

/// Status badge with color-coded background.
class _StatusBadge extends StatelessWidget {
  final String status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (color, label) = switch (status) {
      'pending' => (AppTheme.warningColor, 'Pending'),
      'approved' => (AppTheme.successColor, 'Active'),
      'returned' => (AppTheme.textSecondary, 'Returned'),
      'overdue' => (AppTheme.errorColor, 'Overdue'),
      'rejected' => (AppTheme.errorColor, 'Rejected'),
      _ => (AppTheme.textHint, status),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}
